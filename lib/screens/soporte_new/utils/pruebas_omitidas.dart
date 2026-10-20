import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Si se hizo cada prueba metrológica (el interruptor "Realizar ...").
typedef PruebasRealizadas = ({
  bool excentricidad,
  bool repetibilidad,
  bool linealidad,
});

/// Las pruebas que el técnico omitió, en la columna [columna] de la tabla del
/// módulo. Sin ella, al reabrir el servicio una prueba omitida no se
/// distinguía de una que todavía no se llenó: volvía activa con los datos de
/// antes, o una sin llenar aparecía omitida.
///
/// La columna es solo del teléfono y no se sube (ver
/// `buildSupportUploadEnvelopes`). Una prueba omitida tampoco deja datos en
/// sus columnas: al servidor llega vacía.
abstract final class PruebasOmitidas {
  static const columna = 'pruebas_omitidas';

  static const excentricidad = 'excentricidad';
  static const repetibilidad = 'repetibilidad';
  static const linealidad = 'linealidad';

  /// Valor de la columna: las omitidas separadas por coma; vacío si se
  /// hicieron todas.
  static String escribir(PruebasRealizadas realizadas) => [
        if (!realizadas.excentricidad) excentricidad,
        if (!realizadas.repetibilidad) repetibilidad,
        if (!realizadas.linealidad) linealidad,
      ].join(',');

  /// Qué pruebas se hicieron según [row]; null si el registro no lo dice
  /// porque lo guardó una versión anterior: entonces vale lo que el módulo
  /// deduzca de los datos.
  static PruebasRealizadas? leer(Map<String, dynamic> row) {
    final valor = row[columna];
    if (valor == null) return null;
    final omitidas = valor.toString().split(',').map((p) => p.trim()).toSet();
    return (
      excentricidad: !omitidas.contains(excentricidad),
      repetibilidad: !omitidas.contains(repetibilidad),
      linealidad: !omitidas.contains(linealidad),
    );
  }

  /// Por base y tabla, la creación de la columna en curso o terminada.
  static final Expando<Map<String, Future<void>>> _porBase = Expando();

  /// Agrega la columna a [tabla] si todavía no la tiene. Sin valor por
  /// omisión: los registros anteriores quedan en null, "no se sabe".
  static Future<void> asegurarColumna(Database db, String tabla) {
    final porTabla = _porBase[db] ??= <String, Future<void>>{};
    return porTabla[tabla] ??= () async {
      try {
        await _agregar(db, tabla);
      } catch (error) {
        // Se vuelve a intentar en el próximo guardado.
        porTabla.remove(tabla);
        debugPrint('No se pudo agregar $columna a $tabla: $error');
        rethrow;
      }
    }();
  }

  static Future<void> _agregar(Database db, String tabla) async {
    final info = await db.rawQuery('PRAGMA table_info($tabla)');
    if (info.any((c) => c['name']?.toString() == columna)) return;
    try {
      await db.execute('ALTER TABLE $tabla ADD COLUMN $columna TEXT');
    } on DatabaseException catch (error) {
      // Otra conexión al mismo archivo pudo agregarla primero.
      if (!error.toString().contains('duplicate column')) rethrow;
    }
  }
}
