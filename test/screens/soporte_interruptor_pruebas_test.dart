import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/controllers/mnt_prv_avanzado_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/models/mnt_prv_avanzado_model.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/widgets/steps/paso_pruebas_metrologicas.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/linealidad_prueba_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/prueba_common_widgets.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/repetibilidad_prueba_widget.dart';

/// El interruptor "Realizar ..." de las pruebas metrológicas de soporte:
/// avisa mientras activa u omite la prueba y volver a activarla no deja la
/// pantalla en blanco.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> montar(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));
    await tester.pumpAndSettle();
  }

  Finder interruptor(String prueba) => find.descendant(
        of: find.widgetWithText(PruebaSkipCard, 'Realizar $prueba'),
        matching: find.byType(Switch),
      );

  group('volver a abrir una prueba', () {
    // Con "quitar fila" o al reabrir el servicio, la linealidad puede traer
    // una sola carga; la pantalla pide al menos dos.
    testWidgets('linealidad con una sola carga', (tester) async {
      await montar(
        tester,
        LinealidadPruebaWidget(
          balanza: BalanzaInfo(),
          data: LinealidadData(
              filas: [FilaLinealidad(carga: '10', indicacion: '10')]),
          onChanged: (_) {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Carga 1'), findsOneWidget);
      expect(find.text('Carga 2'), findsOneWidget);
      expect(find.widgetWithText(TextField, '10'), findsNWidgets(2));
    });

    // Al reabrir, la repetibilidad trae las lecturas guardadas: pueden ser
    // 4, un número que la lista de mediciones no tiene.
    testWidgets('repetibilidad con lecturas que no están en la lista',
        (tester) async {
      await montar(
        tester,
        RepetibilidadPruebaWidget(
          balanza: BalanzaInfo(),
          data: RepetibilidadData(cargas: [
            CargaRepetibilidad(
              carga: '10',
              indicaciones: ['10', '10', '10', '10'],
              retornos: ['0', '0', '0', '0'],
            ),
          ]),
          onChanged: (_) {},
        ),
      );

      expect(tester.takeException(), isNull);
      final mediciones = tester.widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>));
      expect(mediciones.value, '5');
    });
  });

  group('aviso del interruptor', () {
    testWidgets('dice qué hace hasta que el cambio queda guardado',
        (tester) async {
      final guardado = Completer<void>();
      final cambios = <bool>[];
      await montar(
        tester,
        PruebaSkipCard(
          realizada: true,
          nombrePrueba: 'linealidad',
          onChanged: (v) {
            cambios.add(v);
            return guardado.future;
          },
        ),
      );

      await tester.tap(interruptor('linealidad'));
      await tester.pump();

      // El interruptor ya se movió, avisa y no admite otro toque.
      expect(find.text('Omitiendo la prueba…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final enCurso = tester.widget<Switch>(interruptor('linealidad'));
      expect(enCurso.value, isFalse);
      expect(enCurso.onChanged, isNull);

      await tester.pump();
      expect(cambios, [false]);

      guardado.complete();
      await tester.pump(PruebaSkipCard.avisoMinimo);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Omitiendo la prueba…'), findsNothing);
      expect(tester.widget<Switch>(interruptor('linealidad')).onChanged,
          isNotNull);
    });

    testWidgets('al activar dice "Activando"', (tester) async {
      final guardado = Completer<void>();
      await montar(
        tester,
        PruebaSkipCard(
          realizada: false,
          nombrePrueba: 'excentricidad',
          onChanged: (_) => guardado.future,
        ),
      );

      await tester.tap(interruptor('excentricidad'));
      await tester.pump();

      expect(find.text('Activando la prueba…'), findsOneWidget);
      guardado.complete();
      await tester.pumpAndSettle();
      expect(find.text('Activando la prueba…'), findsNothing);
    });
  });

  // Como en la pantalla del módulo: la pantalla escucha al controlador y el
  // interruptor pasa por cambiarPrueba.
  group('Mnt Preventivo Avanzado', () {
    late _AvanzadoSinBase controller;

    setUp(() {
      controller = _AvanzadoSinBase()
        ..linealidadInicial = LinealidadData(
            filas: [FilaLinealidad(carga: '10', indicacion: '10')]);
    });
    tearDown(() => controller.dispose());

    Widget paso() => ListenableBuilder(
          listenable: controller,
          builder: (context, _) => PasoPruebasMetrologicas(
            balanza: BalanzaInfo(),
            esInicial: true,
            retornoCero: '',
            estabilidad: '',
            onRetornoCeroChanged: (_) {},
            onEstabilidadChanged: (_) {},
            excentricidadActiva: controller.excentricidadRealizada,
            repetibilidadActiva: controller.repetibilidadRealizada,
            linealidadActiva: controller.linealidadRealizada,
            onExcentricidadActivaChanged: (v) => controller
                .cambiarPrueba(() => controller.excentricidadRealizada = v),
            onRepetibilidadActivaChanged: (v) => controller
                .cambiarPrueba(() => controller.repetibilidadRealizada = v),
            onLinealidadActivaChanged: (v) => controller
                .cambiarPrueba(() => controller.linealidadRealizada = v),
            excentricidad: controller.excentricidadInicial,
            repetibilidad: controller.repetibilidadInicial,
            linealidad: controller.linealidadInicial,
            onExcentricidadChanged: (d) => controller.excentricidadInicial = d,
            onRepetibilidadChanged: (d) => controller.repetibilidadInicial = d,
            onLinealidadChanged: (d) => controller.linealidadInicial = d,
          ),
        );

    Future<void> tocar(WidgetTester tester, String prueba) async {
      await tester.ensureVisible(interruptor(prueba));
      await tester.tap(interruptor(prueba));
      await tester.pump();
    }

    testWidgets('omitir la prueba la quita en el acto y la guarda',
        (tester) async {
      await montar(tester, paso());
      expect(find.byType(LinealidadPruebaWidget), findsOneWidget);

      await tocar(tester, 'linealidad');
      expect(find.text('Omitiendo la prueba…'), findsOneWidget);
      await tester.pump();

      // Sin esperar al autoguardado: ya no está y quedó guardado.
      expect(controller.linealidadRealizada, isFalse);
      expect(find.byType(LinealidadPruebaWidget), findsNothing);
      expect(controller.guardados, 1);
      expect(controller.hasUnsavedChanges.value, isFalse);

      await tester.pumpAndSettle();
      expect(find.text('Prueba omitida: no se registrará'), findsOneWidget);
    });

    testWidgets('apagar y volver a encender no deja la pantalla en blanco',
        (tester) async {
      await montar(tester, paso());

      await tocar(tester, 'linealidad');
      await tester.pumpAndSettle();
      await tocar(tester, 'linealidad');
      expect(find.text('Activando la prueba…'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.linealidadRealizada, isTrue);
      expect(find.byType(LinealidadPruebaWidget), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(controller.guardados, 2);
    });

    testWidgets('las otras pruebas conservan lo cargado', (tester) async {
      await montar(tester, paso());

      await tocar(tester, 'excentricidad');
      await tester.pumpAndSettle();
      await tocar(tester, 'repetibilidad');
      await tester.pumpAndSettle();

      expect(controller.excentricidadRealizada, isFalse);
      expect(controller.repetibilidadRealizada, isFalse);
      expect(find.byType(LinealidadPruebaWidget), findsOneWidget);
      expect(find.widgetWithText(TextField, '10'), findsNWidgets(2));
    });
  });
}

/// El controlador de la pantalla, sin la base: cuenta los guardados.
class _AvanzadoSinBase extends MntPrvAvanzadoController {
  _AvanzadoSinBase()
      : super(
            model: MntPrvAvanzadoModel(
                sessionId: '0001', codMetrica: '0032-11-020'));

  int guardados = 0;

  @override
  Future<void> guardarSesion() async {
    guardados++;
    setSaveInProgress();
    // Sin OT/ST no pide la ubicación del GPS.
    setSaveSuccess(true);
  }
}
