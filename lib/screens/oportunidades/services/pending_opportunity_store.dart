import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/opportunity_draft.dart';

/// Oportunidades comerciales guardadas en el teléfono: las pendientes de
/// enviar a Bitrix24 y las ya enviadas (con el número de prospecto).
///
/// Vive en su propia base, `oportunidades_bitrix.db`, como
/// `support_upload_status.db`: no modifica las tablas de los servicios. El
/// respaldo de la app la incluye porque copia todas las `.db`.
class PendingOpportunityStore {
  static const databaseName = 'oportunidades_bitrix.db';
  static const table = 'pending_bitrix_opportunities';

  static Future<Database>? _shared;

  final Database? _injected;

  /// [database] solo para pruebas; la app comparte una única conexión.
  PendingOpportunityStore({Database? database}) : _injected = database;

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
        service_type TEXT NOT NULL,
        service_name TEXT,
        service_session_id TEXT,
        seca TEXT,
        cod_metrica TEXT,
        company_id INTEGER,
        company_name TEXT,
        contact_id INTEGER,
        contact_name TEXT,
        opportunity_type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT,
        payload TEXT NOT NULL,
        created_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sent_at TEXT,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        bitrix_lead_id INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${table}_status ON $table (status)',
    );
    // Una versión de desarrollo creó la tabla antes de que las oportunidades
    // fueran prospectos (Leads) y no tiene la columna.
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (!columns.any((column) => column['name'] == 'bitrix_lead_id')) {
      await db.execute('ALTER TABLE $table ADD COLUMN bitrix_lead_id INTEGER');
    }
  }

  /// Guarda o actualiza la oportunidad con [status]. Conserva el número de
  /// intentos y el prospecto ya asignado; una oportunidad enviada no se toca.
  Future<PendingOpportunity> save(
    OpportunityDraft draft, {
    required OpportunityStatus status,
    String? lastError,
    bool countAttempt = false,
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final existing = await txn.query(
        table,
        columns: ['status', 'retry_count'],
        where: 'uuid = ?',
        whereArgs: [draft.uuid],
      );
      if (existing.isNotEmpty &&
          existing.first['status'] == OpportunityStatus.sent.name) {
        return;
      }
      final values = <String, Object?>{
        'service_type': draft.service.serviceType.name,
        'service_name': draft.service.serviceName,
        'service_session_id': draft.service.sessionId,
        'seca': draft.service.seca,
        'cod_metrica': draft.service.metricCode,
        'company_id': draft.companyId,
        'company_name': draft.companyName,
        'contact_id': draft.contactId,
        'contact_name': draft.contactName,
        'opportunity_type': draft.typeKey,
        'title': draft.title,
        'description': draft.description,
        'priority': draft.priority?.name,
        'payload': jsonEncode(draft.toJson()),
        'created_by': draft.createdBy,
        'updated_at': now,
        'status': status.name,
        'last_error': lastError,
      };
      if (existing.isEmpty) {
        await txn.insert(table, {
          ...values,
          'uuid': draft.uuid,
          'created_at': draft.createdAt.toUtc().toIso8601String(),
          'retry_count': countAttempt ? 1 : 0,
        });
      } else {
        final retries = (existing.first['retry_count'] as int? ?? 0) +
            (countAttempt ? 1 : 0);
        await txn.update(
          table,
          {...values, 'retry_count': retries},
          where: 'uuid = ?',
          whereArgs: [draft.uuid],
        );
      }
    });
    return (await byUuid(draft.uuid))!;
  }

  Future<PendingOpportunity> markSent(String uuid, int leadId) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      table,
      {
        'status': OpportunityStatus.sent.name,
        'bitrix_lead_id': leadId,
        'sent_at': now,
        'updated_at': now,
        'last_error': null,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return (await byUuid(uuid))!;
  }

  Future<PendingOpportunity> markFailed(
    String uuid, {
    required OpportunityStatus status,
    required String error,
  }) async {
    assert(status != OpportunityStatus.sent);
    final db = await _db;
    await db.update(
      table,
      {
        'status': status.name,
        'last_error': error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'uuid = ? AND status <> ?',
      whereArgs: [uuid, OpportunityStatus.sent.name],
    );
    return (await byUuid(uuid))!;
  }

  Future<PendingOpportunity?> byUuid(String uuid) async {
    final db = await _db;
    final rows = await db.query(table, where: 'uuid = ?', whereArgs: [uuid]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Sin enviar primero (las más antiguas arriba) y luego las enviadas más
  /// recientes, hasta [sentLimit].
  Future<List<PendingOpportunity>> list({int sentLimit = 30}) async {
    final db = await _db;
    final unsent = await db.query(
      table,
      where: 'status <> ?',
      whereArgs: [OpportunityStatus.sent.name],
      orderBy: 'created_at ASC',
    );
    final sent = await db.query(
      table,
      where: 'status = ?',
      whereArgs: [OpportunityStatus.sent.name],
      orderBy: 'sent_at DESC',
      limit: sentLimit,
    );
    return [...unsent, ...sent].map(_fromRow).toList(growable: false);
  }

  Future<int> countUnsent() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $table WHERE status <> ?',
      [OpportunityStatus.sent.name],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Descarta una oportunidad que no llegó a enviarse. Las enviadas se
  /// conservan como historial y no se pueden descartar.
  Future<bool> discard(String uuid) async {
    final db = await _db;
    final deleted = await db.delete(
      table,
      where: 'uuid = ? AND status <> ?',
      whereArgs: [uuid, OpportunityStatus.sent.name],
    );
    return deleted > 0;
  }

  static PendingOpportunity _fromRow(Map<String, Object?> row) {
    DateTime? date(String column) =>
        DateTime.tryParse(row[column]?.toString() ?? '')?.toLocal();
    final payload = jsonDecode(row['payload'].toString());
    return PendingOpportunity(
      id: row['id'] as int,
      draft:
          OpportunityDraft.fromJson(Map<String, dynamic>.from(payload as Map)),
      status: OpportunityStatus.fromName(row['status']?.toString()),
      retryCount: row['retry_count'] as int? ?? 0,
      lastError: row['last_error']?.toString(),
      bitrixLeadId: row['bitrix_lead_id'] as int?,
      updatedAt: date('updated_at') ?? DateTime.now(),
      sentAt: date('sent_at'),
    );
  }
}
