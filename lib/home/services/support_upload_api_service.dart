import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/network/service_met_http_client.dart';
import '../../screens/soporte_new/utils/pruebas_omitidas.dart';
import '../../services/ubicacion_servicio.dart';
import '../models/calibration_upload_models.dart';
import 'calibration_upload_api_service.dart';

const Map<String, Set<String>> _legacyFieldsExcludedByModule = {
  'mnt_prv_avanzado': {
    'retorno_cero_inicial_unidad',
    'retorno_cero_final_unidad',
  },
};

String _normalizeSupportDate(Object value) {
  final text = value.toString().trim();
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (iso != null) {
    return '${iso.group(1)}-${iso.group(2)}-${iso.group(3)}';
  }
  final local = RegExp(r'^(\d{2})[/-](\d{2})[/-](\d{4})$').firstMatch(text);
  if (local != null) {
    return '${local.group(3)}-${local.group(2)}-${local.group(1)}';
  }
  return text;
}

List<Map<String, dynamic>> buildSupportUploadEnvelopes(
  List<Map<String, dynamic>> records,
) {
  return records.map((record) {
    final module = record['_support_module']?.toString() ?? '';
    final legacyFields = _legacyFieldsExcludedByModule[module] ?? const {};
    final data = <String, dynamic>{};
    for (final entry in record.entries) {
      if (entry.key.startsWith('_') ||
          entry.key == 'id' ||
          entry.key == 'n' ||
          entry.key == 'foto_balanza' ||
          entry.key.endsWith('_foto') ||
          entry.key == 'estado_servicio_csv' ||
          entry.key == 'nombre_zip' ||
          // Solo del teléfono: el servidor no tiene esta columna.
          entry.key == PruebasOmitidas.columna ||
          UbicacionServicio.columnas.contains(entry.key) ||
          legacyFields.contains(entry.key)) {
        continue;
      }
      var value = entry.value;
      if ((entry.key == 'fecha_servicio' ||
              entry.key == 'fecha_prox_servicio') &&
          value != null) {
        value = _normalizeSupportDate(value);
      }
      data[entry.key] = value;
    }
    final otst = record['otst']?.toString().trim() ?? '';
    final session = record['session_id']?.toString().trim() ?? '';
    data['nombre_csv'] =
        '${otst}_$module${session.isEmpty ? '' : '_$session'}.csv';
    final ubicacion = UbicacionServicio.deRegistro(record);
    return {
      'module': module,
      'data': data,
      // Aparte del registro: va al resumen DATA_SERVICIOS_DATOS.
      if (ubicacion != null) 'ubicacion': ubicacion.toJson(),
    };
  }).toList(growable: false);
}

class SupportUploadApiService {
  final String baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  SupportUploadApiService(
    String baseUrl, {
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? ServiceMetHttpClient.create(baseUrl),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  String get _tokenKey =>
      'servicemet_api_token_${base64Url.encode(utf8.encode(baseUrl))}';
  String get _expiryKey => '${_tokenKey}_expiry';

  Future<String> _token() async {
    final token = await _secureStorage.read(key: _tokenKey);
    final expiry = DateTime.tryParse(
      await _secureStorage.read(key: _expiryKey) ?? '',
    );
    if (token != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return token;
    }
    throw CalibrationUploadException(
      'Ingresa tu contraseña para renovar la sesión con el servidor.',
      code: 'LOCAL_CREDENTIALS_MISSING',
    );
  }

  Future<void> authenticate({
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
        'El servidor no devolvió una sesión válida.',
      );
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
  }

  List<Map<String, dynamic>> _envelopes(
    List<Map<String, dynamic>> records,
  ) =>
      buildSupportUploadEnvelopes(records);

  Future<http.Response> _post(String path, Object body) async {
    final token = await _token();
    return _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));
  }

  Future<CalibrationValidationResult> validate(
    List<Map<String, dynamic>> records,
  ) async {
    final response = await _post(
      '/api/soporte/validar',
      {'records': _envelopes(records)},
    );
    final body = _decode(response);
    if (response.statusCode != 200) throw _exception(response.statusCode, body);
    return CalibrationValidationResult.fromJson(body);
  }

  Future<CalibrationUploadResult> upload(
    List<Map<String, dynamic>> records, {
    required bool validOnly,
  }) async {
    final response = await _post('/api/soporte/subir', {
      'mode': validOnly ? 'valid_only' : 'all',
      'records': _envelopes(records),
    });
    final body = _decode(response);
    if (response.statusCode != 201) throw _exception(response.statusCode, body);
    return CalibrationUploadResult.fromJson(body);
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

  CalibrationUploadException _exception(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    return CalibrationUploadException(
      body['message']?.toString() ?? 'No se pudo completar la operación.',
      statusCode: statusCode,
      code: body['error']?.toString(),
    );
  }

  void close() => _client.close();
}
