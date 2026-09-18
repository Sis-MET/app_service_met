import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/utils/indicator_reading.dart';

/// Una palabra de [height] píxeles de alto que empieza en [left].
OcrWord _word(String text, double left, {double height = 60, double? width}) =>
    OcrWord(
      text,
      Rect.fromLTWH(left, 100, width ?? text.length * height * 0.55, height),
    );

List<String> _values(List<List<OcrWord>> lines, {int? decimals}) =>
    IndicatorReadingParser.candidates(lines, expectedDecimals: decimals)
        .map((candidate) => candidate.value)
        .toList();

void main() {
  group('IndicatorReadingParser', () {
    test('lee el número y deja la unidad', () {
      expect(
        _values([
          [_word('12.345', 0), _word('kg', 200, height: 30)],
        ]),
        ['12.345'],
      );
    });

    test('junta los dígitos que el display separa entre segmentos', () {
      expect(
        _values([
          [_word('1', 0), _word('2.3', 40), _word('45', 145)],
        ]),
        ['12.345'],
      );
    });

    test('no junta dos números separados', () {
      expect(
        _values([
          [_word('12.345', 0), _word('0.000', 400)],
        ]),
        containsAll(['12.345', '0.000']),
      );
    });

    test('corrige letras que el OCR confunde con dígitos', () {
      expect(
          _values([
            [_word('l2.3S5', 0)]
          ]),
          ['12.355']);
      expect(
          _values([
            [_word('O.OO5', 0)]
          ]),
          ['0.005']);
      expect(
          _values([
            [_word('1O8.4', 0)]
          ]),
          ['108.4']);
    });

    test('lee un display en cero aunque el OCR vea letras O', () {
      expect(
          _values([
            [_word('O.OOO', 0)]
          ]),
          ['0.000']);
    });

    test('una palabra sin dígitos no se convierte en número', () {
      expect(
          _values([
            [_word('kg', 0)],
            [_word('lb', 0)]
          ]),
          isEmpty);
      expect(
          _values([
            [_word('ZERO', 0)],
            [_word('ON', 0)]
          ]),
          isEmpty);
      expect(
          _values([
            [_word('kilo', 0)],
            [_word('Stable', 0)]
          ]),
          isEmpty);
    });

    test('conserva el signo menos, también el tipográfico', () {
      expect(
          _values([
            [_word('-0.005', 0)]
          ]),
          ['-0.005']);
      const menosTipografico = '\u2212';
      expect(
          _values([
            [_word('${menosTipografico}0.005', 0)]
          ]),
          ['-0.005']);
    });

    test('acepta la coma decimal del display', () {
      expect(
          _values([
            [_word('12,345', 0)]
          ]),
          ['12.345']);
    });

    test('quita los ceros que el display deja a la izquierda', () {
      expect(
          _values([
            [_word('0012.345', 0)]
          ]),
          ['12.345']);
    });

    test('ubica el punto perdido con los decimales de la balanza', () {
      final candidates = IndicatorReadingParser.candidates([
        [_word('12345', 0)],
      ], expectedDecimals: 3);
      expect(candidates.single.value, '12.345');
      expect(candidates.single.pointAdded, isTrue);

      expect(
          _values([
            [_word('0005', 0)]
          ], decimals: 3),
          ['0.005']);
      // Sin decimales conocidos no se inventa el punto.
      expect(
          _values([
            [_word('12345', 0)]
          ]),
          ['12345']);
    });

    test('prefiere lo más grande: el display y no la placa', () {
      expect(
        _values([
          [_word('d=0.005', 0, height: 18)],
          [_word('12.345', 0, height: 70)],
        ]).first,
        '12.345',
      );
    });
  });

  group('ReadingStability', () {
    test('es estable con la misma lectura en tres cuadros seguidos', () {
      final stability = ReadingStability();
      stability
        ..add('12.345')
        ..add('12.345');
      expect(stability.stable, isFalse);
      stability.add('12.345');
      expect(stability.stable, isTrue);

      stability.add('12.350');
      expect(stability.stable, isFalse);
      expect(stability.value, '12.350');

      stability.add(null);
      expect(stability.stable, isFalse);
    });
  });

  group('IndicatorReadingCheck', () {
    final balanza = BalanzaInfo(capMax1: '30', d1: 0.005);

    List<String> warnings(String value, {bool pointAdded = false}) =>
        IndicatorReadingCheck.warnings(
          IndicatorCandidate(value: value, height: 60, pointAdded: pointAdded),
          balanza,
        );

    test('una lectura con los decimales y el paso de d no tiene avisos', () {
      expect(warnings('12.345'), isEmpty);
      expect(warnings('0.000'), isEmpty);
    });

    test('avisa si faltan decimales o no es múltiplo de d', () {
      expect(warnings('12.34'),
          ['Con d = 0.005 el indicador muestra 3 decimales.']);
      expect(warnings('12.343'), ['No es múltiplo de d = 0.005.']);
    });

    test('avisa cuando el punto decimal se ubicó por la división', () {
      expect(warnings('12.345', pointAdded: true),
          ['Se ubicó el punto decimal según d = 0.005.']);
    });

    test('decimales esperados según todos los rangos', () {
      expect(IndicatorReadingCheck.expectedDecimals(balanza), 3);
      expect(
        IndicatorReadingCheck.expectedDecimals(BalanzaInfo(
          capMax1: '3',
          d1: 0.001,
          capMax2: '6',
          d2: 0.002,
        )),
        3,
      );
      // Rangos con distintos decimales: depende del valor.
      expect(
        IndicatorReadingCheck.expectedDecimals(BalanzaInfo(
          capMax1: '60',
          d1: 0.01,
          capMax2: '150',
          d2: 0.05,
          capMax3: '300',
          d3: 0.1,
        )),
        isNull,
      );
      expect(IndicatorReadingCheck.decimalsOf(10), 0);
      expect(IndicatorReadingCheck.decimalsOf(0.1), 1);
    });
  });
}
