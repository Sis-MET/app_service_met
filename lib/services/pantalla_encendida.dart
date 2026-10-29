import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mantiene la pantalla encendida mientras dura una medición programada:
/// con la pantalla apagada Android detiene la cámara y se perderían
/// lecturas. Fuera de Android no hace nada.
abstract final class PantallaEncendida {
  static const _canal = MethodChannel('bo.metrica.smet/pantalla');

  static Future<void> mantener(bool encendida) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
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
