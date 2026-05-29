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
    return ServiceSession.fromMap(result);
  }

  Future<void> saveSession(String seca, String sessionId, ServiceSession session) async {
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

  Future<Map<String, dynamic>> getCalibrationData(String secaValue, String sessionId) async {
    final result = await _db.getRegistroBySeca(secaValue, sessionId);
    return result ?? {};
  }

  Future<void> saveCalibrationData(String secaValue, Map<String, dynamic> data) async {
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
      if (result[capKey] != null && result[capKey].toString().isNotEmpty &&
          result[dKey] != null && result[dKey].toString().isNotEmpty) {
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

    List<double> caps = dValues.keys.map((k) => double.tryParse(k) ?? 0.0).toList();
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

  Future<List<Map<String, dynamic>>> getPlantas(String clienteId) async {
    final allPlantas = await _precargaDb.getPlantas();
    return allPlantas.where((p) => p['cliente_id'] == clienteId).toList();
  }

  Future<List<Map<String, dynamic>>> getBalanzas(String? clienteCodigo, String? plantaCodigo) async {
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

  Future<Map<String, dynamic>?> getServicioAnterior(String codMetrica) async {
    final allServices = await _precargaDb.getServicios();
    try {
      return allServices.firstWhere((s) => s['cod_metrica'] == codMetrica);
    } catch (e) {
      return null;
    }
  }

  // --- Servicios incompletos ---

  Future<Map<String, dynamic>?> getServicioIncompleto(String codMetrica) async {
    return await _db.getServicioIncompletoPorCodMetrica(codMetrica);
  }

  Future<List<Map<String, dynamic>>> getServiciosIncompletos() async {
    return await _db.getAllServiciosIncompletos();
  }

  Future<bool> esServicioCompleto(String seca, String sessionId) async {
    return await _db.esServicioCompleto(seca, sessionId);
  }

  Future<void> createBackup(String testType) async {
    final mainPath = join(await getDatabasesPath(), 'metrica_service.db');
    final backupPath = join(await getDatabasesPath(), 'metrica_service_${testType}_backup.db');
    try {
       await File(mainPath).copy(backupPath);
    } catch (e) {
      // Ignorar
    }
  }
}

