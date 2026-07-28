import 'dart:convert';

import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import '../models/ajuste_verificaciones_model.dart';

class AjusteVerificacionesController extends BaseSoporteController {
  @override
  String get tableName => 'ajuste_verificaciones';

  @override
  String get tipoServicio => 'AJUSTE DE VERIFICACIONES';

  final AjusteVerificacionesModel _model;

  @override
  BaseSoporteModel get model => _model;

  AjusteVerificacionesController({required AjusteVerificacionesModel model})
      : _model = model {
    totalSteps = 3;
  }

  void initCamposEstado() {
    camposEstado.addAll([
      CampoEstado(nombre: 'Estado general del equipo'),
      CampoEstado(nombre: 'Estado del indicador'),
      CampoEstado(nombre: 'Estado de la plataforma'),
      CampoEstado(nombre: 'Celdas de carga'),
      CampoEstado(nombre: 'Cableado'),
      CampoEstado(nombre: 'Conexiones'),
      CampoEstado(nombre: 'Nivelación'),
      CampoEstado(nombre: 'Tornillería'),
      CampoEstado(nombre: 'Protecciones'),
      CampoEstado(nombre: 'Limpieza'),
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
