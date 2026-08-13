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
}
