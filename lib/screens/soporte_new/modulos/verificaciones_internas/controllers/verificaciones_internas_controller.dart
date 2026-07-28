import 'dart:convert';

import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import '../models/verificaciones_internas_model.dart';

class VerificacionesInternasController extends BaseSoporteController {
  @override
  String get tableName => 'verificaciones_internas';

  @override
  String get tipoServicio => 'VERIFICACIONES INTERNAS';

  final VerificacionesInternasModel _model;

  @override
  BaseSoporteModel get model => _model;

  VerificacionesInternasController({required VerificacionesInternasModel model})
      : _model = model {
    totalSteps = 3;
  }

  void initCamposEstado() {
    camposEstado.addAll([
      CampoEstado(nombre: 'Estructura general'),
      CampoEstado(nombre: 'Plataforma de carga'),
      CampoEstado(nombre: 'Indicador digital'),
      CampoEstado(nombre: 'Celdas de carga'),
      CampoEstado(nombre: 'Cableado eléctrico'),
      CampoEstado(nombre: 'Conexiones eléctricas'),
      CampoEstado(nombre: 'Nivelación del equipo'),
      CampoEstado(nombre: 'Protecciones mecánicas'),
      CampoEstado(nombre: 'Pintura y acabado'),
      CampoEstado(nombre: 'Limpieza general'),
      CampoEstado(nombre: 'Tornillería y fijaciones'),
      CampoEstado(nombre: 'Juntas y sellos'),
      CampoEstado(nombre: 'Guías y rodamientos'),
      CampoEstado(nombre: 'Sistema de transmisión'),
      CampoEstado(nombre: 'Rodillos'),
      CampoEstado(nombre: 'Correas y bandas'),
      CampoEstado(nombre: 'Sistema hidráulico'),
      CampoEstado(nombre: 'Sistema neumático'),
      CampoEstado(nombre: 'Frenos y seguros'),
      CampoEstado(nombre: 'Sensores'),
      CampoEstado(nombre: 'Pantalla y display'),
      CampoEstado(nombre: 'Botones y pulsadores'),
      CampoEstado(nombre: 'Identificación y rotulado'),
    ]);
  }

  void copiarPruebasInicialesAFinales() {
    pruebasFinales = PruebasMetrologicas.fromOther(pruebasIniciales);
    markChanged();
  }

  @override
  Future<Map<String, dynamic>> buildDataMap() async {
    final map = await super.buildDataMap();
    map['campos_estado'] = jsonEncode(camposEstado.map((c) => {
      'nombre': c.nombre,
      'value': c.value,
      'solutionValue': c.solutionValue,
    }).toList());
    return map;
  }

  @override
  Future<void> loadExistingSession(String sessionId, Map<String, dynamic> data) async {
    await super.loadExistingSession(sessionId, data);
    if (data['campos_estado'] != null) {
      try {
        final decoded = jsonDecode(data['campos_estado']);
        for (int i = 0; i < decoded.length && i < camposEstado.length; i++) {
          camposEstado[i].value = decoded[i]['value'] ?? '';
          camposEstado[i].solutionValue = decoded[i]['solutionValue'] ?? 'No aplica';
        }
      } catch (_) {}
    }
  }
}
