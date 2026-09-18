import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:service_met/database/local_database_catalog.dart';
import 'package:service_met/screens/respaldo/services/database_import_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// La importación solo debe FUSIONAR: agrega lo que falta y, ante un registro
/// que ya existe con la misma clave natural, gana el del teléfono.
void main() {
  late Database live;
  late Database archivo;

  const tabla = 'mnt_prv_regular_stil';
  const esquema = '''
    CREATE TABLE $tabla (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      otst TEXT DEFAULT '',
      session_id TEXT DEFAULT '',
      cod_metrica TEXT DEFAULT '',
      marca TEXT DEFAULT ''
    )
  ''';

  late Directory tempDir;
  late String archivoPath;

  setUpAll(sqfliteFfiInit);

  // Dos bases distintas: `:memory:` comparte instancia en ffi, así que se usan
  // archivos temporales para simular teléfono y respaldo por separado.
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_test');
    archivoPath = p.join(tempDir.path, 'respaldo.db');
    live = await databaseFactoryFfi
        .openDatabase(p.join(tempDir.path, 'live.db'));
    archivo = await databaseFactoryFfi.openDatabase(archivoPath);
    await live.execute(esquema);
    await archivo.execute(esquema);

    // `analyze` cierra el archivo que abre, así que cada llamada recibe su
    // propia conexión, igual que en producción.
    DatabaseImportService.openImportedOverride = (_) => databaseFactoryFfi
        .openDatabase(archivoPath,
            options: OpenDatabaseOptions(singleInstance: false));
    DatabaseImportService.openLiveOverride = (_) async => live;
  });

  tearDown(() async {
    DatabaseImportService.openImportedOverride = null;
    DatabaseImportService.openLiveOverride = null;
    await archivo.close();
    await live.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> insertar(
    Database db, {
    required String otst,
    required String session,
    String marca = 'Toledo',
    String codMetrica = '0001-01-001',
  }) async {
    await db.insert(tabla, {
      'otst': otst,
      'session_id': session,
      'cod_metrica': codMetrica,
      'marca': marca,
    });
  }

  test('detecta la base por su esquema y cuenta nuevos vs existentes',
      () async {
    await insertar(live, otst: 'A', session: 'S1');
    await insertar(archivo, otst: 'A', session: 'S1', marca: 'OTRA');
    await insertar(archivo, otst: 'B', session: 'S2');
    await insertar(archivo, otst: 'C', session: 'S3');

    final preview = await DatabaseImportService.analyze('/tmp/x.db', 'x.db');

    expect(preview.planes.single.spec.table, tabla);
    expect(preview.descripcion, 'Mantenimiento preventivo regular');
    expect(preview.totalLeidas, 3);
    expect(preview.totalNuevas, 2);
    expect(preview.totalExistentes, 1);
    expect(preview.hayAlgoQueImportar, isTrue);
  });

  test('fusiona sin tocar lo local y el registro en conflicto gana el local',
      () async {
    await insertar(live, otst: 'A', session: 'S1', marca: 'LOCAL');
    await insertar(archivo, otst: 'A', session: 'S1', marca: 'ARCHIVO');
    await insertar(archivo, otst: 'B', session: 'S2', marca: 'NUEVO');

    final preview = await DatabaseImportService.analyze('/tmp/x.db', 'x.db');
    final result = await DatabaseImportService.apply(preview);

    expect(result.insertadas, 1);
    expect(result.omitidas, 1);
    expect(result.errores, isEmpty);

    final filas = await live.query(tabla, orderBy: 'otst');
    expect(filas.length, 2);
    // El registro local conserva su valor: no fue pisado por el archivo.
    expect(filas.first['marca'], 'LOCAL');
    expect(filas.last['otst'], 'B');
    expect(filas.last['marca'], 'NUEVO');
  });

  test('importar dos veces el mismo archivo no duplica nada', () async {
    await insertar(archivo, otst: 'A', session: 'S1');
    await insertar(archivo, otst: 'B', session: 'S2');

    await DatabaseImportService.apply(
      await DatabaseImportService.analyze('/tmp/x.db', 'x.db'),
    );
    final segunda = await DatabaseImportService.analyze('/tmp/x.db', 'x.db');

    expect(segunda.totalNuevas, 0);
    expect(segunda.totalExistentes, 2);
    expect(segunda.hayAlgoQueImportar, isFalse);

    final result = await DatabaseImportService.apply(segunda);
    expect(result.insertadas, 0);
    expect((await live.query(tabla)).length, 2);
  });

  test('el id del archivo no pisa los ids locales', () async {
    await insertar(live, otst: 'LOCAL', session: 'S0');
    // El archivo trae un registro cuyo id coincide con el local.
    await archivo.insert(tabla, {
      'id': 1,
      'otst': 'B',
      'session_id': 'S2',
      'cod_metrica': '0002',
      'marca': 'Mettler',
    });

    await DatabaseImportService.apply(
      await DatabaseImportService.analyze('/tmp/x.db', 'x.db'),
    );

    final filas = await live.query(tabla, orderBy: 'id');
    expect(filas.length, 2);
    expect(filas.map((f) => f['id']).toSet().length, 2, reason: 'ids únicos');
    expect(filas.first['otst'], 'LOCAL');
  });

  test('ignora columnas que la versión actual no conoce', () async {
    await archivo.execute("ALTER TABLE $tabla ADD COLUMN campo_futuro TEXT");
    await archivo.insert(tabla, {
      'otst': 'B',
      'session_id': 'S2',
      'marca': 'Mettler',
      'campo_futuro': 'algo',
    });

    final preview = await DatabaseImportService.analyze('/tmp/x.db', 'x.db');
    expect(preview.columnasIgnoradas, contains('campo_futuro'));

    final result = await DatabaseImportService.apply(preview);
    expect(result.insertadas, 1);
    expect((await live.query(tabla)).single['marca'], 'Mettler');
  });

  test('rechaza un archivo sin tablas reconocidas', () async {
    await archivo.execute('DROP TABLE $tabla');
    await archivo.execute('CREATE TABLE cosas_raras (id INTEGER)');

    expect(
      () => DatabaseImportService.analyze('/tmp/x.db', 'x.db'),
      throwsA(isA<ImportUnsupportedFile>()),
    );
  });

  test('avisa si la tabla destino aún no existe en el dispositivo', () async {
    await insertar(archivo, otst: 'A', session: 'S1');
    await live.execute('DROP TABLE $tabla');

    expect(
      () => DatabaseImportService.analyze('/tmp/x.db', 'x.db'),
      throwsA(isA<ImportUnsupportedFile>()),
    );
  });

  test('rechaza un archivo que no es SQLite', () async {
    DatabaseImportService.openImportedOverride =
        (_) => Future<Database>.error(Exception('file is not a database'));

    expect(
      () => DatabaseImportService.analyze('/tmp/foto.jpg', 'foto.jpg'),
      throwsA(isA<ImportUnsupportedFile>()),
    );
  });

  test('el catálogo cubre las nueve tablas sin duplicar tabla', () async {
    final tablas = LocalDatabaseCatalog.all.map((s) => s.table).toList();
    expect(tablas.length, 9);
    expect(tablas.toSet().length, 9, reason: 'sin tablas repetidas');
    expect(LocalDatabaseCatalog.soporte.length, 8);
    // Ambas tablas de diagnóstico comparten archivo.
    expect(
      LocalDatabaseCatalog.forDatabaseFile('diagnostico_correctivo.db')
          .map((s) => s.table),
      containsAll(['diagnostico', 'diagnostico_correctivo']),
    );
    expect(LocalDatabaseCatalog.byTable('registros_calibracion')!.naturalKey,
        ['seca', 'session_id']);
  });
}
