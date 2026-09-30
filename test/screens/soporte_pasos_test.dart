import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/controllers/instalacion_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/models/instalacion_model.dart';
import 'package:service_met/screens/soporte_new/utils/pasos_soporte.dart';
import 'package:service_met/screens/soporte_new/utils/requisitos_pruebas.dart';

/// Instalación con el guardado simulado: sin base de datos.
class _Controlador extends InstalacionController {
  _Controlador()
      : super(model: InstalacionModel(sessionId: '0001', codMetrica: 'X'));

  bool falla = false;
  int guardados = 0;

  @override
  Future<void> guardarSesion() async {
    guardados++;
    setSaveSuccess(!falla, error: falla ? 'disco lleno' : null);
  }
}

ExcentricidadData _excentricidad({String puntos = 'Rectangular 3F'}) =>
    ExcentricidadData(
      tipoPlataforma: 'Rectangular',
      puntosIndicacion: puntos,
      carga: '50',
      posiciones: [
        for (var i = 1; i <= 3; i++)
          PosicionData(posicion: '$i', indicacion: '50.0', retorno: '0'),
      ],
    );

RepetibilidadData _repetibilidad({List<String?>? indicaciones}) =>
    RepetibilidadData(cargas: [
      CargaRepetibilidad(
        carga: '100',
        indicaciones: indicaciones ?? ['100.0', '100.1', '100.0'],
        retornos: ['0', '0', '0'],
      ),
    ]);

LinealidadData _linealidad() => LinealidadData(filas: [
      FilaLinealidad(carga: '10', indicacion: '10.0', retorno: '0'),
      FilaLinealidad(carga: '20', indicacion: '20.1', retorno: '0'),
    ]);

void main() {
  group('pruebas metrológicas de soporte, como en la calibración', () {
    String? faltan({
      ExcentricidadData? excentricidad,
      RepetibilidadData? repetibilidad,
      LinealidadData? linealidad,
      bool excentricidadRealizada = true,
    }) =>
        faltaEnPruebas(
          momento: 'iniciales',
          excentricidadRealizada: excentricidadRealizada,
          excentricidad: excentricidad ?? _excentricidad(),
          repetibilidadRealizada: true,
          repetibilidad: repetibilidad ?? _repetibilidad(),
          linealidadRealizada: true,
          linealidad: linealidad ?? _linealidad(),
        );

    test('completas no piden nada', () {
      expect(faltan(), isNull);
    });

    test('sin tocar, cada prueba realizada pide sus datos', () {
      expect(faltan(excentricidad: ExcentricidadData()),
          'Excentricidad (iniciales): elija el tipo de plataforma.');
      expect(faltan(repetibilidad: RepetibilidadData()),
          'Repetibilidad (iniciales): ingrese la carga.');
      expect(
          faltan(linealidad: LinealidadData()),
          'Linealidad (iniciales): registre al menos una carga con su '
          'indicación.');
    });

    test('una prueba desmarcada no se exige', () {
      expect(
        faltan(
            excentricidad: ExcentricidadData(), excentricidadRealizada: false),
        isNull,
      );
    });

    test('lecturas a medias', () {
      expect(faltan(excentricidad: _excentricidad(puntos: 'Rectangular 3')),
          'Excentricidad (iniciales): elija la posición del indicador.');
      final sinRetorno = _excentricidad().copyWith(posiciones: [
        PosicionData(indicacion: '50.0', retorno: '0'),
        PosicionData(indicacion: '50.0', retorno: ''),
        PosicionData(indicacion: '50.0', retorno: '0'),
      ]);
      expect(faltan(excentricidad: sinRetorno),
          'Excentricidad (iniciales): falta el retorno de la posición 2.');
      expect(
          faltan(
              repetibilidad:
                  _repetibilidad(indicaciones: ['100.0', null, '100.0'])),
          'Repetibilidad (iniciales): falta la indicación 2.');
      expect(
          faltan(
              linealidad: LinealidadData(filas: [
            FilaLinealidad(carga: '10', indicacion: '', retorno: '0'),
          ])),
          'Linealidad (iniciales): falta la indicación de la carga 1.');
    });
  });

  group('pasos de un servicio de soporte', () {
    late BuildContext context;
    late _Controlador controlador;
    late Map<int, String?> faltas;
    late PasosSoporte pasos;

    Future<void> montar(WidgetTester tester) async {
      controlador = _Controlador();
      addTearDown(controlador.dispose);
      faltas = {0: null, 1: null, 2: null};
      pasos = PasosSoporte(
        controller: controlador,
        total: 3,
        falta: (paso) => faltas[paso],
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) {
            context = ctx;
            return const SizedBox.expand();
          }),
        ),
      ));
    }

    Future<void> retirarAvisos(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('no se salta un paso incompleto: lleva a él', (tester) async {
      await montar(tester);
      faltas[1] = 'Complete retorno a cero y estabilidad';

      await pasos.irA(context, 2);
      await tester.pump();
      expect(controlador.currentStep, 1);
      expect(
          find.text('Complete retorno a cero y estabilidad'), findsOneWidget);
      expect(controlador.guardados, 0);
      await retirarAvisos(tester);
    });

    testWidgets('adelante guarda antes y, si no pudo, se queda',
        (tester) async {
      await montar(tester);
      controlador.falla = true;

      await pasos.irA(context, 1);
      await tester.pump();
      expect(controlador.currentStep, 0);
      expect(controlador.guardados, 1);
      expect(find.textContaining('No se pudo guardar en el teléfono: disco'),
          findsOneWidget);
      await retirarAvisos(tester);

      controlador.falla = false;
      await pasos.irA(context, 1);
      expect(controlador.currentStep, 1);
      expect(controlador.guardados, 2);
    });

    testWidgets('atrás siempre se puede', (tester) async {
      await montar(tester);
      controlador.currentStep = 2;
      faltas[0] = 'Falta algo';

      await pasos.irA(context, 0);
      expect(controlador.currentStep, 0);
      expect(controlador.guardados, 0);
    });

    testWidgets('se finaliza solo con todo completo y guardado',
        (tester) async {
      await montar(tester);
      controlador.currentStep = 2;
      faltas[0] = 'Complete todas las condiciones de instalación';

      expect(await pasos.listoParaFinalizar(context), isFalse);
      await tester.pump();
      expect(controlador.currentStep, 0);
      await retirarAvisos(tester);

      faltas[0] = null;
      expect(await pasos.listoParaFinalizar(context), isTrue);
      expect(controlador.guardados, 1);
    });
  });
}
