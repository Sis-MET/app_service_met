import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/rim_documento.dart';

/// RIM emitidos en este teléfono (`servicios_extras.db` › `form_rim`), con el
/// mismo nombre de base y de tabla que en el servidor.
///
/// Un RIM es un registro firmado por el cliente y por el representante de
/// Métrica: se inserta una sola vez y su contenido no se vuelve a escribir.
/// Después solo cambian el estado de la subida y, si corresponde, la
/// anulación (con quién, cuándo y por qué). No hay borrado. El respaldo de la app incluye esta base porque copia todas
/// las `.db`.
class RimStore {
  static const databaseName = 'servicios_extras.db';
  static const table = 'form_rim';

  static Future<Database>? _shared;

  final Database? _injected;

  /// [database] solo para pruebas; la app comparte una única conexión.
  RimStore({Database? database}) : _injected = database;

  Future<Database> get _db async {
    final injected = _injected;
    if (injected != null) {
      await createTable(injected);
      return injected;
    }
    final current = await (_shared ??= _open());
    if (current.isOpen) return current;
    return _shared = _open();
  }

  static Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), databaseName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => createTable(db),
      onOpen: createTable,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        codigo_rim TEXT NOT NULL,
        service_type TEXT NOT NULL,
        service_name TEXT,
        service_session_id TEXT,
        seca TEXT,
        cod_metrica TEXT,
        cliente TEXT,
        planta TEXT,
        contacto_nombre TEXT,
        payload TEXT NOT NULL,
        firma_cliente BLOB NOT NULL,
        firma_representante BLOB,
        created_by TEXT,
        emitido_en TEXT NOT NULL,
        app_version TEXT,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        server_n INTEGER,
        sent_at TEXT,
        anulado INTEGER NOT NULL DEFAULT 0,
        anulado_por TEXT,
        anulado_en TEXT,
        motivo_anulacion TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${table}_status ON $table (status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${table}_session '
      'ON $table (service_session_id)',
    );
    // Tablas creadas antes de pedir la firma del representante de Métrica.
    final columnas = await db.rawQuery('PRAGMA table_info($table)');
    if (!columnas.any((columna) => columna['name'] == 'firma_representante')) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN firma_representante BLOB',
      );
    }
  }

  /// Guarda un RIM recién emitido, con las dos firmas. Falla si el UUID ya
  /// existe: un RIM emitido nunca se reemplaza.
  Future<RimRegistro> insert(
    RimDocumento documento,
    Uint8List firmaCliente,
    Uint8List firmaRepresentante,
  ) async {
    final db = await _db;
    await db.insert(
      table,
      {
        'uuid': documento.uuid,
        'codigo_rim': documento.codigo,
        'service_type': documento.service.serviceType.name,
        'service_name': documento.service.serviceName,
        'service_session_id': documento.service.sessionId,
        'seca': documento.service.seca,
        'cod_metrica': documento.service.metricCode,
        'cliente': documento.service.clientDisplay,
        'planta': documento.service.plantName,
        'contacto_nombre': documento.contactoNombre,
        'payload': jsonEncode(documento.toJson()),
        'firma_cliente': firmaCliente,
        'firma_representante': firmaRepresentante,
        'created_by': documento.creadoPor,
        'emitido_en': documento.emitidoEn.toUtc().toIso8601String(),
        'app_version': documento.appVersion,
        'status': RimEstadoSubida.pending.name,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return (await byUuid(documento.uuid))!;
  }

  Future<RimRegistro?> byUuid(String uuid) async {
    final db = await _db;
    final rows = await db.query(table, where: 'uuid = ?', whereArgs: [uuid]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Por subir primero (los más antiguos arriba), luego los anulados y los
  /// subidos más recientes, hasta [historyLimit].
  Future<List<RimRegistro>> list({int historyLimit = 50}) async {
    final db = await _db;
    final unsent = await db.query(
      table,
      where: 'status <> ? AND anulado = 0',
      whereArgs: [RimEstadoSubida.sent.name],
      orderBy: 'emitido_en ASC',
    );
    final history = await db.query(
      table,
      where: 'status = ? OR anulado = 1',
      whereArgs: [RimEstadoSubida.sent.name],
      orderBy: 'emitido_en DESC',
      limit: historyLimit,
    );
    return [...unsent, ...history].map(_fromRow).toList(growable: false);
  }

  Future<int> countUnsent() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $table WHERE status <> ? AND anulado = 0',
      [RimEstadoSubida.sent.name],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Si el servicio [sessionId] ya tiene un RIM vigente del instrumento
  /// [codMetrica], para no volver a sugerirlo.
  Future<bool> existsForService({
    required String? sessionId,
    required String? codMetrica,
  }) async {
    if (sessionId == null || sessionId.isEmpty) return false;
    final db = await _db;
    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'service_session_id = ? AND anulado = 0'
          '${codMetrica == null ? '' : ' AND cod_metrica = ?'}',
      whereArgs: [sessionId, if (codMetrica != null) codMetrica],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Marca que empezó un intento de subida. No toca lo ya subido ni anulado.
  Future<void> markSending(String uuid) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE $table SET status = ?, retry_count = retry_count + 1 '
      'WHERE uuid = ? AND status <> ? AND anulado = 0',
      [RimEstadoSubida.sending.name, uuid, RimEstadoSubida.sent.name],
    );
  }

  Future<RimRegistro> markSent(String uuid, int serverN) async {
    final db = await _db;
    await db.update(
      table,
      {
        'status': RimEstadoSubida.sent.name,
        'server_n': serverN,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return (await byUuid(uuid))!;
  }

  Future<RimRegistro> markFailed(
    String uuid, {
    required RimEstadoSubida estado,
    required String error,
  }) async {
    assert(estado != RimEstadoSubida.sent);
    final db = await _db;
    await db.update(
      table,
      {'status': estado.name, 'last_error': error},
      where: 'uuid = ? AND status <> ?',
      whereArgs: [uuid, RimEstadoSubida.sent.name],
    );
    return (await byUuid(uuid))!;
  }

  /// Anula un RIM que todavía no se subió: queda en el teléfono, marcado,
  /// con quién lo anuló, cuándo y por qué. Devuelve false si ya estaba
  /// subido o anulado.
  Future<bool> anular(
    String uuid, {
    required String usuario,
    required String motivo,
  }) async {
    final db = await _db;
    final updated = await db.update(
      table,
      {
        'anulado': 1,
        'anulado_por': usuario,
        'anulado_en': DateTime.now().toUtc().toIso8601String(),
        'motivo_anulacion': motivo,
      },
      where: 'uuid = ? AND anulado = 0 AND status <> ?',
      whereArgs: [uuid, RimEstadoSubida.sent.name],
    );
    return updated > 0;
  }

  static RimRegistro _fromRow(Map<String, Object?> row) {
    DateTime? date(String column) =>
        DateTime.tryParse(row[column]?.toString() ?? '')?.toLocal();
    final payload = jsonDecode(row['payload'].toString());
    final firmaRepresentante = row['firma_representante'] as List<int>?;
    return RimRegistro(
      id: row['id'] as int,
      documento:
          RimDocumento.fromJson(Map<String, dynamic>.from(payload as Map)),
      firmaCliente: Uint8List.fromList(row['firma_cliente'] as List<int>),
      firmaRepresentante: firmaRepresentante == null
          ? null
          : Uint8List.fromList(firmaRepresentante),
      estado: RimEstadoSubida.fromName(row['status']?.toString()),
      retryCount: row['retry_count'] as int? ?? 0,
      lastError: row['last_error']?.toString(),
      serverN: row['server_n'] as int?,
      sentAt: date('sent_at'),
      anulado: (row['anulado'] as int? ?? 0) == 1,
      anuladoPor: row['anulado_por']?.toString(),
      anuladoEn: date('anulado_en'),
      motivoAnulacion: row['motivo_anulacion']?.toString(),
    );
  }
}
