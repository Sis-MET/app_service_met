import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/app_database.dart';
import '../../database/precarga_bd.dart';
import '../../home/services/home_dashboard_service.dart';
import '../../home/services/support_upload_status_service.dart';
import '../../home/services/upload_record_deduplicator.dart';
import '../../screens/soporte_new/database/database_helper_soporte.dart';
import '../../screens/soporte_new/utils/support_module_catalog.dart';
import 'notification_plan.dart';
import 'notification_rules.dart';

/// Reúne desde las bases locales lo que necesita el planificador. Cada fuente
/// falla por separado: una base dañada no debe apagar el resto de avisos.
class NotificationSnapshotLoader {
  Future<NotificationSnapshot> load(String personal) async {
    final precargaPath =
        p.join(await getDatabasesPath(), 'precarga_database.db');
    final precargaExists = await databaseExists(precargaPath);

    final results = await Future.wait<Object?>([
      // Sin precarga no se abre la base: abrirla crearía un archivo vacío.
      precargaExists
          ? _safe(loadPatrones, const <CertifiedItem>[])
          : Future.value(const <CertifiedItem>[]),
      precargaExists
          ? _safe(loadBalanzas, const <BalanzaHistorial>[])
          : Future.value(const <BalanzaHistorial>[]),
      _safe(() => _pendientes(personal), const <PendingService>[]),
      _safe(_servicios, const _Servicios()),
      _safe(() => _ultimaPrecarga(precargaPath), null),
    ]);
    final servicios = results[3] as _Servicios;

    return NotificationSnapshot(
      patrones: results[0] as List<CertifiedItem>,
      balanzas: results[1] as List<BalanzaHistorial>,
      pendientes: results[2] as List<PendingService>,
      subidasCalibracion: servicios.subidasCalibracion,
      subidasSoporte: servicios.subidasSoporte,
      calibracionesHechas: servicios.calibraciones,
      soportesHechos: servicios.soportes,
      precargaDescargada: precargaExists,
      ultimaPrecarga: results[4] as DateTime?,
    );
  }

  /// Patrones activos de la precarga con fecha de certificado válida.
  static Future<List<CertifiedItem>> loadPatrones() async {
    final db = await DatabaseHelperPrecarga().database;
    final rows = await db.query(
      'equipamientos',
      columns: ['cod_instrumento', 'instrumento', 'cert_fecha'],
      where: "COALESCE(estado, '') != 'DESACTIVADO'",
    );
    return [
      for (final row in rows)
        if (parseServiceDate(row['cert_fecha']) case final fecha?)
          CertifiedItem(
            codigo: row['cod_instrumento']?.toString().trim() ?? '',
            descripcion: row['instrumento']?.toString().trim() ?? '',
            ultimaCalibracion: fecha,
          ),
    ];
  }

  /// Última calibración de cada balanza del historial, con su cliente y planta.
  static Future<List<BalanzaHistorial>> loadBalanzas() async {
    final db = await DatabaseHelperPrecarga().database;
    final results = await Future.wait([
      db.query('servicios', columns: ['cod_metrica', 'reg_fecha']),
      db.query('plantas', columns: ['planta', 'codigo_planta', 'cliente_id']),
      db.query('clientes',
          columns: ['cliente_id', 'codigo_cliente', 'cliente']),
      db.query(
        'inf',
        columns: ['cod_metrica', 'instrumento'],
        where: "COALESCE(estado, '') != 'DESACTIVADO'",
      ),
    ]);

    final clientes = {
      for (final row in results[2]) row['cliente_id']?.toString() ?? '': row,
    };
    final plantas = <String, (String, String)>{};
    for (final planta in results[1]) {
      final cliente = clientes[planta['cliente_id']?.toString() ?? ''];
      final prefix = plantaPrefix(
        planta['codigo_planta']?.toString() ?? '',
        cliente?['codigo_cliente']?.toString() ?? '',
      );
      if (prefix.isEmpty) continue;
      plantas[prefix] = (
        cliente?['cliente']?.toString().trim() ?? '',
        planta['planta']?.toString().trim() ?? '',
      );
    }
    // Solo instrumentos que siguen activos en DataMET; una precarga sin
    // tabla `inf` no filtra.
    final activos = {
      for (final row in results[3])
        row['cod_metrica']?.toString().trim() ?? '':
            row['instrumento']?.toString().trim() ?? '',
    };

    final balanzas = <BalanzaHistorial>[];
    latestServiceByCodMetrica(results[0]).forEach((codigo, fecha) {
      if (activos.isNotEmpty && !activos.containsKey(codigo)) return;
      final (cliente, planta) = plantaForCodMetrica(codigo, plantas) ??
          ('Cliente sin identificar', '');
      balanzas.add(BalanzaHistorial(
        codigo: codigo,
        descripcion: activos[codigo] ?? '',
        ultimaCalibracion: fecha,
        cliente: cliente.isEmpty ? 'Cliente sin identificar' : cliente,
        planta: planta,
      ));
    });
    return balanzas;
  }

  Future<List<PendingService>> _pendientes(String personal) async {
    final results = await Future.wait([
      AppDatabase().getPendingServiciosPorUsuario(personal),
      DatabaseHelperSoporte().getPendingSessions(personal),
    ]);
    return [
      for (final row in results[0])
        PendingService(
          esCalibracion: true,
          servicio: 'Calibración',
          codMetrica: row['cod_metrica']?.toString().trim() ?? '',
          cliente: row['cliente']?.toString().trim() ?? '',
          seca: row['seca']?.toString().trim() ?? '',
          sessionId: row['session_id']?.toString().trim() ?? '',
        ),
      for (final row in results[1])
        if (SupportModuleCatalog.byKey(row['module_key']?.toString() ?? '')
            case final module?)
          PendingService(
            esCalibracion: false,
            servicio: module.serviceName,
            codMetrica: row['cod_metrica']?.toString().trim() ?? '',
            cliente: row['cliente_nombre']?.toString().trim() ?? '',
            seca: row['otst']?.toString().trim() ?? '',
            sessionId: row['session_id']?.toString().trim() ?? '',
          ),
    ];
  }

  /// Servicios hechos (para el resumen) y terminados sin subir, con las mismas
  /// reglas que usan el inicio y la pantalla de subida.
  Future<_Servicios> _servicios() async {
    final dashboard = await HomeDashboardService().load();

    final calibraciones = <DateTime>[];
    for (final group in dashboard.calibrationServices) {
      for (final row in group.items) {
        if (row['estado_servicio_bal']?.toString() != 'Balanza Calibrada') {
          continue;
        }
        final fecha = parseServiceDate(row['fecha_servicio']);
        if (fecha != null) calibraciones.add(fecha);
      }
    }

    final completos = [
      for (final group in dashboard.supportServiceGroups)
        ...group.items.where(isSupportRecordComplete),
    ];
    final soportes = [
      for (final row in completos)
        if (parseServiceDate(row['fecha_servicio'] ?? row['updated_at'])
            case final fecha?)
          fecha,
    ];

    // Sin close(): sqflite comparte la conexión con la pantalla de subida si
    // está abierta, y cerrarla aquí la dejaría sin base.
    final uploaded = await SupportUploadStatusService().uploadedLogicalKeys();
    final pendientes = deduplicateUploadRecords(
      completos.where(
        (row) => !uploaded.contains(supportUploadLogicalKey(row)),
      ),
      supportUploadLogicalKey,
    );
    return _Servicios(
      subidasCalibracion: dashboard.pendingUploads,
      subidasSoporte: pendientes.records.length,
      calibraciones: calibraciones,
      soportes: soportes,
    );
  }

  /// La descarga guarda la fecha en preferencias; si falta (bases importadas
  /// de un respaldo) se usa la fecha del archivo, como en el inicio.
  Future<DateTime?> _ultimaPrecarga(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = DateTime.tryParse(prefs.getString('lastUpdate') ?? '');
    if (saved != null) return saved;
    if (!await databaseExists(path)) return null;
    return File(path).lastModified();
  }

  static Future<T> _safe<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (error) {
      debugPrint('Notificaciones: no se pudo leer una fuente: $error');
      return fallback;
    }
  }
}

class _Servicios {
  final int subidasCalibracion;
  final int subidasSoporte;
  final List<DateTime> calibraciones;
  final List<DateTime> soportes;

  const _Servicios({
    this.subidasCalibracion = 0,
    this.subidasSoporte = 0,
    this.calibraciones = const [],
    this.soportes = const [],
  });
}
