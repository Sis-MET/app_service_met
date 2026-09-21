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

  test('no envía las rutas locales de las fotos', () {
    // Verificaciones internas e Instalación guardan fotos en columnas propias
    // para poder continuar un servicio; el servidor no las tiene.
    final envelopes = buildSupportUploadEnvelopes([
      {
        '_support_module': 'verificaciones_internas',
        'otst': '26-0090-11-S02',
        'campos_estado_foto': '[["/fotos/001.jpg"],[]]',
        'limpieza_puente_foto': '/fotos/002.jpg',
      },
      {
        '_support_module': 'instalacion',
        'otst': '26-0090-11-S02',
        'entorno_foto': '/fotos/003.jpg',
        'entorno_valor': 'Adecuado',
      },
    ]);

    final verificaciones = envelopes.first['data'] as Map<String, dynamic>;
    final instalacion = envelopes.last['data'] as Map<String, dynamic>;
    expect(verificaciones, isNot(contains('campos_estado_foto')));
    expect(verificaciones, isNot(contains('limpieza_puente_foto')));
    expect(instalacion, isNot(contains('entorno_foto')));
    expect(instalacion['entorno_valor'], 'Adecuado');
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
