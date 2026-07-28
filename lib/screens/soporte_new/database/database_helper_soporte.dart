import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:service_met/screens/soporte_new/utils/soporte_constants.dart';

class DatabaseHelperSoporte {
  static final DatabaseHelperSoporte _instance = DatabaseHelperSoporte._();
  factory DatabaseHelperSoporte() => _instance;
  DatabaseHelperSoporte._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, SoporteConstants.dbName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS precarga (
            session_id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  Future<void> ensureTableExists(String tableName) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        session_id TEXT PRIMARY KEY,
        otst TEXT,
        cod_metrica TEXT,
        estado_servicio TEXT DEFAULT 'Pendiente',
        data TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    // Migración para tablas creadas antes de las nuevas columnas
    final cols = await db.rawQuery('PRAGMA table_info($tableName)');
    final names = cols.map((c) => c['name']?.toString()).toSet();
    if (!names.contains('otst')) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN otst TEXT');
    }
    if (!names.contains('cod_metrica')) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN cod_metrica TEXT');
    }
    if (!names.contains('estado_servicio')) {
      await db.execute(
          "ALTER TABLE $tableName ADD COLUMN estado_servicio TEXT DEFAULT 'Pendiente'");
    }
  }

  Future<void> upsert(
    String tableName,
    String sessionId,
    Map<String, dynamic> data, {
    String? otst,
    String? codMetrica,
    bool completo = false,
  }) async {
    final db = await database;
    await ensureTableExists(tableName);

    // Preservar estado existente salvo completado explícito
    var estado = 'Pendiente';
    final existing = await db.query(
      tableName,
      columns: ['estado_servicio'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      estado = existing.first['estado_servicio']?.toString() ?? 'Pendiente';
    }
    if (completo) estado = 'Completo';

    await db.insert(
      tableName,
      {
        'session_id': sessionId,
        'otst': otst ?? data['seca_value']?.toString() ?? '',
        'cod_metrica': codMetrica ?? '',
        'estado_servicio': estado,
        'data': _safeJsonEncode(data),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> marcarServicioCompleto(
      String tableName, String sessionId) async {
    final db = await database;
    await ensureTableExists(tableName);
    await db.update(
      tableName,
      {
        'estado_servicio': 'Completo',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<Map<String, dynamic>?> query(String tableName, String sessionId) async {
    final db = await database;
    await ensureTableExists(tableName);
    final results = await db.query(
      tableName,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<Map<String, dynamic>?> getFirst(String tableName) async {
    final db = await database;
    await ensureTableExists(tableName);
    final results = await db.query(tableName, limit: 1);
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<String> generateSessionId() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'SOP_${timestamp}_${timestamp % 10000}';
  }

  Future<List<Map<String, dynamic>>> getRegistrosPorSeca(
    String tableName,
    String seca, {
    bool soloHoy = false,
    bool soloCompletos = true,
  }) async {
    final db = await database;
    await ensureTableExists(tableName);
    var where = 'otst = ?';
    final args = <Object?>[seca];
    if (soloCompletos) {
      where += " AND estado_servicio = 'Completo'";
    }
    if (soloHoy) {
      where += " AND updated_at LIKE ?";
      args.add('${DateFormat('yyyy-MM-dd').format(DateTime.now())}%');
    }
    return db.query(tableName, where: where, whereArgs: args);
  }

  Future<String?> getD1(String codMetrica) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT d1_value FROM ajustes_metrologicos WHERE cod_metrica = ? LIMIT 1',
      [codMetrica],
    );
    if (result.isEmpty) return null;
    return result.first['d1_value']?.toString();
  }

  String _safeJsonEncode(Map<String, dynamic> data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      final sanitized = data.map((k, v) => MapEntry(k, _sanitizeValue(v)));
      return jsonEncode(sanitized);
    }
  }

  dynamic _sanitizeValue(dynamic v) {
    if (v == null || v is String || v is num || v is bool) return v;
    if (v is List) return v.map(_sanitizeValue).toList();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _sanitizeValue(val)));
    }
    return v.toString();
  }
}
