import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/models/sustitucion_linealidad.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/screens/calibracion/steps/linealidad_step.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';

/// El asistente de cargas sustitutivas sigue el método declarado, con los
/// ejemplos que dio el laboratorio.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Finder inputFor(String column) => find.descendant(
        of: find.byWidgetPredicate((widget) =>
            widget is CalibrationNumberField && widget.column == column),
        matching: find.byType(TextField),
      );

  Future<ServiceSessionProvider> mount(
    WidgetTester tester, {
    required String metodoCarga,
    required String indicacionPesas,
  }) async {
    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = ServiceSessionProvider(CalibrationRepository());
    await provider.createNewSession('técnico');
    // 500 kg de pesas, ya validados.
    provider.updateLinealidad(LinealidadData(
      metodo: 'Sin metodo de carga',
      metodoCarga: metodoCarga,
      filas: [
        FilaLinealidad(carga: '500', indicacion: indicacionPesas, retorno: '0'),
      ],
      sustitucion: const SustitucionLinealidad(cargasPatron: 1),
    ));
    addTearDown(provider.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: Scaffold(body: LinealidadStep())),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return provider;
  }

  Future<void> sustitucion(WidgetTester tester, String indicacion) async {
    final boton = find.widgetWithText(ElevatedButton, 'Carga sustitutiva');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    final campo = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.tap(campo);
    await tester.pumpAndSettle();
    for (final tecla in indicacion.split('')) {
      await tester.tap(find
          .byKey(ValueKey(tecla == '.' ? 'keypad-point' : 'keypad-$tecla')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('keypad-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar carga sustitutiva'));
    await tester.pumpAndSettle();
  }

  Future<void> indicacion(WidgetTester tester, int fila, String valor) async {
    await tester.ensureVisible(inputFor('ind$fila'));
    await tester.enterText(inputFor('ind$fila'), valor);
    await tester.pump();
  }

  List<String?> cargas(ServiceSessionProvider provider) =>
      [for (final fila in provider.session!.linealidad!.filas) fila.carga];

  testWidgets('Método 1, ejemplo 2: la segunda carga es 1500, no 1994,5',
      (tester) async {
    final provider =
        await mount(tester, metodoCarga: 'Método 1', indicacionPesas: '500.5');

    await sustitucion(tester, '495');
    expect(cargas(provider).take(2), ['500', '994.5']);
    expect(provider.session!.linealidad!.filas[1].indicacion, '');

    await indicacion(tester, 2, '995.5');
    await sustitucion(tester, '1001');
    expect(cargas(provider).take(3), ['500', '994.5', '1500']);

    final pasos = provider.session!.linealidad!.sustitucion.pasos;
    expect([for (final p in pasos) (p.fila, p.filaReferencia, p.filaBase)],
        [(1, 0, 0), (2, 1, 0)]);

    // Si se corrige la lectura de 994,5 kg, la carga que depende de ella
    // cambia con ella: E = +2 → 1001 − 2 = 999 → 1499.
    await indicacion(tester, 2, '996.5');
    expect(cargas(provider)[2], '1499');

    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });

  testWidgets('Método 2: 995,5 → 1498 → 1988,5', (tester) async {
    final provider =
        await mount(tester, metodoCarga: 'Método 2', indicacionPesas: '499.5');

    await sustitucion(tester, '495');
    await indicacion(tester, 2, '995');
    await sustitucion(tester, '502');
    await indicacion(tester, 3, '1497.5');
    await sustitucion(tester, '490');

    expect(cargas(provider).take(4), ['500', '995.5', '1498', '1988.5']);
    final pasos = provider.session!.linealidad!.sustitucion.pasos;
    expect([for (final p in pasos) (p.filaReferencia, p.filaBase)],
        [(0, 0), (0, 1), (0, 2)]);

    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });

  testWidgets('sin la indicación de la carga anterior no abre el asistente',
      (tester) async {
    final provider =
        await mount(tester, metodoCarga: 'Método 1', indicacionPesas: '500.5');
    await sustitucion(tester, '495');

    final boton = find.widgetWithText(ElevatedButton, 'Carga sustitutiva');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.textContaining('Registre primero la indicación de la Carga 2'),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });

  testWidgets('sin Método 1 o 2 el asistente queda apagado', (tester) async {
    final provider = await mount(tester,
        metodoCarga: 'Sin método', indicacionPesas: '500.5');

    final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Carga sustitutiva'));
    expect(boton.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });
}
