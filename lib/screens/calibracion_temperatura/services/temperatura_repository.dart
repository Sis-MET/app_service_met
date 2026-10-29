import 'package:flutter/foundation.dart';

import '../../../core/network/service_met_http_client.dart';
import '../../../utils/new_scale_code.dart';
import '../data/temperatura_store.dart';
import '../models/temperatura_models.dart';
import 'temperatura_api.dart';
import 'temperatura_export.dart';

/// Pide la contraseña para renovar la sesión; null si el técnico cancela.
typedef TemperaturaPasswordPrompt = Future<String?> Function(String? error);

class TemperaturaSubida {
  const TemperaturaSubida(this.servicio, {this.error, this.duplicado = false});

  final TempServicio servicio;
  final TemperaturaApiException? error;

  /// DataMET ya tenía este registro (mismo uuid): quedó marcado como subido.
  final bool duplicado;

  bool get ok => error == null;
}

/// Sube a DataMET las calibraciones de temperatura finalizadas. Nunca lanza
/// por falta de red: el registro queda pendiente con el motivo.
class TemperaturaRepository {
  TemperaturaRepository({
    required String? Function() apiUrl,
    required Future<String?> Function() loggedUser,
    TemperaturaStore? store,
    TemperaturaUploader Function(String baseUrl)? apiFactory,
  })  : _apiUrl = apiUrl,
        _loggedUser = loggedUser,
        _store = store ?? TemperaturaStore(),
        _apiFactory = apiFactory ?? TemperaturaApi.new;

  static final Set<String> _enVuelo = {};

  final String? Function() _apiUrl;
  final Future<String?> Function() _loggedUser;
  final TemperaturaStore _store;
  final TemperaturaUploader Function(String baseUrl) _apiFactory;
  TemperaturaUploader? _api;

  TemperaturaStore get store => _store;

  /// Por qué no se puede subir todavía, o null.
  static String? impedimento(TempServicio servicio) {
    if (servicio.subido) return 'Ya está en DataMET.';
    if (!servicio.finalizado) return 'Finalice la calibración para subirla.';
    if (NewScaleCode.isProvisional(servicio.equipo?.codMetrica)) {
      return 'Asigne el código métrica definitivo del equipo nuevo.';
    }
    return null;
  }

  Future<TemperaturaSubida> subir(
    String uuid, {
    TemperaturaPasswordPrompt? onAuthRequired,
  }) async {
    final paquete = await _store.paquete(uuid);
    if (paquete == null) {
      throw StateError('No existe el registro $uuid');
    }
    final impedimento = TemperaturaRepository.impedimento(paquete.servicio);
    if (impedimento != null) {
      return TemperaturaSubida(
        paquete.servicio,
        error: TemperaturaApiException(impedimento,
            kind: TemperaturaApiErrorKind.rejected, code: 'NOT_READY_LOCAL'),
      );
    }
    if (!_enVuelo.add(uuid)) {
      return TemperaturaSubida(
        paquete.servicio,
        error: const TemperaturaApiException(
            'Este registro ya se está subiendo.',
            kind: TemperaturaApiErrorKind.rejected,
            code: 'IN_FLIGHT'),
      );
    }
    try {
      await _store.marcarSubida(uuid, EstadoSubidaTemp.enviando);
      try {
        final cuerpo = TemperaturaExport.uploadJson(paquete);
        final resultado =
            await _withAuth((api) => api.subir(cuerpo), onAuthRequired);
        await _store.marcarSubida(uuid, EstadoSubidaTemp.subido,
            serverN: resultado.n);
        debugPrint('[Temperatura] subido: n=${resultado.n}');
        return TemperaturaSubida((await _store.servicio(uuid))!,
            duplicado: resultado.duplicate);
      } on TemperaturaApiException catch (error) {
        final pendiente = error.retryable ||
            error.kind == TemperaturaApiErrorKind.authRequired;
        await _store.marcarSubida(
          uuid,
          pendiente ? EstadoSubidaTemp.pendiente : EstadoSubidaTemp.error,
          error: error.message,
        );
        return TemperaturaSubida((await _store.servicio(uuid))!, error: error);
      }
    } finally {
      _enVuelo.remove(uuid);
    }
  }

  TemperaturaUploader _requireApi() {
    final current = _api;
    if (current != null) return current;
    final url = _apiUrl()?.trim() ?? '';
    if (url.isEmpty) {
      throw const TemperaturaApiException(
        'No hay un perfil de conexión con la API de METRICA.',
        kind: TemperaturaApiErrorKind.unavailable,
        code: 'NO_API_PROFILE',
      );
    }
    try {
      return _api = _apiFactory(url);
    } on ServiceMetNetworkException catch (error) {
      throw TemperaturaApiException(error.message,
          kind: TemperaturaApiErrorKind.unavailable, code: error.code);
    }
  }

  /// Ejecuta [operation]; si la sesión venció pide la contraseña (hasta tres
  /// veces si es incorrecta) y reintenta una sola vez.
  Future<T> _withAuth<T>(
    Future<T> Function(TemperaturaUploader api) operation,
    TemperaturaPasswordPrompt? onAuthRequired,
  ) async {
    final api = _requireApi();
    try {
      return await operation(api);
    } on TemperaturaApiException catch (error) {
      if (error.kind != TemperaturaApiErrorKind.authRequired ||
          onAuthRequired == null) {
        rethrow;
      }
      final usuario = await _loggedUser();
      if (usuario == null || usuario.isEmpty) {
        throw const TemperaturaApiException(
          'No hay un usuario activo. Cierre sesión e ingrese nuevamente.',
          kind: TemperaturaApiErrorKind.authRequired,
          code: 'NO_USER',
        );
      }
      String? message;
      for (var attempt = 0; attempt < 3; attempt++) {
        final password = await onAuthRequired(message);
        if (password == null || password.isEmpty) rethrow;
        try {
          await api.authenticate(usuario: usuario, password: password);
        } on TemperaturaApiException catch (authError) {
          if (authError.kind != TemperaturaApiErrorKind.authRequired) rethrow;
          message = authError.message;
          continue;
        }
        return operation(api);
      }
      rethrow;
    }
  }

  void close() {
    _api?.close();
    _api = null;
  }
}
