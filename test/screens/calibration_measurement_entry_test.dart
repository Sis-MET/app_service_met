import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/screens/calibracion/steps/excentricidad_step.dart';
import 'package:service_met/screens/calibracion/steps/linealidad_step.dart';
import 'package:service_met/screens/calibracion/steps/repetibilidad_step.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Finder inputFor(String column) => find.descendant(
        of: find.byWidgetPredicate((widget) =>
            widget is CalibrationNumberField && widget.column == column),
        matching: find.byType(TextField),
      );

  Future<ServiceSessionProvider> mount(WidgetTester tester, Widget child,
      void Function(ServiceSessionProvider) seed) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = ServiceSessionProvider(CalibrationRepository());
    await provider.createNewSession('técnico');
    seed(provider);
    addTearDown(provider.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: Scaffold(body: child)),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return provider;
  }

  // En una balanza en buen estado la indicación coincide con la carga: se
  // replica para que el técnico solo corrija las que difieran.
  testWidgets('excentricidad replica la carga en todas las indicaciones',
      (tester) async {
    final provider = await mount(
        tester,
        const ExcentricidadStep(),
        (p) => p.updateExcentricidad(ExcentricidadData(
              tipoPlataforma: 'Rectangular',
              puntosIndicacion: 'Rectangular 3F',
              carga: '10',
              posiciones: [
                for (var i = 1; i <= 3; i++)
                  PosicionData(posicion: '$i', indicacion: '', retorno: '0')
              ],
            )));
    await tester.ensureVisible(inputFor('carga'));
    await tester.enterText(inputFor('carga'), '20');
    await tester.pump();
    final posiciones = provider.session!.excentricidad!.posiciones;
    expect(posiciones.map((p) => p.indicacion), ['20', '20', '20']);
    expect(posiciones.map((p) => p.retorno), ['0', '0', '0']);

    // Corregir una posición no toca las demás ni la carga.
    await tester.ensureVisible(inputFor('indicacion2'));
    await tester.enterText(inputFor('indicacion2'), '20.5');
    await tester.pump();
    expect(provider.session!.excentricidad!.posiciones.map((p) => p.indicacion),
        ['20', '20.5', '20']);
    expect(provider.session!.excentricidad!.carga, '20');
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });

  testWidgets('repetibilidad replica la carga en sus indicaciones',
      (tester) async {
    final provider = await mount(
        tester,
        const RepetibilidadStep(),
        (p) => p.updateRepetibilidad(RepetibilidadData(cargas: [
              CargaRepetibilidad(
                  carga: '10',
                  indicaciones: [null, null, null],
                  retornos: ['0', '0', '0']),
            ])));
    await tester.ensureVisible(inputFor('repetibilidad1'));
    await tester.enterText(inputFor('repetibilidad1'), '20');
    await tester.pump();
    expect(provider.session!.repetibilidad!.cargas.first.indicaciones,
        ['20', '20', '20']);
    expect(provider.session!.repetibilidad!.cargas.first.retornos,
        ['0', '0', '0']);
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });

  testWidgets('linealidad replica la carga en su indicación', (tester) async {
    final provider = await mount(
        tester,
        const LinealidadStep(),
        (p) => p.updateLinealidad(LinealidadData(
                metodo: 'Sin metodo de carga',
                metodoCarga: 'Sin método',
                filas: [
                  FilaLinealidad(carga: '10', indicacion: '', retorno: '0'),
                ])));
    await tester.ensureVisible(inputFor('lin1'));
    await tester.enterText(inputFor('lin1'), '20');
    await tester.pump();
    expect(provider.session!.linealidad!.filas.first.indicacion, '20');
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });
}
