import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';
import '../../database/auditoria_registros.dart';
import '../../database/local_database_catalog.dart';
import '../../utils/new_scale_code.dart';
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

/// Motivo que queda en el historial al asignar el código definitivo.
const String kMotivoCodigoMetricaAsignado =
    'Código métrica asignado en DataMET a una balanza nueva';

/// No se pudo asignar el código métrica; [message] se muestra al técnico.
class AsignacionCodigoException implements Exception {
  const AsignacionCodigoException(this.message);
  final String message;

  @override
  String toString() => message;
}

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

/// Corrige y elimina registros locales resolviendo automáticamente en qué
/// base de datos vive cada fila:
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

  /// Reemplaza el código métrica provisional de una balanza nueva por el
  /// que le asignó DataMET.
  ///
  /// Es la única corrección que la app permite sobre un registro técnico, y
  /// queda en [AuditoriaRegistros] con el valor anterior, el nuevo, el
  /// usuario, la fecha y el motivo, en la misma transacción que el cambio
  /// (NB/ISO/IEC 17025 7.5.2). Lanza [AsignacionCodigoException] si la fila
  /// ya no tiene el código provisional que se mostró al técnico.
  static Future<void> asignarCodigoMetrica(
    TipoServicio tipo,
    Map<String, dynamic> row, {
    required String nuevo,
    required String usuario,
    required String appVersion,
    String motivo = kMotivoCodigoMetricaAsignado,
  }) async {
    final codigo = nuevo.trim();
    final anterior = row['cod_metrica']?.toString().trim() ?? '';
    if (codigo.isEmpty) {
      throw const AsignacionCodigoException('Ingrese el código métrica.');
    }
    if (NewScaleCode.isProvisional(codigo)) {
      throw const AsignacionCodigoException(
          'Ese código también es provisional. Use el que asignó DataMET.');
    }
    if (!NewScaleCode.isProvisional(anterior)) {
      throw const AsignacionCodigoException(
          'Solo se puede asignar el código a una balanza nueva con código '
          'provisional.');
    }
    if (usuario.trim().isEmpty) {
      throw const AsignacionCodigoException(
          'No hay un usuario activo. Cierre sesión e ingrese nuevamente.');
    }

    final target = await _target(tipo, row);
    if (target == null) {
      throw const AsignacionCodigoException(
          'No se encontró el registro en el teléfono.');
    }
    final clave = AuditoriaRegistros.claveDe(
      row,
      LocalDatabaseCatalog.byTable(target.table)?.naturalKey ?? const ['id'],
    );

    await target.db.transaction((txn) async {
      final actual = await txn.query(
        target.table,
        columns: ['cod_metrica'],
        where: target.where,
        whereArgs: target.whereArgs,
        limit: 1,
      );
      if (actual.isEmpty) {
        throw const AsignacionCodigoException(
            'No se encontró el registro en el teléfono.');
      }
      if ((actual.first['cod_metrica']?.toString().trim() ?? '') != anterior) {
        throw const AsignacionCodigoException(
            'El registro cambió mientras tanto. Actualice la lista e '
            'inténtelo de nuevo.');
      }
      await AuditoriaRegistros.asegurarTabla(txn);
      final escritas = await txn.update(
        target.table,
        {'cod_metrica': codigo},
        where: target.where,
        whereArgs: target.whereArgs,
      );
      if (escritas != 1) {
        throw AsignacionCodigoException(
            'Se esperaba actualizar 1 registro y se encontraron $escritas.');
      }
      await AuditoriaRegistros.registrar(
        txn,
        EntradaAuditoria(
          fechaHora: AuditoriaRegistros.ahora(),
          usuario: usuario.trim(),
          accion: 'MODIFICAR',
          tabla: target.table,
          registroClave: clave,
          campo: 'cod_metrica',
          valorAnterior: anterior,
          valorNuevo: codigo,
          motivo: motivo,
          appVersion: appVersion,
        ),
      );
    });
  }

  /// Historial de cambios de la fila [row], del más antiguo al más reciente.
  static Future<List<EntradaAuditoria>> historial(
    TipoServicio tipo,
    Map<String, dynamic> row,
  ) async {
    final target = await _target(tipo, row);
    if (target == null) return const [];
    final clave = AuditoriaRegistros.claveDe(
      row,
      LocalDatabaseCatalog.byTable(target.table)?.naturalKey ?? const ['id'],
    );
    return AuditoriaRegistros.deRegistro(
      target.db,
      tablaRegistro: target.table,
      clave: clave,
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
