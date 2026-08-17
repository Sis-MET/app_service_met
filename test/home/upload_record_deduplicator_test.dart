import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/home/services/upload_record_deduplicator.dart';

void main() {
  test('consolida calibraciones repetidas conservando la más reciente', () {
    final result = deduplicateUploadRecords(
      [
        {'seca': 'SECA-1', 'cod_metrica': 'MET-1', 'session_id': '0003'},
        {'seca': 'SECA-1', 'cod_metrica': 'met-1', 'session_id': '0002'},
        {'seca': 'SECA-1', 'cod_metrica': 'MET-2', 'session_id': '0001'},
      ],
      calibrationUploadLogicalKey,
    );

    expect(result.records, hasLength(2));
    expect(result.records.first['session_id'], '0003');
    expect(result.duplicateCount, 1);
  });

  test(
      'soporte permite el equipo en otro módulo pero no lo duplica dentro del mismo',
      () {
    final result = deduplicateUploadRecords(
      [
        {
          '_support_module': 'mnt_correctivo',
          'otst': 'OTST-1',
          'cod_metrica': 'MET-1',
          'session_id': 'SOP_3',
        },
        {
          '_support_module': 'MNT_CORRECTIVO',
          'otst': 'otst-1',
          'cod_metrica': 'met-1',
          'session_id': 'SOP_2',
        },
        {
          '_support_module': 'diagnostico',
          'otst': 'OTST-1',
          'cod_metrica': 'MET-1',
          'session_id': 'SOP_1',
        },
      ],
      supportUploadLogicalKey,
    );

    expect(result.records, hasLength(2));
    expect(result.records.first['session_id'], 'SOP_3');
    expect(result.duplicateCount, 1);
  });
}
