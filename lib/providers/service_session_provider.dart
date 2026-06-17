import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/repositories/calibration_repository.dart';

class ServiceSessionProvider extends ChangeNotifier {
  final CalibrationRepository _repository;

  ServiceSession? _session;
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _lastSaveSuccessful = true;
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

  ServiceSessionProvider(this._repository);

  // --- Getters ---
  ServiceSession? get session => _session;
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get lastSaveSuccessful => _lastSaveSuccessful;
  String get cotizacionSuffix => _cotizacionSuffix;
  bool get isQrMode => _isQrMode;
  String? get qrCodMetrica => _qrCodMetrica;
  bool get returnToCondicionesFinales => _returnToCondicionesFinales;
  set returnToCondicionesFinales(bool v) {
    _returnToCondicionesFinales = v;
    notifyListeners();
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
        // Fallback if not found
        await createNewSession(userName, secaValue: secaValue);
      }
    } else {
      await createNewSession(userName);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createNewSession(String userName, {String? secaValue}) async {
    clearQrMode();
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
    _session = await _repository.loadSession(seca, sessionId);
    if (_session != null) {
      _currentStep = _session!.metadata.currentStep;
      _dValues = await _repository.getDValues(seca, sessionId);
    }
  }

  // --- Navegación ---

  void goToStep(int step) {
    if (step >= 0 && step < 12 && _session != null) {
      _currentStep = step;
      _session = _session!
          .copyWith(metadata: _session!.metadata.copyWith(currentStep: step));
      notifyListeners();
      _scheduleAutoSave();
    }
  }

  void nextStep() {
    if (_currentStep < 11) {
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
    _session = _session!.copyWith(cliente: cliente);
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

  Future<void> flushAutoSave() async {
    _autoSaveTimer?.cancel();
    await _autoSave();
  }

  Future<void> _autoSave() async {
    if (_session == null ||
        _session!.sessionInfo.seca == null ||
        _session!.sessionInfo.sessionId == null) {
      return;
    }

    _isSaving = true;
    notifyListeners();

    try {
      await _repository.saveSession(_session!.sessionInfo.seca!,
          _session!.sessionInfo.sessionId!, _session!);
      _lastSaveSuccessful = true;
      // Actualizar dValues
      _dValues = await _repository.getDValues(
          _session!.sessionInfo.seca!, _session!.sessionInfo.sessionId!);
    } catch (e) {
      _lastSaveSuccessful = false;
      debugPrint('Error en auto-save: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
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

    await flushAutoSave();
    return true;
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
    final allPlantas = await _repository.getPlantas(clienteMatch['cliente_id']?.toString() ?? '');

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
      id: plantaMatch['planta_id']?.toString() ?? plantaMatch['unique_key']?.toString(),
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
      return 'No se encontró balanza con código: $_qrCodMetrica';
    }

    updateBalanza(BalanzaInfo(
      codMetrica: balanzaMatch['cod_metrica']?.toString(),
      categoria: balanzaMatch['categoria']?.toString(),
      tecnologia: balanzaMatch['tecnologia']?.toString(),
      clase: balanzaMatch['clase']?.toString(),
      codInterno: balanzaMatch['cod_interno']?.toString(),
      tipo: balanzaMatch['tipo_instrumento']?.toString() ?? balanzaMatch['instrumento']?.toString(),
      marca: balanzaMatch['marca']?.toString(),
      modelo: balanzaMatch['modelo']?.toString(),
      serie: balanzaMatch['inf_serie']?.toString() ?? balanzaMatch['serie']?.toString(),
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
    if (b.capMax1 == null || b.capMax1!.trim().isEmpty) {
      return "Falta la Capacidad Maxima (Rango 1).";
    }
    if (b.d1 == null) {
      return "Falta la division d (Rango 1).";
    }
    if (b.e1 == null) {
      return "Falta la division e (Rango 1).";
    }

    return null;
  }

  String? validateCondicionesFinales() {
    if (_session == null) return "Sesión no inicializada.";

    final pesas = _session!.equipos.where((e) {
      final tipo = e.tipo?.toLowerCase() ?? '';
      return tipo.contains('pesa') ||
          tipo.contains('masa') ||
          tipo.contains('patron') ||
          tipo.contains('patr');
    }).length;
    final medicion = _session!.equipos.length - pesas;

    if (pesas < 1) {
      return "Debe seleccionar al menos una pesa patron.";
    }
    if (medicion < 1) {
      return "Debe seleccionar al menos un termohigrometro, barometro o instrumento de medicion.";
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
    if (exc.puntosIndicacion == null || exc.puntosIndicacion!.trim().isEmpty) {
      return "Debe seleccionar el N° de Puntos de Indicación.";
    }
    if (exc.carga == null || exc.carga!.trim().isEmpty) {
      return "Debe ingresar la Carga (kg).";
    }
    if (exc.posiciones.isEmpty) {
      return "Debe agregar posiciones de medición.";
    }
    for (var i = 0; i < exc.posiciones.length; i++) {
      final p = exc.posiciones[i];
      if (p.indicacion == null || p.indicacion!.trim().isEmpty) {
        return "Falta la Indicación en Posición ${i + 1}.";
      }
      if (p.retorno == null || p.retorno!.trim().isEmpty) {
        return "Falta el Retorno en Posición ${i + 1}.";
      }
    }
    return null;
  }

  Future<bool> confirmBalanza() async {
    if (_session == null) return false;
    setBalanzaConfirmed(true);
    await flushAutoSave();
    return true;
  }

  // --- Exportación ---

  Future<List<Map<String, dynamic>>> prepareExportData() async {
    if (_session == null) return [];
    return [_session!.toMap()];
  }

  Future<bool> exportToCSV() async {
    // Implementar lógica de exportación usando el repositorio
    return true; // Placeholder
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
