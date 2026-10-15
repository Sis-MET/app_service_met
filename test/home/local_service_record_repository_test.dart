import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/database/auditoria_registros.dart';
import 'package:service_met/home/models/servicio_model.dart';
import 'package:service_met/home/services/local_service_record_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Los registros técnicos ya no se editan libremente: la única corrección es
/// asignar el código métrica definitivo a una balanza nueva, y queda en el
/// historial en la misma transacción (NB/ISO/IEC 17025 7.5.2).
void main() {
  late Database database;

  const provisional = '0001-01-151026093012';

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE mnt_prv_regular_stil (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        otst TEXT DEFAULT '',
        session_id TEXT DEFAULT '',
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
  Future<Map<String, dynamic>> seedRow({
    String codMetrica = provisional,
  }) async {
    final id = await database.insert('mnt_prv_regular_stil', {
      'otst': '0001-01-S01-26',
      'session_id': '0001',
      'cod_metrica': codMetrica,
      'marca': 'Toledo',
      'comentario_general': '',
    });
    return {
      'id': id,
      'otst': '0001-01-S01-26',
      'session_id': '0001',
      'cod_metrica': codMetrica,
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

  Future<void> asignar(Map<String, dynamic> row, String nuevo,
          {String usuario = 'tecnico'}) =>
      LocalServiceRecordRepository.asignarCodigoMetrica(
        TipoServicio.soporte,
        row,
        nuevo: nuevo,
        usuario: usuario,
        appVersion: '6.3.4+16',
      );

  test('asigna el código definitivo y deja el cambio en el historial',
      () async {
    final row = await seedRow();

    await asignar(row, ' 0001-01-021 ');

    final stored = await readRow(row['id'] as int);
    expect(stored['cod_metrica'], '0001-01-021');
    // Las demás columnas no se tocan.
    expect(stored['marca'], 'Toledo');

    final historial = await LocalServiceRecordRepository.historial(
        TipoServicio.soporte, row);
    expect(historial, hasLength(1));
    final entrada = historial.single;
    expect(entrada.accion, 'MODIFICAR');
    expect(entrada.tabla, 'mnt_prv_regular_stil');
    expect(entrada.registroClave, 'otst=0001-01-S01-26|session_id=0001');
    expect(entrada.campo, 'cod_metrica');
    expect(entrada.valorAnterior, provisional);
    expect(entrada.valorNuevo, '0001-01-021');
    expect(entrada.usuario, 'tecnico');
    expect(entrada.motivo, kMotivoCodigoMetricaAsignado);
    expect(entrada.appVersion, '6.3.4+16');
    expect(
        entrada.fechaHora,
        matches(
            RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$')));
  });

  test('no corrige registros que ya tienen un código definitivo', () async {
    final row = await seedRow(codMetrica: '0001-01-001');

    await expectLater(asignar(row, '0001-01-002'),
        throwsA(isA<AsignacionCodigoException>()));
    expect((await readRow(row['id'] as int))['cod_metrica'], '0001-01-001');
    expect(
        await LocalServiceRecordRepository.historial(TipoServicio.soporte, row),
        isEmpty);
  });

  test('rechaza otro código provisional, uno vacío o sin usuario', () async {
    final row = await seedRow();

    for (final (codigo, usuario) in [
      ('0001-01-151026093013', 'tecnico'),
      ('  ', 'tecnico'),
      ('0001-01-021', ''),
    ]) {
      await expectLater(asignar(row, codigo, usuario: usuario),
          throwsA(isA<AsignacionCodigoException>()));
    }
    expect((await readRow(row['id'] as int))['cod_metrica'], provisional);
  });

  test('si el registro cambió mientras tanto no escribe nada', () async {
    final row = await seedRow();
    // Otro proceso ya le asignó un código.
    await database.update('mnt_prv_regular_stil', {'cod_metrica': 'OTRO'},
        where: 'id = ?', whereArgs: [row['id']]);

    await expectLater(asignar(row, '0001-01-021'),
        throwsA(isA<AsignacionCodigoException>()));
    expect((await readRow(row['id'] as int))['cod_metrica'], 'OTRO');
    expect(
        await LocalServiceRecordRepository.historial(TipoServicio.soporte, row),
        isEmpty);
  });

  test('si el historial no se puede escribir, el código tampoco cambia',
      () async {
    final row = await seedRow();
    // Una tabla de historial incompatible hace fallar el INSERT de la entrada
    // después del UPDATE: la transacción debe deshacer ambos.
    await database.execute(
        'CREATE TABLE ${AuditoriaRegistros.tabla} (id INTEGER PRIMARY KEY, '
        'fecha_hora TEXT NOT NULL, usuario TEXT NOT NULL, accion TEXT NOT NULL, '
        'tabla TEXT NOT NULL, registro_clave TEXT NOT NULL, '
        'obligatoria TEXT NOT NULL)');

    await expectLater(asignar(row, '0001-01-021'), throwsA(anything));
    expect((await readRow(row['id'] as int))['cod_metrica'], provisional);
  });

  test('reload devuelve los valores frescos y conserva las claves internas',
      () async {
    final row = await seedRow();
    await asignar(row, '0001-01-021');

    final fresh = await LocalServiceRecordRepository.reload(
      TipoServicio.soporte,
      row,
    );

    expect(fresh, isNotNull);
    expect(fresh!['cod_metrica'], '0001-01-021');
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
      'cod_metrica': provisional,
      '_source_table': 'mnt_prv_regular_stil',
    };

    await expectLater(asignar(huerfana, '0001-01-021'),
        throwsA(isA<AsignacionCodigoException>()));
    expect(
      await LocalServiceRecordRepository.delete(
          TipoServicio.soporte, huerfana),
      0,
    );
    expect((await database.query('mnt_prv_regular_stil')).single['cod_metrica'],
        provisional);
  });
}
