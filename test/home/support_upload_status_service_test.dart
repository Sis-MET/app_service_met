import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/home/services/support_upload_status_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('marca cada registro de soporte sin confundir módulos o sesiones',
      () async {
    final database =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final service = SupportUploadStatusService(database: database);
    addTearDown(service.close);
    final first = {
      '_support_module': 'diagnostico',
      'otst': 'OTST-1',
      'session_id': '0001',
      'cod_metrica': 'MET-1',
    };
    final second = {
      '_support_module': 'mnt_correctivo',
      'otst': 'OTST-1',
      'session_id': '0001',
      'cod_metrica': 'MET-1',
    };

    await service.markUploaded(
      record: first,
      codigoRegistro: 'OTST-1-MET-1',
      serverN: 10,
      uploadedBy: 'tecnico',
    );

    final uploaded = await service.uploadedKeys('OTST-1');
    final logical = await service.uploadedLogicalKeys('OTST-1');
    expect(uploaded, contains(service.recordKey(first)));
    expect(uploaded, isNot(contains(service.recordKey(second))));
    expect(logical, contains('DIAGNOSTICO|OTST-1|MET-1'));
    expect(logical, isNot(contains('MNT_CORRECTIVO|OTST-1|MET-1')));
  });
}
