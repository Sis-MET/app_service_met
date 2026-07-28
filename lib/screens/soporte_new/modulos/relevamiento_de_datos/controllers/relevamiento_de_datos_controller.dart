import 'dart:convert';

import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/models/relevamiento_de_datos_model.dart';

class RelevamientoDeDatosController extends BaseSoporteController {
  @override
  String get tableName => 'relevamiento_datos';

  @override
  String get tipoServicio => 'RELEVAMIENTO DE DATOS';

  @override
  final RelevamientoDeDatosModel model;

  String temperatura = '';
  String humedad = '';
  String presion = '';

  RelevamientoDeDatosController({required this.model}) {
    totalSteps = 4;
  }

  void initCamposEstado() {
    camposEstado.clear();
    camposEstado.addAll([
      CampoEstado(nombre: 'Terminal - Estado Físico'),
      CampoEstado(nombre: 'Terminal - Pantalla'),
      CampoEstado(nombre: 'Terminal - Teclado'),
      CampoEstado(nombre: 'Terminal - Conexiones'),
      CampoEstado(nombre: 'Terminal - Fuente de Poder'),
      CampoEstado(nombre: 'Plataforma - Estado Físico'),
      CampoEstado(nombre: 'Plataforma - Cables'),
      CampoEstado(nombre: 'Plataforma - Conectores'),
      CampoEstado(nombre: 'Plataforma - Sensores'),
      CampoEstado(nombre: 'Celdas - Estado Físico'),
      CampoEstado(nombre: 'Celdas - Conexiones Eléctricas'),
      CampoEstado(nombre: 'Celdas - Aislamiento'),
      CampoEstado(nombre: 'Celdas - Sellos'),
      CampoEstado(nombre: 'Celdas - Protección Mecánica'),
      CampoEstado(nombre: 'Celdas - Cableado'),
    ]);
  }

  void setTemperatura(String v) {
    temperatura = v;
    markChanged();
  }

  void setHumedad(String v) {
    humedad = v;
    markChanged();
  }

  void setPresion(String v) {
    presion = v;
    markChanged();
  }

  @override
  Future<Map<String, dynamic>> buildDataMap() async {
    final map = await super.buildDataMap();
    map.addAll({
      'temperatura': temperatura,
      'humedad': humedad,
      'presion': presion,
      'campos_estado': jsonEncode(
        camposEstado
            .map((c) => {
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                })
            .toList(),
      ),
    });
    return map;
  }

  @override
  Future<void> loadExistingSession(String sessionId, Map<String, dynamic> data) async {
    await super.loadExistingSession(sessionId, data);
    temperatura = data['temperatura']?.toString() ?? '';
    humedad = data['humedad']?.toString() ?? '';
    presion = data['presion']?.toString() ?? '';
    if (data['campos_estado'] != null) {
      try {
        final list = jsonDecode(data['campos_estado']) as List;
        camposEstado.clear();
        for (final item in list) {
          camposEstado.add(CampoEstado(
            nombre: item['nombre'] ?? '',
            value: item['value'] ?? '',
            solutionValue: item['solutionValue'] ?? 'No aplica',
            solutionLabel: item['solutionLabel'] ?? '',
            fotos: (item['fotos'] as List?)?.cast<String>() ?? [],
          ));
        }
      } catch (_) {}
    }
    notifyListeners();
  }
}
