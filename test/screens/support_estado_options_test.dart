import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/soporte_new/utils/estado_maps.dart';

void main() {
  test('los estados compartidos incluyen No aplica', () {
    expect(estadoColorMap.keys, contains('No aplica'));
    expect(estadoIconMap.keys, contains('No aplica'));
  });
}
