import 'package:sqflite/sqflite.dart';

class DatabaseHelperSoporte {
  static final DatabaseHelperSoporte _instance =
      DatabaseHelperSoporte._internal();
  factory DatabaseHelperSoporte() => _instance;
  static Database? _database;

  DatabaseHelperSoporte._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return await openDatabase(
      '${dbPath}soporte_tecnico.db',
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de sesiones/registros genérica (cada módulo usa su propia tabla)
    final tables = [
      'verificaciones_internas',
      'relevamiento_de_datos',
      'mnt_prv_avanzado_stac',
      'mnt_prv_regular_stil',
      'mnt_correctivo',
      'instalacion',
      'diagnostico',
      'ajustes_metrologicos',
    ];

    for (final table in tables) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT,
          otst TEXT,
          cod_metrica TEXT,
          tipo_servicio TEXT,
          estado_servicio TEXT DEFAULT 'Pendiente',
          hora_inicio TEXT,
          hora_fin TEXT,
          comentario_general TEXT,
          recomendacion TEXT,
          fisico TEXT,
          operacional TEXT,
          metrologico TEXT,
          fecha_prox_servicio TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }

    // Tabla de ajustes metrológicos (compartida)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ajustes_metrologicos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        cod_metrica TEXT,
        d1 REAL DEFAULT 0.1,
        d2 REAL DEFAULT 0.1,
        d3 REAL DEFAULT 0.1,
        cap_max1 REAL DEFAULT 0,
        cap_max2 REAL DEFAULT 0,
        cap_max3 REAL DEFAULT 0
      )
    ''');
  }

  Future<void> upsert(String tableName, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> query(String tableName,
      {String? where,
      List<dynamic>? whereArgs,
      String? orderBy,
      int? limit}) async {
    final db = await database;
    return await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getFirst(String tableName,
      {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
    final results = await query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? 'id DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<String> generateSessionId(String seca) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM (SELECT session_id FROM verificaciones_internas '
      'UNION ALL SELECT session_id FROM relevamiento_de_datos '
      'UNION ALL SELECT session_id FROM mnt_prv_avanzado_stac '
      'UNION ALL SELECT session_id FROM mnt_prv_regular_stil '
      'UNION ALL SELECT session_id FROM mnt_correctivo '
      'UNION ALL SELECT session_id FROM instalacion '
      'UNION ALL SELECT session_id FROM diagnostico '
      'UNION ALL SELECT session_id FROM ajustes_metrologicos) WHERE session_id LIKE ?',
      ['$seca-%'],
    );
    final count = result.isNotEmpty ? result.first['count'] as int? ?? 0 : 0;
    return '${seca}_${DateTime.now().millisecondsSinceEpoch}_${count + 1}';
  }

  Future<double> getD1(String codMetrica) async {
    try {
      final db = await database;
      final results = await db.query(
        'ajustes_metrologicos',
        columns: ['d1'],
        where: 'cod_metrica = ?',
        whereArgs: [codMetrica],
        limit: 1,
      );
      if (results.isNotEmpty && results.first['d1'] != null) {
        return _toDouble(results.first['d1']!);
      }
      return 0.1;
    } catch (e) {
      return 0.1;
    }
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.1;
    return 0.1;
  }
}
