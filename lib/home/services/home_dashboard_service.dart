import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';
import '../../database/local_database_catalog.dart';
import '../models/home_dashboard_data.dart';
import '../models/servicio_model.dart';

class HomeDashboardService {
  Future<HomeDashboardData> load() async {
    final results = await Future.wait<dynamic>([
      _loadCalibrationData(),
      _loadSupportServices(),
      _lastPreload(),
    ]);
    final calibration = results[0] as _CalibrationDashboardData;
    final support = results[1] as List<ServicioResumen>;

    return HomeDashboardData(
      calibratedScales: calibration.completed,
      supportServices: support.fold(0, (sum, item) => sum + item.cantidad),
      servicesInProgress: calibration.inProgress,
      pendingUploads:
          calibration.pendingUploads.fold(0, (sum, item) => sum + item.count),
      lastPreload: results[2] as String,
      pendingUploadGroups: calibration.pendingUploads,
      calibrationServices: calibration.services,
      supportServiceGroups: support,
    );
  }

  Future<_CalibrationDashboardData> _loadCalibrationData() async {
    final db = await AppDatabase().database;
    final records = await db.rawQuery('''
      SELECT r.*,
             CASE WHEN u.session_id IS NULL THEN 0 ELSE 1 END AS uploaded
      FROM registros_calibracion r
      LEFT JOIN calibration_upload_status u
        ON r.seca = u.seca AND r.session_id = u.session_id
      ORDER BY r.fecha_servicio DESC, r.session_id DESC
    ''');

    final bySeca = <String, List<Map<String, dynamic>>>{};
    final pendingBySeca = <String, int>{};
    var completed = 0;
    var inProgress = 0;

    for (final raw in records) {
      final record = Map<String, dynamic>.from(raw)..remove('uploaded');
      final seca = record['seca']?.toString().trim();
      final groupKey = seca == null || seca.isEmpty ? 'Sin SECA' : seca;
      bySeca.putIfAbsent(groupKey, () => []).add(record);

      final isCompleted =
          record['estado_servicio_bal']?.toString() == 'Balanza Calibrada';
      if (isCompleted) {
        completed++;
        if ((raw['uploaded'] as int? ?? 0) == 0 && groupKey != 'Sin SECA') {
          pendingBySeca.update(groupKey, (value) => value + 1,
              ifAbsent: () => 1);
        }
      } else {
        inProgress++;
      }
    }

    final services = bySeca.entries.map((entry) {
      entry.value.sort(_compareRowsNewestFirst);
      final date = _latestServiceDate(entry.value);
      return ServicioResumen(
        tipo: TipoServicio.calibracion,
        codigo: entry.key,
        cantidad: entry.value.length,
        items: entry.value,
        fecha: date.isEmpty ? null : date,
      );
    }).toList()
      ..sort(_compareServicesNewestFirst);

    final pending = pendingBySeca.entries
        .map((entry) => PendingUploadGroup(
              seca: entry.key,
              count: entry.value,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return _CalibrationDashboardData(
      completed: completed,
      inProgress: inProgress,
      pendingUploads: pending,
      services: services,
    );
  }

  Future<List<ServicioResumen>> _loadSupportServices() async {
    final root = await getDatabasesPath();
    final grouped = <String, List<Map<String, dynamic>>>{};

    final databaseRows = await Future.wait(
      LocalDatabaseCatalog.soporte.map((source) async {
        final path = p.join(root, source.database);
        if (!await databaseExists(path)) return <Map<String, dynamic>>[];
        Database? db;
        try {
          db = await openDatabase(path, readOnly: true);
          final rows = await db.query(source.table);
          return rows
              .map((row) => Map<String, dynamic>.from(row)
                ..['_support_module'] = source.module
                ..['_support_label'] = source.label
                ..['_source_database'] = source.database
                ..['_source_table'] = source.table)
              .toList();
        } catch (_) {
          return <Map<String, dynamic>>[];
        } finally {
          await db?.close();
        }
      }),
    );

    for (final rows in databaseRows) {
      for (final row in rows) {
        final code = row['otst']?.toString().trim();
        grouped
            .putIfAbsent(
              code == null || code.isEmpty ? 'Sin OTST' : code,
              () => [],
            )
            .add(row);
      }
    }

    final services = grouped.entries.map((entry) {
      entry.value.sort(_compareRowsNewestFirst);
      final date = _latestServiceDate(entry.value);
      return ServicioResumen(
        tipo: TipoServicio.soporte,
        codigo: entry.key,
        cantidad: entry.value.length,
        items: entry.value,
        fecha: date.isEmpty ? null : date,
      );
    }).toList()
      ..sort(_compareServicesNewestFirst);

    return services;
  }

  static int _compareRowsNewestFirst(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final byDate = _compareDatesNewestFirst(
      a['fecha_servicio']?.toString(),
      b['fecha_servicio']?.toString(),
    );
    if (byDate != 0) return byDate;

    final aId = int.tryParse(a['id']?.toString() ?? '') ?? -1;
    final bId = int.tryParse(b['id']?.toString() ?? '') ?? -1;
    return bId.compareTo(aId);
  }

  static int _compareServicesNewestFirst(
    ServicioResumen a,
    ServicioResumen b,
  ) {
    final byDate = _compareDatesNewestFirst(a.fecha, b.fecha);
    if (byDate != 0) return byDate;
    return b.codigo.compareTo(a.codigo);
  }

  static int _compareDatesNewestFirst(String? a, String? b) {
    final aDate = _parseServiceDate(a);
    final bDate = _parseServiceDate(b);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  static String _latestServiceDate(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final value = row['fecha_servicio']?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static DateTime? _parseServiceDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final iso = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (iso != null) return iso;

    final parts = text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        final parsed = DateTime(year, month, day);
        if (parsed.year == year && parsed.month == month && parsed.day == day) {
          return parsed;
        }
      }
    }
    return null;
  }

  Future<String> _lastPreload() async {
    try {
      final path = p.join(
        await getDatabasesPath(),
        'precarga_database.db',
      );
      if (!await databaseExists(path)) return 'Aún no descargada';
      final modified = await File(path).lastModified();
      return DateFormat("d 'de' MMMM 'de' y", 'es_ES').format(modified);
    } catch (_) {
      return 'No disponible';
    }
  }
}

class _CalibrationDashboardData {
  final int completed;
  final int inProgress;
  final List<PendingUploadGroup> pendingUploads;
  final List<ServicioResumen> services;

  const _CalibrationDashboardData({
    required this.completed,
    required this.inProgress,
    required this.pendingUploads,
    required this.services,
  });
}
