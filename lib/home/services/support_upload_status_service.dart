import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class SupportUploadStatusService {
  Database? _database;

  SupportUploadStatusService({Database? database}) : _database = database;

  Future<Database> get _db async {
    final current = _database;
    if (current != null && current.isOpen) {
      await _createTable(current);
      return current;
    }
    final path = p.join(await getDatabasesPath(), 'support_upload_status.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => _createTable(db),
    );
    return _database!;
  }

  Future<void> _createTable(Database db) => db.execute('''
        CREATE TABLE IF NOT EXISTS support_upload_status (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          module TEXT NOT NULL,
          otst TEXT NOT NULL,
          session_id TEXT NOT NULL,
          cod_metrica TEXT NOT NULL,
          codigo_registro TEXT NOT NULL,
          server_n INTEGER NOT NULL,
          uploaded_by TEXT,
          uploaded_at TEXT NOT NULL,
          UNIQUE(module, otst, session_id, cod_metrica)
        )
      ''');

  String recordKey(Map<String, dynamic> record) => [
        record['_support_module'],
        record['otst'],
        record['session_id'],
        record['cod_metrica'],
      ].map((value) => value?.toString().trim() ?? '').join('|');

  Future<Set<String>> uploadedKeys(String otst) async {
    final db = await _db;
    final rows = await db.query(
      'support_upload_status',
      where: 'otst = ?',
      whereArgs: [otst],
    );
    return rows
        .map((row) => [
              row['module'],
              row['otst'],
              row['session_id'],
              row['cod_metrica'],
            ].map((value) => value?.toString().trim() ?? '').join('|'))
        .toSet();
  }

  Future<void> markUploaded({
    required Map<String, dynamic> record,
    required String codigoRegistro,
    required int serverN,
    required String uploadedBy,
  }) async {
    final db = await _db;
    await db.insert(
      'support_upload_status',
      {
        'module': record['_support_module']?.toString() ?? '',
        'otst': record['otst']?.toString() ?? '',
        'session_id': record['session_id']?.toString() ?? '',
        'cod_metrica': record['cod_metrica']?.toString() ?? '',
        'codigo_registro': codigoRegistro,
        'server_n': serverN,
        'uploaded_by': uploadedBy,
        'uploaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
