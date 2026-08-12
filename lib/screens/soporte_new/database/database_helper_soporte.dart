import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:service_met/screens/soporte_new/utils/soporte_constants.dart';

const supportSessionStatusTable = 'support_session_status';

class DatabaseHelperSoporte {
  static final DatabaseHelperSoporte _instance = DatabaseHelperSoporte._();
  factory DatabaseHelperSoporte() => _instance;
  DatabaseHelperSoporte._();

  DatabaseHelperSoporte.forTesting(Database database) : _database = database;

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
        await _createSessionStatusTable(db);
      },
      onOpen: _createSessionStatusTable,
    );
  }

  Future<void> _createSessionStatusTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $supportSessionStatusTable (
        module_key TEXT NOT NULL,
        session_id TEXT NOT NULL,
        otst TEXT NOT NULL,
        personal TEXT NOT NULL,
        current_step INTEGER DEFAULT 0,
        total_steps INTEGER DEFAULT 1,
        status TEXT DEFAULT 'in_progress',
        cliente_id TEXT DEFAULT '',
        cliente_nombre TEXT DEFAULT '',
        cliente_razon_social TEXT DEFAULT '',
        planta_codigo TEXT DEFAULT '',
        planta_nombre TEXT DEFAULT '',
        planta_direccion TEXT DEFAULT '',
        planta_departamento TEXT DEFAULT '',
        cod_metrica TEXT DEFAULT '',
        n_reca TEXT DEFAULT '',
        instrumento_data TEXT,
        created_at TEXT DEFAULT '',
        updated_at TEXT DEFAULT '',
        completed_at TEXT,
        PRIMARY KEY (module_key, session_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_support_session_pending
      ON $supportSessionStatusTable (personal, status, updated_at)
    ''');
  }

  Future<void> saveSessionProgress({
    required String moduleKey,
    required String sessionId,
    required String otst,
    required String personal,
    required int currentStep,
    required int totalSteps,
    required Map<String, dynamic> routeData,
  }) async {
    if (moduleKey.trim().isEmpty ||
        sessionId.trim().isEmpty ||
        otst.trim().isEmpty ||
        personal.trim().isEmpty) {
      return;
    }
    final db = await database;
    await _createSessionStatusTable(db);
    await db.transaction((txn) async {
      final existing = await txn.query(
        supportSessionStatusTable,
        columns: ['status', 'created_at'],
        where: 'module_key = ? AND session_id = ?',
        whereArgs: [moduleKey, sessionId],
        limit: 1,
      );
      final existingStatus = existing.isEmpty
          ? null
          : existing.first['status']?.toString().toLowerCase();
      if (existingStatus == 'completed' || existingStatus == 'abandoned') {
        return;
      }

      final now = DateTime.now().toIso8601String();
      await txn.insert(
        supportSessionStatusTable,
        {
          'module_key': moduleKey,
          'session_id': sessionId,
          'otst': otst,
          'personal': personal,
          'current_step': currentStep.clamp(0, totalSteps - 1),
          'total_steps': totalSteps,
          'status': 'in_progress',
          'cliente_id': routeData['cliente_id']?.toString() ?? '',
          'cliente_nombre': routeData['cliente_nombre']?.toString() ?? '',
          'cliente_razon_social':
              routeData['cliente_razon_social']?.toString() ?? '',
          'planta_codigo': routeData['planta_codigo']?.toString() ?? '',
          'planta_nombre': routeData['planta_nombre']?.toString() ?? '',
          'planta_direccion': routeData['planta_direccion']?.toString() ?? '',
          'planta_departamento':
              routeData['planta_departamento']?.toString() ?? '',
          'cod_metrica': routeData['cod_metrica']?.toString() ?? '',
          'n_reca': routeData['n_reca']?.toString() ?? '',
          'instrumento_data': _safeJsonEncode(
            Map<String, dynamic>.from(
              routeData['instrumento_data'] as Map? ?? const {},
            ),
          ),
          'created_at': existing.isEmpty
              ? now
              : existing.first['created_at']?.toString() ?? now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Map<String, dynamic>?> getSessionProgress(
    String moduleKey,
    String sessionId,
  ) async {
    final db = await database;
    await _createSessionStatusTable(db);
    final rows = await db.query(
      supportSessionStatusTable,
      where: 'module_key = ? AND session_id = ?',
      whereArgs: [moduleKey, sessionId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getPendingSessions(String personal) async {
    final db = await database;
    await _createSessionStatusTable(db);
    return db.query(
      supportSessionStatusTable,
      where: '''personal = ? AND status = 'in_progress'
        AND TRIM(module_key) <> '' AND TRIM(session_id) <> ''
        AND TRIM(otst) <> '' AND TRIM(cod_metrica) <> '' ''',
      whereArgs: [personal],
      orderBy: 'updated_at DESC',
    );
  }

  Future<void> markSessionCompleted(
    String moduleKey,
    String sessionId,
  ) async {
    await _markSessionTerminal(moduleKey, sessionId, 'completed');
  }

  Future<void> markSessionAbandoned(
    String moduleKey,
    String sessionId,
  ) async {
    await _markSessionTerminal(moduleKey, sessionId, 'abandoned');
  }

  Future<void> _markSessionTerminal(
    String moduleKey,
    String sessionId,
    String status,
  ) async {
    final db = await database;
    await _createSessionStatusTable(db);
    final now = DateTime.now().toIso8601String();
    await db.update(
      supportSessionStatusTable,
      {
        'status': status,
        'updated_at': now,
        if (status == 'completed') 'completed_at': now,
      },
      where: '''module_key = ? AND session_id = ?
        AND status = 'in_progress' ''',
      whereArgs: [moduleKey, sessionId],
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

  Future<Map<String, dynamic>?> query(
      String tableName, String sessionId) async {
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
