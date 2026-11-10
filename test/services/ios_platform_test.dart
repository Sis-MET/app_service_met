import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/services/pantalla_encendida.dart';
import 'package:service_met/services/permisos_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const screen = MethodChannel('bo.metrica.smet/pantalla');
  const permissions = MethodChannel('bo.metrica.smet/permisos');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(screen, null);
    messenger.setMockMethodCallHandler(permissions, null);
  });

  test('la medición en iOS mantiene la pantalla hasta que termina', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var awake = false;
    messenger.setMockMethodCallHandler(screen, (call) async {
      awake = (call.arguments as Map)['encendida'] as bool;
      return null;
    });
    await PantallaEncendida.mantener(true);
    expect(awake, isTrue);
    await PantallaEncendida.mantener(false);
    expect(awake, isFalse);
  });

  test('consulta la cámara sin concederla ni solicitarla silenciosamente',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var granted = false;
    messenger.setMockMethodCallHandler(permissions, (call) async => granted);
    expect(await PermisoCamara.concedido(), isFalse);
    granted = true;
    expect(await PermisoCamara.concedido(), isTrue);
  });
}
