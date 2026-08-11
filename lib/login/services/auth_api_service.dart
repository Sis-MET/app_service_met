import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/network/service_met_http_client.dart';
import '../models/user_model.dart';

class AuthApiResult {
  final UserModel user;
  final String token;
  final DateTime expiresAt;

  const AuthApiResult({
    required this.user,
    required this.token,
    required this.expiresAt,
  });
}

class AuthApiService {
  final String baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  AuthApiService(
    String baseUrl, {
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : baseUrl = ServiceMetHttpClient.normalizeBaseUrl(baseUrl),
        _client = client ?? ServiceMetHttpClient.create(baseUrl),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  String get _tokenKey =>
      'servicemet_api_token_${base64Url.encode(utf8.encode(baseUrl))}';
  String get _expiryKey => '${_tokenKey}_expiry';

  Future<void> checkHealth() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw _exception(response.statusCode, _decode(response));
    }
  }

  Future<AuthApiResult> login({
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
    if (response.statusCode != 200) {
      throw _exception(response.statusCode, body);
    }

    final token = body['token']?.toString() ?? '';
    final userJson = Map<String, dynamic>.from(body['user'] as Map? ?? {});
    if (token.isEmpty || userJson['usuario'] == null) {
      throw const ServiceMetNetworkException(
        'El servidor no devolvió una sesión válida.',
        code: 'INVALID_RESPONSE',
      );
    }
    final expiresIn = (body['expiresIn'] as num?)?.toInt() ?? 28800;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await Future.wait([
      _secureStorage.write(key: _tokenKey, value: token),
      _secureStorage.write(
        key: _expiryKey,
        value: expiresAt.toIso8601String(),
      ),
    ]);
    return AuthApiResult(
      user: UserModel.fromMap(userJson),
      token: token,
      expiresAt: expiresAt,
    );
  }

  Future<Map<String, dynamic>> downloadBootstrap({String? token}) async {
    final sessionToken = token ?? await readValidToken();
    if (sessionToken == null) {
      throw const ServiceMetNetworkException(
        'La sesión online venció. Ingresa tu contraseña para actualizar.',
        code: 'AUTH_REQUIRED',
      );
    }
    final response = await _client.get(
      Uri.parse('$baseUrl/api/bootstrap'),
      headers: {'Authorization': 'Bearer $sessionToken'},
    ).timeout(const Duration(seconds: 120));
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw _exception(response.statusCode, body);
    }
    return body;
  }

  Future<String?> readValidToken() async {
    final token = await _secureStorage.read(key: _tokenKey);
    final expiry = DateTime.tryParse(
      await _secureStorage.read(key: _expiryKey) ?? '',
    );
    if (token == null ||
        expiry == null ||
        !expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return null;
    }
    return token;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    } catch (_) {
      return {'message': 'Respuesta inválida del servidor.'};
    }
  }

  ServiceMetNetworkException _exception(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    return ServiceMetNetworkException(
      body['message']?.toString() ?? 'No se pudo completar la operación.',
      statusCode: statusCode,
      code: body['error']?.toString(),
    );
  }

  void close() => _client.close();
}
