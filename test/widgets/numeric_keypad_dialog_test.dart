import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';
import 'package:service_met/widgets/numeric_keypad.dart';

void main() {
  testWidgets('el teclado queda al pie de pantalla y fuera del diálogo',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final percentage = TextEditingController();
    final factor = TextEditingController();
    addTearDown(percentage.dispose);
    addTearDown(factor.dispose);
    List<String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<List<String>>(
                        context: context,
                        builder: (dialogContext) => NumericKeypadHost(
                          dockToScreen: true,
                          child: AlertDialog(
                            scrollable: true,
                            title: const Text('Datos del Certificado'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                        'Ingrese los datos para el certificado de calibración:'),
                                    const SizedBox(height: 16),
                                    Row(children: [
                                      Expanded(
                                          child: CalibrationNumberField(
                                        key: const ValueKey('percentage'),
                                        controller: percentage,
                                        column: 'indicar',
                                        decoration: const InputDecoration(
                                            labelText: 'Indicar (%)'),
                                      )),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: CalibrationNumberField(
                                        key: const ValueKey('factor'),
                                        controller: factor,
                                        column: 'factor',
                                        decoration: const InputDecoration(
                                            labelText: 'Factor Seguridad'),
                                      )),
                                    ]),
                                    const SizedBox(height: 80),
                                  ]),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext,
                                    [percentage.text, factor.text]),
                                child: const Text('Continuar'),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                    child: const Text('Abrir'),
                  ))),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('percentage')));
    await tester.pumpAndSettle();
    final keypad = find.byType(NumericKeypad);
    expect(find.descendant(of: find.byType(AlertDialog), matching: keypad),
        findsNothing);
    final bounds = tester.getRect(keypad);
    expect(bounds.left, 0);
    expect(bounds.right, 360);
    expect(bounds.bottom, 640);
    expect(tester.getRect(find.byType(AlertDialog)).bottom,
        lessThanOrEqualTo(bounds.top));
    expect(tester.takeException(), isNull);

    Future<void> key(String name) async {
      await tester.tap(find.byKey(ValueKey('keypad-$name')));
      await tester.pumpAndSettle();
    }

    await key('5');
    await key('point');
    await key('5');
    await key('next');
    await key('2');
    expect(percentage.text, '5.5');
    expect(factor.text, '2');

    // Atrás oculta el teclado sin cerrar el diálogo ni perder los valores.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keypad-1')), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('factor')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keypad-1')), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(result, ['5.5', '2']);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(NumericKeypad), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
