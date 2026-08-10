import 'dart:io';
import 'package:path/path.dart';
import 'package:service_met/database/app_database.dart';
import 'package:service_met/database/precarga_bd.dart';
import 'package:service_met/models/service_session.dart';
import 'package:sqflite/sqflite.dart';

class CalibrationRepository {
  final AppDatabase _db = AppDatabase();
  final DatabaseHelperPrecarga _precargaDb = DatabaseHelperPrecarga();

  // --- Sesión de calibración ---

  Future<ServiceSession?> loadSession(String seca, String sessionId) async {
    final result = await _db.getRegistroBySeca(seca, sessionId);
    if (result == null) return null;
    final progress = await _db.getServicioStatus(seca, sessionId);
    final merged = Map<String, dynamic>.from(result);
    if (progress != null) {
      merged.addAll(progress);
    }
    return ServiceSession.fromMap(merged);
  }

  Future<void> saveSession(
      String seca, String sessionId, ServiceSession session) async {
    final Map<String, dynamic> data = session.toMap();
    data['seca'] = seca;
    data['session_id'] = sessionId;
    await _db.upsertRegistroCalibracion(data);
  }

  Future<String> generateSessionId(String seca) async {
    return await _db.generateSessionId(seca);
  }

  Future<bool> secaExists(String seca) async {
    return await _db.secaExists(seca);
  }

  // --- Legacy methods (to be removed in Phase 7) ---

  Future<Map<String, dynamic>> getCalibrationData(
      String secaValue, String sessionId) async {
    final result = await _db.getRegistroBySeca(secaValue, sessionId);
    return result ?? {};
  }

  Future<void> saveCalibrationData(
      String secaValue, Map<String, dynamic> data) async {
    final Map<String, dynamic> newData = {
      'seca': secaValue,
      ...data,
    };
    await _db.upsertRegistroCalibracion(newData);
  }

  // --- Helper - D-values ---

  Future<Map<String, double>> getDValues(String seca, String sessionId) async {
    final result = await _db.getRegistroBySeca(seca, sessionId);
    if (result == null) return {};

    Map<String, double> dValues = {};

    void addDValue(String capKey, String dKey) {
      if (result[capKey] != null &&
          result[capKey].toString().isNotEmpty &&
          result[dKey] != null &&
          result[dKey].toString().isNotEmpty) {
        double? cap = double.tryParse(result[capKey].toString());
        double? d = double.tryParse(result[dKey].toString());
        if (cap != null && d != null) {
          dValues[cap.toString()] = d;
        }
      }
    }

    addDValue('cap_max1', 'd1');
    addDValue('cap_max2', 'd2');
    addDValue('cap_max3', 'd3');

    return dValues;
  }

  double getDFromCarga(double carga, Map<String, double> dValues) {
    if (dValues.isEmpty) return 0.0;

    List<double> caps =
        dValues.keys.map((k) => double.tryParse(k) ?? 0.0).toList();
    caps.sort();

    for (double cap in caps) {
      if (carga <= cap) {
        return dValues[cap.toString()] ?? 0.0;
      }
    }

    return dValues[caps.last.toString()] ?? 0.0;
  }

  int getDecimalPlaces(double dValue) {
    String dString = dValue.toString();
    if (dString.contains('.')) {
      String fractionalPart = dString.split('.')[1];
      if (fractionalPart == '0') return 0;
      return fractionalPart.length;
    }
    return 0;
  }

  // --- Datos maestros (precarga_database.db) ---

  Future<List<Map<String, dynamic>>> getClientes() async {
    return await _precargaDb.getClientes();
  }

  Future<List<Map<String, dynamic>>> searchClientes(
    String query, {
    int limit = 50,
  }) async {
    return _precargaDb.searchClientes(query, limit: limit);
  }

  Future<List<Map<String, dynamic>>> getPlantas(String clienteId) async {
    return _precargaDb.getPlantasPorCliente(clienteId);
  }

  Future<List<Map<String, dynamic>>> getBalanzas(
      String? clienteCodigo, String? plantaCodigo) async {
    if (plantaCodigo != null && plantaCodigo.isNotEmpty) {
      String prefix;
      if (plantaCodigo.contains('-')) {
        prefix = plantaCodigo;
      } else if (clienteCodigo != null && clienteCodigo.isNotEmpty) {
        prefix = '$clienteCodigo-$plantaCodigo';
      } else {
        // Fallback si no tenemos clienteCodigo pero la planta no tiene guion
        prefix = plantaCodigo;
      }
      return await _precargaDb.getBalanzasPorPrefix(prefix);
    }
    return await _precargaDb.getBalanzas();
  }

  Future<List<Map<String, dynamic>>> getEquipos() async {
    return await _precargaDb.getEquipamientos();
  }

  /// Obtiene el último servicio registrado para un código métrica.
  /// Busca en la tabla `servicios` de la precarga con query optimizada.
  /// Retorna null si no hay servicios anteriores.
  Future<Map<String, dynamic>?> getServicioAnterior(String codMetrica) async {
    final db = await _precargaDb.database;
    final results = await db.query(
      'servicios',
      where: 'cod_metrica = ?',
      whereArgs: [codMetrica],
      orderBy: 'reg_fecha DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // --- Servicios incompletos ---

  Future<Map<String, dynamic>?> getServicioIncompleto(String codMetrica) async {
    return await _db.getServicioIncompletoPorCodMetrica(codMetrica);
  }

  /// Retorna servicios pendientes para un usuario.
  /// Busca en `servicio_status` (status=in_progress) y también
  /// registros viejos sin status que pertenezcan al usuario.
  Future<List<Map<String, dynamic>>> getServiciosIncompletos(
      String personal) async {
    return await _db.getPendingServiciosPorUsuario(personal);
  }

  Future<bool> esServicioCompleto(String seca, String sessionId) async {
    return await _db.esServicioCompleto(seca, sessionId);
  }

  Future<void> marcarBalanzaCompleta(String seca, String sessionId) async {
    await _db.marcarBalanzaCompleta(seca, sessionId);
  }

  // ─── Progreso de sesión ──────────────────────────────────────────────────

  Future<void> saveProgress({
    required String seca,
    required String sessionId,
    required String personal,
    int currentStep = 0,
    bool secaConfirmed = false,
    bool balanzaConfirmed = false,
    String status = 'in_progress',
  }) async {
    await _db.upsertServicioStatus({
      'seca': seca,
      'session_id': sessionId,
      'personal': personal,
      'current_step': currentStep,
      'seca_confirmed': secaConfirmed ? 1 : 0,
      'balanza_confirmed': balanzaConfirmed ? 1 : 0,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> loadProgress(
      String seca, String sessionId) async {
    return await _db.getServicioStatus(seca, sessionId);
  }

  Future<void> markServicioCompletado(String seca, String sessionId) async {
    await _db.markServicioCompletado(seca, sessionId);
  }

  Future<List<Map<String, dynamic>>> getRegistrosPorSeca(String seca) async {
    return await _db.getRegistrosPorSeca(seca);
  }

  Future<Map<String, Map<String, dynamic>>> getUploadStatus(String seca) {
    return _db.getCalibrationUploadStatus(seca);
  }

  Future<void> markRecordsUploaded(
    List<Map<String, dynamic>> records, {
    required String uploadedBy,
  }) {
    return _db.markCalibrationRecordsUploaded(
      records,
      uploadedBy: uploadedBy,
    );
  }

  Future<void> updateSharedExportData(
      String seca, Map<String, dynamic> values) {
    return _db.updateCalibrationRecordsBySeca(seca, values);
  }

  Future<void> finalizeCalibrationRecords({
    required String seca,
    required Iterable<String> sessionIds,
    required String nombreCsv,
    required String finalizedAt,
  }) {
    return _db.finalizeCalibrationRecords(
      seca: seca,
      sessionIds: sessionIds,
      nombreCsv: nombreCsv,
      finalizedAt: finalizedAt,
    );
  }

  Future<void> createBackup(String testType) async {
    final mainPath = join(await getDatabasesPath(), 'metrica_service.db');
    final backupPath =
        join(await getDatabasesPath(), 'metrica_service_${testType}_backup.db');
    try {
      await File(mainPath).copy(backupPath);
    } catch (e) {
      // Ignorar
    }
  }
}
