import 'dart:convert';

import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/models/mnt_prv_avanzado_model.dart';

class MntPrvAvanzadoController extends BaseSoporteController {
  @override
  String get tableName => 'mnt_prv_avanzado';

  @override
  String get tipoServicio => 'MNT PREVENTIVO AVANZADO';

  @override
  final MntPrvAvanzadoModel model;

  final List<CampoEstado> camposLozas = [];
  final List<CampoEstado> camposLimpieza = [];
  final List<CampoEstado> camposChequeo = [];
  final List<CampoEstado> camposElectricas = [];

  MntPrvAvanzadoController({required this.model}) {
    totalSteps = 7;
  }

  void initCamposEstado() {
    camposLozas.clear();
    camposLozas.addAll([
      CampoEstado(nombre: 'Loza - Estado Superficial'),
      CampoEstado(nombre: 'Loza - Grietas'),
      CampoEstado(nombre: 'Loza - Nivelación'),
      CampoEstado(nombre: 'Loza - Drenaje'),
      CampoEstado(nombre: 'Loza - Bordes'),
    ]);

    camposLimpieza.clear();
    camposLimpieza.addAll([
      CampoEstado(nombre: 'Limpieza - Plataforma'),
      CampoEstado(nombre: 'Limpieza - Celdas'),
      CampoEstado(nombre: 'Limpieza - Terminal'),
      CampoEstado(nombre: 'Limpieza - Caja Sumadora'),
      CampoEstado(nombre: 'Limpieza - Área Circundante'),
    ]);

    camposChequeo.clear();
    camposChequeo.addAll([
      CampoEstado(nombre: 'Chequeo - Tornillería'),
      CampoEstado(nombre: 'Chequeo - Conexiones Eléctricas'),
      CampoEstado(nombre: 'Chequeo - Cableado'),
      CampoEstado(nombre: 'Chequeo - Sellos'),
      CampoEstado(nombre: 'Chequeo - Protecciones'),
      CampoEstado(nombre: 'Chequeo - Puesta a Tierra'),
      CampoEstado(nombre: 'Chequeo - Sensores'),
      CampoEstado(nombre: 'Chequeo - Actuadores'),
    ]);

    camposElectricas.clear();
    camposElectricas.addAll([
      CampoEstado(nombre: 'Eléctricas - Tablero General'),
      CampoEstado(nombre: 'Eléctricas - Protecciones'),
      CampoEstado(nombre: 'Eléctricas - Cableado'),
      CampoEstado(nombre: 'Eléctricas - Borneras'),
      CampoEstado(nombre: 'Eléctricas - Fuente de Alimentación'),
      CampoEstado(nombre: 'Eléctricas - Puesta a Tierra'),
      CampoEstado(nombre: 'Eléctricas - Aislamiento'),
    ]);
  }

  @override
  Future<Map<String, dynamic>> buildDataMap() async {
    final map = await super.buildDataMap();
    map.addAll({
      'campos_lozas': jsonEncode(
        camposLozas
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
      'campos_limpieza': jsonEncode(
        camposLimpieza
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
      'campos_chequeo': jsonEncode(
        camposChequeo
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
      'campos_electricas': jsonEncode(
        camposElectricas
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
    });
    return map;
  }

  void _loadCamposFromJson(List<CampoEstado> target, dynamic json) {
    if (json == null) return;
    try {
      final list = jsonDecode(json) as List;
      target.clear();
      for (final item in list) {
        target.add(CampoEstado(
          nombre: item['nombre'] ?? '',
          value: item['value'] ?? '',
          solutionValue: item['solutionValue'] ?? 'No aplica',
          solutionLabel: item['solutionLabel'] ?? '',
          fotos: (item['fotos'] as List?)?.cast<String>() ?? [],
        ));
      }
    } catch (_) {}
  }

  @override
  Future<void> loadExistingSession(String sessionId, Map<String, dynamic> data) async {
    await super.loadExistingSession(sessionId, data);
    _loadCamposFromJson(camposLozas, data['campos_lozas']);
    _loadCamposFromJson(camposLimpieza, data['campos_limpieza']);
    _loadCamposFromJson(camposChequeo, data['campos_chequeo']);
    _loadCamposFromJson(camposElectricas, data['campos_electricas']);
    notifyListeners();
  }
}
