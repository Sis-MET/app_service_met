// ignore_for_file: avoid_print

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelperPrecarga {
  static final DatabaseHelperPrecarga _instance =
      DatabaseHelperPrecarga._internal();
  static Database? _database;
  static final String _databaseName =
      'precarga_database.db'; // Nombre de la base de datos

  // Constructor privado
  DatabaseHelperPrecarga._internal();

  // Obtener la instancia única
  factory DatabaseHelperPrecarga() {
    return _instance;
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    try {
      // Cerrar antes de borrar: si no, la conexión cacheada sobrevive al
      // borrado apuntando a un archivo que ya no existe.
      await close();
      await databaseFactory.deleteDatabase(path);
      _database = null; // Resetear la instancia de la base de datos
      print('Precarga eliminada correctamente en: $path');
    } catch (e) {
      print('Error al eliminar la Precarga: $e');
      throw Exception('Error al eliminar la Precarga: $e');
    }
  }

  // Obtener la base de datos
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Cierra la conexión; la siguiente lectura vuelve a abrirla.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
  }

  // Inicializar la base de datos
  Future<Database> _initDatabase() async {
    // Obtener la ruta de la base de datos
    String path = join(await getDatabasesPath(), 'precarga_database.db');
    print('Ruta de la base de datos: $path'); // Depuración

    // Abrir la base de datos con permisos de lectura y escritura
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: _onOpen,
      readOnly: false, // Asegúrate de que no esté en modo solo lectura
    );
  }

  /// Se ejecuta en cada apertura, no solo al crear el archivo.
  ///
  /// El esquema se asegura aquí a propósito: si el archivo
  /// `precarga_database.db` existe pero quedó sin tablas (descarga
  /// interrumpida, archivo borrado y recreado vacío por otra ruta que lo abre
  /// sin `onCreate`, etc.), los `CREATE INDEX` de abajo fallaban con
  /// "no such table: clientes" y reventaban toda la pantalla de precarga.
  /// Recreando el esquema vacío la app degrada a "0 registros, descarga la
  /// precarga" en lugar de romperse.
  Future<void> _onOpen(Database db) async {
    await _createSchema(db);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_clientes_nombre '
      'ON clientes(cliente COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_plantas_cliente '
      'ON plantas(cliente_id)',
    );
  }

  // Crear las tablas
  Future<void> _onCreate(Database db, int version) async => _createSchema(db);

  Future<void> _createSchema(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS clientes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      codigo_cliente TEXT,
      cliente_id TEXT,
      cliente TEXT,
      razonsocial TEXT
    )
  ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS plantas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      planta TEXT,
      planta_id TEXT,
      codigo_planta TEXT,
      dep TEXT,
      dir TEXT,
      cliente_id TEXT,
      dep_id TEXT
     
    )
  ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS balanzas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cod_metrica TEXT,
      serie TEXT,
      unidad TEXT,
      n_celdas TEXT,
      cap_max1 TEXT,
      d1 TEXT,
      e1 TEXT,
      dec1 TEXT,
      cap_max2 TEXT,
      d2 TEXT,
      e2 TEXT,
      dec2 TEXT,
      cap_max3 TEXT,
      d3 TEXT,
      e3 TEXT,
      dec3 TEXT,
      categoria TEXT
    )
  ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS inf (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cod_interno TEXT,
      cod_metrica TEXT,
      instrumento TEXT,
      tipo_instrumento TEXT,
      marca TEXT,
      modelo TEXT,
      serie TEXT,
      estado TEXT,
      detalles TEXT,
      ubicacion TEXT
    )
  ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS equipamientos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cod_instrumento TEXT,
      instrumento TEXT,
      cert_fecha TEXT,
      ente_calibrador TEXT,
      estado TEXT
    )
  ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS servicios (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cod_interno TEXT,
      cod_metrica TEXT,
      seca TEXT,
      reg_fecha TEXT,
      reg_usuario TEXT,
      exc TEXT,
      rep1 TEXT,
      rep2 TEXT,
      rep3 TEXT,
      rep4 TEXT,
      rep5 TEXT,
      rep6 TEXT,
      rep7 TEXT,
      rep8 TEXT,
      rep9 TEXT,
      rep10 TEXT,
      rep11 TEXT,
      rep12 TEXT,
      rep13 TEXT,
      rep14 TEXT,
      rep15 TEXT,
      rep16 TEXT,
      rep17 TEXT,
      rep18 TEXT,
      rep19 TEXT,
      rep20 TEXT,
      rep21 TEXT,
      rep22 TEXT,
      rep23 TEXT,
      rep24 TEXT,
      rep25 TEXT,
      rep26 TEXT,
      rep27 TEXT,
      rep28 TEXT,
      rep29 TEXT,
      rep30 TEXT,
      lin1 TEXT,
      lin2 TEXT,
      lin3 TEXT,
      lin4 TEXT,
      lin5 TEXT,
      lin6 TEXT,
      lin7 TEXT,
      lin8 TEXT,
      lin9 TEXT,
      lin10 TEXT,
      lin11 TEXT,
      lin12 TEXT,
      lin13 TEXT,
      lin14 TEXT,
      lin15 TEXT,
      lin16 TEXT,
      lin17 TEXT,
      lin18 TEXT,
      lin19 TEXT,
      lin20 TEXT,
      lin21 TEXT,
      lin22 TEXT,
      lin23 TEXT,
      lin24 TEXT,
      lin25 TEXT,
      lin26 TEXT,
      lin27 TEXT,
      lin28 TEXT,
      lin29 TEXT,
      lin30 TEXT,
      lin31 TEXT,
      lin32 TEXT,
      lin33 TEXT,
      lin34 TEXT,
      lin35 TEXT,
      lin36 TEXT,
      lin37 TEXT,
      lin38 TEXT,
      lin39 TEXT,
      lin40 TEXT,
      lin41 TEXT,
      lin42 TEXT,
      lin43 TEXT,
      lin44 TEXT,
      lin45 TEXT,
      lin46 TEXT,
      lin47 TEXT,
      lin48 TEXT,
      lin49 TEXT,
      lin50 TEXT,
      lin51 TEXT,
      lin52 TEXT,
      lin53 TEXT,
      lin54 TEXT,
      lin55 TEXT,
      lin56 TEXT,
      lin57 TEXT,
      lin58 TEXT,
      lin59 TEXT,
      lin60 TEXT
    )
  ''');
  }

  // Métodos para acceder a los datos
  Future<List<Map<String, dynamic>>> getClientes() async {
    final db = await database;
    return await db.query('clientes');
  }

  Future<List<Map<String, dynamic>>> searchClientes(
    String query, {
    int limit = 100,
  }) async {
    final db = await database;
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return db.query(
        'clientes',
        orderBy: 'cliente COLLATE NOCASE',
        limit: limit,
      );
    }
    final pattern = '%$normalized%';
    return db.query(
      'clientes',
      where:
          'cliente LIKE ? COLLATE NOCASE OR razonsocial LIKE ? COLLATE NOCASE',
      whereArgs: [pattern, pattern],
      orderBy: 'cliente COLLATE NOCASE',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getPlantas() async {
    final db = await database;
    return await db.query('plantas');
  }

  Future<List<Map<String, dynamic>>> getPlantasPorCliente(
    String clienteId,
  ) async {
    final db = await database;
    return db.query(
      'plantas',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      orderBy: 'planta COLLATE NOCASE',
    );
  }

  Future<List<Map<String, dynamic>>> getBalanzas() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT b.*, i.cod_interno, i.instrumento, i.tipo_instrumento, i.marca, i.modelo, i.ubicacion, i.serie as inf_serie
      FROM balanzas b
      LEFT JOIN inf i ON b.cod_metrica = i.cod_metrica
    ''');
  }

  Future<List<Map<String, dynamic>>> getBalanzasPorPrefix(String prefix) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT b.*, i.cod_interno, i.instrumento, i.tipo_instrumento, i.marca, i.modelo, i.ubicacion, i.serie as inf_serie
      FROM balanzas b
      LEFT JOIN inf i ON b.cod_metrica = i.cod_metrica
      WHERE b.cod_metrica LIKE ?
    ''', ['$prefix-%']);
  }

  /// Balanza del catálogo con su información (`inf`), o null si no está.
  Future<Map<String, dynamic>?> getBalanzaPorCodigo(String codMetrica) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT b.*, i.cod_interno, i.instrumento, i.tipo_instrumento, i.marca, i.modelo, i.ubicacion, i.serie as inf_serie
      FROM balanzas b
      LEFT JOIN inf i ON b.cod_metrica = i.cod_metrica
      WHERE b.cod_metrica = ? COLLATE NOCASE
      LIMIT 1
    ''', [codMetrica.trim()]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Instrumentos de la planta [prefix] ("0032-11") registrados en DataMET
  /// que no son balanzas: muflas, hornos, estufas…
  Future<List<Map<String, dynamic>>> getInstrumentosNoBalanzaPorPrefix(
    String prefix,
  ) async {
    final db = await database;
    return db.rawQuery('''
      SELECT i.* FROM inf i
      WHERE i.cod_metrica LIKE ?
        AND NOT EXISTS (
          SELECT 1 FROM balanzas b
          WHERE b.cod_metrica = i.cod_metrica COLLATE NOCASE
        )
      ORDER BY i.cod_metrica
    ''', ['$prefix-%']);
  }

  /// La ficha de un instrumento por su código métrica, o null.
  Future<Map<String, dynamic>?> getInfPorCodigo(String codMetrica) async {
    final db = await database;
    final rows = await db.query(
      'inf',
      where: 'cod_metrica = ? COLLATE NOCASE',
      whereArgs: [codMetrica.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getInf() async {
    final db = await database;
    return await db.query('inf');
  }

  Future<List<Map<String, dynamic>>> getEquipamientos() async {
    final db = await database;
    return await db.query('equipamientos');
  }

  Future<List<Map<String, dynamic>>> getServicios() async {
    final db = await database;
    return await db.query('servicios');
  }
}
