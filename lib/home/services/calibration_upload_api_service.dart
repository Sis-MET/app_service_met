import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/calibration_upload_models.dart';

class CalibrationUploadException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  CalibrationUploadException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}

class CalibrationUploadApiService {
  final String baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  CalibrationUploadApiService(
    String baseUrl, {
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  String get _tokenKey =>
      'servicemet_api_token_${base64Url.encode(utf8.encode(baseUrl))}';
  String get _expiryKey => '${_tokenKey}_expiry';

  Future<Map<String, String>> _loadLocalCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('logged_user');
    if (usuario == null || usuario.isEmpty) {
      throw CalibrationUploadException(
        'No hay un usuario autenticado.',
        code: 'LOCAL_USER_MISSING',
      );
    }
    final dbPath = p.join(await getDatabasesPath(), 'usuarios.db');
    if (!await databaseExists(dbPath)) {
      throw CalibrationUploadException(
        'No se encontró la sesión local del usuario.',
        code: 'LOCAL_CREDENTIALS_MISSING',
      );
    }
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final rows = await db.query(
        'usuarios',
        columns: ['usuario', 'pass'],
        where: 'usuario = ?',
        whereArgs: [usuario],
        limit: 1,
      );
      if (rows.isEmpty || (rows.first['pass']?.toString() ?? '').isEmpty) {
        throw CalibrationUploadException(
          'No se encontraron credenciales para autenticar la subida.',
          code: 'LOCAL_CREDENTIALS_MISSING',
        );
      }
      return {'usuario': usuario, 'password': rows.first['pass'].toString()};
    } finally {
      await db.close();
    }
  }

  Future<String> _getToken({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final token = await _secureStorage.read(key: _tokenKey);
      final expiryRaw = await _secureStorage.read(key: _expiryKey);
      final expiry = DateTime.tryParse(expiryRaw ?? '');
      if (token != null &&
          expiry != null &&
          expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        return token;
      }
    }

    final credentials = await _loadLocalCredentials();
    return authenticate(
      usuario: credentials['usuario']!,
      password: credentials['password']!,
    );
  }

  Future<String> authenticate({
    required String usuario,
    required String password,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'usuario': usuario, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(response);
    if (response.statusCode != 200) throw _exception(response.statusCode, body);
    final token = body['token']?.toString();
    if (token == null || token.isEmpty) {
      throw CalibrationUploadException(
          'El servidor no devolvió una sesión válida.');
    }
    final expiresIn = body['expiresIn'] as int? ?? 3600;
    await Future.wait([
      _secureStorage.write(key: _tokenKey, value: token),
      _secureStorage.write(
        key: _expiryKey,
        value:
            DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String(),
      ),
    ]);
    return token;
  }

  Future<http.Response> _authorizedPost(String path, Object body) async {
    var token = await _getToken();
    var response = await _post(path, body, token);
    if (response.statusCode == 401) {
      token = await _getToken(forceRefresh: true);
      response = await _post(path, body, token);
    }
    return response;
  }

  Future<http.Response> _post(String path, Object body, String token) {
    return _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));
  }

  Future<CalibrationValidationResult> validate(
      List<Map<String, dynamic>> records) async {
    final response =
        await _authorizedPost('/api/calibracion/validar', {'records': records});
    final body = _decode(response);
    if (response.statusCode != 200) throw _exception(response.statusCode, body);
    return CalibrationValidationResult.fromJson(body);
  }

  Future<CalibrationUploadResult> upload(
    List<Map<String, dynamic>> records, {
    required bool validOnly,
  }) async {
    final response = await _authorizedPost('/api/calibracion/subir', {
      'mode': validOnly ? 'valid_only' : 'all',
      'records': records,
    });
    final body = _decode(response);
    if (response.statusCode != 201) throw _exception(response.statusCode, body);
    return CalibrationUploadResult.fromJson(body);
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map);
    } catch (_) {
      return {'message': 'Respuesta inválida del servidor.'};
    }
  }

  CalibrationUploadException _exception(
      int statusCode, Map<String, dynamic> body) {
    return CalibrationUploadException(
      body['message']?.toString() ?? 'No se pudo completar la operación.',
      statusCode: statusCode,
      code: body['error']?.toString(),
    );
  }

  void close() => _client.close();
}
