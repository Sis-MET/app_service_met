import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Elimina credenciales directas de SQL Server conservadas por versiones
/// antiguas. La aplicación actual solo almacena perfiles de API y tokens JWT.
class CredentialStorage {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static const _legacyKeys = ['ip', 'port', 'database', 'dbuser', 'dbpass'];

  Future<void> clearCredentials() async {
    await Future.wait(
      _legacyKeys.map((key) => _secure.delete(key: key)),
    );
    final preferences = await SharedPreferences.getInstance();
    await Future.wait(_legacyKeys.map(preferences.remove));
  }
}
