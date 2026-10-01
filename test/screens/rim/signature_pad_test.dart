import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/rim/widgets/signature_pad.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

  test('un toque o una rayita no cuentan como firma', () {
    final controller = SignaturePadController();
    addTearDown(controller.dispose);
    expect(controller.isEmpty, isTrue);
    expect(controller.hasSignature, isFalse);

    controller.start(const Offset(10, 10));
    expect(controller.isEmpty, isFalse);
    expect(controller.hasSignature, isFalse);

    controller.extend(const Offset(30, 10));
    expect(controller.hasSignature, isFalse);

    // Varios trazos cortos suman.
    controller.start(const Offset(40, 40));
    controller.extend(const Offset(90, 40));
    expect(controller.hasSignature, isTrue);

    controller.clear();
    expect(controller.isEmpty, isTrue);
    expect(controller.hasSignature, isFalse);
  });

  testWidgets('exporta la firma como PNG recortado a lo dibujado',
      (tester) async {
    final controller = SignaturePadController();
    addTearDown(controller.dispose);
    expect(await controller.toPng(), isNull);

    controller
      ..start(const Offset(100, 100))
      ..extend(const Offset(200, 120))
      ..extend(const Offset(300, 100))
      ..start(const Offset(150, 140));

    final png = await tester.runAsync(() => controller.toPng());

    expect(png, isNotNull);
    expect(png!.take(8), pngSignature);
    // Ancho 900 px (lado mayor) y alto proporcional al trazo, no a la
    // pantalla: IHDR guarda ambos en los bytes 16 a 23.
    final header = ByteData.sublistView(png, 16, 24);
    expect(header.getUint32(0), 900);
    expect(header.getUint32(4), lessThan(300));
  });

  testWidgets('se firma con el dedo y se devuelve el PNG', (tester) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Uint8List? firma;
    var cerrado = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            firma = await SignatureCaptureScreen.open(
              context,
              signerName: 'Juan Pérez',
              documentLabel: 'RIM-0090-11-26 · 0090-11-014',
            );
            cerrado = true;
          },
          child: const Text('firmar'),
        ),
      ),
    ));
    await tester.tap(find.text('firmar'));
    await tester.pumpAndSettle();

    expect(find.text('Firma del cliente'), findsOneWidget);
    expect(find.textContaining('Firma de Juan Pérez'), findsOneWidget);
    FilledButton aceptar() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aceptar firma'));
    expect(aceptar().onPressed, isNull, reason: 'todavía no hay firma');

    final pad = tester.getCenter(find.byType(SignaturePad));
    final gesture = await tester.startGesture(pad - const Offset(120, 0));
    await gesture.moveBy(const Offset(80, -30));
    await gesture.moveBy(const Offset(80, 40));
    await gesture.moveBy(const Offset(80, -20));
    await gesture.up();
    await tester.pump();
    expect(aceptar().onPressed, isNotNull);

    // "Limpiar" borra y vuelve a deshabilitar.
    await tester.tap(find.text('Limpiar'));
    await tester.pump();
    expect(aceptar().onPressed, isNull);

    final again = await tester.startGesture(pad - const Offset(100, 10));
    await again.moveBy(const Offset(200, 20));
    await again.up();
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('Aceptar firma'));
      // Codificar el PNG ocurre fuera del reloj simulado.
      for (var i = 0; i < 50 && !cerrado; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(cerrado, isTrue);
    expect(firma, isNotNull);
    expect(firma!.take(8), pngSignature);
    expect(find.text('Firma del cliente'), findsNothing);
  });
}
