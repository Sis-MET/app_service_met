import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/excentricidad_bascula_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/excentricidad_prueba_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/linealidad_prueba_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/repetibilidad_prueba_widget.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

final _balanza = BalanzaInfo(
  codMetrica: '0090-11-014',
  capMax1: '30',
  d1: 0.01,
  e1: 0.01,
  unidad: 'kg',
);

const _pasos = [
  StepData(title: 'Pruebas', subtitle: 'Paso 1', icon: Icons.scale),
];

/// Pantalla de soporte con [contenido] como único paso.
Future<void> _montar(
  WidgetTester tester,
  Widget contenido, {
  String? lectura = '12.345',
  VoidCallback? onPopBlocked,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    // En las pruebas cada letra es un cuadrado del alto de la fuente, mucho
    // más ancho que Inter: rótulos fijos como "Pos 1" (56 px) no cabrían.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(0.5)),
      child: child!,
    ),
    home: ServiceWorkspaceLayout(
      title: 'Mnt Preventivo Regular',
      steps: _pasos,
      stepWidgets: [SingleChildScrollView(child: contenido)],
      currentStep: 0,
      onNext: () {},
      onReadIndicator: lectura == null ? null : (_) async => lectura,
      canPop: onPopBlocked == null,
      onPopBlocked: onPopBlocked,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('pantalla de soporte', () {
    final indicacion = TextEditingController();
    final carga = TextEditingController();
    final escritos = <String>[];

    setUp(() {
      indicacion.clear();
      carga.clear();
      escritos.clear();
    });

    Widget campos() => Column(children: [
          CalibrationNumberField(
            key: const ValueKey('indicacion'),
            controller: indicacion,
            allowNegative: true,
            readable: true,
            onChanged: escritos.add,
          ),
          CalibrationNumberField(
            key: const ValueKey('carga'),
            controller: carga,
          ),
        ]);

    testWidgets('el teclado propio reemplaza a la píldora y lee el indicador',
        (tester) async {
      await _montar(tester, campos());
      expect(find.byType(ServiceNavPill), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();
      expect(find.byKey(const ValueKey('keypad-1')), findsOneWidget);
      expect(find.byType(ServiceNavPill), findsNothing);

      await tester.tap(find.byKey(const ValueKey('keypad-read')));
      await tester.pumpAndSettle();
      expect(indicacion.text, '12.345');
      expect(escritos, ['12.345']);
    });

    testWidgets('la carga no se lee del display', (tester) async {
      await _montar(tester, campos());
      await tester.tap(find.byKey(const ValueKey('carga')));
      await tester.pump();
      expect(find.byKey(const ValueKey('keypad-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('keypad-read')), findsNothing);
    });

    testWidgets('sin lector el teclado no ofrece leer', (tester) async {
      await _montar(tester, campos(), lectura: null);
      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();
      expect(find.byKey(const ValueKey('keypad-read')), findsNothing);
    });

    testWidgets('Atrás cierra primero el teclado y después pide salir',
        (tester) async {
      var salidas = 0;
      await _montar(tester, campos(), onPopBlocked: () => salidas++);

      await tester.tap(find.byKey(const ValueKey('indicacion')));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('keypad-1')), findsNothing);
      expect(find.byType(ServiceNavPill), findsOneWidget);
      expect(salidas, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(salidas, 1);
    });
  });

  group('pruebas metrológicas de soporte', () {
    /// Indicaciones y retornos se leen del display y admiten signo; las
    /// cargas no.
    void comprobarCampos(WidgetTester tester, {required int cargas}) {
      final campos = tester
          .widgetList<CalibrationNumberField>(
              find.byType(CalibrationNumberField))
          .toList();
      expect(campos, isNotEmpty);
      final lecturas = campos.where((c) => c.readable).toList();
      expect(campos.length - lecturas.length, cargas);
      expect(lecturas, isNotEmpty);
      for (final campo in campos) {
        expect(campo.allowNegative, campo.readable);
      }
    }

    testWidgets('excentricidad de báscula', (tester) async {
      await _montar(
        tester,
        ExcentricidadBasculaWidget(
          balanza: _balanza,
          data: ExcentricidadData(
            puntosIndicacion: '4F',
            carga: '10',
            posiciones: List.generate(4, (_) => PosicionData()),
          ),
          onChanged: (_) {},
        ),
      );
      comprobarCampos(tester, cargas: 1);
    });

    testWidgets('excentricidad de balanza', (tester) async {
      await _montar(
        tester,
        ExcentricidadPruebaWidget(
          balanza: _balanza,
          data: ExcentricidadData(
            tipoPlataforma: 'Rectangular',
            puntosIndicacion: '5',
            carga: '10',
            posiciones: List.generate(5, (_) => PosicionData()),
          ),
          onChanged: (_) {},
        ),
      );
      comprobarCampos(tester, cargas: 1);
    });

    testWidgets('repetibilidad: escribe la lectura y la guarda',
        (tester) async {
      RepetibilidadData? guardado;
      await _montar(
        tester,
        RepetibilidadPruebaWidget(
          balanza: _balanza,
          data: RepetibilidadData(),
          onChanged: (data) => guardado = data,
        ),
      );
      comprobarCampos(tester, cargas: 1);

      // Primera indicación: el campo que sigue a la carga.
      final indicacion = find.byType(CalibrationNumberField).at(1);
      await tester.tap(indicacion);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('keypad-read')));
      await tester.pumpAndSettle();

      expect(guardado!.cargas.single.indicaciones.first, '12.345');
    });

    testWidgets('linealidad', (tester) async {
      await _montar(
        tester,
        LinealidadPruebaWidget(
          balanza: _balanza,
          data: LinealidadData(filas: [
            FilaLinealidad(carga: '10'),
            FilaLinealidad(carga: '20'),
          ]),
          onChanged: (_) {},
        ),
      );
      final campos = tester
          .widgetList<CalibrationNumberField>(
              find.byType(CalibrationNumberField))
          .toList();
      // Cada fila: carga real, indicación y retorno a cero.
      expect(campos.where((c) => !c.readable).length, campos.length ~/ 3);
      expect(campos.where((c) => c.readable).length, campos.length * 2 ~/ 3);
      for (final campo in campos) {
        expect(campo.allowNegative, campo.readable);
      }
    });
  });
}
