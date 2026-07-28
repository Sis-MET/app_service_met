import 'dart:convert';
import 'dart:io';

import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';

class MntCorrectivoModel implements BaseSoporteModel {
  @override
  String sessionId;
  @override
  String codMetrica;
  String secaValue;
  List<CampoEstado> camposEstado;
  PruebasMetrologicas pruebasFinales;
  String comentarioGeneral;
  String recomendacion;
  String estadoFisico;
  String estadoOperacional;
  String estadoMetrologico;
  String horaInicio;
  String horaFin;
  String fechaProxServicio;
  String reporteFalla;
  String trabajoRealizado;
  String repuestosUtilizados;

  @override
  Map<String, List<File>> fieldPhotos = {};

  MntCorrectivoModel({
    required this.sessionId,
    required this.codMetrica,
    this.secaValue = '',
    List<CampoEstado>? camposEstado,
    PruebasMetrologicas? pruebasFinales,
    this.comentarioGeneral = '',
    this.recomendacion = '',
    this.estadoFisico = '',
    this.estadoOperacional = '',
    this.estadoMetrologico = '',
    this.horaInicio = '',
    this.horaFin = '',
    this.fechaProxServicio = '',
    this.reporteFalla = '',
    this.trabajoRealizado = '',
    this.repuestosUtilizados = '',
  })  : camposEstado = camposEstado ?? [],
        pruebasFinales = pruebasFinales ?? PruebasMetrologicas();

  @override
  Map<String, dynamic> toMap() => {
        'session_id': sessionId,
        'cod_metrica': codMetrica,
        'seca_value': secaValue,
        'campos_estado': jsonEncode(camposEstado.map((c) => {
              'nombre': c.nombre,
              'value': c.value,
              'solutionValue': c.solutionValue,
            }).toList()),
        'pruebas_finales': jsonEncode(pruebasFinales.toMap()),
        'comentario_general': comentarioGeneral,
        'recomendacion': recomendacion,
        'estado_fisico': estadoFisico,
        'estado_operacional': estadoOperacional,
        'estado_metrologico': estadoMetrologico,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'fecha_prox_servicio': fechaProxServicio,
        'reporte_falla': reporteFalla,
        'trabajo_realizado': trabajoRealizado,
        'repuestos_utilizados': repuestosUtilizados,
      };

  @override
  void addPhoto(String field, File photo) {
    fieldPhotos.putIfAbsent(field, () => []);
    fieldPhotos[field]!.add(photo);
  }

  @override
  void removePhoto(String field, int index) {
    if (fieldPhotos.containsKey(field) && index < fieldPhotos[field]!.length) {
      fieldPhotos[field]!.removeAt(index);
    }
  }

  @override
  void clearPhotos(String field) {
    fieldPhotos[field]?.clear();
  }
}
