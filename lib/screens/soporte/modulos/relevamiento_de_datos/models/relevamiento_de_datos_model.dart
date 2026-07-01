import 'dart:io';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte/models/campo_estado.dart';
import 'package:service_met/screens/soporte/models/shared_metrology_models.dart';

export 'package:service_met/screens/soporte/models/campo_estado.dart';
export 'package:service_met/screens/soporte/models/shared_metrology_models.dart';

class RelevamientoDeDatosModel implements BaseSoporteModel {
  @override
  final String codMetrica;
  @override
  final String sessionId;
  @override
  final String secaValue;

  // Campos de estado general
  Map<String, CampoEstado> camposEstado;

  // Pruebas metrológicas FINALES únicamente (sin iniciales)
  PruebasMetrologicas pruebasFinales;

  // Estado general
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

  RelevamientoDeDatosModel({
    required this.codMetrica,
    required this.sessionId,
    required this.secaValue,
    required this.camposEstado,
    PruebasMetrologicas? pruebasFinales,
    this.comentarioGeneral = '',
    this.recomendacion = '',
    this.estadoFisico = '',
    this.estadoOperacional = '',
    this.estadoMetrologico = '',
    this.horaInicio = '',
    this.horaFin = '',
    this.fechaProxServicio = '',
  }) : pruebasFinales = pruebasFinales ?? PruebasMetrologicas();

  // Método para resetear el modelo
  void reset() {
    camposEstado.forEach((key, value) {
      value.initialValue = '';
      value.solutionValue = '';
      value.comentario = '';
      value.fotos.clear();
    });

    pruebasFinales = PruebasMetrologicas();

    comentarioGeneral = '';
    recomendacion = '';
    estadoFisico = '';
    estadoOperacional = '';
    estadoMetrologico = '';
    horaInicio = '';
    horaFin = '';
    fechaProxServicio = '';
  }

  @override
  void addPhoto(String field, File photo) {
    if (!fieldPhotos.containsKey(field)) {
      fieldPhotos[field] = [];
    }
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
    if (fieldPhotos.containsKey(field)) {
      fieldPhotos[field]!.clear();
    }
  }
}
