import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/network/service_met_http_client.dart';
import '../models/rim_documento.dart';
import '../models/rim_numeracion.dart';
import 'rim_api.dart';
import 'rim_store.dart';

/// Pide la contraseña del técnico para renovar la sesión. [error] explica el
/// intento anterior fallido. Devuelve null si el técnico cancela.
typedef RimPasswordPrompt = Future<String?> Function(String? error);

class RimUploadResult {
  final RimRegistro registro;

  /// Null si quedó registrado en el servidor.
  final RimApiException? error;

  const RimUploadResult(this.registro, {this.error});

  bool get sent => registro.isSent;
}

/// Resultado de [RimRepository.asegurarTalonarios].
class RimTalonariosResultado {
  /// Talonarios recibidos en esta pasada.
  final int recibidos;

  /// Números libres de la gestión en curso al terminar.
  final int restantes;

  /// Por qué no se pudo pedir un talonario que hacía falta.
  final RimApiException? error;

  const RimTalonariosResultado({
    required this.recibidos,
    required this.restantes,
    this.error,
  });
}

/// Orquesta la tabla local de RIM y la API METRICA.
///
/// Emitir es solo local: el RIM queda guardado en el teléfono, con las firmas
/// del cliente y del representante de Métrica, aunque no haya red. Su número
/// sale de un talonario que el teléfono recibió antes, cuando tuvo conexión
/// ([asegurarTalonarios]). La subida al servidor es un paso aparte que el
/// técnico inicia a mano; reenviar usa el mismo UUID, así que no duplica el
/// RIM en el servidor.
class RimRepository {
  /// UUIDs que se están subiendo ahora, en cualquier pantalla.
  static final Set<String> _inFlight = {};

  /// Pasada de talonarios en curso, compartida por todas las pantallas.
  static Future<RimTalonariosResultado>? _talonariosEnCurso;

  final RimStore _store;
  final String? Function() _apiUrl;
  final Future<String?> Function() _loggedUser;
  final Future<String?> Function() _appVersion;
  final RimApi Function(String baseUrl) _apiFactory;
  RimApi? _api;

  RimRepository({
    required String? Function() apiUrl,
    required Future<String?> Function() loggedUser,
    Future<String?> Function()? appVersion,
    RimStore? store,
    RimApi Function(String baseUrl)? apiFactory,
  })  : _apiUrl = apiUrl,
        _loggedUser = loggedUser,
        _appVersion = appVersion ?? (() async => null),
        _store = store ?? RimStore(),
        _apiFactory = apiFactory ?? RimApi.new;

  /// Siguiente número libre de este teléfono para un RIM emitido [ahora];
  /// null si no le quedan (hay que conectarse para recibir un talonario).
  Future<RimNumero?> proximoNumero([DateTime? ahora]) =>
      _store.proximoNumero(gestion: (ahora ?? DateTime.now()).year);

  /// Pide un talonario si a este teléfono le quedan menos de
  /// [rimUmbralTalonario] números en la gestión (y, en diciembre, también
  /// para la siguiente), e informa al servidor los talonarios de gestiones
  /// pasadas que ya no usará. Nunca lanza por falta de red: lo que no se pudo
  /// hacer queda en el resultado y se reintenta en la siguiente pasada.
  Future<RimTalonariosResultado> asegurarTalonarios({
    RimPasswordPrompt? onAuthRequired,
    DateTime? ahora,
  }) {
    final enCurso = _talonariosEnCurso;
    if (enCurso != null) return enCurso;
    final pasada = _asegurarTalonarios(onAuthRequired, ahora ?? DateTime.now());
    _talonariosEnCurso = pasada;
    return pasada.whenComplete(() => _talonariosEnCurso = null);
  }

  Future<RimTalonariosResultado> _asegurarTalonarios(
    RimPasswordPrompt? onAuthRequired,
    DateTime ahora,
  ) async {
    var recibidos = 0;
    RimApiException? error;
    final gestiones = [ahora.year, if (ahora.month == 12) ahora.year + 1];
    for (final gestion in gestiones) {
      final actual = await _store.proximoNumero(gestion: gestion);
      if ((actual?.restantes ?? 0) >= rimUmbralTalonario) continue;
      try {
        final instalacion = await _store.instalacion();
        final solicitud = await _store.solicitudTalonario(gestion);
        final version = await _versionSegura();
        final recibido = await _withAuth(
          (api) => api.pedirTalonario(
            requestId: solicitud,
            installationId: instalacion,
            year: gestion,
            device: _dispositivo(),
            appVersion: version,
          ),
          onAuthRequired,
        );
        await _store.guardarTalonario(
          RimTalonario(
            id: recibido.id,
            instalacion: instalacion,
            gestion: recibido.gestion,
            desde: recibido.desde,
            hasta: recibido.hasta,
            recibidoEn: DateTime.now(),
          ),
          solicitud: solicitud,
        );
        recibidos++;
        debugPrint('[RIM] talonario ${recibido.gestion}: '
            '${recibido.desde}-${recibido.hasta}');
      } on RimApiException catch (failure) {
        error = failure;
        debugPrint('[RIM] talonario no recibido: ${failure.code ?? failure.kind}');
        break;
      }
    }

    // Talonarios de gestiones pasadas: sus números libres ya no se usarán.
    if (error == null) {
      try {
        final instalacion = await _store.instalacion();
        for (final pendiente in await _store.talonariosPorCerrar(ahora.year)) {
          await _withAuth(
            (api) => api.cerrarTalonario(
              pendiente.talonario.id,
              installationId: instalacion,
              lastUsed: pendiente.ultimoUsado,
            ),
            null,
          );
          await _store.marcarCierreReportado(pendiente.talonario.id);
        }
      } on RimApiException catch (failure) {
        debugPrint('[RIM] cierre de talonario pendiente: '
            '${failure.code ?? failure.kind}');
      }
    }

    final restantes =
        (await _store.proximoNumero(gestion: ahora.year))?.restantes ?? 0;
    return RimTalonariosResultado(
      recibidos: recibidos,
      restantes: restantes,
      error: error,
    );
  }

  Future<String?> _versionSegura() async {
    try {
      return await _appVersion();
    } catch (_) {
      return null;
    }
  }

  /// Sistema del teléfono, como referencia del talonario (sin datos
  /// personales).
  static String _dispositivo() {
    try {
      final texto =
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      return texto.length > 120 ? texto.substring(0, 120) : texto;
    } catch (_) {
      return '';
    }
  }

  /// Guarda el RIM firmado en el teléfono. Desde aquí ya no se modifica.
  Future<RimRegistro> emitir(
    RimDocumento documento,
    Uint8List firmaCliente,
    Uint8List firmaRepresentante,
  ) =>
      _store.insert(documento, firmaCliente, firmaRepresentante);

  Future<List<RimRegistro>> list() => _store.list();

  Future<int> countUnsent() => _store.countUnsent();

  Future<bool> existsForService({
    required String? sessionId,
    required String? codMetrica,
  }) =>
      _store.existsForService(sessionId: sessionId, codMetrica: codMetrica);

  /// Anula un RIM todavía no subido, a nombre del usuario con sesión.
  Future<bool> anular(RimRegistro registro, String motivo) async {
    final usuario = (await _loggedUser())?.trim() ?? '';
    if (usuario.isEmpty) {
      throw StateError('No hay un usuario activo para anular el RIM.');
    }
    return _store.anular(registro.uuid, usuario: usuario, motivo: motivo);
  }

  /// Sube el RIM al servidor. Nunca lanza por falta de red: el RIM sigue
  /// pendiente y el motivo queda en el resultado.
  Future<RimUploadResult> subir(
    RimRegistro registro, {
    RimPasswordPrompt? onAuthRequired,
  }) async {
    if (!registro.canUpload) return RimUploadResult(registro);
    if (!_inFlight.add(registro.uuid)) {
      return RimUploadResult(
        registro,
        error: const RimApiException(
          'Este RIM ya se está subiendo.',
          kind: RimApiErrorKind.rejected,
          code: 'IN_FLIGHT',
        ),
      );
    }
    try {
      await _store.markSending(registro.uuid);
      try {
        final uploaded = await _withAuth(
          (api) => api.upload(registro),
          onAuthRequired,
        );
        debugPrint('[RIM] subido: n=${uploaded.n}');
        return RimUploadResult(
          await _store.markSent(registro.uuid, uploaded.n),
        );
      } on RimApiException catch (error) {
        final keepPending =
            error.retryable || error.kind == RimApiErrorKind.authRequired;
        final failed = await _store.markFailed(
          registro.uuid,
          estado: keepPending ? RimEstadoSubida.pending : RimEstadoSubida.error,
          error: error.message,
        );
        debugPrint('[RIM] subida no completada: ${error.code ?? error.kind}');
        return RimUploadResult(failed, error: error);
      }
    } finally {
      _inFlight.remove(registro.uuid);
    }
  }

  RimApi _requireApi() {
    final current = _api;
    if (current != null) return current;
    final url = _apiUrl()?.trim() ?? '';
    if (url.isEmpty) {
      throw const RimApiException(
        'No hay un perfil de conexión con la API de METRICA.',
        kind: RimApiErrorKind.unavailable,
        code: 'NO_API_PROFILE',
      );
    }
    try {
      return _api = _apiFactory(url);
    } on ServiceMetNetworkException catch (error) {
      throw RimApiException(
        error.message,
        kind: RimApiErrorKind.unavailable,
        code: error.code,
      );
    }
  }

  /// Ejecuta [operation]; si la sesión venció pide la contraseña (hasta tres
  /// veces si es incorrecta) y reintenta una sola vez.
  Future<T> _withAuth<T>(
    Future<T> Function(RimApi api) operation,
    RimPasswordPrompt? onAuthRequired,
  ) async {
    final api = _requireApi();
    try {
      return await operation(api);
    } on RimApiException catch (error) {
      if (error.kind != RimApiErrorKind.authRequired ||
          onAuthRequired == null) {
        rethrow;
      }
      final usuario = await _loggedUser();
      if (usuario == null || usuario.isEmpty) {
        throw const RimApiException(
          'No hay un usuario activo. Cierre sesión e ingrese nuevamente.',
          kind: RimApiErrorKind.authRequired,
          code: 'NO_USER',
        );
      }
      String? message;
      for (var attempt = 0; attempt < 3; attempt++) {
        final password = await onAuthRequired(message);
        if (password == null || password.isEmpty) rethrow;
        try {
          await api.authenticate(usuario: usuario, password: password);
        } on RimApiException catch (authError) {
          if (authError.kind != RimApiErrorKind.authRequired) rethrow;
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
