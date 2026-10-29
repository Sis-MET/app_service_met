import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/service_met_http_client.dart';
import '../../../login/services/auth_api_service.dart';

enum TemperaturaApiErrorKind {
  /// Sin red o la API METRICA no responde: el registro sigue pendiente.
  offline,

  /// El servidor no está disponible o todavía no tiene las tablas (017).
  unavailable,

  /// La sesión venció o no tiene permiso de subir calibraciones.
  authRequired,

  /// El servidor rechazó el contenido del registro.
  rejected,
}

class TemperaturaApiException implements Exception {
  const TemperaturaApiException(
    this.message, {
    required this.kind,
    this.code,
    this.statusCode,
    this.details,
  });

  final String message;
  final TemperaturaApiErrorKind kind;
  final String? code;
  final int? statusCode;

  /// Los problemas de validación que devolvió el servidor.
  final List<String>? details;

  bool get retryable =>
      kind == TemperaturaApiErrorKind.offline ||
      kind == TemperaturaApiErrorKind.unavailable;

  @override
  String toString() => message;
}

/// Lo que la subida necesita del servidor; las pruebas lo reemplazan.
abstract interface class TemperaturaUploader {
  Future<({int n, bool duplicate})> subir(Map<String, Object?> registro);
  Future<void> authenticate(
      {required String usuario, required String password});
  void close();
}

/// `POST /api/calibracion/temperatura`: sube una calibración de temperatura
/// completa (cabecera, patrones, canales, puntos, lecturas y correcciones)
/// en una sola transacción. Con el mismo `uuid` responde que ya estaba.
class TemperaturaApi implements TemperaturaUploader {
  static const uploadTimeout = Duration(seconds: 60);
  static const authTimeout = Duration(seconds: 20);
  static const path = '/api/calibracion/temperatura';

  TemperaturaApi._(this.baseUrl, this._client, this._auth);

  /// Lanza [ServiceMetNetworkException] si [baseUrl] no es la API interna
  /// autorizada (HTTPS con huella fijada).
  factory TemperaturaApi(
    String baseUrl, {
    http.Client? client,
    AuthApiService? auth,
  }) {
    final httpClient = client ?? ServiceMetHttpClient.create(baseUrl);
    return TemperaturaApi._(
      ServiceMetHttpClient.normalizeBaseUrl(baseUrl),
      httpClient,
      auth ?? AuthApiService(baseUrl, client: httpClient),
    );
  }

  final String baseUrl;
  final http.Client _client;
  final AuthApiService _auth;

  /// El número asignado en DataMET y si ya estaba registrado.
  @override
  Future<({int n, bool duplicate})> subir(Map<String, Object?> registro) async {
    final token = await _auth.readValidToken();
    if (token == null) {
      throw const TemperaturaApiException(
        'La sesión con el servidor venció. Ingrese su contraseña.',
        kind: TemperaturaApiErrorKind.authRequired,
        code: 'LOCAL_CREDENTIALS_MISSING',
      );
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(registro),
          )
          .timeout(uploadTimeout);
    } on TimeoutException {
      throw const TemperaturaApiException(
        'El servidor no respondió a tiempo.',
        kind: TemperaturaApiErrorKind.offline,
        code: 'TIMEOUT',
      );
    } on SocketException {
      throw _offline();
    } on HandshakeException {
      throw _offline();
    } on http.ClientException {
      throw _offline();
    }
    final body = _decode(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final n = body['n'];
      if (n is! int) {
        throw const TemperaturaApiException(
          'El servidor no devolvió el número del registro.',
          kind: TemperaturaApiErrorKind.unavailable,
          code: 'NO_N',
        );
      }
      return (n: n, duplicate: body['duplicate'] == true);
    }
    final error = exception(response.statusCode, body);
    debugPrint('[Temperatura] ${response.statusCode} ${error.code ?? ''}');
    throw error;
  }

  /// Renueva el JWT con la contraseña del técnico.
  @override
  Future<void> authenticate({
    required String usuario,
    required String password,
  }) async {
    try {
      await _auth
          .login(usuario: usuario, password: password)
          .timeout(authTimeout);
    } on ServiceMetNetworkException catch (error) {
      throw TemperaturaApiException(
        error.message,
        kind: error.statusCode == 401 || error.statusCode == 403
            ? TemperaturaApiErrorKind.authRequired
            : TemperaturaApiErrorKind.unavailable,
        code: error.code,
        statusCode: error.statusCode,
      );
    } on TimeoutException {
      throw _offline();
    } on SocketException {
      throw _offline();
    } on HandshakeException {
      throw _offline();
    } on http.ClientException {
      throw _offline();
    }
  }

  static TemperaturaApiException _offline() => const TemperaturaApiException(
        'Sin conexión con la API de METRICA.',
        kind: TemperaturaApiErrorKind.offline,
        code: 'OFFLINE',
      );

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  @visibleForTesting
  static TemperaturaApiException exception(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    final code = body['error']?.toString();
    final message =
        body['message']?.toString() ?? 'No se pudo completar la operación.';
    final details = body['details'] is List
        ? [
            for (final detail in body['details'] as List)
              detail is Map ? '${detail['message'] ?? detail}' : '$detail',
          ]
        : null;
    if (statusCode == 401 || code == 'INSUFFICIENT_SCOPE') {
      return TemperaturaApiException(message,
          kind: TemperaturaApiErrorKind.authRequired,
          code: code,
          statusCode: statusCode);
    }
    if (statusCode == 404 && (code == null || code == 'NOT_FOUND')) {
      return TemperaturaApiException(
        'El servidor todavía no recibe calibraciones de temperatura.',
        kind: TemperaturaApiErrorKind.unavailable,
        code: code ?? 'NOT_FOUND',
        statusCode: statusCode,
      );
    }
    return TemperaturaApiException(
      message,
      kind: const {400, 409, 422}.contains(statusCode)
          ? TemperaturaApiErrorKind.rejected
          : TemperaturaApiErrorKind.unavailable,
      code: code,
      statusCode: statusCode,
      details: details,
    );
  }

  @override
  void close() => _client.close();
}
