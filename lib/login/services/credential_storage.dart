// Almacenamiento seguro de credenciales usando flutter_secure_storage
// con respaldo (fallback) a SharedPreferences para compatibilidad con
// configuraciones existentes. Las nuevas escrituras siempre usan
// flutter_secure_storage.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CredentialStorage {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  // ── Claves ──
  static const String _ipKey = 'ip';
  static const String _portKey = 'port';
  static const String _databaseKey = 'database';
  static const String _dbUserKey = 'dbuser';
  static const String _dbPassKey = 'dbpass';

  // ── Guardar credenciales de BD en secure storage ──
  Future<void> saveDatabaseCredentials({
    required String ip,
    required String port,
    required String database,
    required String dbUser,
    required String dbPass,
  }) async {
    await Future.wait([
      _secure.write(key: _ipKey, value: ip),
      _secure.write(key: _portKey, value: port),
      _secure.write(key: _databaseKey, value: database),
      _secure.write(key: _dbUserKey, value: dbUser),
      _secure.write(key: _dbPassKey, value: dbPass),
    ]);
  }

  // ── Leer credenciales de BD (con fallback a SharedPreferences) ──
  Future<Map<String, String>?> getDatabaseCredentials() async {
    try {
      final ip = await _secure.read(key: _ipKey);
      final port = await _secure.read(key: _portKey);
      final database = await _secure.read(key: _databaseKey);
      final dbUser = await _secure.read(key: _dbUserKey);
      final dbPass = await _secure.read(key: _dbPassKey);

      if (ip != null &&
          port != null &&
          database != null &&
          dbUser != null &&
          dbPass != null) {
        return {
          'ip': ip,
          'port': port,
          'database': database,
          'username': dbUser,
          'password': dbPass,
        };
      }
    } catch (_) {}

    // Fallback: leer desde SharedPreferences (configuraciones existentes)
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString(_ipKey);
    final port = prefs.getString(_portKey);
    final database = prefs.getString(_databaseKey);
    final dbUser = prefs.getString(_dbUserKey);
    final dbPass = prefs.getString(_dbPassKey);

    if (ip == null ||
        port == null ||
        database == null ||
        dbUser == null ||
        dbPass == null) {
      return null;
    }

    // Migrar a secure storage si se encontraron en SharedPreferences
    await saveDatabaseCredentials(
      ip: ip,
      port: port,
      database: database,
      dbUser: dbUser,
      dbPass: dbPass,
    );

    return {
      'ip': ip,
      'port': port,
      'database': database,
      'username': dbUser,
      'password': dbPass,
    };
  }

  // ── Limpiar credenciales ──
  Future<void> clearCredentials() async {
    await Future.wait([
      _secure.delete(key: _ipKey),
      _secure.delete(key: _portKey),
      _secure.delete(key: _databaseKey),
      _secure.delete(key: _dbUserKey),
      _secure.delete(key: _dbPassKey),
    ]);
  }
}
