import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:service_met/database/precarga_bd.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regresión: si `precarga_database.db` existía pero se había quedado sin
/// tablas (descarga interrumpida, archivo borrado desde Respaldo y recreado
/// vacío por otra ruta que lo abre sin `onCreate`), el `CREATE INDEX ... ON
/// clientes` de `onOpen` reventaba con "no such table: clientes" y la pantalla
/// de precarga se ponía roja. Ahora el esquema se asegura en cada apertura.
void main() {
  late String precargaPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    precargaPath = p.join(await getDatabasesPath(), 'precarga_database.db');
    await DatabaseHelperPrecarga().deleteDatabase();
  });

  tearDown(() async {
    await DatabaseHelperPrecarga().deleteDatabase();
  });

  /// Deja en disco un archivo con la versión ya marcada pero sin ninguna tabla.
  Future<void> crearBaseSinTablas() async {
    final db = await openDatabase(
      precargaPath,
      version: 1,
      onCreate: (_, __) async {},
    );
    await db.close();
  }

  test('abrir una base sin tablas no lanza y recrea el esquema', () async {
    await crearBaseSinTablas();

    final db = await DatabaseHelperPrecarga().database;

    final tablas = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ))
        .map((r) => r['name'])
        .toSet();
    expect(tablas, containsAll(['clientes', 'plantas', 'balanzas']));
  });

  test('los contadores quedan en cero en vez de romper la pantalla', () async {
    await crearBaseSinTablas();

    final clientes = await DatabaseHelperPrecarga().getClientes();

    expect(clientes, isEmpty);
  });

  test('una base recién creada tiene el esquema completo', () async {
    final db = await DatabaseHelperPrecarga().database;

    final tablas = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ))
        .map((r) => r['name'])
        .toSet();
    expect(
      tablas,
      containsAll(
          ['clientes', 'plantas', 'balanzas', 'inf', 'equipamientos', 'servicios']),
    );
  });

  test('no borra los datos existentes al reabrir', () async {
    final db = await DatabaseHelperPrecarga().database;
    await db.insert('clientes', {'cliente_id': 'C1', 'cliente': 'ACME'});
    await DatabaseHelperPrecarga().close();

    final clientes = await DatabaseHelperPrecarga().getClientes();

    expect(clientes.single['cliente'], 'ACME');
  });

  /// Regresión de la causa raíz: `SetupService` descarga la precarga en un
  /// archivo aparte y lo renombra encima del activo. Como la conexión vive en
  /// un campo estático, si no se cierra antes del swap sigue leyendo el
  /// archivo viejo el resto de la sesión: los clientes recién descargados no
  /// aparecen.
  test('tras cerrar, reabrir ve el archivo intercambiado por debajo', () async {
    final viejo = await DatabaseHelperPrecarga().database;
    await viejo.insert('clientes', {'cliente_id': 'C1', 'cliente': 'VIEJO'});

    // La descarga arma la base nueva en un archivo temporal.
    final nuevoPath = '$precargaPath.next';
    final nuevo = await openDatabase(
      nuevoPath,
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'codigo_cliente TEXT, cliente_id TEXT, cliente TEXT, razonsocial TEXT)',
      ),
    );
    await nuevo.insert('clientes', {'cliente_id': 'C2', 'cliente': 'NUEVO'});
    await nuevo.close();

    // Cerrar ANTES del swap es justo lo que faltaba en SetupService.
    await DatabaseHelperPrecarga().close();
    await File(nuevoPath).rename(precargaPath);

    final clientes = await DatabaseHelperPrecarga().getClientes();
    expect(clientes.single['cliente'], 'NUEVO');
  });
}
