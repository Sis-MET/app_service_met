import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/service_met_http_client.dart';
import '../../../login/services/auth_api_service.dart';
import '../models/bitrix_crm.dart';
import '../models/opportunity_draft.dart';

enum BitrixApiErrorKind {
  /// Sin red o la API METRICA no responde: guardar como pendiente.
  offline,

  /// La API o Bitrix24 no están disponibles o mal configurados: pendiente.
  unavailable,

  /// La sesión venció o no tiene el permiso de oportunidades.
  authRequired,

  /// Datos inválidos: el técnico debe corregirlos.
  validation,

  /// Bitrix24 rechazó la oportunidad por otro motivo.
  rejected,
}

class BitrixFieldError {
  final String field;
  final String message;

  const BitrixFieldError(this.field, this.message);
}

class BitrixApiException implements Exception {
  final String message;
  final BitrixApiErrorKind kind;
  final String? code;
  final int? statusCode;
  final List<BitrixFieldError> details;

  const BitrixApiException(
    this.message, {
    required this.kind,
    this.code,
    this.statusCode,
    this.details = const [],
  });

  /// Conviene guardarla y reintentar más tarde (no hay nada que corregir).
  bool get retryable =>
      kind == BitrixApiErrorKind.offline ||
      kind == BitrixApiErrorKind.unavailable;

  @override
  String toString() => message;
}

/// Habla con `/api/bitrix/*` de la API METRICA. ServiceMET nunca llama a
/// Bitrix24 directamente: el webhook solo existe en el servidor.
class BitrixOpportunityApi {
  static const searchTimeout = Duration(seconds: 20);
  static const contactsTimeout = Duration(seconds: 25);

  /// Crear consulta etapa, campos y duplicados en Bitrix24.
  static const createTimeout = Duration(seconds: 60);

  final String baseUrl;
  final http.Client _client;
  final AuthApiService _auth;

  BitrixOpportunityApi._(this.baseUrl, this._client, this._auth);

  /// Lanza [ServiceMetNetworkException] si [baseUrl] no es la API interna
  /// autorizada (HTTPS con huella fijada).
  factory BitrixOpportunityApi(
    String baseUrl, {
    http.Client? client,
    AuthApiService? auth,
  }) {
    final httpClient = client ?? ServiceMetHttpClient.create(baseUrl);
    return BitrixOpportunityApi._(
      ServiceMetHttpClient.normalizeBaseUrl(baseUrl),
      httpClient,
      auth ?? AuthApiService(baseUrl, client: httpClient),
    );
  }

  Future<BitrixCompanySearch> searchCompanies(String query) async {
    final uri = Uri.parse('$baseUrl/api/bitrix/companies')
        .replace(queryParameters: {'q': query.trim()});
    final body = await _send(
        () async => _client.get(uri, headers: {
              'Authorization': 'Bearer ${await _token()}',
            }),
        searchTimeout);
    return BitrixCompanySearch.fromJson(body);
  }

  Future<List<BitrixContact>> contactsOf(int companyId) async {
    final uri = Uri.parse('$baseUrl/api/bitrix/companies/$companyId/contacts');
    final body = await _send(
        () async => _client.get(uri, headers: {
              'Authorization': 'Bearer ${await _token()}',
            }),
        contactsTimeout);
    return (body['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => BitrixContact.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<BitrixFormOptions> formOptions() async {
    final uri = Uri.parse('$baseUrl/api/bitrix/form-options');
    final body = await _send(
        () async => _client.get(uri, headers: {
              'Authorization': 'Bearer ${await _token()}',
            }),
        searchTimeout);
    return BitrixFormOptions.fromJson(body);
  }

  Future<OpportunityCreated> createOpportunity(OpportunityDraft draft) async {
    final uri = Uri.parse('$baseUrl/api/bitrix/opportunities');
    final body = await _send(
      () async => _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _token()}',
        },
        body: jsonEncode(draft.toJson()),
      ),
      createTimeout,
    );
    final leadId = (body['leadId'] as num?)?.toInt();
    if (leadId == null || leadId <= 0) {
      throw const BitrixApiException(
        'El servidor no devolvió el número del prospecto.',
        kind: BitrixApiErrorKind.unavailable,
        code: 'INVALID_RESPONSE',
      );
    }
    return OpportunityCreated(
      leadId: leadId,
      duplicate: body['duplicate'] == true,
      message: body['message']?.toString() ?? 'Prospecto #$leadId registrado.',
    );
  }

  /// Renueva el JWT con la contraseña del técnico (mismo token que la subida).
  Future<void> authenticate({
    required String usuario,
    required String password,
  }) async {
    try {
      await _auth
          .login(usuario: usuario, password: password)
          .timeout(searchTimeout);
    } on ServiceMetNetworkException catch (error) {
      throw BitrixApiException(
        error.message,
        kind: error.statusCode == 401 || error.statusCode == 403
            ? BitrixApiErrorKind.authRequired
            : BitrixApiErrorKind.unavailable,
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

  Future<String> _token() async {
    final token = await _auth.readValidToken();
    if (token == null) {
      throw const BitrixApiException(
        'La sesión con el servidor venció. Ingrese su contraseña.',
        kind: BitrixApiErrorKind.authRequired,
        code: 'LOCAL_CREDENTIALS_MISSING',
      );
    }
    return token;
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
    Duration timeout,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on BitrixApiException {
      rethrow;
    } on TimeoutException {
      throw const BitrixApiException(
        'El servidor no respondió a tiempo.',
        kind: BitrixApiErrorKind.offline,
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
    if (response.statusCode == 200 || response.statusCode == 201) return body;
    final error = _exception(response.statusCode, body);
    debugPrint('[Bitrix] ${response.statusCode} ${error.code ?? ''}');
    throw error;
  }

  static BitrixApiException _offline() => const BitrixApiException(
        'Sin conexión con la API de METRICA.',
        kind: BitrixApiErrorKind.offline,
        code: 'OFFLINE',
      );

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  static BitrixApiException _exception(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    final code = body['error']?.toString();
    final message =
        body['message']?.toString() ?? 'No se pudo completar la operación.';
    final details = (body['details'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => BitrixFieldError(
              item['field']?.toString() ?? '',
              item['message']?.toString() ?? '',
            ))
        .toList(growable: false);
    final BitrixApiErrorKind kind;
    if (statusCode == 401 || code == 'INSUFFICIENT_SCOPE') {
      kind = BitrixApiErrorKind.authRequired;
    } else if (statusCode == 400) {
      kind = BitrixApiErrorKind.validation;
    } else if (statusCode == 422) {
      kind = BitrixApiErrorKind.rejected;
    } else if (statusCode == 404) {
      // Una API anterior a esta versión no tiene las rutas de Bitrix.
      return BitrixApiException(
        'El servidor todavía no tiene habilitadas las oportunidades de Bitrix24.',
        kind: BitrixApiErrorKind.unavailable,
        code: code ?? 'NOT_FOUND',
        statusCode: statusCode,
      );
    } else {
      kind = BitrixApiErrorKind.unavailable;
    }
    return BitrixApiException(
      message,
      kind: kind,
      code: code,
      statusCode: statusCode,
      details: details,
    );
  }

  void close() => _client.close();
}
