import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/calibration_data_normalizer.dart';
import 'package:service_met/database/calibration_record_validator.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/utils/scale_range_validator.dart';

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
    final cambioCliente =
        anterior?.id != cliente.id || anterior?.isNew != cliente.isNew;
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
    if (_session == null) {
      return "Sesion no inicializada.";
    }

    final info = _session!.sessionInfo;
    if (info.nReca == null || info.nReca!.trim().isEmpty) {
      return "Debe ingresar el Nro. RECA.";
    }
    if (info.sticker == null || info.sticker!.trim().isEmpty) {
      return "Debe ingresar el Nro. Sticker.";
    }

    final b = _session!.balanza;
    if (b == null) {
      return "Debe seleccionar o registrar una balanza.";
    }
    if (b.codMetrica == null || b.codMetrica!.trim().isEmpty) {
      return "Falta el Codigo Metrica.";
    }
    if (b.tipo == null || b.tipo!.trim().isEmpty) {
      return "Falta el Tipo de Instrumento.";
    }
    if (b.marca == null || b.marca!.trim().isEmpty) {
      return "Falta la Marca.";
    }
    if (b.modelo == null || b.modelo!.trim().isEmpty) {
      return "Falta el Modelo.";
    }
    if (b.serie == null || b.serie!.trim().isEmpty) {
      return "Falta la Serie.";
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
    if (rangeError != null) return rangeError;

    return null;
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

  /// Lo que impide dejar el paso [step]: primero un dato que la base
  /// rechazaría, después un dato obligatorio vacío. Null si se puede avanzar.
  ///
  /// El chequeo de esquema es el mismo que aplica el guardado: si pasa aquí,
  /// el paso se guarda.
  String? validateStep(int step) {
    final session = _session;
    if (session == null) return "Sesión no inicializada.";

    final issues = CalibrationRecordValidator.schemaIssues(session.toMap())
        .where((issue) => issue.step == step);
    if (issues.isNotEmpty) return '${issues.first}';

    return switch (step) {
      3 => validateBalanza(),
      4 => validateInspeccionVisual(),
      5 => validatePrecargasAjuste(),
      6 => validateExcentricidad(),
      7 => validateRepetibilidad(),
      8 => validateLinealidad(),
      9 => validateCondicionesFinales(),
      _ => null,
    };
  }

  String? validateCondicionesFinales() {
    if (_session == null) return "Sesión no inicializada.";

    final cf = _session!.condicionesFinales;
    if (_isBlank(cf?.horaFin)) {
      return "Registre la Hora Fin con el botón del reloj.";
    }
    if (_isBlank(cf?.hriFin)) {
      return "Debe ingresar la Humedad Relativa final (HRi Fin).";
    }
    if (_isBlank(cf?.tiFin)) {
      return "Debe ingresar la Temperatura final (Ti Fin).";
    }
    if (_isBlank(cf?.patmiFin)) {
      return "Debe ingresar la Presión Atmosférica final (Patmi Fin).";
    }

    final pesas = _session!.equipos.where((e) {
      final tipo = e.tipo?.toLowerCase() ?? '';
      return tipo.contains('pesa') ||
          tipo.contains('masa') ||
          tipo.contains('patron') ||
          tipo.contains('patr');
    }).length;

    if (pesas < 1) {
      return "Debe seleccionar al menos una pesa patron.";
    }

    return null;
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
    if (_session == null) return "Sesión no inicializada.";

    final insp = _session!.inspeccion;
    if (insp == null) return "Debe completar la inspección visual.";

    if (insp.tiempoEstab == null || insp.tiempoEstab!.trim().isEmpty) {
      return "Seleccione el tiempo de estabilización de pesas.";
    }
    if (insp.tiempoOperacion == null || insp.tiempoOperacion!.trim().isEmpty) {
      return "Seleccione el tiempo previo a operación de la balanza.";
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
        return "Falta el estado de: ${fieldLabels[key] ?? key}.";
      }
    }

    return null;
  }

  String? validatePrecargasAjuste() {
    if (_session == null) return "Sesión no inicializada.";

    final pa = _session!.precargasAjuste;
    if (pa == null) {
      return "Debe completar las precargas y condiciones ambientales.";
    }

    // Al menos una fila de precarga debe estar completa
    final tienePrecargas = pa.precargas.any(
      (r) => (r.precarga?.trim().isNotEmpty ?? false),
    );
    if (!tienePrecargas) {
      return "Debe ingresar al menos una precarga.";
    }
    for (var i = 0; i < pa.precargas.length; i++) {
      final fila = pa.precargas[i];
      if (!_isBlank(fila.precarga) && _isBlank(fila.pIndicador)) {
        return "Falta la Indicación de la Precarga ${i + 1}.";
      }
      if (_isBlank(fila.precarga) && !_isBlank(fila.pIndicador)) {
        return "Falta el valor de la Precarga ${i + 1}.";
      }
    }

    // Condiciones ambientales obligatorias
    if (pa.ti == null || pa.ti!.trim().isEmpty) {
      return "Debe ingresar la Temperatura inicial (Ti).";
    }
    if (pa.hri == null || pa.hri!.trim().isEmpty) {
      return "Debe ingresar la Humedad Relativa inicial (HRi).";
    }
    if (pa.patmi == null || pa.patmi!.trim().isEmpty) {
      return "Debe ingresar la Presión Atmosférica inicial (Patmi).";
    }

    // Si se realizó ajuste, debe indicar el tipo
    if ((pa.ajusteRealizado ?? false) &&
        (pa.tipoAjuste == null || pa.tipoAjuste!.trim().isEmpty)) {
      return "Debe seleccionar el Tipo de Ajuste.";
    }

    return null;
  }

  String? validateExcentricidad() {
    if (_session == null) return "Sesión no inicializada.";

    final exc = _session!.excentricidad;
    if (exc == null) return "Debe completar las pruebas de excentricidad.";
    if (exc.tipoPlataforma == null || exc.tipoPlataforma!.trim().isEmpty) {
      return "Debe seleccionar el Tipo de Plataforma.";
    }
    final puntos = exc.puntosCount;
    if (puntos == null) {
      return "Debe seleccionar el N° de Puntos de Indicación.";
    }
    if (!RegExp(r'\d[FAID]$').hasMatch(exc.puntosIndicacion!.trim())) {
      return "Debe seleccionar la Posición del Indicador.";
    }
    if (exc.carga == null || exc.carga!.trim().isEmpty) {
      return "Debe ingresar la Carga.";
    }
    if (exc.posiciones.length < puntos) {
      return "Faltan posiciones: la prueba es de $puntos puntos.";
    }
    // Solo las posiciones de la prueba: una sesión recuperada puede traer
    // más filas vacías que puntos.
    for (var i = 0; i < puntos; i++) {
      final p = exc.posiciones[i];
      if (_isBlank(p.indicacion)) {
        return "Falta la Indicación en Posición ${i + 1}.";
      }
      if (_isBlank(p.retorno)) {
        return "Falta el Retorno en Posición ${i + 1}.";
      }
    }
    return null;
  }

  String? validateRepetibilidad() {
    if (_session == null) return "Sesión no inicializada.";

    final rep = _session!.repetibilidad;
    if (rep == null || rep.cargas.isEmpty) {
      return "Debe seleccionar el N° de Cargas de repetibilidad.";
    }
    for (var i = 0; i < rep.cargas.length; i++) {
      final carga = rep.cargas[i];
      if (carga.indicaciones.isEmpty) {
        return "Debe seleccionar el N° de Mediciones por Carga.";
      }
      if (_isBlank(carga.carga)) {
        return "Falta el valor de la Carga ${i + 1}.";
      }
      for (var j = 0; j < carga.indicaciones.length; j++) {
        if (_isBlank(carga.indicaciones[j])) {
          return "Falta la Indicación ${j + 1} de la Carga ${i + 1}.";
        }
        if (j >= carga.retornos.length || _isBlank(carga.retornos[j])) {
          return "Falta el Retorno ${j + 1} de la Carga ${i + 1}.";
        }
      }
    }
    return null;
  }

  String? validateLinealidad() {
    if (_session == null) return "Sesión no inicializada.";

    final lin = _session!.linealidad;
    if (lin == null) return "Debe completar las pruebas de linealidad.";
    if (_isBlank(lin.metodo)) {
      return "Debe seleccionar el Método de Carga.";
    }
    if (_isBlank(lin.metodoCarga)) {
      return "Debe seleccionar el Método de Cargas Sustitutivas.";
    }
    var puntos = 0;
    for (var i = 0; i < lin.filas.length; i++) {
      final fila = lin.filas[i];
      final tieneCarga = !_isBlank(fila.carga);
      final tieneIndicacion = !_isBlank(fila.indicacion);
      if (tieneCarga && !tieneIndicacion) {
        return "Falta la Indicación de la Carga ${i + 1}.";
      }
      if (!tieneCarga && tieneIndicacion) {
        return "Falta la Carga real de la Carga ${i + 1}.";
      }
      if (tieneCarga) puntos++;
    }
    if (puntos == 0) {
      return "Debe registrar al menos una carga con su indicación.";
    }
    if (lin.fotosPaths.isEmpty) {
      return "Debe tomar al menos una fotografía de la última carga.";
    }
    return null;
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
