import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/utils/seven_segment_reader.dart';

import 'seven_segment_render.dart';

String? _read(GrayImage image) => SevenSegmentReader.read(image)?.toString();

void main() {
  group('SevenSegmentReader', () {
    test('no ofrece un número cortado por el borde del recuadro', () {
      final full = renderSevenSegment('23456', margin: 20);
      for (final cutLeft in [true, false]) {
        final left = cutLeft ? 36 : 0;
        final width = cutLeft ? full.width - left : full.width - 44;
        final pixels = Uint8List(width * full.height);
        for (var y = 0; y < full.height; y++) {
          pixels.setRange(
              y * width, (y + 1) * width, full.pixels, y * full.width + left);
        }
        expect(_read(GrayImage(width, full.height, pixels)), isNull,
            reason:
                cutLeft ? 'primer dígito cortado' : 'último dígito cortado');
      }
    });

    test('no sustituye segmentos ni devuelve una parte del número', () {
      final cases = {
        '-70274': renderSevenSegment('-70274',
            background: 33,
            gap: 0.03154608891330167,
            height: 40,
            ink: 213,
            noise: 11,
            rotate: -1.553691509199962,
            spacing: 0.28067658611513824,
            stroke: 0.1487786445341886,
            seed: 41),
        '-3443': renderSevenSegment('-3443',
            background: 168,
            gap: 0.031141949292988164,
            height: 30,
            ink: 78,
            noise: 2,
            rotate: 0.5549754301620202,
            spacing: 0.2609110300545361,
            stroke: 0.1460144009844446,
            seed: 805),
        '59.2': renderSevenSegment('59.2',
            background: 222,
            gap: 0.027380334583983916,
            height: 108,
            ink: 54,
            noise: 20,
            rotate: 1.1598710233704213,
            spacing: 0.12344673792488949,
            stroke: 0.12939534380650963,
            seed: 346),
      };
      for (final entry in cases.entries) {
        // Es preferible pedir otro cuadro a ofrecer un peso equivocado.
        expect(_read(entry.value), anyOf(isNull, entry.key), reason: entry.key);
      }
    });

    test('lee un VFD con cortes entre segmentos, con el punto', () {
      // Como el display de la AND GF-6002A: claro sobre oscuro, dígitos
      // pegados y un punto diminuto.
      expect(
        _read(renderSevenSegment('4000.01', gap: 0.04, spacing: 0.12)),
        '4000.01',
      );
    });

    test('lee un LCD oscuro sobre claro, en itálica', () {
      expect(
        _read(renderSevenSegment(
          '12.345',
          ink: 40,
          background: 190,
          slant: 8,
        )),
        '12.345',
      );
    });

    test('lee todos los dígitos', () {
      for (final text in ['0123456789', '9876543210']) {
        expect(_read(renderSevenSegment(text)), text);
      }
    });

    test('lee el signo menos', () {
      final reading = SevenSegmentReader.read(renderSevenSegment('-0.50'));
      expect(reading?.negative, isTrue);
      expect(reading.toString(), '-0.50');
    });

    test('aguanta la foto un poco girada y con ruido', () {
      for (final rotate in [-6.0, 6.0]) {
        expect(
          _read(renderSevenSegment('4000.01', rotate: rotate, noise: 20)),
          '4000.01',
          reason: 'girada $rotate°',
        );
      }
    });

    test('lee dígitos chicos y grandes', () {
      for (final height in [36, 60, 160]) {
        expect(
          _read(renderSevenSegment('305.28', height: height)),
          '305.28',
          reason: 'alto $height',
        );
      }
    });

    test('sin punto a la vista no lo inventa', () {
      final reading = SevenSegmentReader.read(renderSevenSegment('400001'));
      expect(reading?.digits, '400001');
      expect(reading?.pointAfter, isNull);
    });

    test('prefiere la fila grande del display a un rótulo chico', () {
      expect(
        _read(renderSevenSegment(
          '12.345',
          margin: 60,
          extra: [('6200', 70, 8, 22)],
        )),
        '12.345',
      );
    });

    test('un dígito suelto o una fila de unos no alcanzan', () {
      expect(_read(renderSevenSegment('8')), isNull);
      expect(_read(renderSevenSegment('11')), isNull);
    });

    test('no lee manchas ni letra de imprenta', () {
      // Bloques macizos del tamaño de un dígito: sin las ventanas del 8.
      const width = 300, height = 140;
      final pixels = Uint8List(width * height)
        ..fillRange(0, width * height, 20);
      for (var i = 0; i < 5; i++) {
        for (var y = 40; y < 100; y++) {
          for (var x = 30 + i * 45; x < 63 + i * 45; x++) {
            pixels[y * width + x] = 230;
          }
        }
      }
      expect(_read(GrayImage(width, height, pixels)), isNull);

      // Ruido puro.
      final random = math.Random(7);
      final noise = Uint8List.fromList(
          List.generate(width * height, (_) => random.nextInt(256)));
      expect(_read(GrayImage(width, height, noise)), isNull);
    });

    test('una imagen vacía o diminuta no se lee', () {
      expect(_read(GrayImage(8, 8, Uint8List(64))), isNull);
      expect(_read(GrayImage(200, 100, Uint8List(20000))), isNull);
    });
  });
}
