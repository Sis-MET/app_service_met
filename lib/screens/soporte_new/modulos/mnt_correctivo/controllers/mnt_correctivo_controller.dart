import 'dart:convert';

import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import '../models/mnt_correctivo_model.dart';

class MntCorrectivoController extends BaseSoporteController {
  @override
  String get tableName => 'mnt_correctivo';

  @override
  String get tipoServicio => 'MANTENIMIENTO CORRECTIVO';

  final MntCorrectivoModel _model;

  @override
  BaseSoporteModel get model => _model;

  String reporteFalla = '';
  String trabajoRealizado = '';
  String repuestosUtilizados = '';

  MntCorrectivoController({required MntCorrectivoModel model}) : _model = model {
    totalSteps = 3;
  }

  void initCamposEstado() {
    camposEstado.addAll([
      CampoEstado(nombre: 'Estructura general'),
      CampoEstado(nombre: 'Plataforma de carga'),
      CampoEstado(nombre: 'Indicador'),
      CampoEstado(nombre: 'Celdas de carga'),
      CampoEstado(nombre: 'Cableado eléctrico'),
      CampoEstado(nombre: 'Conexiones'),
      CampoEstado(nombre: 'Nivelación'),
      CampoEstado(nombre: 'Protecciones'),
      CampoEstado(nombre: 'Limpieza'),
      CampoEstado(nombre: 'Tornillería'),
      CampoEstado(nombre: 'Fallas encontradas'),
      CampoEstado(nombre: 'Componentes reemplazados'),
      CampoEstado(nombre: 'Ajustes realizados'),
    ]);
  }

  @override
  Future<Map<String, dynamic>> buildDataMap() async {
    final map = {
      'comentario_general': comentarioGeneral,
      'recomendacion': recomendacion,
      'estado_fisico': estadoFisico,
      'estado_operacional': estadoOperacional,
      'estado_metrologico': estadoMetrologico,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'fecha_prox_servicio': fechaProxServicio,
      'pruebas_finales': jsonEncode(pruebasFinales.toMap()),
      'reporte_falla': reporteFalla,
      'trabajo_realizado': trabajoRealizado,
      'repuestos_utilizados': repuestosUtilizados,
    };
    if (camposEstado.isNotEmpty) {
      map['campos_estado'] = jsonEncode(camposEstado.map((c) => {
        'nombre': c.nombre,
        'value': c.value,
        'solutionValue': c.solutionValue,
      }).toList());
    }
    return map;
  }

  @override
  Future<void> loadExistingSession(String sessionId, Map<String, dynamic> data) async {
    comentarioGeneral = data['comentario_general']?.toString() ?? '';
    recomendacion = data['recomendacion']?.toString() ?? '';
    estadoFisico = data['estado_fisico']?.toString() ?? '';
    estadoOperacional = data['estado_operacional']?.toString() ?? '';
    estadoMetrologico = data['estado_metrologico']?.toString() ?? '';
    horaInicio = data['hora_inicio']?.toString() ?? '';
    horaFin = data['hora_fin']?.toString() ?? '';
    fechaProxServicio = data['fecha_prox_servicio']?.toString() ?? '';
    reporteFalla = data['reporte_falla']?.toString() ?? '';
    trabajoRealizado = data['trabajo_realizado']?.toString() ?? '';
    repuestosUtilizados = data['repuestos_utilizados']?.toString() ?? '';

    if (data['pruebas_finales'] != null) {
      try {
        final pf = jsonDecode(data['pruebas_finales']);
        pruebasFinales = PruebasMetrologicas(
          excentricidad: (pf['excentricidad'] as List).map((e) => Excentricidad(
            posicion: e['posicion'] ?? '', carga: e['carga'] ?? '',
            indicacion1: e['indicacion1'] ?? '', indicacion2: e['indicacion2'] ?? '',
            indicacion3: e['indicacion3'] ?? '', diferencia: e['diferencia'] ?? '',
            error: e['error'] ?? '', errorMaximo: e['errorMaximo'] ?? '',
          )).toList(),
          repetibilidad: (pf['repetibilidad'] as List).map((r) => Repetibilidad(
            carga: r['carga'] ?? '', indicacion1: r['indicacion1'] ?? '',
            indicacion2: r['indicacion2'] ?? '', indicacion3: r['indicacion3'] ?? '',
            diferencia: r['diferencia'] ?? '', errorMaximo: r['errorMaximo'] ?? '',
          )).toList(),
          linealidad: (pf['linealidad'] as List).map((l) => Linealidad(
            carga: l['carga'] ?? '', indicacion1: l['indicacion1'] ?? '',
            indicacion2: l['indicacion2'] ?? '', error: l['error'] ?? '',
            errorMaximo: l['errorMaximo'] ?? '', incertidumbre: l['incertidumbre'] ?? '',
          )).toList(),
        );
      } catch (_) {}
    }

    if (data['campos_estado'] != null) {
      try {
        final decoded = jsonDecode(data['campos_estado']);
        for (int i = 0; i < decoded.length && i < camposEstado.length; i++) {
          camposEstado[i].value = decoded[i]['value'] ?? '';
          camposEstado[i].solutionValue = decoded[i]['solutionValue'] ?? 'No aplica';
        }
      } catch (_) {}
    }
    notifyListeners();
  }
}
