import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/calibration_data_normalizer.dart';
import 'package:service_met/database/calibration_record_validator.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/utils/scale_range_validator.dart';

typedef _StepIssue = ({String message, String? column});

class ServiceSessionProvider extends ChangeNotifier {
  final CalibrationRepository _repository;

  ServiceSession? _session;
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _lastSaveSuccessful = true;
  String? _saveError;
  Timer? _autoSaveTimer;

  // D-values cache
  Map<String, double> _dValues = {};

  String _cotizacionSuffix = 'C01';

  // QR mode
  bool _isQrMode = false;
  String? _qrCodMetrica;

  // Navigation flag: si se activa, al presionar "Siguiente" en paso 5,
  // vuelve directo a condiciones finales (paso 10) en vez de paso 6
  bool _returnToCondicionesFinales = false;

  // Navigation flag: indica que el usuario agregó otra balanza desde finalización
  bool _addingNuevaBalanza = false;

  ServiceSessionProvider(this._repository);

  // --- Getters ---
  ServiceSession? get session => _session;
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasPendingSave => _autoSaveTimer?.isActive ?? false;
  bool get lastSaveSuccessful => _lastSaveSuccessful;

  /// Por qué la base rechazó el último guardado. Mientras no sea null, lo que
  /// se escribe queda solo en memoria y se pierde al cerrar la aplicación.
  String? get saveError => _saveError;
  String get cotizacionSuffix => _cotizacionSuffix;
  bool get isQrMode => _isQrMode;
  String? get qrCodMetrica => _qrCodMetrica;
  bool get returnToCondicionesFinales => _returnToCondicionesFinales;
  set returnToCondicionesFinales(bool v) {
    _returnToCondicionesFinales = v;
    notifyListeners();
  }

  bool get addingNuevaBalanza => _addingNuevaBalanza;
  set addingNuevaBalanza(bool v) {
    _addingNuevaBalanza = v;
    notifyListeners();
  }

  // --- Datos del servicio anterior ---

  Map<String, dynamic>? _previousServiceData;

  /// Datos del último servicio registrado para la balanza seleccionada.
  Map<String, dynamic>? get previousServiceData => _previousServiceData;

  /// Carga los datos del último servicio desde la precarga para el código métrica dado.
  /// Si el código es el mismo que ya está cargado, no vuelve a consultar.
  Future<void> loadPreviousServiceData(String codMetrica) async {
    if (_previousServiceData != null &&
        _session?.sessionInfo.codMetrica == codMetrica) {
      return;
    }
    _previousServiceData = await _repository.getServicioAnterior(codMetrica);
    notifyListeners();
  }

  /// Limpia los datos del servicio anterior (ej. al cambiar de balanza).
  void clearPreviousServiceData() {
    _previousServiceData = null;
    notifyListeners();
  }

  // ─── Progreso (servicio_status) ──────────────────────────────────────────

  Future<void> _saveCurrentProgress({String? status}) async {
    final s = _session;
    if (s == null) return;
    final seca = s.sessionInfo.seca;
    final sessionId = s.sessionInfo.sessionId;
    final userName = s.sessionInfo.userName;
    if (seca == null || sessionId == null || userName == null) return;
    try {
      // Preservar status existente si no se pasa uno explícito
      String resolvedStatus;
      if (status != null) {
        resolvedStatus = status;
      } else {
        final existing = await _repository.loadProgress(seca, sessionId);
        resolvedStatus = existing?['status']?.toString() ?? 'in_progress';
      }

      await _repository.saveProgress(
        seca: seca,
        sessionId: sessionId,
        personal: userName,
        currentStep: _currentStep,
        secaConfirmed: s.metadata.secaConfirmed,
        balanzaConfirmed: s.metadata.balanzaConfirmed,
        status: resolvedStatus,
      );
    } catch (e) {
      debugPrint('Error guardando progreso: $e');
    }
  }

  // --- Inicialización ---

  Future<void> initialize({
    required String userName,
    String? secaValue,
    String? sessionId,
  }) async {
    _isLoading = true;
    notifyListeners();

    if (secaValue != null && sessionId != null) {
      await loadExistingSession(secaValue, sessionId);
      if (_session == null) {
        await createNewSession(userName, secaValue: secaValue);
      }
    } else {
      await createNewSession(userName);
    }

    // Crear/actualizar entrada de progreso al iniciar
    if (_session != null &&
        _session!.sessionInfo.seca != null &&
        _session!.sessionInfo.sessionId != null) {
      await _saveCurrentProgress();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createNewSession(String userName, {String? secaValue}) async {
    clearQrMode();
    _cotizacionSuffix = 'C01';
    _saveError = null;
    _lastSaveSuccessful = true;
    _session = ServiceSession(
      sessionInfo: SessionInfo(
        userName: userName,
        seca: secaValue,
        fechaServicio: DateTime.now().toIso8601String().split('T')[0],
      ),
      metadata: SessionMetadata(currentStep: 0),
    );
    _currentStep = 0;
  }

  Future<void> loadExistingSession(String seca, String sessionId) async {
    _saveError = null;
    _lastSaveSuccessful = true;
    _session = await _repository.loadSession(seca, sessionId);
    if (_session != null) {
      _currentStep = _session!.metadata.currentStep;
      _dValues = await _repository.getDValues(seca, sessionId);
    }
  }

  // --- Navegación ---

  void goToStep(int step) {
    if (step >= 0 && step < 11 && _session != null) {
      _currentStep = step;
      _session = _session!
          .copyWith(metadata: _session!.metadata.copyWith(currentStep: step));
      notifyListeners();
      _scheduleAutoSave();
      _saveCurrentProgress();
    }
  }

  void nextStep() {
    if (_currentStep < 10) {
      goToStep(_currentStep + 1);
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      goToStep(_currentStep - 1);
    }
  }

  bool canGoToStep(int step) {
    if (_session == null) return false;

    // Paso 0: Cliente (siempre accesible)
    if (step == 0) return true;

    // Paso 1: Planta (requiere Cliente seleccionado o nuevo)
    if (step >= 1) {
      if (_session!.cliente?.nombreComercial == null ||
          _session!.cliente!.nombreComercial!.isEmpty) {
        return false;
      }
    }

    // Paso 2: SECA (requiere Planta seleccionada o nueva)
    if (step >= 2) {
      if (_session!.planta?.nombre == null ||
          _session!.planta!.nombre!.isEmpty) {
        return false;
      }
    }

    // Paso 3+: Instrumento y resto (requiere SECA confirmado)
    if (step >= 3) {
      if (!_session!.metadata.secaConfirmed) {
        return false;
      }
    }

    return true;
  }

  // --- Update Methods ---

  void updateSessionInfo(SessionInfo info) {
    if (_session == null) return;
    _session = _session!.copyWith(sessionInfo: info);
    notifyListeners();
    _scheduleAutoSave();
  }

  void updateCliente(ClienteInfo cliente) {
    if (_session == null) return;
    final anterior = _session!.cliente;
    // Una sesión recuperada de la base no trae el id del catálogo ni si el
    // cliente era nuevo: se compara por código o nombre, para que volver a
    // tocar el mismo cliente no borre la planta.
    final recuperado =
        anterior != null && anterior.id == null && anterior.isNew == null;
    final cambioCliente = recuperado
        ? !_mismoCliente(anterior, cliente)
        : anterior?.id != cliente.id || anterior?.isNew != cliente.isNew;
    _session = _session!.copyWith(
      cliente: cliente,
      planta: cambioCliente ? PlantaInfo() : _session!.planta,
    );
    notifyListeners();
    _scheduleAutoSave();
  }

  void updatePlanta(PlantaInfo planta) {
    if (_session == null) return;
    _session = _session!.copyWith(planta: planta);
    notifyListeners();
    _scheduleAutoSave();
  }

  void updateBalanza(BalanzaInfo balanza) {
    if (_session == null) return;
    _session = _session!.copyWith(balanza: balanza);
    notifyListeners();
    _scheduleAutoSave();
  }

  void updateEquipos(List<EquipoInfo> equipos) {
    if (_session == null) return;
    _session = _session!.copyWith(equipos: equipos);
    notifyListeners();
    _scheduleAutoSave();
  }

  /// Una sesión contiene patrones e instrumentos ambientales en la misma lista.
  /// Cada paso modifica solo su parte para conservar lo elegido en el otro.
  static bool isPatronType(String? type) {
    final value = type?.toLowerCase() ?? '';
    return value.contains('pesa') ||
        value.contains('masa') ||
        value.contains('patron') ||
        value.contains('patr');
  }

  void updatePatronWeights(List<EquipoInfo> weights) {
    final other =
        _session?.equipos.where((e) => !isPatronType(e.tipo)).toList() ??
            <EquipoInfo>[];
    updateEquipos([...weights, ...other]);
  }

  void updateMeasuringInstruments(List<EquipoInfo> instruments) {
    final weights =
        _session?.equipos.where((e) => isPatronType(e.tipo)).toList() ??
            <EquipoInfo>[];
    updateEquipos([...weights, ...instruments]);
  }

  void updateInspeccionVisual(InspeccionVisual data) {
    if (_session == null) return;
    _session = _session!.copyWith(inspeccion: data);
    notifyListeners();
    _scheduleAutoSave();
  }

  void updatePrecargasAjuste(PrecargasAjuste data) {
    if (_session == null) return;
    _session = _session!.copyWith(precargasAjuste: data);
    notifyListeners();
    _scheduleAutoSave();
  }

  void updateExcentricidad(ExcentricidadData data) {
    if (_session == null) return;
    _session = _session!.copyWith(excentricidad: data);
    notifyListeners();
    _scheduleAutoSave();
  }

  void updateRepetibilidad(RepetibilidadData data) {
    if (_session == null) return;
    _session = _session!.copyWith(repetibilidad: data);
    notifyListeners();
    _scheduleAutoSave();
  }

  void updateLinealidad(LinealidadData data) {
    if (_session == null) return;
    _session = _session!.copyWith(linealidad: data);
    notifyListeners();
    _scheduleAutoSave();
  }

  void updateCondicionesFinales(CondicionesFinales data) {
    if (_session == null) return;
    _session = _session!.copyWith(condicionesFinales: data);
    notifyListeners();
    _scheduleAutoSave();
  }

  void updateExportacion(ExportacionData data) {
    if (_session == null) return;
    _session = _session!.copyWith(exportacion: data);
    notifyListeners();
    _scheduleAutoSave();
  }

  // --- Auto-Save ---

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () {
      _autoSave();
    });
  }

  /// Guarda ya lo pendiente. Devuelve false si la base rechazó los datos; el
  /// motivo queda en [saveError]. Quien avance de paso o cierre la balanza
  /// debe detenerse si es false: lo escrito sigue solo en memoria.
  Future<bool> flushAutoSave() async {
    _autoSaveTimer?.cancel();
    return _autoSave();
  }

  /// Escribe ya el autoguardado que está esperando, si lo hay.
  Future<void> flushPendingSave() async {
    if (_autoSaveTimer?.isActive ?? false) await flushAutoSave();
  }

  Future<bool> _autoSave() async {
    final session = _session;
    final seca = session?.sessionInfo.seca;
    final sessionId = session?.sessionInfo.sessionId;
    // Antes de confirmar la SECA no hay registro donde guardar.
    if (session == null || seca == null || sessionId == null) return true;

    _isSaving = true;
    notifyListeners();

    try {
      await _repository.saveSession(seca, sessionId, session);
      _lastSaveSuccessful = true;
      _saveError = null;
      // Actualizar dValues
      _dValues = await _repository.getDValues(seca, sessionId);
      return true;
    } catch (e) {
      _lastSaveSuccessful = false;
      _saveError = _describeSaveError(session, e);
      debugPrint('Error en auto-save: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Un valor fuera de esquema rechaza el registro entero: se listan todos los
  /// que lo impiden, con su nombre en pantalla, para que se corrijan.
  String _describeSaveError(ServiceSession session, Object error) {
    if (error is! CalibrationDataException) {
      return 'No se pudo guardar en el teléfono: $error';
    }
    final issues = CalibrationRecordValidator.schemaIssues(session.toMap());
    if (issues.isEmpty) {
      return 'No se pudo guardar: '
          '${CalibrationRecordValidator.issueFor(error)}';
    }
    final shown = issues.take(3).join('\n');
    final more =
        issues.length > 3 ? '\n(y ${issues.length - 3} dato(s) más)' : '';
    return 'No se pudo guardar. Corrija:\n$shown$more';
  }

  // --- Helpers ---

  double getDForCarga(double carga) {
    return _repository.getDFromCarga(carga, _dValues);
  }

  int getDecimalPlaces(double carga) {
    double dValue = getDForCarga(carga);
    return _repository.getDecimalPlaces(dValue);
  }

  void setCotizacionSuffix(String val) {
    _cotizacionSuffix = val;
    notifyListeners();
  }

  /// La cotización del servicio (C01, C02...): la del SECA ya confirmado o,
  /// mientras se lo arma, la que se está escribiendo. Al continuar un
  /// servicio lo escrito al crearlo ya no está en memoria, así que sale del
  /// SECA guardado: `<código de planta>-<cotización>-<año>`, y el código de
  /// planta lleva su propio guion.
  String get cotizacion {
    final parts = _session?.sessionInfo.seca?.split('-') ?? const <String>[];
    if (parts.length >= 3) return parts[parts.length - 2];
    return _cotizacionSuffix.isEmpty ? 'C01' : _cotizacionSuffix;
  }

  String getProposedSeca() {
    final plantaCod = _session?.planta?.codigo ?? 'NNNN-NN';
    final year = DateTime.now().year.toString().substring(2);
    final cotizacion = _cotizacionSuffix.isEmpty ? 'C01' : _cotizacionSuffix;
    return '$plantaCod-$cotizacion-$year';
  }

  Future<bool> confirmSeca() async {
    if (_session == null) return false;

    final seca = getProposedSeca();

    String sessionId = await _repository.generateSessionId(seca);

    _session = _session!.copyWith(
      sessionInfo: _session!.sessionInfo.copyWith(
        seca: seca,
        sessionId: sessionId,
      ),
      metadata: _session!.metadata.copyWith(secaConfirmed: true),
    );

    final saved = await flushAutoSave();
    await _saveCurrentProgress();
    return saved;
  }

  // ==================== MÉTODOS QR ====================

  Future<String?> processQrCode(String codMetrica) async {
    _isQrMode = true;
    _qrCodMetrica = codMetrica;

    final parts = codMetrica.trim().split('-');
    if (parts.length < 3) {
      _isQrMode = false;
      _qrCodMetrica = null;
      return 'Formato de código QR inválido: $codMetrica';
    }

    // El QR puede contener texto extra después del código métrica
    // Ej: "0032-11-020 Balanza X Marca Y" → limpiamos
    final suffix = RegExp(r'^\d+').stringMatch(parts[2]) ?? '';
    final codigoCliente = parts[0];
    final codigoPlanta = '${parts[0]}-${parts[1]}';
    final cleanMetrica = '${parts[0]}-${parts[1]}-$suffix';
    _qrCodMetrica = cleanMetrica;

    // 1. Buscar y auto-seleccionar cliente
    final clientes = await _repository.getClientes();
    final clienteMatch = clientes.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['codigo_cliente']?.toString().trim() == codigoCliente,
          orElse: () => null,
        );

    if (clienteMatch == null) {
      _isQrMode = false;
      _qrCodMetrica = null;
      return 'No se encontró cliente con código: $codigoCliente';
    }

    updateCliente(ClienteInfo(
      id: clienteMatch['cliente_id']?.toString(),
      codigoCliente: codigoCliente,
      nombreComercial: clienteMatch['cliente']?.toString(),
      razonSocial: clienteMatch['razonsocial']?.toString(),
      isNew: false,
    ));

    // 2. Buscar y auto-seleccionar planta
    final allPlantas = await _repository
        .getPlantas(clienteMatch['cliente_id']?.toString() ?? '');

    final plantaMatch = allPlantas.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p?['codigo_planta']?.toString().trim() == codigoPlanta,
          orElse: () => null,
        );

    if (plantaMatch == null) {
      _isQrMode = false;
      _qrCodMetrica = null;
      return 'No se encontró planta con código: $codigoPlanta';
    }

    updatePlanta(PlantaInfo(
      id: plantaMatch['planta_id']?.toString() ??
          plantaMatch['unique_key']?.toString(),
      codigo: codigoPlanta,
      nombre: plantaMatch['planta']?.toString(),
      direccion: plantaMatch['dir']?.toString(),
      departamento: plantaMatch['dep']?.toString(),
      isNew: false,
    ));

    // 3. Avanzar al paso SECA
    goToStep(2);

    return null;
  }

  Future<String?> autoSelectBalanzaFromQr() async {
    if (!_isQrMode || _qrCodMetrica == null) return null;

    final clienteCod = _session?.cliente?.codigoCliente;
    final plantaCod = _session?.planta?.codigo;
    final balanzas = await _repository.getBalanzas(clienteCod, plantaCod);

    final balanzaMatch = balanzas.cast<Map<String, dynamic>?>().firstWhere(
          (b) => b?['cod_metrica']?.toString().trim() == _qrCodMetrica?.trim(),
          orElse: () => null,
        );

    if (balanzaMatch == null) {
      return 'El código QR no pertenece al cliente y planta seleccionados';
    }

    updateBalanza(BalanzaInfo(
      codMetrica: balanzaMatch['cod_metrica']?.toString(),
      categoria: balanzaMatch['categoria']?.toString(),
      tecnologia: balanzaMatch['tecnologia']?.toString(),
      clase: balanzaMatch['clase']?.toString(),
      codInterno: balanzaMatch['cod_interno']?.toString(),
      tipo: balanzaMatch['tipo_instrumento']?.toString() ??
          balanzaMatch['instrumento']?.toString(),
      marca: balanzaMatch['marca']?.toString(),
      modelo: balanzaMatch['modelo']?.toString(),
      serie: balanzaMatch['inf_serie']?.toString() ??
          balanzaMatch['serie']?.toString(),
      unidad: balanzaMatch['unidad']?.toString(),
      ubicacion: balanzaMatch['ubicacion']?.toString(),
      rango: balanzaMatch['rango']?.toString(),
      nCeldas: balanzaMatch['n_celdas']?.toString(),
      capMax1: balanzaMatch['cap_max1']?.toString(),
      d1: double.tryParse(balanzaMatch['d1']?.toString() ?? ''),
      e1: double.tryParse(balanzaMatch['e1']?.toString() ?? ''),
      dec1: double.tryParse(balanzaMatch['dec1']?.toString() ?? ''),
      capMax2: balanzaMatch['cap_max2']?.toString(),
      d2: double.tryParse(balanzaMatch['d2']?.toString() ?? ''),
      e2: double.tryParse(balanzaMatch['e2']?.toString() ?? ''),
      dec2: double.tryParse(balanzaMatch['dec2']?.toString() ?? ''),
      capMax3: balanzaMatch['cap_max3']?.toString(),
      d3: double.tryParse(balanzaMatch['d3']?.toString() ?? ''),
      e3: double.tryParse(balanzaMatch['e3']?.toString() ?? ''),
      dec3: double.tryParse(balanzaMatch['dec3']?.toString() ?? ''),
    ));

    return null;
  }

  void clearQrMode() {
    _isQrMode = false;
    _qrCodMetrica = null;
    notifyListeners();
  }

  void setBalanzaConfirmed(bool confirmed) {
    if (_session == null) return;
    _session = _session!.copyWith(
      metadata: _session!.metadata.copyWith(balanzaConfirmed: confirmed),
    );
    notifyListeners();
  }

  String? validateBalanza() {
    final issues = _withSession(_balanzaIssues);
    return issues.isEmpty ? null : issues.first.message;
  }

  static List<_StepIssue> _balanzaIssues(ServiceSession session) {
    final issues = <_StepIssue>[];
    final info = session.sessionInfo;
    if (info.nReca == null || info.nReca!.trim().isEmpty) {
      issues.add((message: 'Debe ingresar el Nro. RECA.', column: null));
    }
    if (info.sticker == null || info.sticker!.trim().isEmpty) {
      issues.add((message: 'Debe ingresar el Nro. Sticker.', column: null));
    }

    final b = session.balanza;
    if (b == null) {
      issues.add(
          (message: 'Debe seleccionar o registrar una balanza.', column: null));
      return issues;
    }
    if (b.codMetrica == null || b.codMetrica!.trim().isEmpty) {
      issues.add((message: 'Falta el Codigo Metrica.', column: null));
    }
    if (b.tipo == null || b.tipo!.trim().isEmpty) {
      issues.add((message: 'Falta el Tipo de Instrumento.', column: null));
    }
    if (b.marca == null || b.marca!.trim().isEmpty) {
      issues.add((message: 'Falta la Marca.', column: null));
    }
    if (b.modelo == null || b.modelo!.trim().isEmpty) {
      issues.add((message: 'Falta el Modelo.', column: null));
    }
    if (b.serie == null || b.serie!.trim().isEmpty) {
      issues.add((message: 'Falta la Serie.', column: null));
    }
    final rangeError = ScaleRangeValidator.validate([
      ScaleRangeValues(
        capacity: b.capMax1,
        division: b.d1,
        verificationDivision: b.e1,
        decimals: b.dec1,
      ),
      ScaleRangeValues(
        capacity: b.capMax2,
        division: b.d2,
        verificationDivision: b.e2,
        decimals: b.dec2,
      ),
      ScaleRangeValues(
        capacity: b.capMax3,
        division: b.d3,
        verificationDivision: b.e3,
        decimals: b.dec3,
      ),
    ]);
    if (rangeError != null) {
      issues.add((message: rangeError, column: null));
    }
    return issues;
  }

  Future<String?> validateDuplicateBalanza() async {
    final info = _session?.sessionInfo;
    final seca = info?.seca?.trim() ?? '';
    final sessionId = info?.sessionId?.trim() ?? '';
    final codMetrica = _session?.balanza?.codMetrica?.trim() ?? '';
    if (seca.isEmpty || sessionId.isEmpty || codMetrica.isEmpty) return null;
    final duplicate = await _repository.findDuplicateService(
      seca: seca,
      codMetrica: codMetrica,
      excludingSessionId: sessionId,
    );
    if (duplicate == null) return null;
    final status =
        duplicate['estado_servicio_bal']?.toString() == 'Balanza Calibrada'
            ? 'ya fue calibrada'
            : 'ya tiene una calibración en curso';
    return 'La balanza $codMetrica $status dentro del SECA $seca. '
        'Continúe o revise el registro existente en lugar de crear otro.';
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static bool _mismoCliente(ClienteInfo a, ClienteInfo b) {
    bool igual(String? x, String? y) => !_isBlank(x) && x!.trim() == y?.trim();
    return igual(a.codigoCliente, b.codigoCliente) ||
        igual(a.nombreComercial, b.nombreComercial);
  }

  /// Lo que impide dejar el paso [step]: primero un dato que la base
  /// rechazaría, después un dato obligatorio vacío. Null si se puede avanzar.
  ///
  /// El chequeo de esquema es el mismo que aplica el guardado: si pasa aquí,
  /// el paso se guarda.
  List<({String message, String? column})> stepIssues(int step) {
    final session = _session;
    if (session == null) {
      return [(message: 'Sesión no inicializada.', column: null)];
    }
    return issuesForStep(session, step);
  }

  /// Las mismas reglas de [stepIssues] aplicadas a cualquier sesión, también
  /// a una balanza guardada que no está abierta: así la lista del servicio y
  /// la revisión de cada balanza no pueden discrepar.
  static List<({String message, String? column})> issuesForStep(
      ServiceSession session, int step) {
    final issues = <_StepIssue>[
      for (final issue
          in CalibrationRecordValidator.schemaIssues(session.toMap())
              .where((issue) => issue.step == step))
        (message: '$issue', column: issue.column),
    ];
    final required = switch (step) {
      3 => _balanzaIssues(session),
      4 => _inspeccionIssues(session),
      5 => _precargasIssues(session),
      6 => _excentricidadIssues(session),
      7 => _repetibilidadIssues(session),
      8 => _linealidadIssues(session),
      9 => _condicionesFinalesIssues(session),
      _ => <_StepIssue>[],
    };
    for (final issue in required) {
      if (!issues.any((existing) => existing.message == issue.message)) {
        issues.add(issue);
      }
    }
    return issues;
  }

  /// Pasos de medición de una balanza (instrumento a condiciones finales).
  static const measurementSteps = [3, 4, 5, 6, 7, 8, 9];

  static const stepNames = {
    3: 'Instrumento',
    4: 'Inspección visual',
    5: 'Precarga y ajuste',
    6: 'Excentricidad',
    7: 'Repetibilidad',
    8: 'Linealidad',
    9: 'Condiciones finales',
  };

  /// Todo lo que le falta a [session] para darse por calibrada, con el paso
  /// donde se corrige. Vacío si la balanza está completa.
  static List<({int step, String message})> calibrationIssues(
      ServiceSession session) {
    return [
      if (!session.metadata.balanzaConfirmed)
        (step: 3, message: 'Confirma los datos del instrumento.'),
      for (final step in measurementSteps)
        for (final issue in issuesForStep(session, step))
          (step: step, message: issue.message),
    ];
  }

  /// Texto breve para explicar por qué la balanza no puede cerrarse.
  static String describeCalibrationIssues(
      List<({int step, String message})> issues) {
    final lines = [
      for (final issue in issues.take(4))
        '• ${stepNames[issue.step]}: ${issue.message}',
      if (issues.length > 4) '• y ${issues.length - 4} dato(s) más.',
    ];
    return 'Faltan datos para dar la balanza por calibrada:\n'
        '${lines.join('\n')}';
  }

  List<_StepIssue> _withSession(
      List<_StepIssue> Function(ServiceSession) issues) {
    final session = _session;
    if (session == null) {
      return [(message: 'Sesión no inicializada.', column: null)];
    }
    return issues(session);
  }

  String? validateStep(int step) {
    final issues = stepIssues(step);
    return issues.isEmpty ? null : issues.first.message;
  }

  String? validateCondicionesFinales() {
    final issues = _withSession(_condicionesFinalesIssues);
    return issues.isEmpty ? null : issues.first.message;
  }

  static List<_StepIssue> _condicionesFinalesIssues(ServiceSession session) {
    final issues = <_StepIssue>[];
    final cf = session.condicionesFinales;
    if (_isBlank(cf?.horaFin)) {
      issues.add((
        message: 'Registre la Hora Fin con el botón del reloj.',
        column: null
      ));
    }
    if (_isBlank(cf?.hriFin)) {
      issues.add((
        message: 'Debe ingresar la Humedad Relativa final (HRi Fin).',
        column: 'hri_fin'
      ));
    }
    if (_isBlank(cf?.tiFin)) {
      issues.add((
        message: 'Debe ingresar la Temperatura final (Ti Fin).',
        column: 'ti_fin'
      ));
    }
    if (_isBlank(cf?.patmiFin)) {
      issues.add((
        message: 'Debe ingresar la Presión Atmosférica final (Patmi Fin).',
        column: 'patmi_fin'
      ));
    }
    if (!session.equipos.any((e) => isPatronType(e.tipo))) {
      issues.add((
        message: 'Debe seleccionar al menos una pesa patron.',
        column: null
      ));
    }
    return issues;
  }

  String? validarCondicionesAmbientales() {
    if (_session == null) return null;
    final iniciales = _session!.precargasAjuste;
    final finales = _session!.condicionesFinales;
    if (iniciales == null || finales == null) return null;

    final errors = <String>[];

    final hriInicial = double.tryParse(iniciales.hri ?? '');
    final hriFinal = double.tryParse(finales.hriFin ?? '');
    if (hriInicial != null && hriFinal != null) {
      if ((hriFinal - hriInicial).abs() > 5) {
        errors.add(
            'HRi varió de ${hriInicial.toStringAsFixed(1)}% a ${hriFinal.toStringAsFixed(1)}% (máx ±5%)');
      }
    }

    final tiInicial = double.tryParse(iniciales.ti ?? '');
    final tiFinal = double.tryParse(finales.tiFin ?? '');
    if (tiInicial != null && tiFinal != null) {
      if ((tiFinal - tiInicial).abs() > 2) {
        errors.add(
            'Ti varió de ${tiInicial.toStringAsFixed(1)}°C a ${tiFinal.toStringAsFixed(1)}°C (máx ±2°C)');
      }
    }

    final patmiInicial = double.tryParse(iniciales.patmi ?? '');
    final patmiFinal = double.tryParse(finales.patmiFin ?? '');
    if (patmiInicial != null && patmiFinal != null) {
      if ((patmiFinal - patmiInicial).abs() > 5) {
        errors.add(
            'Patmi varió de ${patmiInicial.toStringAsFixed(1)} hPa a ${patmiFinal.toStringAsFixed(1)} hPa (máx ±5 hPa)');
      }
    }

    if (errors.isEmpty) return null;
    return 'Los valores finales difieren significativamente de los iniciales:\n${errors.join('\n')}';
  }

  String? validateInspeccionVisual() {
    final issues = _withSession(_inspeccionIssues);
    return issues.isEmpty ? null : issues.first.message;
  }

  static List<_StepIssue> _inspeccionIssues(ServiceSession session) {
    final insp = session.inspeccion;
    if (insp == null) {
      return [(message: 'Debe completar la inspección visual.', column: null)];
    }
    final issues = <_StepIssue>[];

    if (insp.tiempoEstab == null || insp.tiempoEstab!.trim().isEmpty) {
      issues.add((
        message: 'Seleccione el tiempo de estabilización de pesas.',
        column: null
      ));
    }
    if (insp.tiempoOperacion == null || insp.tiempoOperacion!.trim().isEmpty) {
      issues.add((
        message: 'Seleccione el tiempo previo a operación de la balanza.',
        column: null
      ));
    }

    const entornoFields = [
      'vibracion',
      'polvo',
      'temp',
      'humedad',
      'mesada',
      'iluminacion',
      'limp_foza',
      'estado_drenaje',
    ];
    const balanzaFields = [
      'limp_general',
      'golpes_terminal',
      'nivelacion',
      'limp_recepto',
      'golpes_receptor',
      'encendido',
    ];
    const fieldLabels = {
      'vibracion': 'Vibración',
      'polvo': 'Polvo',
      'temp': 'Temperatura',
      'humedad': 'Humedad',
      'mesada': 'Mesada',
      'iluminacion': 'Iluminación',
      'limp_foza': 'Limpieza de Fosa',
      'estado_drenaje': 'Estado de Drenaje',
      'limp_general': 'Limpieza General',
      'golpes_terminal': 'Golpes al Terminal',
      'nivelacion': 'Nivelación',
      'limp_recepto': 'Limpieza Receptor',
      'golpes_receptor': 'Golpes al Receptor de Carga',
      'encendido': 'Encendido',
    };

    for (final key in [...entornoFields, ...balanzaFields]) {
      final val = insp.campos[key];
      if (val == null || val.trim().isEmpty) {
        issues.add((
          message: 'Falta el estado de: ${fieldLabels[key] ?? key}.',
          column: null
        ));
      }
    }

    return issues;
  }

  String? validatePrecargasAjuste() {
    final issues = _withSession(_precargasIssues);
    return issues.isEmpty ? null : issues.first.message;
  }

  static List<_StepIssue> _precargasIssues(ServiceSession session) {
    final pa = session.precargasAjuste;
    if (pa == null) {
      return [
        (
          message: 'Debe completar las precargas y condiciones ambientales.',
          column: null
        )
      ];
    }
    final issues = <_StepIssue>[];

    // Al menos una fila de precarga debe estar completa
    final tienePrecargas = pa.precargas.any(
      (r) => (r.precarga?.trim().isNotEmpty ?? false),
    );
    if (!tienePrecargas) {
      issues
          .add((message: 'Debe ingresar al menos una precarga.', column: null));
    }
    for (var i = 0; i < pa.precargas.length; i++) {
      final fila = pa.precargas[i];
      if (!_isBlank(fila.precarga) && _isBlank(fila.pIndicador)) {
        issues.add((
          message: 'Falta la Indicación de la Precarga ${i + 1}.',
          column: 'p_indicador${i + 1}'
        ));
      }
      if (_isBlank(fila.precarga) && !_isBlank(fila.pIndicador)) {
        issues.add((
          message: 'Falta el valor de la Precarga ${i + 1}.',
          column: 'precarga${i + 1}'
        ));
      }
    }

    // Condiciones ambientales obligatorias
    if (pa.ti == null || pa.ti!.trim().isEmpty) {
      issues.add((
        message: 'Debe ingresar la Temperatura inicial (Ti).',
        column: 'ti'
      ));
    }
    if (pa.hri == null || pa.hri!.trim().isEmpty) {
      issues.add((
        message: 'Debe ingresar la Humedad Relativa inicial (HRi).',
        column: 'hri'
      ));
    }
    if (pa.patmi == null || pa.patmi!.trim().isEmpty) {
      issues.add((
        message: 'Debe ingresar la Presión Atmosférica inicial (Patmi).',
        column: 'patmi'
      ));
    }

    // Si se realizó ajuste, debe indicar el tipo
    if ((pa.ajusteRealizado ?? false) &&
        (pa.tipoAjuste == null || pa.tipoAjuste!.trim().isEmpty)) {
      issues
          .add((message: 'Debe seleccionar el Tipo de Ajuste.', column: null));
    }

    return issues;
  }

  String? validateExcentricidad() {
    final issues = _withSession(_excentricidadIssues);
    return issues.isEmpty ? null : issues.first.message;
  }

  static List<_StepIssue> _excentricidadIssues(ServiceSession session) {
    final exc = session.excentricidad;
    if (exc == null) {
      return [
        (message: 'Debe completar las pruebas de excentricidad.', column: null)
      ];
    }
    final issues = <_StepIssue>[];
    if (exc.tipoPlataforma == null || exc.tipoPlataforma!.trim().isEmpty) {
      issues.add(
          (message: 'Debe seleccionar el Tipo de Plataforma.', column: null));
    }
    final puntos = exc.puntosCount;
    if (puntos == null) {
      issues.add((
        message: 'Debe seleccionar el N° de Puntos de Indicación.',
        column: null
      ));
    }
    if (exc.puntosIndicacion == null ||
        !RegExp(r'\d[FAID]$').hasMatch(exc.puntosIndicacion!.trim())) {
      issues.add((
        message: 'Debe seleccionar la Posición del Indicador.',
        column: null
      ));
    }
    if (exc.carga == null || exc.carga!.trim().isEmpty) {
      issues.add((message: 'Debe ingresar la Carga.', column: 'carga'));
    }
    if (puntos != null && exc.posiciones.length < puntos) {
      issues.add((
        message: 'Faltan posiciones: la prueba es de $puntos puntos.',
        column: null
      ));
    }
    // Solo las posiciones de la prueba: una sesión recuperada puede traer
    // más filas vacías que puntos.
    for (var i = 0; i < (puntos ?? 0) && i < exc.posiciones.length; i++) {
      final p = exc.posiciones[i];
      if (_isBlank(p.indicacion)) {
        issues.add((
          message: 'Falta la Indicación en Posición ${i + 1}.',
          column: 'indicacion${i + 1}'
        ));
      }
      if (_isBlank(p.retorno)) {
        issues.add((
          message: 'Falta el Retorno en Posición ${i + 1}.',
          column: 'retorno${i + 1}'
        ));
      }
    }
    return issues;
  }

  String? validateRepetibilidad() {
    final issues = _withSession(_repetibilidadIssues);
    return issues.isEmpty ? null : issues.first.message;
  }

  static List<_StepIssue> _repetibilidadIssues(ServiceSession session) {
    final rep = session.repetibilidad;
    if (rep == null || rep.cargas.isEmpty) {
      return [
        (
          message: 'Debe seleccionar el N° de Cargas de repetibilidad.',
          column: null
        )
      ];
    }
    final issues = <_StepIssue>[];
    for (var i = 0; i < rep.cargas.length; i++) {
      final carga = rep.cargas[i];
      if (carga.indicaciones.isEmpty) {
        issues.add((
          message: 'Debe seleccionar el N° de Mediciones por Carga.',
          column: null
        ));
      }
      if (_isBlank(carga.carga)) {
        issues.add((
          message: 'Falta el valor de la Carga ${i + 1}.',
          column: 'repetibilidad${i + 1}'
        ));
      }
      for (var j = 0; j < carga.indicaciones.length; j++) {
        if (_isBlank(carga.indicaciones[j])) {
          issues.add((
            message: 'Falta la Indicación ${j + 1} de la Carga ${i + 1}.',
            column: 'indicacion${i + 1}_${j + 1}'
          ));
        }
        if (j >= carga.retornos.length || _isBlank(carga.retornos[j])) {
          issues.add((
            message: 'Falta el Retorno ${j + 1} de la Carga ${i + 1}.',
            column: 'retorno${i + 1}_${j + 1}'
          ));
        }
      }
    }
    return issues;
  }

  String? validateLinealidad() {
    final issues = _withSession(_linealidadIssues);
    return issues.isEmpty ? null : issues.first.message;
  }

  static List<_StepIssue> _linealidadIssues(ServiceSession session) {
    final lin = session.linealidad;
    if (lin == null) {
      return [
        (message: 'Debe completar las pruebas de linealidad.', column: null)
      ];
    }
    final issues = <_StepIssue>[];
    if (_isBlank(lin.metodo)) {
      issues
          .add((message: 'Debe seleccionar el Método de Carga.', column: null));
    }
    if (_isBlank(lin.metodoCarga)) {
      issues.add((
        message: 'Debe seleccionar el Método de Cargas Sustitutivas.',
        column: null
      ));
    }
    var puntos = 0;
    for (var i = 0; i < lin.filas.length; i++) {
      final fila = lin.filas[i];
      final tieneCarga = !_isBlank(fila.carga);
      final tieneIndicacion = !_isBlank(fila.indicacion);
      if (tieneCarga && !tieneIndicacion) {
        issues.add((
          message: 'Falta la Indicación de la Carga ${i + 1}.',
          column: 'ind${i + 1}'
        ));
      }
      if (!tieneCarga && tieneIndicacion) {
        issues.add((
          message: 'Falta la Carga real de la Carga ${i + 1}.',
          column: 'lin${i + 1}'
        ));
      }
      if (tieneCarga) puntos++;
    }
    if (puntos == 0) {
      issues.add((
        message: 'Debe registrar al menos una carga con su indicación.',
        column: null
      ));
    }
    if (lin.fotosPaths.isEmpty) {
      issues.add((
        message: 'Debe tomar al menos una fotografía de la última carga.',
        column: null
      ));
    }
    return issues;
  }

  /// Confirma la balanza solo si quedó guardada. Si la base la rechaza,
  /// vuelve a quedar sin confirmar y el motivo queda en [saveError].
  Future<bool> confirmBalanza() async {
    if (_session == null) return false;
    setBalanzaConfirmed(true);
    if (!await flushAutoSave()) {
      setBalanzaConfirmed(false);
      return false;
    }
    await _saveCurrentProgress();
    return true;
  }

  // --- Marcar balanza completa ---

  /// Marca la balanza como calibrada solo si lo que está en pantalla quedó en
  /// la base: guarda, relee la fila y la compara con la sesión. Si algo no
  /// cuadra no la marca y devuelve el motivo.
  ///
  /// Antes se marcaba aunque el guardado hubiera fallado: la balanza quedaba
  /// "calibrada" sin las pruebas que el técnico había escrito, y así se
  /// exportaba y se subía.
  Future<String?> marcarBalanzaCompleta() async {
    final session = _session;
    final seca = session?.sessionInfo.seca;
    final sessionId = session?.sessionInfo.sessionId;
    if (session == null || seca == null || sessionId == null) {
      return 'La sesión no tiene SECA; no se puede cerrar la balanza.';
    }
    // "Balanza Calibrada" tiene que significar lo mismo en todas partes: la
    // lista de balanzas, la revisión final y la exportación. Sin este control
    // se podía saltar al último paso desde la barra y cerrar la balanza con
    // pruebas vacías.
    final pending = calibrationIssues(session);
    if (pending.isNotEmpty) return describeCalibrationIssues(pending);
    if (!await flushAutoSave()) return _saveError;
    try {
      final unsaved =
          await _repository.findUnsavedColumns(seca, sessionId, session);
      if (unsaved.isNotEmpty) {
        final campos = unsaved
            .take(3)
            .map((column) => CalibrationRecordValidator.labelFor(column).label)
            .join(', ');
        return 'Los datos no quedaron guardados en el teléfono ($campos'
            '${unsaved.length > 3 ? ' y ${unsaved.length - 3} más' : ''}). '
            'Vuelva a intentarlo; si persiste, no cierre la aplicación y '
            'avise a soporte.';
      }
      await _repository.marcarBalanzaCompleta(seca, sessionId);
    } catch (e) {
      debugPrint('Error al cerrar la balanza: $e');
      return 'No se pudo cerrar la balanza: $e';
    }
    await _saveCurrentProgress(status: 'completed');
    return null;
  }

  // --- Resetear sesión para nueva balanza (conserva cliente, planta, seca) ---

  Future<void> resetearParaNuevaBalanza() async {
    clearPreviousServiceData();
    final old = _session;
    if (old == null) return;
    // Un guardado pendiente es de la balanza que se deja: que no se pierda ni
    // se escriba sobre la nueva.
    await flushPendingSave();
    _saveError = null;
    _lastSaveSuccessful = true;
    final seca = old.sessionInfo.seca;
    final nuevoSessionId = seca != null
        ? await _repository.generateSessionId(seca)
        : old.sessionInfo.sessionId;
    _session = ServiceSession(
      sessionInfo: SessionInfo(
        seca: seca,
        sessionId: nuevoSessionId,
        fechaServicio: old.sessionInfo.fechaServicio,
        userName: old.sessionInfo.userName,
      ),
      cliente: old.cliente,
      planta: old.planta,
      metadata: SessionMetadata(
        currentStep: 3,
        secaConfirmed: old.metadata.secaConfirmed,
      ),
    );
    _currentStep = 3;
    _dValues = {};
    notifyListeners();
  }

  /// Deja sin concluir la balanza en curso (p. ej., tras emitir su RIM) y
  /// pasa a elegir otra con el mismo cliente, planta y SECA.
  ///
  /// Lo registrado se conserva en el teléfono; la sesión queda descartada,
  /// como con "Descartar y crear otro": no vuelve a ofrecerse como pendiente
  /// ni se sube como balanza calibrada. Devuelve el motivo si no se pudo
  /// guardar; en ese caso la balanza sigue abierta.
  Future<String?> interrumpirBalanza() async {
    final session = _session;
    if (session == null) return 'No hay una calibración en curso.';
    if (!await flushAutoSave()) return saveError ?? 'No se pudo guardar.';
    final seca = session.sessionInfo.seca;
    final sessionId = session.sessionInfo.sessionId;
    final userName = session.sessionInfo.userName;
    if (seca != null && sessionId != null && userName != null) {
      try {
        await _repository.markServicioAbandonado(seca, sessionId, userName);
      } catch (e) {
        return 'No se pudo cerrar la balanza: $e';
      }
    }
    await resetearParaNuevaBalanza();
    return null;
  }

  // --- Finalización ---

  Future<List<Map<String, dynamic>>> getRegistrosCompletos(String seca,
      {bool soloHoy = false}) async {
    final registros = await _repository.getRegistrosPorSeca(seca);
    if (soloHoy) {
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return registros
          .where((r) => r['fecha_servicio']?.toString() == hoy)
          .toList();
    }
    return registros;
  }

  Future<void> persistSharedExportData(
      String seca, Map<String, dynamic> values) async {
    await _repository.updateSharedExportData(seca, values);
  }

  Future<void> finalizeCalibrationRecords({
    required String seca,
    required Iterable<String> sessionIds,
    required String nombreCsv,
    required DateTime finalizedAt,
  }) {
    return _repository.finalizeCalibrationRecords(
      seca: seca,
      sessionIds: sessionIds,
      nombreCsv: nombreCsv,
      finalizedAt: finalizedAt.toIso8601String(),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
