import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/utils/new_scale_code.dart';

void main() {
  test('genera el mismo código métrica en calibración y soporte', () {
    final code = NewScaleCode.generate(
      clientCode: '0004',
      plantCode: '08',
      now: DateTime(2026, 8, 13, 11, 31, 8),
    );

    expect(code, '0004-08-130826113108');
  });

  test('no duplica códigos generados dentro del mismo segundo', () {
    final instant = DateTime(2026, 8, 13, 11, 31, 8);
    final first = NewScaleCode.generate(
      clientCode: '0005',
      plantCode: '09',
      now: instant,
    );
    final second = NewScaleCode.generate(
      clientCode: '0005',
      plantCode: '09',
      now: instant,
    );

    expect(first, '0005-09-130826113108');
    expect(second, '0005-09-130826113109');
  });

  test('conserva un código de planta que ya incluye al cliente', () {
    final code = NewScaleCode.generate(
      clientCode: '0006',
      plantCode: '0006-10',
      now: DateTime(2026, 8, 13, 11, 31, 8),
    );

    expect(code, '0006-10-130826113108');
  });

  group('código provisional', () {
    test('reconoce el código que genera la app para una balanza nueva', () {
      final code = NewScaleCode.generate(
        clientCode: '0032',
        plantCode: '11',
        now: DateTime(2026, 10, 15, 9, 30, 12),
      );
      expect(NewScaleCode.isProvisional(code), isTrue);
      expect(NewScaleCode.provisionalPrefix(code), '0032-11');
      expect(NewScaleCode.isProvisional('NNNN-NN-151026093012'), isTrue);
    });

    test('un código de DataMET no es provisional', () {
      expect(NewScaleCode.isProvisional('0032-11-020'), isFalse);
      expect(NewScaleCode.isProvisional('0032-11-0201'), isFalse);
      expect(NewScaleCode.isProvisional(''), isFalse);
      expect(NewScaleCode.isProvisional(null), isFalse);
      expect(NewScaleCode.provisionalPrefix('0032-11-020'), isNull);
    });

    test('igual que el servidor, exige una fecha y hora reales', () {
      // 31 de febrero y 25 horas no son una marca de tiempo válida.
      expect(NewScaleCode.isProvisional('0032-11-310226093012'), isFalse);
      expect(NewScaleCode.isProvisional('0032-11-151026253012'), isFalse);
      expect(NewScaleCode.isProvisional(' 0032-11-151026093012 '), isTrue);
    });
  });
}
