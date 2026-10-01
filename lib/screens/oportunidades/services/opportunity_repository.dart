import 'package:flutter/foundation.dart';

import '../../../core/network/service_met_http_client.dart';
import '../models/bitrix_crm.dart';
import '../models/opportunity_draft.dart';
import '../models/opportunity_service_context.dart';
import 'bitrix_company_matcher.dart';
import 'bitrix_opportunity_api.dart';
import 'form_options_cache.dart';
import 'pending_opportunity_store.dart';

/// Pide la contraseña del técnico para renovar la sesión. [error] explica el
/// intento anterior fallido. Devuelve null si el técnico cancela.
typedef PasswordPrompt = Future<String?> Function(String? error);

enum OpportunitySubmitOutcome {
  /// Registrada en Bitrix24.
  sent,

  /// Guardada en el teléfono para enviarla después.
  savedPending,

  /// Rechazada: el técnico debe corregir los datos.
  failed,
}

class OpportunitySubmitResult {
  final OpportunitySubmitOutcome outcome;
  final PendingOpportunity? record;
  final BitrixApiException? error;
  final bool duplicate;

  const OpportunitySubmitResult._(
    this.outcome, {
    this.record,
    this.error,
    this.duplicate = false,
  });

  int? get leadId => record?.bitrixLeadId;
}

/// Qué pasó al sincronizar las oportunidades pendientes.
class OpportunitySyncReport {
  /// Registradas en Bitrix24 en esta pasada.
  final int sent;

  /// A las que se les asignó la empresa automáticamente.
  final int linked;

  /// Sin empresa segura: el técnico tiene que elegirla.
  final int needCompany;

  /// Rechazadas por el servidor: hay que revisarlas.
  final int rejected;

  /// La sesión venció: hace falta la contraseña para seguir enviando.
  final bool authRequired;

  /// Motivo por el que no hubo conexión con el servidor o con Bitrix24.
  final String? offline;

  const OpportunitySyncReport({
    this.sent = 0,
    this.linked = 0,
    this.needCompany = 0,
    this.rejected = 0,
    this.authRequired = false,
    this.offline,
  });

  /// Resumen para el técnico; null si no hay nada que contar.
  String? get message {
    final parts = [
      if (sent > 0) '$sent oportunidad(es) enviada(s) a Bitrix24.',
      if (needCompany > 0)
        '$needCompany necesita(n) que elija la empresa de Bitrix24.',
      if (rejected > 0) '$rejected con error: revísela(s).',
      if (authRequired)
        'Ingrese su contraseña para enviar las oportunidades pendientes.',
      if (offline != null && sent == 0 && !authRequired) offline!,
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// Orquesta la API METRICA y la tabla local de oportunidades.
///
/// Regla de oro: primero se guarda en el teléfono (con su UUID) y después se
/// envía. Si la conexión se corta en medio, el siguiente intento manda el
/// mismo UUID y el servidor reconoce el prospecto ya creado.
///
/// Sin conexión, la oportunidad se registra con el cliente de ServiceMET; la
/// empresa de Bitrix24 se resuelve al volver la conexión, y solo cuando es
/// seguro: la que el técnico ya eligió antes para ese cliente o una
/// coincidencia exacta de nombre. Si no, queda para que la elija él.
class OpportunityRepository {
  /// UUIDs que se están enviando ahora, en cualquier pantalla.
  static final Set<String> _inFlight = {};

  final PendingOpportunityStore _store;
  final FormOptionsCache _optionsCache;
  final String? Function() _apiUrl;
  final Future<String?> Function() _loggedUser;
  final BitrixOpportunityApi Function(String baseUrl) _apiFactory;
  BitrixOpportunityApi? _api;

  OpportunityRepository({
    required String? Function() apiUrl,
    required Future<String?> Function() loggedUser,
    PendingOpportunityStore? store,
    FormOptionsCache? optionsCache,
    BitrixOpportunityApi Function(String baseUrl)? apiFactory,
  })  : _apiUrl = apiUrl,
        _loggedUser = loggedUser,
        _store = store ?? PendingOpportunityStore(),
        _optionsCache =
            optionsCache ?? const SharedPreferencesFormOptionsCache(),
        _apiFactory = apiFactory ?? BitrixOpportunityApi.new;

  BitrixOpportunityApi _requireApi() {
    final current = _api;
    if (current != null) return current;
    final url = _apiUrl()?.trim() ?? '';
    if (url.isEmpty) {
      throw const BitrixApiException(
        'No hay un perfil de conexión con la API de METRICA.',
        kind: BitrixApiErrorKind.unavailable,
        code: 'NO_API_PROFILE',
      );
    }
    try {
      return _api = _apiFactory(url);
    } on ServiceMetNetworkException catch (error) {
      throw BitrixApiException(
        error.message,
        kind: BitrixApiErrorKind.unavailable,
        code: error.code,
      );
    }
  }

  Future<BitrixCompanySearch> searchCompanies(
    String query, {
    PasswordPrompt? onAuthRequired,
  }) =>
      _withAuth((api) => api.searchCompanies(query), onAuthRequired);

  Future<List<BitrixContact>> contactsOf(
    int companyId, {
    PasswordPrompt? onAuthRequired,
  }) =>
      _withAuth((api) => api.contactsOf(companyId), onAuthRequired);

  // ── Empresa de Bitrix24 de un cliente ──────────────────────────────────

  /// Empresa que el técnico ya eligió antes para el cliente de [service], en
  /// este teléfono. No usa la red. Null si no hay ninguna.
  Future<BitrixCompany?> rememberedCompany(
    OpportunityServiceContext service,
  ) async {
    final key = BitrixCompanyMatcher.clientKey(service);
    if (key == null) return null;
    try {
      return await _store.companyLink(key);
    } catch (error) {
      debugPrint('[Bitrix] no se pudo leer la empresa recordada: $error');
      return null;
    }
  }

  /// Busca la empresa de Bitrix24 del cliente de [service]: primero la
  /// recordada y, con conexión, una coincidencia exacta de nombre. Lanza
  /// [BitrixApiException] si no hay conexión para buscarla.
  Future<CompanyResolution> resolveCompany(
    OpportunityServiceContext service, {
    PasswordPrompt? onAuthRequired,
  }) async {
    final remembered = await rememberedCompany(service);
    if (remembered != null) {
      return CompanyResolution.found(remembered, CompanySource.remembered);
    }
    for (final query in BitrixCompanyMatcher.queries(service)) {
      final found = await searchCompanies(
        query,
        onAuthRequired: onAuthRequired,
      );
      final matches = BitrixCompanyMatcher.exactMatches(service, found.items);
      if (matches.length == 1) {
        return CompanyResolution.found(matches.single, CompanySource.exact);
      }
      if (matches.length > 1) {
        return const CompanyResolution.none(ambiguous: true);
      }
    }
    return const CompanyResolution.none();
  }

  Future<void> _remember(OpportunityDraft draft) async {
    final key = BitrixCompanyMatcher.clientKey(draft.service);
    if (key == null ||
        !draft.hasCompany ||
        draft.companySource == CompanySource.remembered) {
      return;
    }
    try {
      await _store.rememberCompany(
        key,
        clientName: draft.service.clientDisplay,
        company: BitrixCompany(
          id: draft.companyId!,
          title: draft.companyName ?? 'Empresa #${draft.companyId}',
        ),
      );
    } catch (error) {
      debugPrint('[Bitrix] no se pudo recordar la empresa: $error');
    }
  }

  // ── Opciones del formulario ────────────────────────────────────────────

  /// Últimas opciones del formulario guardadas en el teléfono.
  Future<BitrixFormOptions?> cachedFormOptions() async {
    try {
      return await _optionsCache.read();
    } catch (error) {
      debugPrint('[Bitrix] no se pudieron leer las opciones guardadas: $error');
      return null;
    }
  }

  /// Descarga las opciones del formulario y las guarda para trabajar sin
  /// conexión. Es un refresco silencioso: sin red o sin sesión devuelve null
  /// y no pide la contraseña.
  Future<BitrixFormOptions?> refreshFormOptions() async {
    final BitrixFormOptions options;
    try {
      options = await _requireApi().formOptions();
    } on BitrixApiException catch (error) {
      debugPrint('[Bitrix] opciones del formulario no disponibles: '
          '${error.code ?? error.kind}');
      return null;
    } catch (error) {
      debugPrint('[Bitrix] opciones del formulario no disponibles: $error');
      return null;
    }
    try {
      await _optionsCache.write(options);
    } catch (error) {
      debugPrint('[Bitrix] no se pudieron guardar las opciones: $error');
    }
    return options;
  }

  // ── Guardar y enviar ───────────────────────────────────────────────────

  /// Registra la oportunidad en Bitrix24. Nunca lanza por falta de red: en
  /// ese caso la deja pendiente y lo informa en el resultado.
  ///
  /// Sin empresa elegida, primero la resuelve ([resolveCompany]). Si no hay
  /// conexión, la oportunidad queda pendiente y la sincronización la
  /// completa después; si no hay una coincidencia segura, falla con
  /// `COMPANY_NOT_RESOLVED` para que el técnico la elija.
  Future<OpportunitySubmitResult> submit(
    OpportunityDraft draft, {
    PasswordPrompt? onAuthRequired,
  }) async {
    if (!_inFlight.add(draft.uuid)) {
      return OpportunitySubmitResult._(
        OpportunitySubmitOutcome.failed,
        error: const BitrixApiException(
          'Esta oportunidad ya se está enviando.',
          kind: BitrixApiErrorKind.rejected,
          code: 'IN_FLIGHT',
        ),
      );
    }
    try {
      final previous = await _store.byUuid(draft.uuid);
      if (previous != null && previous.isSent) {
        return OpportunitySubmitResult._(
          OpportunitySubmitOutcome.sent,
          record: previous,
          duplicate: true,
        );
      }
      if (!draft.hasCompany) {
        final resolved = await _withCompany(draft, onAuthRequired);
        if (resolved.result != null) return resolved.result!;
        draft = resolved.draft;
      }
      await _store.save(
        draft,
        status: OpportunityStatus.sending,
        countAttempt: true,
      );
      await _remember(draft);
      try {
        final created = await _withAuth(
          (api) => api.createOpportunity(draft),
          onAuthRequired,
        );
        final record = await _store.markSent(draft.uuid, created.leadId);
        debugPrint(
            '[Bitrix] oportunidad enviada: prospecto #${created.leadId}');
        return OpportunitySubmitResult._(
          OpportunitySubmitOutcome.sent,
          record: record,
          duplicate: created.duplicate,
        );
      } on BitrixApiException catch (error) {
        final keepPending =
            error.retryable || error.kind == BitrixApiErrorKind.authRequired;
        final record = await _store.markFailed(
          draft.uuid,
          status:
              keepPending ? OpportunityStatus.pending : OpportunityStatus.error,
          error: error.message,
        );
        debugPrint('[Bitrix] envío no completado: ${error.code ?? error.kind}');
        return OpportunitySubmitResult._(
          keepPending
              ? OpportunitySubmitOutcome.savedPending
              : OpportunitySubmitOutcome.failed,
          record: record,
          error: error,
        );
      }
    } finally {
      _inFlight.remove(draft.uuid);
    }
  }

  /// Asigna a [draft] la empresa de su cliente. Si no se puede, devuelve el
  /// resultado con el que termina el envío.
  Future<({OpportunityDraft draft, OpportunitySubmitResult? result})>
      _withCompany(
    OpportunityDraft draft,
    PasswordPrompt? onAuthRequired,
  ) async {
    final CompanyResolution resolution;
    try {
      resolution = await resolveCompany(
        draft.service,
        onAuthRequired: onAuthRequired,
      );
    } on BitrixApiException catch (error) {
      final keepPending =
          error.retryable || error.kind == BitrixApiErrorKind.authRequired;
      final record = await _store.save(
        draft,
        status: OpportunityStatus.pending,
        lastError: keepPending ? null : error.message,
      );
      debugPrint('[Bitrix] empresa sin resolver: ${error.code ?? error.kind}');
      return (
        draft: draft,
        result: OpportunitySubmitResult._(
          keepPending
              ? OpportunitySubmitOutcome.savedPending
              : OpportunitySubmitOutcome.failed,
          record: record,
          error: error,
        ),
      );
    }
    final company = resolution.company;
    if (company == null) {
      final record = await _store.save(
        draft,
        status: OpportunityStatus.pending,
        lastError: resolution.message,
      );
      return (
        draft: draft,
        result: OpportunitySubmitResult._(
          OpportunitySubmitOutcome.failed,
          record: record,
          error: BitrixApiException(
            resolution.message,
            kind: BitrixApiErrorKind.validation,
            code: companyNotResolved,
            details: [BitrixFieldError('companyId', resolution.message)],
          ),
        ),
      );
    }
    return (
      draft: draft.withCompany(company, resolution.source!),
      result: null
    );
  }

  /// Código del error cuando no hay una empresa segura para el cliente.
  static const companyNotResolved = 'COMPANY_NOT_RESOLVED';

  /// Reenvía una oportunidad guardada, con su mismo UUID y contenido.
  Future<OpportunitySubmitResult> resend(
    PendingOpportunity record, {
    PasswordPrompt? onAuthRequired,
  }) =>
      submit(record.draft, onAuthRequired: onAuthRequired);

  /// Completa y envía todo lo pendiente: a las oportunidades sin empresa les
  /// busca la del cliente y después las registra en Bitrix24. Se detiene en
  /// cuanto falta la conexión o la sesión, y no reintenta las que el
  /// servidor rechazó.
  ///
  /// Sin [onAuthRequired] (sincronización automática) nunca pide la
  /// contraseña: lo informa en el resultado.
  Future<OpportunitySyncReport> syncPending({
    PasswordPrompt? onAuthRequired,
  }) async {
    var sent = 0, linked = 0, needCompany = 0, rejected = 0;
    var authRequired = false;
    String? offline;

    final records = (await _store.list(sentLimit: 0))
        .where((record) => record.canSync)
        .toList();
    for (final record in records) {
      final hadCompany = record.draft.hasCompany;
      final result = await submit(
        record.draft,
        onAuthRequired: onAuthRequired,
      );
      final error = result.error;
      if (!hadCompany && (result.record?.draft.hasCompany ?? false)) linked++;
      switch (result.outcome) {
        case OpportunitySubmitOutcome.sent:
          sent++;
        case OpportunitySubmitOutcome.failed:
          if (error?.code == companyNotResolved) {
            needCompany++;
          } else if (error?.code != 'IN_FLIGHT') {
            rejected++;
          }
        case OpportunitySubmitOutcome.savedPending:
          if (error?.kind == BitrixApiErrorKind.authRequired) {
            authRequired = true;
          } else {
            offline = error?.message ?? 'Sin conexión con el servidor.';
          }
      }
      // Sin sesión o sin conexión no tiene sentido seguir con las demás.
      if (authRequired || offline != null) break;
    }
    return OpportunitySyncReport(
      sent: sent,
      linked: linked,
      needCompany: needCompany,
      rejected: rejected,
      authRequired: authRequired,
      offline: offline,
    );
  }

  Future<List<PendingOpportunity>> list() => _store.list();

  Future<int> countUnsent() => _store.countUnsent();

  Future<bool> discard(String uuid) => _store.discard(uuid);

  /// Ejecuta [operation]; si la sesión venció pide la contraseña (hasta tres
  /// veces si es incorrecta) y reintenta una sola vez.
  Future<T> _withAuth<T>(
    Future<T> Function(BitrixOpportunityApi api) operation,
    PasswordPrompt? onAuthRequired,
  ) async {
    final api = _requireApi();
    try {
      return await operation(api);
    } on BitrixApiException catch (error) {
      if (error.kind != BitrixApiErrorKind.authRequired ||
          onAuthRequired == null) {
        rethrow;
      }
      final usuario = await _loggedUser();
      if (usuario == null || usuario.isEmpty) {
        throw const BitrixApiException(
          'No hay un usuario activo. Cierre sesión e ingrese nuevamente.',
          kind: BitrixApiErrorKind.authRequired,
          code: 'NO_USER',
        );
      }
      String? message;
      for (var attempt = 0; attempt < 3; attempt++) {
        final password = await onAuthRequired(message);
        if (password == null || password.isEmpty) rethrow;
        try {
          await api.authenticate(usuario: usuario, password: password);
        } on BitrixApiException catch (authError) {
          if (authError.kind != BitrixApiErrorKind.authRequired) rethrow;
          message = authError.message;
          continue;
        }
        return operation(api);
      }
      rethrow;
    }
  }

  void close() {
    _api?.close();
    _api = null;
  }
}
