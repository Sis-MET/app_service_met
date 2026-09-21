import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';
import 'package:service_met/widgets/numeric_keypad.dart';

TextEditingValue _at(String text, [int? offset]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset ?? text.length),
    );

void main() {
  group('KeypadEdit', () {
    test('el punto entra una sola vez y al principio escribe "0."', () {
      expect(KeypadEdit.decimalPoint(_at('')).text, '0.');
      expect(KeypadEdit.decimalPoint(_at('-')).text, '-0.');
      expect(KeypadEdit.decimalPoint(_at('12')).text, '12.');
      expect(KeypadEdit.decimalPoint(_at('12.5')).text, '12.5');
    });

    test('el signo va siempre delante y pulsarlo otra vez lo quita', () {
      final negativo = KeypadEdit.toggleSign(_at('1.5', 1));
      expect(negativo.text, '-1.5');
      expect(negativo.selection.baseOffset, 2);
      expect(KeypadEdit.toggleSign(negativo).text, '1.5');
    });

    test('borrar quita el caracter antes del cursor o la selección', () {
      expect(KeypadEdit.backspace(_at('12.5')).text, '12.');
      expect(KeypadEdit.backspace(_at('12.5', 0)).text, '12.5');
      final seleccion = const TextEditingValue(
        text: '12.5',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
      );
      expect(KeypadEdit.backspace(seleccion).text, '15');
    });
  });

  group('DecimalTextInputFormatter', () {
    TextEditingValue format(String text,
            {bool negative = false, bool decimal = true}) =>
        DecimalTextInputFormatter(
          allowNegative: negative,
          allowDecimal: decimal,
        ).formatEditUpdate(_at('1'), _at(text));

    test('cambia la coma del teclado del sistema por punto', () {
      expect(format('0,5').text, '0.5');
    });

    test('rechaza letras, dos separadores y signos no permitidos', () {
      expect(format('1a').text, '1');
      expect(format('1.2.3').text, '1');
      expect(format('-1').text, '1');
      expect(format('-1', negative: true).text, '-1');
      expect(format('1.5', decimal: false).text, '1');
    });
  });

  group('teclado en un formulario', () {
    late TextEditingController indicacion;
    late TextEditingController carga;
    late TextEditingController cantidad;
    late List<String> escritos;

    setUp(() {
      indicacion = TextEditingController();
      carga = TextEditingController();
      cantidad = TextEditingController();
      escritos = [];
    });

    tearDown(() {
      indicacion.dispose();
      carga.dispose();
      cantidad.dispose();
    });

    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumericKeypadHost(
              child: Column(
                children: [
                  CalibrationNumberField(
                    key: const ValueKey('indicacion'),
                    controller: indicacion,
                    column: 'indicacion1_1',
                    allowNegative: true,
                    onChanged: escritos.add,
                  ),
                  CalibrationNumberField(
                    key: const ValueKey('carga'),
                    controller: carga,
                    column: 'carga',
                  ),
                  CalibrationNumberField(
                    key: const ValueKey('cantidad'),
                    controller: cantidad,
                    column: 'cantidad1',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Future<void> tecla(WidgetTester tester, String nombre) async {
      await tester.tap(find.byKey(ValueKey('keypad-$nombre')));
      await tester.pump();
    }

    bool teclaActiva(WidgetTester tester, String nombre) =>
        tester
            .widget<GestureDetector>(find.descendant(
              of: find.byKey(ValueKey('keypad-$nombre')),
              matching: find.byType(GestureDetector),
            ))
            .onTap !=
        null;

    testWidgets('escribe con punto decimal sin abrir el teclado del sistema',
        (tester) async {
      await montar(tester);
      expect(find.byKey(const ValueKey('keypad-1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();

      expect(find.byKey(const ValueKey('keypad-1')), findsOneWidget);
      // Ni siquiera se abre la conexión con el teclado del sistema: el campo
      // es de solo lectura y lo escribe el teclado propio.
      expect(tester.testTextInput.setClientArgs, isNull);
      expect(tester.testTextInput.isVisible, isFalse);

      await tecla(tester, 'sign');
      await tecla(tester, '1');
      await tecla(tester, 'point');
      await tecla(tester, '5');
      await tecla(tester, 'point');

      expect(indicacion.text, '-1.5');
      expect(escritos.last, '-1.5');
    });

    testWidgets(
        '"Siguiente" recorre los campos: la carga lleva punto, la cantidad no',
        (tester) async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();

      await tecla(tester, 'next');
      await tester.pump();

      // La carga es decimal(15,6) desde la migración 011, pero no negativa.
      expect(teclaActiva(tester, 'point'), isTrue);
      expect(teclaActiva(tester, 'sign'), isFalse);
      for (final nombre in ['6', '6', 'point', '6', '5']) {
        await tecla(tester, nombre);
      }
      expect(carga.text, '66.65');

      await tecla(tester, 'next');
      await tester.pump();

      expect(teclaActiva(tester, 'point'), isFalse);
      await tecla(tester, '3');
      expect(cantidad.text, '3');

      // Después del último campo, "Siguiente" cierra el teclado.
      await tecla(tester, 'next');
      await tester.pump();
      expect(find.byKey(const ValueKey('keypad-1')), findsNothing);
    });

    testWidgets('el panel no se rearma al cerrarlo y volverlo a abrir',
        (tester) async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();
      final antes = tester.element(find.byKey(const ValueKey('keypad-1')));

      await tecla(tester, 'done');
      expect(find.byKey(const ValueKey('keypad-1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('carga')));
      await tester.pump();
      expect(
        tester.element(find.byKey(const ValueKey('keypad-1'))),
        same(antes),
      );
    });

    testWidgets('pasar de un campo a otro no avisa que el teclado se ve',
        (tester) async {
      await montar(tester);
      final keypad = NumericKeypadScope.maybeOf(
        tester.element(find.byKey(const ValueKey('indicacion'))),
      )!;
      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();

      var avisos = 0;
      keypad.visibility.addListener(() => avisos++);
      await tecla(tester, 'next');
      await tecla(tester, 'next');

      expect(cantidad.text, isEmpty);
      expect(keypad.visible, isTrue);
      expect(avisos, 0);
    });

    testWidgets('muestra debajo del campo lo que el guardado rechazaría',
        (tester) async {
      await montar(tester);

      cantidad.text = '1.5';
      await tester.pump();

      expect(find.text('debe ser un número entero, sin decimales'),
          findsOneWidget);

      cantidad.text = '2';
      await tester.pump();

      expect(
          find.text('debe ser un número entero, sin decimales'), findsNothing);
    });

    testWidgets('"Listo" cierra el teclado sin borrar lo escrito',
        (tester) async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();
      await tecla(tester, '2');

      await tecla(tester, 'done');
      await tester.pump();

      expect(find.byKey(const ValueKey('keypad-1')), findsNothing);
      expect(indicacion.text, '2');
    });
  });

  group('leer del indicador', () {
    late TextEditingController indicacion;
    late TextEditingController carga;
    late List<String> escritos;

    setUp(() {
      indicacion = TextEditingController();
      carga = TextEditingController();
      escritos = [];
    });

    tearDown(() {
      indicacion.dispose();
      carga.dispose();
    });

    /// Lector falso: abre una pantalla, como la cámara, y devuelve [lectura]
    /// al tocar "usar" o null al tocar "cancelar".
    Future<String?> lector(BuildContext context, String lectura) {
      return Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Column(children: [
            TextButton(
              onPressed: () => Navigator.pop(context, lectura),
              child: const Text('usar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('cancelar'),
            ),
          ]),
        ),
      ));
    }

    Future<NumericKeypadController> montar(
      WidgetTester tester, {
      bool conLector = true,
    }) async {
      final keypad = NumericKeypadController(
        onReadIndicator:
            conLector ? (context) => lector(context, '12.345') : null,
      );
      addTearDown(keypad.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumericKeypadScope(
              controller: keypad,
              child: Column(
                children: [
                  CalibrationNumberField(
                    key: const ValueKey('indicacion'),
                    controller: indicacion,
                    column: 'indicacion1',
                    allowNegative: true,
                    readable: true,
                    onChanged: escritos.add,
                  ),
                  CalibrationNumberField(
                    key: const ValueKey('carga'),
                    controller: carga,
                    column: 'carga',
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: keypad,
                    builder: (_, __) => keypad.visible
                        ? NumericKeypad(controller: keypad)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return keypad;
    }

    testWidgets('escribe la lectura confirmada y vuelve al campo',
        (tester) async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('keypad-read')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('usar'));
      await tester.pumpAndSettle();

      expect(indicacion.text, '12.345');
      expect(escritos, ['12.345']);
      // El teclado vuelve para seguir con "Siguiente".
      expect(find.byKey(const ValueKey('keypad-next')), findsOneWidget);
    });

    testWidgets('cancelar no toca el campo', (tester) async {
      await montar(tester);
      indicacion.text = '10.000';
      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('keypad-read')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cancelar'));
      await tester.pumpAndSettle();

      expect(indicacion.text, '10.000');
      expect(escritos, isEmpty);
    });

    testWidgets('solo se ofrece en lecturas del display', (tester) async {
      await montar(tester);
      await tester.tap(find.byKey(const ValueKey('carga')));
      await tester.pump();

      expect(find.byKey(const ValueKey('keypad-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('keypad-read')), findsNothing);
    });

    testWidgets('sin lector no se ofrece', (tester) async {
      await montar(tester, conLector: false);
      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();

      expect(find.byKey(const ValueKey('keypad-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('keypad-read')), findsNothing);
    });
  });

  testWidgets('funciona dentro de un AlertDialog, que mide anchos intrínsecos',
      (tester) async {
    final cantidad = TextEditingController();
    addTearDown(cantidad.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: NumericKeypadHost(
                      child: CalibrationNumberField(
                        controller: cantidad,
                        column: 'cantidad1',
                        autofocus: true,
                      ),
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // El autofoco abre el teclado propio del diálogo.
    expect(find.byKey(const ValueKey('keypad-3')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('keypad-3')));
    await tester.pump();

    expect(cantidad.text, '3');
    expect(tester.takeException(), isNull);
  });
}
