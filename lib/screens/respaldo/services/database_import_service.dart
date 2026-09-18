import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../database/local_database_catalog.dart';

/// Resultado del análisis de una sola tabla del archivo importado.
class TableImportPlan {
  final LocalTableSpec spec;

  /// Filas del archivo listas para insertar (ya recortadas a las columnas que
  /// existen en la base destino).
  final List<Map<String, Object?>> nuevas;

  /// Filas del archivo que ya existen localmente y se van a omitir.
  final int yaExisten;

  /// Total de filas leídas del archivo para esta tabla.
  final int total;

  const TableImportPlan({
    required this.spec,
    required this.nuevas,
    required this.yaExisten,
    required this.total,
  });
}

/// Análisis completo de un archivo, listo para mostrarse antes de confirmar.
class ImportPreview {
  final String filePath;
  final String fileName;
  final List<TableImportPlan> planes;

  /// Columnas presentes en el archivo pero ausentes en la base destino.
  final Set<String> columnasIgnoradas;

  const ImportPreview({
    required this.filePath,
    required this.fileName,
    required this.planes,
    this.columnasIgnoradas = const {},
  });

  int get totalLeidas => planes.fold(0, (sum, p) => sum + p.total);
  int get totalNuevas => planes.fold(0, (sum, p) => sum + p.nuevas.length);
  int get totalExistentes => planes.fold(0, (sum, p) => sum + p.yaExisten);
  bool get hayAlgoQueImportar => totalNuevas > 0;

  /// Nombre legible de lo que contiene el archivo.
  String get descripcion => planes.map((p) => p.spec.label).join(' · ');
}

/// Resultado de aplicar la importación.
class ImportResult {
  final int insertadas;
  final int omitidas;
  final List<String> errores;

  const ImportResult({
    required this.insertadas,
    required this.omitidas,
    this.errores = const [],
  });
}

/// El archivo elegido no es una base reconocida por la app.
class ImportUnsupportedFile implements Exception {
  final String message;
  const ImportUnsupportedFile(this.message);
  @override
  String toString() => message;
}

/// Importa registros desde un archivo `.db` externo hacia las bases vivas.
///
/// Política (definida con el equipo):
/// * **Solo fusiona**: nunca reemplaza ni borra la base local.
/// * **Ante conflicto gana lo local**: si la clave natural ya existe en el
///   teléfono, la fila del archivo se omite.
/// * **Reconocimiento por esquema**: el archivo se identifica por las tablas
///   que contiene, no por su nombre.
class DatabaseImportService {
  DatabaseImportService._();

  /// Permite a las pruebas sustituir la apertura del archivo y del destino.
  @visibleForTesting
  static Future<Database> Function(String path)? openImportedOverride;

  @visibleForTesting
  static Future<Database> Function(LocalTableSpec spec)? openLiveOverride;

  static Future<Database> _openImported(String path) =>
      (openImportedOverride ?? _defaultOpenImported)(path);

  static Future<Database> _defaultOpenImported(String path) =>
      openDatabase(path, readOnly: true);

  static Future<Database> _openLive(LocalTableSpec spec) =>
      openLiveOverride != null ? openLiveOverride!(spec) : spec.openLive();

  /// Lee [filePath] y calcula qué se importaría, sin escribir nada.
  ///
  /// Lanza [ImportUnsupportedFile] si el archivo no es SQLite o no contiene
  /// ninguna tabla conocida.
  static Future<ImportPreview> analyze(String filePath, String fileName) async {
    Database? imported;
    try {
      try {
        imported = await _openImported(filePath);
      } catch (e) {
        throw const ImportUnsupportedFile(
          'El archivo no se pudo abrir como base de datos SQLite. '
          'Verifica que sea un respaldo .db generado por ServiceMET.',
        );
      }

      final tablasArchivo = await _tableNames(imported);
      final specs = LocalDatabaseCatalog.all
          .where((spec) => tablasArchivo.contains(spec.table))
          .toList();

      if (specs.isEmpty) {
        throw const ImportUnsupportedFile(
          'La base no contiene ninguna tabla que ServiceMET reconozca. '
          'Debe ser un respaldo de calibración o de un módulo de soporte.',
        );
      }

      final planes = <TableImportPlan>[];
      final ignoradas = <String>{};

      for (final spec in specs) {
        final filas = await imported.query(spec.table);
        if (filas.isEmpty) {
          planes.add(TableImportPlan(
              spec: spec, nuevas: const [], yaExisten: 0, total: 0));
          continue;
        }

        final live = await _openLive(spec);
        final columnasDestino = await _columnNames(live, spec.table);
        if (columnasDestino.isEmpty) {
          // Sin esto la importación terminaría en silencio sin copiar nada.
          throw ImportUnsupportedFile(
            'La tabla "${spec.table}" no existe todavía en este dispositivo. '
            'Abre una vez el módulo "${spec.label}" y vuelve a intentarlo.',
          );
        }
        final existentes = await _existingKeys(live, spec);

        // `id` se descarta siempre: lo reasigna el AUTOINCREMENT local para no
        // chocar con las filas que ya están en el teléfono.
        final columnasCopiables = columnasDestino.difference({'id'});

        for (final columna in filas.first.keys) {
          if (columna != 'id' && !columnasDestino.contains(columna)) {
            ignoradas.add(columna);
          }
        }

        final nuevas = <Map<String, Object?>>[];
        var yaExisten = 0;

        for (final fila in filas) {
          final recortada = <String, Object?>{};
          for (final entry in fila.entries) {
            if (columnasCopiables.contains(entry.key)) {
              recortada[entry.key] = entry.value;
            }
          }
          if (recortada.isEmpty) continue;

          final clave = _rowKey(recortada, spec.naturalKey);
          if (existentes.contains(clave)) {
            yaExisten++;
            continue;
          }
          // Evita duplicar dentro del propio archivo y hace la operación
          // idempotente si se importa dos veces.
          existentes.add(clave);
          nuevas.add(recortada);
        }

        planes.add(TableImportPlan(
          spec: spec,
          nuevas: nuevas,
          yaExisten: yaExisten,
          total: filas.length,
        ));
      }

      return ImportPreview(
        filePath: filePath,
        fileName: fileName,
        planes: planes,
        columnasIgnoradas: ignoradas,
      );
    } finally {
      await imported?.close();
    }
  }

  /// Inserta las filas nuevas calculadas en [preview]. No borra nada.
  static Future<ImportResult> apply(ImportPreview preview) async {
    var insertadas = 0;
    final errores = <String>[];

    for (final plan in preview.planes) {
      if (plan.nuevas.isEmpty) continue;
      try {
        final live = await _openLive(plan.spec);
        await live.transaction((txn) async {
          for (final fila in plan.nuevas) {
            await txn.insert(plan.spec.table, fila);
            insertadas++;
          }
        });
      } catch (e) {
        errores.add('${plan.spec.label}: $e');
      }
    }

    return ImportResult(
      insertadas: insertadas,
      omitidas: preview.totalExistentes,
      errores: errores,
    );
  }

  /// Clave de deduplicación: la clave natural si tiene contenido; si no, el
  /// conjunto completo de valores, para no perder filas huérfanas ni
  /// duplicarlas al reimportar.
  static String _rowKey(Map<String, Object?> fila, List<String> naturalKey) {
    final partes = naturalKey
        .map((k) => fila[k]?.toString().trim() ?? '')
        .toList(growable: false);
    if (partes.any((p) => p.isNotEmpty)) return partes.join('|');

    final claves = fila.keys.toList()..sort();
    return claves.map((k) => '$k=${fila[k]}').join('|');
  }

  static Future<Set<String>> _existingKeys(
      Database live, LocalTableSpec spec) async {
    final columnasDestino = await _columnNames(live, spec.table);
    final filas = await live.query(spec.table);
    final copiables = columnasDestino.difference({'id'});
    return filas.map((fila) {
      final recortada = <String, Object?>{};
      for (final entry in fila.entries) {
        if (copiables.contains(entry.key)) recortada[entry.key] = entry.value;
      }
      return _rowKey(recortada, spec.naturalKey);
    }).toSet();
  }

  static Future<Set<String>> _tableNames(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return rows.map((r) => r['name']?.toString() ?? '').toSet();
  }

  static Future<Set<String>> _columnNames(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => r['name']?.toString() ?? '').toSet();
  }
}
