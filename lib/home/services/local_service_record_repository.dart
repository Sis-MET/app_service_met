import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';
import '../../database/local_database_catalog.dart';
import '../models/servicio_model.dart';

/// Claves internas que la app agrega a cada fila (o que son identidad de la
/// tabla) y que nunca deben escribirse de vuelta a la base.
const Set<String> kLocalRecordSystemKeys = {
  'id',
  '_support_module',
  '_support_label',
  '_source_database',
  '_source_table',
  'uploaded',
};

/// Ubicación concreta de una fila: conexión, tabla y cláusula que la identifica.
class LocalRecordTarget {
  final Database db;
  final String table;
  final String where;
  final List<Object?> whereArgs;

  const LocalRecordTarget({
    required this.db,
    required this.table,
    required this.where,
    required this.whereArgs,
  });
}

typedef LocalRecordTargetResolver = Future<LocalRecordTarget?> Function(
  TipoServicio tipo,
  Map<String, dynamic> row,
);

/// Escribe y elimina registros locales resolviendo automáticamente en qué base
/// de datos vive cada fila:
///
/// * Calibración -> `calibracion.db`, tabla `registros_calibracion`.
/// * Soporte     -> una de las 7 bases de `lib/database/soporte_tecnico/`,
///   identificada por las claves `_source_database` / `_source_table` que
///   agrega `HomeDashboardService` al cargar el dashboard.
class LocalServiceRecordRepository {
  LocalServiceRecordRepository._();

  /// Permite a las pruebas apuntar a una base en memoria.
  @visibleForTesting
  static LocalRecordTargetResolver? resolverOverride;

  static Future<LocalRecordTarget?> _target(
    TipoServicio tipo,
    Map<String, dynamic> row,
  ) =>
      (resolverOverride ?? _defaultResolver)(tipo, row);

  /// Actualiza la fila [row] con [values] (solo columnas de datos).
  /// Devuelve el número de filas afectadas.
  static Future<int> update(
    TipoServicio tipo,
    Map<String, dynamic> row,
    Map<String, dynamic> values,
  ) async {
    final clean = <String, dynamic>{};
    values.forEach((key, value) {
      if (!kLocalRecordSystemKeys.contains(key)) clean[key] = value;
    });
    if (clean.isEmpty) return 0;

    final target = await _target(tipo, row);
    if (target == null) return 0;
    return target.db.update(
      target.table,
      clean,
      where: target.where,
      whereArgs: target.whereArgs,
    );
  }

  /// Elimina de forma permanente la fila [row]. Devuelve filas afectadas.
  static Future<int> delete(
    TipoServicio tipo,
    Map<String, dynamic> row,
  ) async {
    final target = await _target(tipo, row);
    if (target == null) return 0;
    return target.db.delete(
      target.table,
      where: target.where,
      whereArgs: target.whereArgs,
    );
  }

  /// Relee la fila desde la base, conservando las claves internas
  /// (`_source_*`, etc.) que la UI necesita para seguir operando sobre ella.
  static Future<Map<String, dynamic>?> reload(
    TipoServicio tipo,
    Map<String, dynamic> row,
  ) async {
    final target = await _target(tipo, row);
    if (target == null) return null;

    final rows = await target.db.query(
      target.table,
      where: target.where,
      whereArgs: target.whereArgs,
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final fresh = Map<String, dynamic>.from(rows.first);
    for (final key in kLocalRecordSystemKeys) {
      if (key != 'id' && row.containsKey(key)) fresh[key] = row[key];
    }
    return fresh;
  }

  static Future<LocalRecordTarget?> _defaultResolver(
    TipoServicio tipo,
    Map<String, dynamic> row,
  ) async {
    final id = _intId(row['id']);

    if (tipo == TipoServicio.calibracion) {
      final db = await AppDatabase().database;
      if (id != null) {
        return LocalRecordTarget(
          db: db,
          table: 'registros_calibracion',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      // Respaldo para filas sin `id`: la pareja seca + session_id es única.
      final seca = row['seca']?.toString();
      final sessionId = row['session_id']?.toString();
      if (seca == null || sessionId == null) return null;
      return LocalRecordTarget(
        db: db,
        table: 'registros_calibracion',
        where: 'seca = ? AND session_id = ?',
        whereArgs: [seca, sessionId],
      );
    }

    // `diagnostico` y `diagnostico_correctivo` comparten archivo, así que la
    // tabla es la que desambigua, no la base.
    final table = row['_source_table']?.toString();
    if (table == null || table.isEmpty || id == null) return null;
    final spec = LocalDatabaseCatalog.byTable(table);
    if (spec == null) {
      throw StateError('Tabla de soporte desconocida: "$table"');
    }
    return LocalRecordTarget(
      db: await spec.openLive(),
      table: table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static int? _intId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
