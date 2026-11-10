import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Permisos del teléfono que pide ServiceMET. Antes de cada solicitud del
/// sistema la app muestra su propio aviso (ver `confirmarPermiso`): ninguna
/// se pide en silencio.
enum PermisoApp { ubicacion, notificaciones, camara }

/// Abre la página de la app en los ajustes del teléfono, donde se conceden
/// los permisos rechazados con "No volver a preguntar".
Future<bool> abrirAjustesDeLaApp() => Geolocator.openAppSettings();

/// En qué situación está la ubicación del teléfono para la app.
enum EstadoUbicacion {
  /// Permiso concedido y ubicación del teléfono encendida.
  concedida,

  /// Sin permiso todavía, o rechazado una vez: se puede volver a pedir.
  denegada,

  /// Rechazado con "No volver a preguntar": solo se concede en Ajustes.
  denegadaSiempre,

  /// Permiso concedido, pero la ubicación del teléfono está apagada.
  apagada,
}

/// Acceso al permiso y al interruptor de ubicación del teléfono.
///
class AccesoUbicacion {
  const AccesoUbicacion();

  /// La que usa la app; las pruebas la reemplazan para simular cada
  /// situación.
  static AccesoUbicacion instancia = const AccesoUbicacion();

  Future<EstadoUbicacion> estado() async =>
      _desdePermiso(await Geolocator.checkPermission());

  /// Muestra la solicitud del sistema y devuelve cómo quedó.
  Future<EstadoUbicacion> solicitar() async =>
      _desdePermiso(await Geolocator.requestPermission());

  Future<void> abrirAjustesApp() => abrirAjustesDeLaApp();

  Future<void> abrirAjustesUbicacion() => Geolocator.openLocationSettings();

  Future<EstadoUbicacion> _desdePermiso(LocationPermission permiso) async {
    switch (permiso) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return await Geolocator.isLocationServiceEnabled()
            ? EstadoUbicacion.concedida
            : EstadoUbicacion.apagada;
      case LocationPermission.deniedForever:
        return EstadoUbicacion.denegadaSiempre;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return EstadoUbicacion.denegada;
    }
  }
}

/// Estado del permiso de cámara. La cámara la piden los complementos que la
/// abren (QR, lector del indicador, fotos); aquí solo se consulta, para avisar
/// antes de que aparezca la solicitud del sistema.
class PermisoCamara {
  const PermisoCamara._();

  static const _canal = MethodChannel('bo.metrica.smet/permisos');

  /// Las pruebas lo reemplazan.
  @visibleForTesting
  static Future<bool> Function()? concedidoOverride;

  static Future<bool> concedido() async {
    final override = concedidoOverride;
    if (override != null) return override();
    try {
      return await _canal.invokeMethod<bool>('camaraConcedida') ?? false;
    } on MissingPluginException {
      // En escritorio y en las pruebas no se registra el canal nativo.
      return true;
    } catch (_) {
      return false;
    }
  }
}
