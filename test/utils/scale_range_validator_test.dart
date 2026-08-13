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
}
