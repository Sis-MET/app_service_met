import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/login/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('conserva varios servicios históricos del mismo código métrica',
      () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await DatabaseService().createPrecargaTables(database);

    await database.insert('servicios', {
      'cod_metrica': 'MET-001',
      'seca': 'SECA-001',
      'reg_fecha': '2026-08-10',
    });
    await database.insert('servicios', {
      'cod_metrica': 'MET-001',
      'seca': 'SECA-002',
      'reg_fecha': '2026-08-11',
    });

    final rows = await database.query(
      'servicios',
      where: 'cod_metrica = ?',
      whereArgs: ['MET-001'],
    );
    expect(rows, hasLength(2));
    expect(rows.map((row) => row['id']).toSet(), hasLength(2));
  });
}
