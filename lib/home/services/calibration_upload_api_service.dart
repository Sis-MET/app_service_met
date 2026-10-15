import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/network/service_met_http_client.dart';
import '../../database/calibration_data_normalizer.dart';
import '../../services/ubicacion_servicio.dart';
import '../models/calibration_upload_models.dart';

class CalibrationUploadException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  CalibrationUploadException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}

/// Ubicación de cada registro, en el mismo orden que `records` (null si no
/// tiene). El servidor la guarda en el resumen, no en el detalle.
List<Map<String, Object?>?> calibrationUploadLocations(
  List<Map<String, dynamic>> records,
) =>
    records
        .map((record) => UbicacionServicio.deRegistro(record)?.toJson())
        .toList(growable: false);

class CalibrationUploadApiService {
  final String baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  CalibrationUploadApiService(
    String baseUrl, {
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? ServiceMetHttpClient.create(baseUrl),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  String get _tokenKey =>
      'servicemet_api_token_${base64Url.encode(utf8.encode(baseUrl))}';
  String get _expiryKey => '${_tokenKey}_expiry';

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

    throw CalibrationUploadException(
      'Ingresa tu contraseña para renovar la sesión con el servidor.',
      code: 'LOCAL_CREDENTIALS_MISSING',
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
    final normalized = records
        .map(CalibrationDataNormalizer.normalizeForUpload)
        .toList(growable: false);
    final response = await _authorizedPost(
      '/api/calibracion/validar',
      {'records': normalized},
    );
    final body = _decode(response);
    if (response.statusCode != 200) throw _exception(response.statusCode, body);
    return CalibrationValidationResult.fromJson(body);
  }

  Future<CalibrationUploadResult> upload(
    List<Map<String, dynamic>> records, {
    required bool validOnly,
  }) async {
    final normalized = records
        .map(CalibrationDataNormalizer.normalizeForUpload)
        .toList(growable: false);
    final response = await _authorizedPost('/api/calibracion/subir', {
      'mode': validOnly ? 'valid_only' : 'all',
      'records': normalized,
      'ubicaciones': calibrationUploadLocations(records),
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
