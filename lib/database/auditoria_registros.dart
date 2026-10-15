import 'package:sqflite/sqflite.dart';

import '../utils/fecha_iso.dart';

/// Una modificación de un registro técnico (NB/ISO/IEC 17025 7.5.2): qué
/// campo cambió, de qué valor a cuál, quién, cuándo y por qué.
class EntradaAuditoria {
  const EntradaAuditoria({
    required this.fechaHora,
    required this.usuario,
    required this.accion,
    required this.tabla,
    required this.registroClave,
    required this.campo,
    required this.valorAnterior,
    required this.valorNuevo,
    required this.motivo,
    required this.appVersion,
  });

  /// ISO-8601 con desfase horario: 2026-10-15T09:30:00-04:00.
  final String fechaHora;
  final String usuario;

  /// MODIFICAR (por ahora la única acción que la app registra).
  final String accion;
  final String tabla;

  /// Clave natural del registro, p. ej. `seca=26-0032-11|session_id=0001`.
  /// No incluye el código métrica, que es justamente lo que puede cambiar.
  final String registroClave;
  final String? campo;
  final String? valorAnterior;
  final String? valorNuevo;
  final String motivo;
  final String appVersion;

  Map<String, Object?> toRow() => {
        'fecha_hora': fechaHora,
        'usuario': usuario,
        'accion': accion,
        'tabla': tabla,
        'registro_clave': registroClave,
        'campo': campo,
        'valor_anterior': valorAnterior,
        'valor_nuevo': valorNuevo,
        'motivo': motivo,
        'app_version': appVersion,
      };

  factory EntradaAuditoria.fromRow(Map<String, Object?> row) =>
      EntradaAuditoria(
        fechaHora: row['fecha_hora']?.toString() ?? '',
        usuario: row['usuario']?.toString() ?? '',
        accion: row['accion']?.toString() ?? '',
        tabla: row['tabla']?.toString() ?? '',
        registroClave: row['registro_clave']?.toString() ?? '',
        campo: row['campo']?.toString(),
        valorAnterior: row['valor_anterior']?.toString(),
        valorNuevo: row['valor_nuevo']?.toString(),
        motivo: row['motivo']?.toString() ?? '',
        appVersion: row['app_version']?.toString() ?? '',
      );
}

/// Historial de cambios de los registros técnicos.
///
/// Vive en la misma base que el registro, para escribirse en la misma
/// transacción que el cambio: si una de las dos escrituras falla, no queda
/// ninguna. Solo se agrega; nada en la app edita ni borra entradas.
class AuditoriaRegistros {
  const AuditoriaRegistros._();

  static const tabla = 'auditoria_registros';

  static Future<void> asegurarTabla(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tabla (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_hora TEXT NOT NULL,
        usuario TEXT NOT NULL,
        accion TEXT NOT NULL,
        tabla TEXT NOT NULL,
        registro_clave TEXT NOT NULL,
        campo TEXT,
        valor_anterior TEXT,
        valor_nuevo TEXT,
        motivo TEXT NOT NULL,
        app_version TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_auditoria_clave '
        'ON $tabla (tabla, registro_clave)');
  }

  static Future<void> registrar(
      DatabaseExecutor txn, EntradaAuditoria entrada) async {
    await txn.insert(tabla, entrada.toRow());
  }

  /// Entradas de un registro, de la más antigua a la más reciente.
  static Future<List<EntradaAuditoria>> deRegistro(
    Database db, {
    required String tablaRegistro,
    required String clave,
  }) async {
    final existe = await db.rawQuery(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        [tabla]);
    if (existe.isEmpty) return const [];
    final rows = await db.query(
      tabla,
      where: 'tabla = ? AND registro_clave = ?',
      whereArgs: [tablaRegistro, clave],
      orderBy: 'id ASC',
    );
    return rows.map(EntradaAuditoria.fromRow).toList();
  }

  /// `campo=valor|campo=valor` con la clave natural de la fila.
  static String claveDe(Map<String, dynamic> row, List<String> clave) =>
      clave.map((k) => '$k=${row[k]?.toString().trim() ?? ''}').join('|');

  /// Fecha y hora actuales con desfase horario.
  static String ahora() => fechaIsoConDesfase(DateTime.now());
}
