import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/service_met_http_client.dart';
import '../../../login/services/auth_api_service.dart';
import '../models/rim_documento.dart';

enum RimApiErrorKind {
  /// Sin red o la API METRICA no responde: el RIM sigue pendiente.
  offline,

  /// El servidor no está disponible o todavía no tiene la tabla de RIM.
  unavailable,

  /// La sesión venció o no tiene el permiso de formularios adicionales.
  authRequired,

  /// El servidor rechazó el contenido del RIM.
  rejected,
}

class RimApiException implements Exception {
  final String message;
  final RimApiErrorKind kind;
  final String? code;
  final int? statusCode;

  const RimApiException(
    this.message, {
    required this.kind,
    this.code,
    this.statusCode,
  });

  /// Conviene reintentar más tarde tal cual (no hay nada que corregir).
  bool get retryable =>
      kind == RimApiErrorKind.offline || kind == RimApiErrorKind.unavailable;

  @override
  String toString() => message;
}

/// Resultado de `POST /api/extras/rim`.
class RimUploaded {
  /// Correlativo asignado por el servidor en `form_rim`.
  final int n;

  /// El servidor ya tenía este RIM (mismo UUID) y no lo insertó de nuevo.
  final bool duplicate;

  const RimUploaded({required this.n, required this.duplicate});
}

/// Sube los RIM a `servicios_extras.form_rim` a través de la API METRICA.
class RimApi {
  static const uploadTimeout = Duration(seconds: 45);
  static const authTimeout = Duration(seconds: 20);

  final String baseUrl;
  final http.Client _client;
  final AuthApiService _auth;

  RimApi._(this.baseUrl, this._client, this._auth);

  /// Lanza [ServiceMetNetworkException] si [baseUrl] no es la API interna
  /// autorizada (HTTPS con huella fijada).
  factory RimApi(
    String baseUrl, {
    http.Client? client,
    AuthApiService? auth,
  }) {
    final httpClient = client ?? ServiceMetHttpClient.create(baseUrl);
    return RimApi._(
      ServiceMetHttpClient.normalizeBaseUrl(baseUrl),
      httpClient,
      auth ?? AuthApiService(baseUrl, client: httpClient),
    );
  }

  Future<RimUploaded> upload(RimRegistro registro) async {
    final token = await _auth.readValidToken();
    if (token == null) {
      throw const RimApiException(
        'La sesión con el servidor venció. Ingrese su contraseña.',
        kind: RimApiErrorKind.authRequired,
        code: 'LOCAL_CREDENTIALS_MISSING',
      );
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/api/extras/rim'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(registro.toUploadJson()),
          )
          .timeout(uploadTimeout);
    } on TimeoutException {
      throw const RimApiException(
        'El servidor no respondió a tiempo.',
        kind: RimApiErrorKind.offline,
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
      final n = (body['n'] as num?)?.toInt();
      if (n == null || n <= 0) {
        throw const RimApiException(
          'El servidor no devolvió el número del RIM.',
          kind: RimApiErrorKind.unavailable,
          code: 'INVALID_RESPONSE',
        );
      }
      return RimUploaded(n: n, duplicate: body['duplicate'] == true);
    }
    final error = _exception(response.statusCode, body);
    debugPrint('[RIM] ${response.statusCode} ${error.code ?? ''}');
    throw error;
  }

  /// Renueva el JWT con la contraseña del técnico (mismo token que la subida
  /// de servicios).
  Future<void> authenticate({
    required String usuario,
    required String password,
  }) async {
    try {
      await _auth
          .login(usuario: usuario, password: password)
          .timeout(authTimeout);
    } on ServiceMetNetworkException catch (error) {
      throw RimApiException(
        error.message,
        kind: error.statusCode == 401 || error.statusCode == 403
            ? RimApiErrorKind.authRequired
            : RimApiErrorKind.unavailable,
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

  static RimApiException _offline() => const RimApiException(
        'Sin conexión con la API de METRICA.',
        kind: RimApiErrorKind.offline,
        code: 'OFFLINE',
      );

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  static RimApiException _exception(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    final code = body['error']?.toString();
    final message =
        body['message']?.toString() ?? 'No se pudo completar la operación.';
    if (statusCode == 401 || code == 'INSUFFICIENT_SCOPE') {
      return RimApiException(
        message,
        kind: RimApiErrorKind.authRequired,
        code: code,
        statusCode: statusCode,
      );
    }
    if (statusCode == 404) {
      // Una API anterior a esta versión no tiene la ruta de RIM.
      return RimApiException(
        'El servidor todavía no recibe formularios RIM.',
        kind: RimApiErrorKind.unavailable,
        code: code ?? 'NOT_FOUND',
        statusCode: statusCode,
      );
    }
    return RimApiException(
      message,
      kind: statusCode == 400 || statusCode == 422
          ? RimApiErrorKind.rejected
          : RimApiErrorKind.unavailable,
      code: code,
      statusCode: statusCode,
    );
  }

  void close() => _client.close();
}
