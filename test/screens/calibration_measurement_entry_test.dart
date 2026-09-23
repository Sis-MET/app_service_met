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

  testWidgets('excentricidad no inventa indicaciones al cambiar la carga',
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
    expect(
        provider.session!.excentricidad!.posiciones
            .every((position) => position.indicacion?.isEmpty ?? true),
        isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });

  testWidgets('repetibilidad conserva vacías las indicaciones al editar carga',
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
    expect(
        provider.session!.repetibilidad!.cargas.first.indicaciones
            .every((reading) => reading == null || reading.isEmpty),
        isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });

  testWidgets('linealidad conserva vacía la indicación al editar carga',
      (tester) async {
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
    expect(provider.session!.linealidad!.filas.first.indicacion, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });
}
