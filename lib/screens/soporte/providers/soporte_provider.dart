import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/database/database_helper_soporte.dart';

class SoporteProvider extends ChangeNotifier {
  // =========================================================================
  // ESTADO DE SESIÓN ACTIVA
  // =========================================================================
  
  String? _sessionId;
  String? _secaValue;
  String? _codMetrica;
  String? _tipoServicio;
  String? _userName;
  String? _clienteId;
  String? _plantaCodigo;
  String? _nReca;

  bool _isLoading = false;
  int _currentStep = 0;
  String? _errorMessage;

  // Getters
  String get sessionId => _sessionId ?? '';
  String get secaValue => _secaValue ?? '';
  String get codMetrica => _codMetrica ?? '';
  String get tipoServicio => _tipoServicio ?? '';
  String get userName => _userName ?? '';
  String get clienteId => _clienteId ?? '';
  String get plantaCodigo => _plantaCodigo ?? '';
  String get nReca => _nReca ?? '';
  bool get isLoading => _isLoading;
  int get currentStep => _currentStep;
  String? get errorMessage => _errorMessage;

  bool get hasActiveSession => _sessionId != null && _secaValue != null;

  // =========================================================================
  // MÉTODOS DE SESIÓN
  // =========================================================================

  void startSession({
    required String sessionId,
    required String secaValue,
    required String codMetrica,
    required String tipoServicio,
    required String userName,
    required String clienteId,
    required String plantaCodigo,
    required String nReca,
  }) {
    _sessionId = sessionId;
    _secaValue = secaValue;
    _codMetrica = codMetrica;
    _tipoServicio = tipoServicio;
    _userName = userName;
    _clienteId = clienteId;
    _plantaCodigo = plantaCodigo;
    _nReca = nReca;
    _currentStep = 0;
    _errorMessage = null;
    notifyListeners();
  }

  void updateStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearSession() {
    _sessionId = null;
    _secaValue = null;
    _codMetrica = null;
    _tipoServicio = null;
    _userName = null;
    _clienteId = null;
    _plantaCodigo = null;
    _nReca = null;
    _currentStep = 0;
    _errorMessage = null;
    notifyListeners();
  }

  // =========================================================================
  // RECUPERACIÓN DE SESIONES
  // =========================================================================

  Future<Map<String, dynamic>?> loadSession(String sessionId) async {
    setLoading(true);
    try {
      final dbHelper = DatabaseHelperSoporte();
      // Search across all module tables
      final tables = [
        'verificaciones_internas',
        'relevamiento_de_datos',
        'mnt_prv_avanzado_stac',
        'mnt_prv_regular_stil',
        'mnt_correctivo',
        'instalacion',
        'diagnostico',
        'ajustes_metrologicos',
      ];

      for (final table in tables) {
        final result = await dbHelper.getFirst(
          table,
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
        if (result != null) {
          return result;
        }
      }
      return null;
    } catch (e) {
      _errorMessage = 'Error al cargar sesión: $e';
      return null;
    } finally {
      setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> getIncompleteSessions() async {
    try {
      final dbHelper = DatabaseHelperSoporte();
      final tables = [
        'verificaciones_internas',
        'relevamiento_de_datos',
        'mnt_prv_avanzado_stac',
        'mnt_prv_regular_stil',
        'mnt_correctivo',
        'instalacion',
        'diagnostico',
        'ajustes_metrologicos',
      ];

      final List<Map<String, dynamic>> incompleteSessions = [];

      for (final table in tables) {
        final results = await dbHelper.query(
          table,
          where: "estado_servicio = 'Pendiente'",
          orderBy: 'updated_at DESC',
          limit: 5,
        );
        incompleteSessions.addAll(results);
      }

      // Sort by updated_at descending
      incompleteSessions.sort((a, b) {
        final aDate = a['updated_at']?.toString() ?? '';
        final bDate = b['updated_at']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

      return incompleteSessions.take(10).toList();
    } catch (e) {
      _errorMessage = 'Error al recuperar sesiones: $e';
      return [];
    }
  }
}
