import 'dart:convert';

import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/models/instalacion_model.dart';
import 'package:service_met/screens/soporte_new/utils/soporte_metrologia_utils.dart';

class InstalacionController extends BaseSoporteController {
  @override
  String get tableName => 'instalacion';

  @override
  String get tipoServicio => 'INSTALACIÓN';

  @override
  final InstalacionModel model;

  InstalacionController({required this.model}) {
    totalSteps = 3;
  }

  void initCamposEstado() {
    camposEstado.clear();
    camposEstado.addAll([
      CampoEstado(nombre: 'Base de la balanza'),
      CampoEstado(nombre: 'Nivelación'),
      CampoEstado(nombre: 'Anclajes'),
      CampoEstado(nombre: 'Conexión eléctrica'),
      CampoEstado(nombre: 'Cableado de celdas'),
      CampoEstado(nombre: 'Protección de cables'),
      CampoEstado(nombre: 'Terminal de pesaje'),
      CampoEstado(nombre: 'Conexión a tierra'),
      CampoEstado(nombre: 'Señalización'),
      CampoEstado(nombre: 'Documentación técnica'),
    ]);
  }

  double getDForCarga(String codMetrica, double carga) {
    return carga * 0.01;
  }

  double getDecimalPlaces(double dValue) {
    return dValue == 0 ? 1 : parseDouble(formatDouble(dValue));
  }

  List<String> getIndicationSuggestions(String cargaText, String currentValue) {
    return getIndicationSuggestionsForCarga(cargaText, currentValue);
  }

  @override
  Future<Map<String, dynamic>> buildDataMap() async {
    final map = await super.buildDataMap();
    map.addAll({
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
