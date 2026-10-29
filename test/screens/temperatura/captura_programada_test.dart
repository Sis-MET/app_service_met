import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/utils/indicator_frame.dart';
import 'package:service_met/screens/calibracion/utils/indicator_reading.dart';
import 'package:service_met/screens/calibracion/utils/seven_segment_reader.dart';
import 'package:service_met/screens/calibracion_temperatura/captura/captura_programada.dart';
import 'package:service_met/screens/calibracion_temperatura/models/temperatura_models.dart';
import 'package:service_met/screens/calibracion_temperatura/services/medicion_programada.dart';
import 'package:service_met/screens/calibracion_temperatura/services/temperatura_resultados.dart';

final _band = GrayImage(2, 2, Uint8List(4));

RegionReading _lee(String? valor, {bool sinValor = false}) => RegionReading(
      band: _band,
      candidate: valor == null
          ? null
          : sinValor
              ? IndicatorCandidate.sinValor(valor, height: 30)
              : IndicatorCandidate(
                  value: valor,
                  height: 30,
                  source: IndicatorSource.segmentos,
                ),
    );

void main() {
  final inicio = DateTime(2026, 10, 29, 9, 0, 0);

  group('horario', () {
    final horario = MedicionProgramada(
      inicio: inicio,
      intervalo: const Duration(seconds: 30),
      lecturas: 91,
    );

    test('horas, ventana y límite', () {
      expect(horario.horaDe(2), inicio.add(const Duration(minutes: 1)));
      expect(horario.ultima, inicio.add(const Duration(minutes: 45)));
      expect(horario.ventana, const Duration(seconds: 10));
      expect(horario.segundosDe(90), 2700);
      expect(
          horario.actual(inicio.subtract(const Duration(seconds: 1))), isNull);
      expect(horario.actual(inicio.add(const Duration(seconds: 29))), 0);
      expect(horario.actual(inicio.add(const Duration(seconds: 30))), 1);
      expect(horario.enVentana(1, inicio.add(const Duration(seconds: 39))),
          isTrue);
      expect(horario.enVentana(1, inicio.add(const Duration(seconds: 40))),
          isFalse);
      expect(
          horario.actual(inicio.add(const Duration(minutes: 45, seconds: 30))),
          isNull);
    });

    test('vencidas y fin', () {
      final ahora = inicio.add(const Duration(seconds: 95));
      expect(horario.vencidas(ahora, {0}), [1, 2]);
      expect(horario.terminada(ahora, {0, 1, 2}), isFalse);
      expect(
          horario.terminada(
              inicio.add(const Duration(minutes: 45, seconds: 30)), {}),
          isTrue);
      expect(horario.hastaLaProxima(inicio.add(const Duration(seconds: 10))),
          const Duration(seconds: 20));
    });

    test('la ventana va de 2 a 10 segundos', () {
      MedicionProgramada con(int segundos) => MedicionProgramada(
            inicio: inicio,
            intervalo: Duration(seconds: segundos),
            lecturas: 3,
          );
      expect(con(2).ventana, const Duration(seconds: 2));
      expect(con(12).ventana, const Duration(seconds: 6));
      expect(con(120).ventana, const Duration(seconds: 10));
    });
  });

  group('captura programada', () {
    late DateTime ahora;
    late List<TempLectura> guardadas;
    late CapturaProgramada captura;

    const canales = [
      TempCanal(n: 1, nombre: 'Patrón', rol: RolCanal.patron),
      TempCanal(
          n: 2,
          nombre: 'Equipo',
          rol: RolCanal.equipo,
          metodo: MetodoCanal.manual,
          decimales: 0),
    ];

    CapturaProgramada nueva({Iterable<TempLectura> previas = const []}) =>
        CapturaProgramada(
          punto: TempPunto(
            n: 1,
            temperaturaNominal: 300,
            duracionMin: 1,
            intervaloS: 30,
            estado: EstadoPunto.enCurso,
            inicioMedicion: inicio.toIso8601String(),
          ),
          canales: canales,
          registrar: (lectura) async {
            guardadas.add(lectura);
            return true;
          },
          guardarImagen: (_, n, canal) async => 'L${n}_C$canal.png',
          expectativas: {
            1: const ReadingExpectations(decimals: 1, maxJump: 15),
          },
          previas: previas,
          reloj: () => ahora,
        );

    setUp(() {
      ahora = inicio;
      guardadas = [];
      captura = nueva();
    });

    test('registra la cámara solo con 3 cuadros iguales', () async {
      await captura.tick();
      expect(captura.actual, 0);
      expect(captura.necesitaCuadros, isTrue);
      await captura.cuadro([_lee('300.1')]);
      await captura.cuadro([_lee('300.7')]);
      await captura.cuadro([_lee('300.1')]);
      expect(guardadas, isEmpty);
      await captura.cuadro([_lee('300.1')]);
      final lectura = guardadas.single;
      expect(lectura.valor, 300.1);
      expect(lectura.valorOriginal, 300.1);
      expect(lectura.origen, OrigenLectura.ocrSegmentos);
      expect(lectura.coincidencia, closeTo(0.75, 1e-9));
      expect(lectura.cuadros, 4);
      expect(lectura.imagenPath, 'L0_C1.png');
      expect(captura.necesitaCuadros, isFalse);
      // El canal manual se pide.
      expect(captura.pendientesManuales.single.n, 2);
    });

    test('el canal manual se escribe hasta la siguiente lectura', () async {
      await captura.tick();
      ahora = inicio.add(const Duration(seconds: 12));
      expect(await captura.manual(2, 298), isNull);
      expect(guardadas.single.origen, OrigenLectura.manual);
      expect(guardadas.single.alerta, isNull, reason: 'sin aviso de decimales');
      expect(await captura.manual(2, 297), 'Esa lectura ya está registrada.');
    });

    test('sin acuerdo ni lectura manual queda sin lectura con su motivo',
        () async {
      await captura.tick();
      for (final valor in ['1', '2', '3', '4', '5']) {
        await captura.cuadro([_lee(valor)]);
      }
      expect(guardadas, isEmpty);
      // Pasada la ventana, la cámara queda para escribirla a mano.
      ahora = inicio.add(const Duration(seconds: 15));
      await captura.tick();
      expect(captura.necesitaCuadros, isFalse);
      expect(captura.estadoDe(1), EstadoCanalCaptura.faltaManual);
      ahora = inicio.add(const Duration(seconds: 30));
      await captura.tick();
      expect(guardadas.map((l) => (l.nCanal, l.motivo)), [
        (1, MotivoSinLectura.noLegible),
        (2, MotivoSinLectura.manualSinIngresar),
      ]);
      expect(guardadas.every((l) => l.valor == null), isTrue);
      expect(captura.actual, 1);
    });

    test('un display sin valor queda registrado como tal', () async {
      await captura.tick();
      for (var i = 0; i < 3; i++) {
        await captura.cuadro([_lee('----', sinValor: true)]);
      }
      final lectura = guardadas.single;
      expect(lectura.estado, EstadoLectura.sinLectura);
      expect(lectura.motivo, MotivoSinLectura.sinValor);
      expect(lectura.textoLeido, '----');
    });

    test('en segundo plano las lecturas vencidas lo dicen', () async {
      await captura.tick();
      captura.pausar();
      expect(captura.necesitaCuadros, isFalse);
      ahora = inicio.add(const Duration(seconds: 31));
      await captura.tick();
      captura.reanudar();
      expect(
        guardadas.firstWhere((l) => l.nCanal == 1).motivo,
        MotivoSinLectura.segundoPlano,
      );
    });

    test('al volver tras cerrar la app no repite y marca lo perdido', () async {
      ahora = inicio.add(const Duration(seconds: 65));
      captura = nueva(previas: [
        TempLectura(
          nPunto: 1,
          nLectura: 0,
          nCanal: 1,
          tiempoProgramadoS: 0,
          capturadaEn: '',
          valor: 300,
          valorOriginal: 300,
          origen: OrigenLectura.ocrSegmentos,
        ),
      ]);
      await captura.tick();
      final motivos = {
        for (final l in guardadas) '${l.nLectura}/${l.nCanal}': l.motivo,
      };
      expect(motivos, {
        '0/2': MotivoSinLectura.appCerrada,
        '1/1': MotivoSinLectura.appCerrada,
        '1/2': MotivoSinLectura.appCerrada,
      });
      expect(captura.actual, 2);
      // Lo último del patrón es la lectura perdida al cerrar la app.
      expect(captura.ultimas[1]?.nLectura, 1);
      expect(captura.ultimas[1]?.estado, EstadoLectura.sinLectura);
    });

    test('termina al pasar la última lectura', () async {
      ahora = inicio.add(const Duration(seconds: 91));
      await captura.tick();
      expect(captura.terminada, isTrue);
      expect(guardadas.length, 3 * 2, reason: '3 lecturas × 2 canales');
    });

    test('avisa un salto brusco', () async {
      await captura.tick();
      for (var i = 0; i < 3; i++) {
        await captura.cuadro([_lee('300.0')]);
      }
      ahora = inicio.add(const Duration(seconds: 30));
      await captura.tick();
      for (var i = 0; i < 3; i++) {
        await captura.cuadro([_lee('380.0')]);
      }
      expect(guardadas.last.alerta, 'salto');
    });
  });

  group('resultados preliminares', () {
    const canales = [
      TempCanal(n: 1, nombre: 'T1', rol: RolCanal.patron),
      TempCanal(n: 2, nombre: 'T2', rol: RolCanal.patron),
      TempCanal(n: 3, nombre: 'Equipo', rol: RolCanal.equipo, decimales: 0),
    ];
    const punto = TempPunto(
      n: 1,
      temperaturaNominal: 300,
      duracionMin: 1,
      intervaloS: 30,
      estado: EstadoPunto.completo,
    );
    TempLectura l(int n, int canal, double? valor,
            [EstadoLectura estado = EstadoLectura.valida]) =>
        TempLectura(
          nPunto: 1,
          nLectura: n,
          nCanal: canal,
          tiempoProgramadoS: n * 30,
          capturadaEn: '',
          valor: valor,
          origen: OrigenLectura.ocrSegmentos,
          estado: valor == null ? EstadoLectura.sinLectura : estado,
        );

    test('promedios, desviación, uniformidad y error calculados a mano', () {
      final lecturas = [
        // T1: 299, 301, 300 → promedio 300, s = 1
        l(0, 1, 299), l(1, 1, 301), l(2, 1, 300),
        // T2: 302, 304, 303 → promedio 303
        l(0, 2, 302), l(1, 2, 304), l(2, 2, 303),
        // Equipo: 305, 306, (sin lectura) → promedio 305.5
        l(0, 3, 305), l(1, 3, 306), l(2, 3, null),
        // Una excluida que no debe contar.
        l(3, 1, 900, EstadoLectura.excluida),
      ];
      final resumen = TemperaturaResultados.punto(punto, canales, lecturas);
      final t1 = resumen.canales[0];
      expect(t1.validas, 3);
      expect(t1.promedio, closeTo(300, 1e-9));
      expect(t1.desviacion, closeTo(1, 1e-9));
      expect(t1.variacion, closeTo(2, 1e-9));
      expect(resumen.canales[1].promedio, closeTo(303, 1e-9));
      expect(resumen.patron, closeTo(301.5, 1e-9));
      // Diferencias por lectura: 3, 3, 3 → 3.
      expect(resumen.uniformidad, closeTo(3, 1e-9));
      expect(resumen.errores[3], closeTo(4, 1e-9));
      expect(resumen.sinLectura, 1);
      expect(resumen.excluidas, 1);
    });

    test('con un solo sensor no hay uniformidad', () {
      final resumen = TemperaturaResultados.punto(
        punto,
        const [TempCanal(n: 1, nombre: 'T1', rol: RolCanal.patron)],
        [l(0, 1, 300)],
      );
      expect(resumen.uniformidad, isNull);
      expect(resumen.canales.single.desviacion, isNull);
      expect(resumen.errores, isEmpty);
    });
  });
}
