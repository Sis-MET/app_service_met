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
  
  ServiceSessionProvider(this._repository);

  // --- Getters ---
  ServiceSession? get session => _session;
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get lastSaveSuccessful => _lastSaveSuccessful;

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
      _session = _session!.copyWith(
        metadata: _session!.metadata.copyWith(currentStep: step)
      );
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
    // Aquí se puede agregar lógica de validación, por ej. no ir al paso 4 si el 3 no está completo.
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
    if (_session == null || _session!.sessionInfo.seca == null || _session!.sessionInfo.sessionId == null) {
      return;
    }

    _isSaving = true;
    notifyListeners();

    try {
      await _repository.saveSession(
        _session!.sessionInfo.seca!,
        _session!.sessionInfo.sessionId!,
        _session!
      );
      _lastSaveSuccessful = true;
      // Actualizar dValues
      _dValues = await _repository.getDValues(_session!.sessionInfo.seca!, _session!.sessionInfo.sessionId!);
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

  Future<bool> confirmSeca(String seca) async {
    if (_session == null) return false;
    
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
