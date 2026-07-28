import 'dart:convert';
import 'dart:io';

import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';

class AjusteVerificacionesModel implements BaseSoporteModel {
  @override
  String sessionId;
  @override
  String codMetrica;
  String secaValue;
  List<CampoEstado> camposEstado;
  PruebasMetrologicas pruebasIniciales;
  PruebasMetrologicas pruebasFinales;
  String comentarioGeneral;
  String recomendacion;
  String estadoFisico;
  String estadoOperacional;
  String estadoMetrologico;
  String horaInicio;
  String horaFin;
  String fechaProxServicio;

  @override
  Map<String, List<File>> fieldPhotos = {};

  AjusteVerificacionesModel({
    required this.sessionId,
    required this.codMetrica,
    this.secaValue = '',
    List<CampoEstado>? camposEstado,
    PruebasMetrologicas? pruebasIniciales,
    PruebasMetrologicas? pruebasFinales,
    this.comentarioGeneral = '',
    this.recomendacion = '',
    this.estadoFisico = '',
    this.estadoOperacional = '',
    this.estadoMetrologico = '',
    this.horaInicio = '',
    this.horaFin = '',
    this.fechaProxServicio = '',
  })  : camposEstado = camposEstado ?? [],
        pruebasIniciales = pruebasIniciales ?? PruebasMetrologicas(),
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
        'pruebas_iniciales': jsonEncode(pruebasIniciales.toMap()),
        'pruebas_finales': jsonEncode(pruebasFinales.toMap()),
        'comentario_general': comentarioGeneral,
        'recomendacion': recomendacion,
        'estado_fisico': estadoFisico,
        'estado_operacional': estadoOperacional,
        'estado_metrologico': estadoMetrologico,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'fecha_prox_servicio': fechaProxServicio,
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

  void copiarPruebasInicialesAFinales() {
    pruebasFinales = PruebasMetrologicas.fromOther(pruebasIniciales);
  }
}
