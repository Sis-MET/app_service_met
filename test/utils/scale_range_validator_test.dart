import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';
import 'package:service_met/utils/scale_range_validator.dart';

void main() {
  test('acepta una balanza nueva con dos rangos completos', () {
    final error = ScaleRangeValidator.validate(const [
      ScaleRangeValues(
        capacity: '100',
        division: '0.1',
        verificationDivision: '1',
        decimals: '1',
      ),
      ScaleRangeValues(
        capacity: '200',
        division: '0.01',
        verificationDivision: '0.1',
        decimals: '2',
      ),
      ScaleRangeValues(
        capacity: '0',
        division: '0',
        verificationDivision: '0',
        decimals: '0',
      ),
    ]);

    expect(error, isNull);
  });

  test('valida solamente los rangos que fueron activados', () {
    final error = ScaleRangeValidator.validate(const [
      ScaleRangeValues(
        capacity: '100',
        division: '0.1',
        verificationDivision: '1',
        decimals: '1',
      ),
      ScaleRangeValues(
        capacity: '200',
        division: '',
        verificationDivision: '0.1',
        decimals: '2',
      ),
    ]);

    expect(error, 'Falta la división d (Rango 2).');
  });

  test('usa d1, d2 y d3 según la capacidad del valor sugerido', () {
    final balanza = BalanzaInfo(
      capMax1: '100',
      d1: 0.1,
      capMax2: '200',
      d2: 0.01,
      capMax3: '300',
      d3: 0.001,
    );

    expect(SuggestionHelper.getDivisionForValue(balanza, 50), 0.1);
    expect(SuggestionHelper.getDivisionForValue(balanza, 150), 0.01);
    expect(SuggestionHelper.getDivisionForValue(balanza, 250), 0.001);
    expect(SuggestionHelper.getDecimalPlaces(0.001), 3);
  });

  group('orden visual de los rangos', () {
    test('el Rango 1 es siempre el de menor capacidad', () {
      expect(ScaleRangeOrder.displayOrder(['600', '300', '1500']), [1, 0, 2]);
      expect(ScaleRangeOrder.displayNumbers(['600', '300', '1500']),
          [2, 1, 3]);
      // Con coma decimal y valores numéricos.
      expect(ScaleRangeOrder.displayOrder(['6,5', 3.2, '0']), [1, 0, 2]);
    });

    test('los rangos sin capacidad van al final, en su orden', () {
      expect(ScaleRangeOrder.displayOrder(['', '300', '0']), [1, 0, 2]);
      expect(ScaleRangeOrder.displayOrder([null, '0', '']), [0, 1, 2]);
      expect(ScaleRangeOrder.displayOrder(['300', '300', '0']), [0, 1, 2]);
    });

    test('los mensajes nombran el rango como se ve en pantalla', () {
      const ranges = [
        ScaleRangeValues(
          capacity: '600',
          division: '',
          verificationDivision: '1',
          decimals: '0',
        ),
        ScaleRangeValues(
          capacity: '300',
          division: '0.1',
          verificationDivision: '1',
          decimals: '1',
        ),
      ];
      // cap_max1 = 600 se muestra como Rango 2.
      expect(
        ScaleRangeValidator.validate(ranges,
            displayNumbers: ScaleRangeOrder.displayNumbers(['600', '300'])),
        'Falta la división d (Rango 2).',
      );
      expect(ScaleRangeValidator.validate(ranges),
          'Falta la división d (Rango 1).');
    });
  });
}
