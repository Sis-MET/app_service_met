import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_controller.dart';

void main() {
  test('la OTST de soporte siempre utiliza el prefijo S', () {
    final controller = PrecargaController()..plantaCodigo = '0090-11';

    controller.setCotizacionSuffix('C02');
    expect(controller.cotizacionSuffix, 'S02');
    expect(controller.suggestedSeca, endsWith('-0090-11-S02'));

    controller.setNoOtst(true);
    expect(controller.cotizacionSuffix, 'S00');
    expect(controller.suggestedSeca, endsWith('-0090-11-S00'));

    controller.dispose();
  });

  test('muestra codigo_registro con el código del módulo de soporte', () {
    final controller = PrecargaController()
      ..selectedServicio = 'MNT PREVENTIVO REGULAR'
      ..selectedSeca = '26-0090-11-S02'
      ..codMetrica = '0090-11-014';

    expect(
      controller.suggestedCodigoRegistro,
      '26-0090-11-S02-MPR.BL-0090-11-014',
    );

    controller.dispose();
  });
}
