import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/tipos_oportunidad.dart';
import '../models/bitrix_crm.dart';
import '../models/opportunity_draft.dart';
import '../models/opportunity_service_context.dart';
import '../services/bitrix_company_matcher.dart';
import '../services/bitrix_opportunity_api.dart';
import '../services/opportunity_repository.dart';

/// Estado del formulario único de oportunidad (Calibración y Soporte).
///
/// Vive lo que vive la ruta del formulario. No conoce widgets ni
/// `BuildContext`: la pantalla le entrega [passwordPrompt] para renovar la
/// sesión. Toda respuesta que llegue después de [dispose], o de una búsqueda
/// ya reemplazada por otra, se descarta.
class OpportunityFormController extends ChangeNotifier {
  static const titleMaxLength = 255;
  static const descriptionMaxLength = 4000;
  static const notesMaxLength = 2000;

  final OpportunityServiceContext serviceContext;
  final OpportunityRepository _repository;
  final Duration _searchDebounce;
  final Future<String?> Function() _loggedUser;
  final Future<String?> Function() _appVersion;

  /// Identificador local y clave de idempotencia en Bitrix24.
  final String uuid;
  final DateTime createdAt;

  /// Abierto desde "Oportunidades" para completar una pendiente.
  final bool editingExisting;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final notesController = TextEditingController();

  /// La pantalla lo asigna: muestra el diálogo de contraseña.
  PasswordPrompt? passwordPrompt;

  bool _disposed = false;
  bool _titleEdited = false;
  String? _createdBy;
  String? _version;

  BitrixCompany? _company;
  CompanySource? _companySource;
  BitrixContact? _contact;
  List<BitrixContact> _contacts = const [];
  bool _loadingContacts = false;
  bool _contactsLoaded = false;
  String? _contactsError;

  OpportunityType? _type;
  OpportunityPriority? _priority = OpportunityPriority.media;

  /// Null = el servidor la deduce del departamento de la planta.
  String? _city;
  BitrixFormOptions? _options;

  String _query = '';
  BitrixCompanySearch? _results;
  bool _searching = false;
  String? _searchError;
  Timer? _debounce;
  int _searchSequence = 0;

  bool _busy = false;
  bool _storedLocally = false;
  String? _formError;
  Map<String, String> _fieldErrors = const {};

  OpportunityFormController({
    required this.serviceContext,
    required OpportunityRepository repository,
    required Future<String?> Function() loggedUser,
    Future<String?> Function()? appVersion,
    PendingOpportunity? existing,
    Duration searchDebounce = const Duration(milliseconds: 450),
    String? uuid,
    DateTime? now,
  })  : _repository = repository,
        _loggedUser = loggedUser,
        _appVersion = appVersion ?? (() async => null),
        _searchDebounce = searchDebounce,
        uuid = existing?.uuid ?? uuid ?? newOpportunityUuid(),
        createdAt = existing?.draft.createdAt ?? now ?? DateTime.now(),
        editingExisting = existing != null {
    final draft = existing?.draft;
    if (draft != null) {
      _storedLocally = true;
      _type = OpportunityTypeCatalog.byKey(draft.typeKey);
      _priority = draft.priority;
      _city = draft.city;
      titleController.text = draft.title;
      _titleEdited = draft.title.isNotEmpty;
      descriptionController.text = draft.description;
      notesController.text = draft.notes;
      _createdBy = draft.createdBy;
      _version = draft.appVersion;
      if (draft.companyId != null) {
        _company = BitrixCompany(
          id: draft.companyId!,
          title: draft.companyName ?? 'Empresa #${draft.companyId}',
        );
        _companySource = draft.companySource ?? CompanySource.manual;
      }
      if (draft.contactId != null) {
        _contact = BitrixContact(
          id: draft.contactId!,
          name: draft.contactName ?? '',
        );
      }
    } else {
      titleController.text = _autoTitle();
    }
    unawaited(_loadMetadata());
    unawaited(_loadFormOptions());
    unawaited(_loadRememberedCompany());
  }

  // ── Lectura ────────────────────────────────────────────────────────────

  BitrixCompany? get company => _company;

  /// Cómo se asignó [company]; null sin empresa.
  CompanySource? get companySource => _company == null ? null : _companySource;
  BitrixContact? get contact => _contact;
  List<BitrixContact> get contacts => _contacts;
  bool get loadingContacts => _loadingContacts;
  bool get contactsLoaded => _contactsLoaded;
  String? get contactsError => _contactsError;
  OpportunityType? get type => _type;
  OpportunityPriority? get priority => _priority;

  /// Ciudades de Bitrix24; vacía si no hay lista configurada o todavía no se
  /// descargó (entonces el servidor la deduce de la planta).
  List<String> get cityOptions => _options?.cities ?? const [];
  bool get cityRequired => _options?.cityRequired ?? false;
  String? get city => _city;

  /// Ciudad que corresponde al departamento de la planta cuando coincide con
  /// una opción ("LA PAZ" → "La Paz"). Las abreviaturas las resuelve el
  /// servidor.
  String? get suggestedCity {
    final department = _plain(serviceContext.plantDepartment);
    if (department.isEmpty) return null;
    for (final option in cityOptions) {
      if (_plain(option) == department) return option;
    }
    return null;
  }

  String get query => _query;
  BitrixCompanySearch? get results => _results;
  bool get searching => _searching;
  String? get searchError => _searchError;
  bool get busy => _busy;
  String? get formError => _formError;
  Map<String, String> get fieldErrors => _fieldErrors;

  /// Ya existe una copia en el teléfono (pendiente o con error).
  bool get storedLocally => _storedLocally;

  /// Hay algo escrito o elegido que se perdería al cancelar.
  bool get isDirty =>
      !_storedLocally &&
      // Una empresa propuesta por la app no es algo que el técnico pierda.
      ((_company != null && _companySource == CompanySource.manual) ||
          _type != null ||
          descriptionController.text.trim().isNotEmpty ||
          notesController.text.trim().isNotEmpty);

  /// Cliente de ServiceMET sin sufijos societarios: búsqueda inicial.
  String get suggestedQuery {
    final words = _clientWords(serviceContext.clientDisplay);
    return words.join(' ');
  }

  /// Palabras distintivas del cliente (nombre comercial y razón social) para
  /// buscar con un toque cuando los nombres no coinciden con Bitrix24.
  List<String> get searchSuggestions {
    final words = <String>[];
    for (final source in [
      serviceContext.clientName,
      serviceContext.clientLegalName,
    ]) {
      for (final word in _clientWords(source)) {
        if (word.length >= 3 &&
            !words.any((w) => w.toLowerCase() == word.toLowerCase())) {
          words.add(word);
        }
      }
    }
    return words.take(5).toList(growable: false);
  }

  // ── Empresa y contacto ─────────────────────────────────────────────────

  /// Busca empresas en Bitrix24. Espera a que el técnico deje de escribir y
  /// descarta las respuestas de búsquedas anteriores.
  void search(String query, {bool immediate = false}) {
    _query = query;
    _debounce?.cancel();
    final text = query.trim();
    if (text.length < 2) {
      _searchSequence++;
      _results = null;
      _searching = false;
      _searchError = null;
      _notify();
      return;
    }
    _searching = true;
    _searchError = null;
    _notify();
    _debounce = Timer(
      immediate ? Duration.zero : _searchDebounce,
      () => _runSearch(text),
    );
  }

  Future<void> _runSearch(String text) async {
    final sequence = ++_searchSequence;
    try {
      final results = await _repository.searchCompanies(
        text,
        onAuthRequired: passwordPrompt,
      );
      if (_disposed || sequence != _searchSequence) return;
      _results = results;
      _searchError = null;
    } on BitrixApiException catch (error) {
      if (_disposed || sequence != _searchSequence) return;
      _results = null;
      _searchError = error.retryable
          ? '${error.message} Puede guardar la oportunidad como pendiente y '
              'elegir la empresa después.'
          : error.message;
    } catch (error) {
      if (_disposed || sequence != _searchSequence) return;
      _results = null;
      _searchError = 'No se pudo buscar: $error';
    } finally {
      if (!_disposed && sequence == _searchSequence) {
        _searching = false;
        notifyListeners();
      }
    }
  }

  void selectCompany(BitrixCompany company) =>
      _setCompany(company, CompanySource.manual);

  /// Sin elegir todavía: propone la empresa que el técnico ya usó para este
  /// cliente. Se lee del teléfono, así que también sirve sin conexión.
  Future<void> _loadRememberedCompany() async {
    if (_company != null) return;
    final remembered = await _repository.rememberedCompany(serviceContext);
    if (_disposed || remembered == null || _company != null) return;
    _setCompany(remembered, CompanySource.remembered);
  }

  void _setCompany(BitrixCompany company, CompanySource source) {
    final changed = _company?.id != company.id;
    _company = company;
    _companySource = source;
    _fieldErrors = Map.of(_fieldErrors)..remove('company');
    if (changed) {
      _contact = null;
      _contacts = const [];
      _contactsLoaded = false;
    }
    _refreshAutoTitle();
    _notify();
    if (changed || !_contactsLoaded) unawaited(loadContacts());
  }

  Future<void> loadContacts() async {
    final company = _company;
    if (company == null || _loadingContacts) return;
    _loadingContacts = true;
    _contactsError = null;
    _notify();
    try {
      final contacts = await _repository.contactsOf(
        company.id,
        onAuthRequired: passwordPrompt,
      );
      if (_disposed || _company?.id != company.id) return;
      _contacts = contacts;
      _contactsLoaded = true;
      final selected = _contact;
      if (selected != null) {
        _contact = contacts.firstWhere(
          (candidate) => candidate.id == selected.id,
          orElse: () => selected,
        );
      }
    } on BitrixApiException catch (error) {
      if (_disposed || _company?.id != company.id) return;
      _contactsError = error.message;
    } catch (error) {
      if (_disposed || _company?.id != company.id) return;
      _contactsError = 'No se pudieron cargar los contactos: $error';
    } finally {
      if (!_disposed) {
        _loadingContacts = false;
        notifyListeners();
      }
    }
  }

  /// null = continuar sin contacto.
  void selectContact(BitrixContact? contact) {
    _contact = contact;
    _fieldErrors = Map.of(_fieldErrors)..remove('contact');
    _notify();
  }

  // ── Datos de la oportunidad ────────────────────────────────────────────

  void selectType(OpportunityType? type) {
    _type = type;
    _fieldErrors = Map.of(_fieldErrors)..remove('type');
    _refreshAutoTitle();
    _notify();
  }

  void selectPriority(OpportunityPriority? priority) {
    _priority = priority;
    _notify();
  }

  /// null = "Automática" (según el departamento de la planta).
  void selectCity(String? city) {
    _city = city;
    _fieldErrors = Map.of(_fieldErrors)..remove('city');
    _notify();
  }

  /// El técnico escribió el título: deja de generarse solo (salvo que lo
  /// borre por completo).
  void onTitleChanged(String value) {
    _titleEdited = value.trim().isNotEmpty;
    if (_fieldErrors.containsKey('title')) {
      _fieldErrors = Map.of(_fieldErrors)..remove('title');
      _notify();
    }
  }

  void onDescriptionChanged(String _) {
    if (_fieldErrors.containsKey('description')) {
      _fieldErrors = Map.of(_fieldErrors)..remove('description');
      _notify();
    }
  }

  String _autoTitle() => [
        'Oportunidad ServiceMET',
        _type?.label,
        _company?.title ?? serviceContext.clientDisplay,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' - ');

  void _refreshAutoTitle() {
    if (_titleEdited) return;
    final title = _autoTitle();
    titleController.value = TextEditingValue(
      text: title,
      selection: TextSelection.collapsed(offset: title.length),
    );
  }

  // ── Guardar y enviar ───────────────────────────────────────────────────

  OpportunityDraft buildDraft() {
    final type = _type ?? OpportunityTypeCatalog.otro;
    return OpportunityDraft(
      uuid: uuid,
      service: serviceContext,
      companyId: _company?.id,
      companyName: _company?.title,
      companySource: companySource,
      contactId: _contact?.id,
      contactName: _contact?.fullName,
      typeKey: type.key,
      typeLabel: type.label,
      typeLine: type.line,
      city: _city,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      priority: _priority,
      notes: notesController.text.trim(),
      createdAt: createdAt,
      createdBy: _createdBy,
      appVersion: _version,
    );
  }

  /// La empresa no se exige aquí: si falta, al registrar se busca la del
  /// cliente y, sin conexión, la oportunidad queda pendiente.
  bool _validate() {
    final errors = <String, String>{};
    if (_type == null) errors['type'] = 'Seleccione el tipo de oportunidad.';
    final title = titleController.text.trim();
    if (title.length < 3) errors['title'] = 'Escriba un título.';
    if (title.length > titleMaxLength) {
      errors['title'] = 'Máximo $titleMaxLength caracteres.';
    }
    final description = descriptionController.text.trim();
    if (description.length < 5) {
      errors['description'] = 'Describa la oportunidad detectada.';
    }
    if (description.length > descriptionMaxLength) {
      errors['description'] = 'Máximo $descriptionMaxLength caracteres.';
    }
    if (notesController.text.trim().length > notesMaxLength) {
      errors['notes'] = 'Máximo $notesMaxLength caracteres.';
    }
    // Sin departamento no hay de dónde deducirla; con uno desconocido, el
    // servidor lo informa.
    if (cityRequired &&
        _city == null &&
        _plain(serviceContext.plantDepartment).isEmpty) {
      errors['city'] = 'Elija la ciudad del prospecto.';
    }
    _fieldErrors = errors;
    _formError = errors.isEmpty ? null : 'Revise los datos marcados.';
    return errors.isEmpty;
  }

  /// Registra en Bitrix24. Devuelve null si falta completar algo o si ya se
  /// está enviando (doble toque).
  ///
  /// Sin empresa elegida usa la del cliente si hay una coincidencia segura;
  /// sin conexión, la oportunidad queda pendiente y se completa y envía sola
  /// más tarde.
  Future<OpportunitySubmitResult?> submit() async {
    if (_busy) return null;
    if (!_validate()) {
      _notify();
      return null;
    }
    _busy = true;
    _notify();
    try {
      final result = await _repository.submit(
        buildDraft(),
        onAuthRequired: passwordPrompt,
      );
      _storedLocally = true;
      if (result.outcome == OpportunitySubmitOutcome.failed) {
        _applyServerErrors(result.error);
      }
      return result;
    } catch (error) {
      _formError = 'No se pudo guardar la oportunidad: $error';
      return null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _applyServerErrors(BitrixApiException? error) {
    if (error == null) return;
    const fields = {
      'companyId': 'company',
      'contactId': 'contact',
      'opportunityType': 'type',
      'title': 'title',
      'description': 'description',
      'notes': 'notes',
      'priority': 'priority',
      'city': 'city',
    };
    final errors = <String, String>{};
    final other = <String>[];
    for (final detail in error.details) {
      final field = fields[detail.field];
      if (field == null) {
        other.add(detail.message);
      } else {
        errors[field] = detail.message;
      }
    }
    _fieldErrors = errors;
    _formError = [error.message, ...other].join('\n');
  }

  /// Primero lo guardado en el teléfono (sirve sin conexión) y luego, si hay
  /// red, lo vigente en Bitrix24.
  Future<void> _loadFormOptions() async {
    final cached = await _repository.cachedFormOptions();
    if (_disposed) return;
    if (cached != null) {
      _options = cached;
      _notify();
    }
    final fresh = await _repository.refreshFormOptions();
    if (_disposed || fresh == null) return;
    _options = fresh;
    if (_city != null && !fresh.cities.contains(_city)) _city = null;
    _notify();
  }

  Future<void> _loadMetadata() async {
    try {
      final user = _createdBy ?? await _loggedUser();
      final version = _version ?? await _appVersion();
      if (_disposed) return;
      _createdBy = user;
      _version = version;
    } catch (_) {
      // Solo son datos de referencia del registro.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    titleController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    _repository.close();
    super.dispose();
  }

  static const _stopWords = {
    'S.A.',
    'SA',
    'S.A',
    'S.R.L.',
    'SRL',
    'S.R.L',
    'LTDA',
    'LTDA.',
    'SAC',
    'S.A.C.',
    'CIA',
    'CIA.',
    'CÍA',
    'CÍA.',
    'Y',
    'DE',
    'DEL',
    'LA',
    'LAS',
    'EL',
    'LOS',
    'E',
  };

  /// Minúsculas, sin tildes ni espacios de más, para comparar nombres.
  static String _plain(String? value) {
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u'
    };
    return (value ?? '')
        .trim()
        .toLowerCase()
        .split('')
        .map((char) => accents[char] ?? char)
        .join()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> _clientWords(String? value) {
    if (value == null) return const [];
    return value
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceAll(RegExp(r'^[,;:()]+|[,;:()]+$'), ''))
        .where((word) =>
            word.isNotEmpty && !_stopWords.contains(word.toUpperCase()))
        .toList(growable: false);
  }
}
