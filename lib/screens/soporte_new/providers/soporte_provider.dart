import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/database/database_helper_soporte.dart';

class SoporteProvider extends ChangeNotifier {
  final DatabaseHelperSoporte _dbHelper = DatabaseHelperSoporte();

  String? _currentSessionId;
  String? get currentSessionId => _currentSessionId;

  Map<String, String> _sessionData = {};
  Map<String, String> get sessionData => _sessionData;

  bool _hasActiveSession = false;
  bool get hasActiveSession => _hasActiveSession;

  Future<String> startNewSession() async {
    _currentSessionId = await _dbHelper.generateSessionId();
    _sessionData = {};
    _hasActiveSession = true;
    notifyListeners();
    return _currentSessionId!;
  }

  Future<Map<String, dynamic>?> recoverSession(String tableName, String sessionId) async {
    final result = await _dbHelper.query(tableName, sessionId);
    if (result != null) {
      _currentSessionId = sessionId;
      _hasActiveSession = true;
      notifyListeners();
    }
    return result;
  }

  void setSessionData(Map<String, String> data) {
    _sessionData = data;
    notifyListeners();
  }

  void clearSession() {
    _currentSessionId = null;
    _sessionData = {};
    _hasActiveSession = false;
    notifyListeners();
  }
}
