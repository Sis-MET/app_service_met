import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/home/services/support_upload_api_service.dart';

void main() {
  test('no envía las columnas legacy de retorno a cero para MPA', () {
    final envelopes = buildSupportUploadEnvelopes([
      {
        '_support_module': 'mnt_prv_avanzado',
        'otst': '26-0090-11-S02',
        'session_id': '0001',
        'cod_metrica': '0090-11-014',
        'retorno_cero_inicial_unidad': 'kg',
        'retorno_cero_final_unidad': 'kg',
      },
    ]);

    final data = envelopes.single['data'] as Map<String, dynamic>;
    expect(data, isNot(contains('retorno_cero_inicial_unidad')));
    expect(data, isNot(contains('retorno_cero_final_unidad')));
  });

  test('conserva las unidades de retorno a cero para instalación', () {
    final envelopes = buildSupportUploadEnvelopes([
      {
        '_support_module': 'instalacion',
        'otst': '26-0090-11-S02',
        'retorno_cero_inicial_unidad': 'kg',
        'retorno_cero_final_unidad': 'kg',
      },
    ]);

    final data = envelopes.single['data'] as Map<String, dynamic>;
    expect(data['retorno_cero_inicial_unidad'], 'kg');
    expect(data['retorno_cero_final_unidad'], 'kg');
  });

  test('normaliza todas las variantes de fecha antes de enviarlas', () {
    final envelopes = buildSupportUploadEnvelopes([
      {
        '_support_module': 'mnt_correctivo',
        'otst': '26-0090-11-S02',
        'fecha_servicio': '12-08-2026',
        'fecha_prox_servicio': '13/08/2027',
      },
      {
        '_support_module': 'diagnostico',
        'otst': '26-0090-11-S03',
        'fecha_servicio': '2026-08-14 15:30:00',
      },
    ]);

    final correctivo = envelopes[0]['data'] as Map<String, dynamic>;
    expect(correctivo['fecha_servicio'], '2026-08-12');
    expect(correctivo['fecha_prox_servicio'], '2027-08-13');

    final diagnostico = envelopes[1]['data'] as Map<String, dynamic>;
    expect(diagnostico['fecha_servicio'], '2026-08-14');
  });
}
