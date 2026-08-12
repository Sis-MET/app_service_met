import 'package:shared_preferences/shared_preferences.dart';

import '../../../database/soporte_tecnico/database_helper_ajustes.dart';
import '../../../database/soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import '../../../database/soporte_tecnico/database_helper_instalacion.dart';
import '../../../database/soporte_tecnico/database_helper_mnt_prv_avanzado_stac.dart';
import '../../../database/soporte_tecnico/database_helper_mnt_prv_regular_stil.dart';
import '../../../database/soporte_tecnico/database_helper_relevamiento.dart';
import '../../../database/soporte_tecnico/database_helper_verificaciones.dart';
import '../database/database_helper_soporte.dart';
import '../utils/support_module_catalog.dart';

class SupportLegacyRecoveryService {
  static const _migrationKey = 'support_recovery_index_version';
  static const _migrationVersion = 1;

  final DatabaseHelperSoporte _statusDb;

  SupportLegacyRecoveryService({DatabaseHelperSoporte? statusDb})
      : _statusDb = statusDb ?? DatabaseHelperSoporte();

  Future<void> migrateOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(_migrationKey) ?? 0) >= _migrationVersion) return;

    await _migrateRows(
      SupportModuleCatalog.ajustes,
      await DatabaseHelperAjustes().getAllRegistrosRelevamiento(),
    );
    final diagnosticoDb = DatabaseHelperDiagnosticoCorrectivo();
    await _migrateRows(
      SupportModuleCatalog.correctivo,
      await diagnosticoDb.getAllRegistrosRelevamiento(),
    );
    await _migrateRows(
      SupportModuleCatalog.diagnostico,
      await diagnosticoDb.getAllRegistrosDiagnostico(),
      diagnostico: true,
    );
    await _migrateRows(
      SupportModuleCatalog.instalacion,
      await DatabaseHelperInstalacion().getAllRegistrosRelevamiento(),
    );
    await _migrateRows(
      SupportModuleCatalog.avanzado,
      await DatabaseHelperMntPrvAvanzadoStac().getAllRegistrosRelevamiento(),
    );
    await _migrateRows(
      SupportModuleCatalog.regular,
      await DatabaseHelperMntPrvRegularStil().getAllRegistrosRelevamiento(),
    );
    await _migrateRows(
      SupportModuleCatalog.relevamiento,
      await DatabaseHelperRelevamiento().getAllRegistrosRelevamiento(),
      relevamiento: true,
    );
    await _migrateRows(
      SupportModuleCatalog.verificaciones,
      await DatabaseHelperVerificaciones().getAllRegistrosRelevamiento(),
    );

    await prefs.setInt(_migrationKey, _migrationVersion);
  }

  Future<void> _migrateRows(
    SupportModuleDefinition module,
    List<Map<String, dynamic>> rows, {
    bool diagnostico = false,
    bool relevamiento = false,
  }) async {
    for (final row in rows) {
      if (_isComplete(
        row,
        diagnostico: diagnostico,
        relevamiento: relevamiento,
      )) {
        continue;
      }
      final sessionId = _value(row, 'session_id');
      final otst = _value(row, 'otst');
      final personal = _value(row, 'personal');
      final codMetrica = _value(row, 'cod_metrica');
      if ([sessionId, otst, personal, codMetrica].any((v) => v.isEmpty)) {
        continue;
      }
      await _statusDb.saveSessionProgress(
        moduleKey: module.key,
        sessionId: sessionId,
        otst: otst,
        personal: personal,
        currentStep: 0,
        totalSteps: module.totalSteps,
        routeData: {
          'cliente_id': _value(row, 'cliente_id'),
          'cliente_nombre': _value(row, 'cliente'),
          'cliente_razon_social': _value(row, 'razon_social'),
          'planta_codigo': _value(row, 'cod_planta'),
          'planta_nombre': _value(row, 'planta'),
          'planta_direccion': _value(row, 'dir_planta'),
          'planta_departamento': _value(row, 'dep_planta'),
          'cod_metrica': codMetrica,
          'n_reca': _value(row, 'n_reca'),
          'instrumento_data': row,
        },
      );
    }
  }

  bool _isComplete(
    Map<String, dynamic> row, {
    required bool diagnostico,
    required bool relevamiento,
  }) {
    final estado = _value(row, 'estado_servicio').toLowerCase();
    if (estado == 'completo') return true;
    if (relevamiento && estado == 'balanza realizada') return true;
    if (!diagnostico) return false;
    return _value(row, 'reporte').isNotEmpty &&
        _value(row, 'evaluacion').isNotEmpty &&
        _value(row, 'comentario_general').isNotEmpty &&
        _value(row, 'hora_fin').isNotEmpty;
  }

  String _value(Map<String, dynamic> row, String key) =>
      row[key]?.toString().trim() ?? '';
}
