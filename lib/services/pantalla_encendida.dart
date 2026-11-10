import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mantiene la pantalla encendida mientras dura una medición programada:
/// con la pantalla apagada el sistema detiene la cámara y se perderían
/// lecturas. Compatible con Android y iOS.
abstract final class PantallaEncendida {
  static const _canal = MethodChannel('bo.metrica.smet/pantalla');

  static Future<void> mantener(bool encendida) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _canal
          .invokeMethod<void>('mantenerEncendida', {'encendida': encendida});
    } on MissingPluginException {
      // En las pruebas no hay actividad.
    } on PlatformException catch (error) {
      debugPrint('No se pudo mantener la pantalla encendida: $error');
    }
  }
}
