import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/home/models/servicio_model.dart';
import 'package:service_met/home/services/local_service_record_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// El editor anterior mostraba "Cambios guardados correctamente" pero sólo
/// mutaba una lista en memoria. Estas pruebas fijan que ahora la escritura
/// llega realmente a SQLite.
void main() {
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE mnt_prv_regular_stil (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        otst TEXT DEFAULT '',
        cod_metrica TEXT DEFAULT '',
        marca TEXT DEFAULT '',
        comentario_general TEXT DEFAULT ''
      )
    ''');

    LocalServiceRecordRepository.resolverOverride = (tipo, row) async {
      final id = int.tryParse(row['id']?.toString() ?? '');
      if (id == null) return null;
      return LocalRecordTarget(
        db: database,
        table: row['_source_table']?.toString() ?? 'mnt_prv_regular_stil',
        where: 'id = ?',
        whereArgs: [id],
      );
    };
  });

  tearDown(() async {
    LocalServiceRecordRepository.resolverOverride = null;
    await database.close();
  });

  /// Fila tal como la entrega `HomeDashboardService`: columnas reales más las
  /// claves internas `_source_*`.
  Future<Map<String, dynamic>> seedRow() async {
    final id = await database.insert('mnt_prv_regular_stil', {
      'otst': '0001-01-S01-26',
      'cod_metrica': '0001-01-001',
      'marca': 'Toledo',
      'comentario_general': '',
    });
    return {
      'id': id,
      'otst': '0001-01-S01-26',
      'cod_metrica': '0001-01-001',
      'marca': 'Toledo',
      'comentario_general': '',
      '_support_module': 'mnt_prv_regular',
      '_support_label': 'Mantenimiento preventivo regular',
      '_source_database': 'mnt_prv_regular_stil.db',
      '_source_table': 'mnt_prv_regular_stil',
    };
  }

  Future<Map<String, dynamic>> readRow(int id) async {
    final rows = await database
        .query('mnt_prv_regular_stil', where: 'id = ?', whereArgs: [id]);
    return rows.single;
  }

  test('la edición se persiste realmente en la base', () async {
    final row = await seedRow();

    final affected = await LocalServiceRecordRepository.update(
      TipoServicio.soporte,
      row,
      {'marca': 'Mettler', 'comentario_general': 'Se ajustó la celda'},
    );

    expect(affected, 1);
    final stored = await readRow(row['id'] as int);
    expect(stored['marca'], 'Mettler');
    expect(stored['comentario_general'], 'Se ajustó la celda');
    // Las columnas no tocadas se conservan.
    expect(stored['cod_metrica'], '0001-01-001');
  });

  test('permite completar una columna que estaba vacía', () async {
    final row = await seedRow();

    await LocalServiceRecordRepository.update(
      TipoServicio.soporte,
      row,
      {'comentario_general': 'Observación agregada'},
    );

    final stored = await readRow(row['id'] as int);
    expect(stored['comentario_general'], 'Observación agregada');
  });

  test('nunca escribe las claves internas ni el id', () async {
    final row = await seedRow();

    final affected = await LocalServiceRecordRepository.update(
      TipoServicio.soporte,
      row,
      {
        'id': 999,
        '_source_table': 'otra_tabla',
        '_support_module': 'otro',
      },
    );

    // Sin columnas de datos que escribir, no se toca la base.
    expect(affected, 0);
    final stored = await readRow(row['id'] as int);
    expect(stored['id'], row['id']);
  });

  test('reload devuelve los valores frescos y conserva las claves internas',
      () async {
    final row = await seedRow();
    await LocalServiceRecordRepository.update(
      TipoServicio.soporte,
      row,
      {'marca': 'Mettler'},
    );

    final fresh = await LocalServiceRecordRepository.reload(
      TipoServicio.soporte,
      row,
    );

    expect(fresh, isNotNull);
    expect(fresh!['marca'], 'Mettler');
    expect(fresh['_source_database'], 'mnt_prv_regular_stil.db');
    expect(fresh['_source_table'], 'mnt_prv_regular_stil');
    expect(fresh['_support_module'], 'mnt_prv_regular');
  });

  test('delete elimina la fila de forma permanente', () async {
    final row = await seedRow();

    final affected = await LocalServiceRecordRepository.delete(
      TipoServicio.soporte,
      row,
    );

    expect(affected, 1);
    final rows = await database.query('mnt_prv_regular_stil');
    expect(rows, isEmpty);
    expect(
      await LocalServiceRecordRepository.reload(TipoServicio.soporte, row),
      isNull,
    );
  });

  test('una fila sin id no escribe ni borra nada', () async {
    await seedRow();
    final huerfana = <String, dynamic>{
      'marca': 'Toledo',
      '_source_table': 'mnt_prv_regular_stil',
    };

    expect(
      await LocalServiceRecordRepository.update(
          TipoServicio.soporte, huerfana, {'marca': 'X'}),
      0,
    );
    expect(
      await LocalServiceRecordRepository.delete(
          TipoServicio.soporte, huerfana),
      0,
    );
    expect((await database.query('mnt_prv_regular_stil')).single['marca'],
        'Toledo');
  });
}
