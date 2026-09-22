import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/utils/indicator_reading.dart';
import 'package:service_met/screens/calibracion/utils/seven_segment_reader.dart';
import 'indicator_image_support.dart';

void main() {
  test('foto AND conserva 4000.01 en distintas escalas', () async {
    final photo = await loadIndicator('and');
    for (final scale in [0.7, 1.0, 1.4]) {
      final reading = SevenSegmentReader.read(resizeIndicator(photo, scale));
      expect(reading?.toString(), '4000.01', reason: 'escala $scale');
    }
  });

  test('fotos con variaciones de encuadre no inventan valores', () async {
    for (final name in ['and', 'sartorius']) {
      final photo = await loadIndicator(name);
      final random = math.Random(7);
      var accepted = 0;
      for (var i = 0; i < 60; i++) {
        final scale = 0.6 + random.nextDouble();
        final band = cropIndicator(
            photo, random.nextInt(81), random.nextInt(61), 570, 308);
        final reading = SevenSegmentReader.read(resizeIndicator(band, scale));
        if (name == 'sartorius') {
          expect(reading, isNull, reason: '$name caso $i: $reading');
        } else if (reading != null) {
          accepted++;
          expect(
              IndicatorReadingParser.fromSegments(reading, expectedDecimals: 2)
                  ?.value,
              '4000.01',
              reason: '$name caso $i');
        }
      }
      // Evita que una regresión que rechace todos los cuadros pase la prueba.
      if (name == 'and') expect(accepted, greaterThanOrEqualTo(40));
    }
  });
}
