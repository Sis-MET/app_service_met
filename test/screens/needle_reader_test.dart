import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/utils/indicator_reading.dart';
import 'package:service_met/screens/calibracion/utils/needle_reader.dart';
import 'package:service_met/screens/calibracion/utils/reading_profile.dart';

import 'dial_render.dart';

/// Lee [image] con la escala [dial] en toda la imagen.
NeedleReading? _read(DialSpec spec, DialScale dial,
    {double? value,
    bool darkFace = false,
    double noise = 0,
    double shade = 0,
    bool glare = false,
    bool tail = true,
    bool numbers = true}) {
  final image = renderDial(spec,
      value: value,
      darkFace: darkFace,
      noise: noise,
      shade: shade,
      glare: glare,
      tail: tail,
      numbers: numbers);
  final geometry = dial.geometry(spec.size.toDouble(), spec.size.toDouble())!;
  return NeedleReader.read(image, geometry);
}

void main() {
  group('escala del dial', () {
    test('el dial inicial sube 270° en sentido horario', () {
      final dial = DialScale.inicial(const Rect.fromLTWH(0, 0, 1, 1),
          desde: 0, hasta: 160, aspect: 1);
      final g = dial.geometry(100, 100)!;
      expect(g.direction, 1);
      expect(g.total, closeTo(1.5 * math.pi, 1e-9));
      expect(dial.marks.map((m) => m.value), [0, 80, 160]);
      // Arriba (−90° en la imagen) está el medio de la escala.
      expect(g.valueAt(g.sweepOf(-math.pi / 2)), closeTo(80, 1e-9));
      // A la derecha (0°), 225° del recorrido: 133,3.
      expect(g.valueAt(g.sweepOf(0)), closeTo(400 / 3, 1e-9));
    });

    test('la zona muerta se reparte entre antes del inicio y después del fin',
        () {
      final g = DialScale.inicial(const Rect.fromLTWH(0, 0, 1, 1),
              desde: 0, hasta: 160, aspect: 1)
          .geometry(100, 100)!;
      // Abajo un poco a la derecha (cerca del fin): pasado el final.
      final despues = g.sweepOf(math.pi / 2 - 0.3);
      expect(despues, greaterThan(g.total));
      expect(g.valueAt(despues), greaterThan(160));
      // Abajo un poco a la izquierda (cerca del inicio): antes del inicio.
      final antes = g.sweepOf(math.pi / 2 + 0.3);
      expect(antes, lessThan(0));
      expect(g.valueAt(antes), lessThan(0));
    });

    test('con tres marcas reconoce un dial que sube al revés', () {
      const spec = DialSpec(clockwise: false, start: 135);
      final g = spec.dial().geometry(420, 420)!;
      expect(g.direction, -1);
      expect(g.total, closeTo(1.5 * math.pi, 1e-6));
      final angle = math.atan2(spec.pointAt(40).dy - spec.axis.dy,
          spec.pointAt(40).dx - spec.axis.dx);
      expect(g.valueAt(g.sweepOf(angle)), closeTo(40, 1e-6));
    });

    test('interpola por tramos entre marcas', () {
      const spec = DialSpec();
      // Un dial con el medio corrido (escala no lineal o foto oblicua): cada
      // tramo usa sus marcas.
      final dial = spec.dial().withMark(
          1, DialMark(spec.dial(values: [0, 70, 160]).marks[1].position, 80));
      final g = dial.geometry(420, 420)!;
      final at70 = spec.pointAt(70);
      final angle = math.atan2(at70.dy - spec.axis.dy, at70.dx - spec.axis.dx);
      expect(g.valueAt(g.sweepOf(angle)), closeTo(80, 1e-6));
    });

    test('rechaza marcas que no forman una escala', () {
      const spec = DialSpec();
      final dial = spec.dial();
      expect(
          dial
              .withMark(1, dial.marks[1].copyWith(value: 200))
              .geometry(420, 420),
          isNull);
      expect(
          dial
              .withMark(0, dial.marks[0].copyWith(position: dial.center))
              .geometry(420, 420),
          isNull);
      expect(
          dial.withCenter(dial.marks[2].position).geometry(420, 420), isNull);
    });

    test('acompaña al recuadro al moverlo o agrandarlo', () {
      final dial = DialScale.inicial(const Rect.fromLTWH(0.2, 0.2, 0.4, 0.4),
          desde: 0, hasta: 300, aspect: 1);
      final moved = dial.mapped(const Rect.fromLTWH(0.2, 0.2, 0.4, 0.4),
          const Rect.fromLTWH(0.3, 0.1, 0.6, 0.6));
      expect(moved.center.dx, closeTo(0.6, 1e-9));
      expect(moved.center.dy, closeTo(0.4, 1e-9));
      expect(moved.marks.map((m) => m.value), [0, 150, 300]);
      final g = moved.geometry(1000, 1000)!;
      expect(g.radius, closeTo(1.5 * dial.geometry(1000, 1000)!.radius, 1e-6));
    });

    test('se guarda con el perfil y vuelve igual', () {
      final dial = const DialSpec().dial();
      final profile = ReadingProfile.aguja(dial);
      final back =
          ReadingProfile.fromJson(Map<String, Object?>.from(profile.toJson()));
      expect(back, profile);
      expect(back.engine, IndicatorEngine.aguja);
      expect(back.dial, dial);
      expect(back.descripcion, 'Aguja');
      expect(
          DialScale.fromJson({
            'center': [0.5],
            'marks': []
          }),
          isNull);
    });
  });

  group('lector de aguja', () {
    const spec = DialSpec();
    final dial = spec.dial();

    test('lee la aguja en toda la escala', () {
      for (final value in [
        0.0,
        3.0,
        22.5,
        47.3,
        80.0,
        112.0,
        137.0,
        158.0,
        160.0
      ]) {
        final reading = _read(spec, dial, value: value);
        expect(reading, isNotNull, reason: 'en $value');
        expect(reading!.value, closeTo(value, 0.3), reason: 'en $value');
        expect(reading.outOfScale, isFalse, reason: 'en $value');
      }
    });

    test('no confunde la cola, los números ni el rótulo con la aguja', () {
      // Con la aguja en 22 la cola apunta cerca del 140 y el rótulo queda
      // bajo el eje.
      final reading = _read(spec, dial, value: 22);
      expect(reading!.value, closeTo(22, 0.3));
      expect(_read(spec, dial), isNull, reason: 'sin aguja no hay lectura');
      expect(_read(spec, dial, value: 60, tail: false, numbers: false)!.value,
          closeTo(60, 0.3));
    });

    test('tolera el eje marcado unos píxeles corrido', () {
      for (final error in const [Offset(3, 0), Offset(0, -3), Offset(-2, 2)]) {
        final shifted = spec.dial(centerError: error);
        for (final value in [10.0, 80.0, 150.0]) {
          final reading = _read(spec, shifted, value: value);
          expect(reading, isNotNull, reason: 'en $value con $error');
          expect(reading!.value, closeTo(value, 1.5),
              reason: 'en $value con $error');
        }
      }
    });

    test('dial oscuro con aguja clara', () {
      final reading = _read(spec, dial, value: 95, darkFace: true);
      expect(reading!.value, closeTo(95, 0.3));
    });

    test('con luz despareja, reflejo y ruido de la cámara', () {
      for (final value in [30.0, 75.0, 120.0]) {
        final reading = _read(spec, dial,
            value: value, shade: 0.45, glare: true, noise: 12);
        expect(reading, isNotNull, reason: 'en $value');
        expect(reading!.value, closeTo(value, 0.5), reason: 'en $value');
      }
    });

    test('un dial grande se reduce y se lee igual', () {
      const big = DialSpec(size: 1100, scale: 470);
      final reading = _read(big, big.dial(), value: 64.5);
      expect(reading!.value, closeTo(64.5, 0.3));
    });

    test('un dial que sube al revés', () {
      const ccw = DialSpec(clockwise: false, start: 135);
      final reading = _read(ccw, ccw.dial(), value: 41);
      expect(reading!.value, closeTo(41, 0.3));
    });

    test('una escala que no empieza en cero', () {
      const freezer = DialSpec(min: -40, max: 40);
      final reading = _read(freezer, freezer.dial(), value: -18.5);
      expect(reading!.value, closeTo(-18.5, 0.2));
    });

    test('la aguja apenas antes del inicio queda fuera de escala', () {
      final reading = _read(spec, dial, value: -9);
      expect(reading, isNotNull);
      expect(reading!.outOfScale, isTrue);
      expect(reading.value, lessThan(0));
    });
  });

  group('valor de la aguja', () {
    NeedleReading needle(double value, {bool out = false}) => NeedleReading(
          angle: 0,
          sweep: 1,
          value: value,
          score: 1,
          outOfScale: out,
          scale: const [0, 80, 160],
        );

    test('se redondea a la resolución del indicador', () {
      String read(double value, double step, int decimals) =>
          IndicatorReadingParser.fromNeedle(needle(value),
                  step: step, decimals: decimals)
              .value;
      expect(read(22.73, 1, 0), '23');
      expect(read(22.73, 0.5, 1), '22.5');
      expect(read(22.76, 0.5, 1), '23.0');
      expect(read(22.73, 2, 0), '22');
      expect(read(-0.2, 1, 0), '0');
      expect(read(-18.4, 0.5, 1), '-18.5');
    });

    test('guarda lo leído sin redondear y de dónde salió', () {
      final candidate = IndicatorReadingParser.fromNeedle(needle(22.734),
          step: 1, decimals: 0);
      expect(candidate.source, IndicatorSource.aguja);
      expect(candidate.isNumber, isTrue);
      expect(candidate.raw, 'aguja 22.73 · 57.3° · escala 0/80/160');
      final fuera = IndicatorReadingParser.fromNeedle(needle(-6, out: true),
          step: 1, decimals: 0);
      expect(fuera.isNumber, isFalse);
      expect(fuera.status, IndicatorReadingParser.fueraDeEscala);
    });
  });
}
