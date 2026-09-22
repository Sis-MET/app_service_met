// Casos deterministas con contraste, inclinación, ruido y tamaños variables.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/utils/seven_segment_reader.dart';

import 'seven_segment_render.dart';

void main() {
  for (final extreme in [false, true]) {
    test('sinteticos al azar $extreme', () {
      final random = math.Random(2024);
      var ok = 0, empty = 0, wrong = 0;
      final errors = <String>[];
      for (var i = 0; i < 1000; i++) {
        final digits = 2 + random.nextInt(6);
        var text = List.generate(digits, (_) => random.nextInt(10)).join();
        text = text.replaceFirst(RegExp(r'^0+(?=\d)'), '');
        if (text.length >= 2 && random.nextBool()) {
          final at = 1 + random.nextInt(text.length - 1);
          text = '${text.substring(0, at)}.${text.substring(at)}';
        }
        if (random.nextInt(8) == 0) text = '-$text';
        final bright = random.nextBool();
        final params = (
          height: (extreme ? 30 : 36) + random.nextInt(extreme ? 120 : 114),
          stroke: 0.08 + random.nextDouble() * 0.08,
          gap: extreme
              ? 0.01 + random.nextDouble() * 0.04
              : 0.005 + random.nextDouble() * 0.03,
          spacing: 0.12 + random.nextDouble() * 0.18,
          slant: random.nextBool() ? 0.0 : random.nextDouble() * 12,
          rotate: (random.nextDouble() - 0.5) * (extreme ? 10 : 8),
          ink: bright ? 150 + random.nextInt(100) : 10 + random.nextInt(80),
          background:
              bright ? 10 + random.nextInt(60) : 140 + random.nextInt(100),
          noise: random.nextInt(extreme ? 25 : 20),
        );
        final image = renderSevenSegment(
          text,
          height: params.height,
          stroke: params.stroke,
          gap: params.gap,
          spacing: params.spacing,
          slant: params.slant,
          rotate: params.rotate,
          ink: params.ink,
          background: params.background,
          noise: params.noise,
          seed: i,
        );
        final reading = SevenSegmentReader.read(image);
        final expected = text;
        final got = reading?.toString();
        // Sin punto visible el lector no lo inventa: comparar solo dígitos.
        final same = got == expected ||
            (reading != null &&
                reading.pointAfter == null &&
                reading.digits == expected.replaceAll(RegExp(r'[.-]'), '') &&
                reading.negative == expected.startsWith('-'));
        if (reading == null) {
          empty++;
        } else if (same) {
          ok++;
        } else {
          wrong++;
          errors.add('i=$i $expected -> $got  $params');
        }
      }
      expect(wrong, 0, reason: errors.join('\n'));
      expect(ok, greaterThanOrEqualTo(extreme ? 850 : 900),
          reason: 'Aceptadas: $ok, rechazadas: $empty');
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
