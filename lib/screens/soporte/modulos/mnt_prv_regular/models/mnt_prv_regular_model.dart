import 'dart:io';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte/models/campo_estado.dart';

class MntPrvRegularModel implements BaseSoporteModel {
  @override final String codMetrica;
  @override final String sessionId;
  @override final String secaValue;

  Map<String, CampoEstado> camposEstado;
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

  @override Map<String, List<File>> fieldPhotos = {};

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
    if (fieldPhotos.containsKey(field)) {
      fieldPhotos[field]!.clear();
    }
  }

  MntPrvRegularModel({
    required this.codMetrica,
    required this.sessionId,
    required this.secaValue,
    required this.camposEstado,
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
  })  : pruebasIniciales = pruebasIniciales ?? PruebasMetrologicas(),
        pruebasFinales = pruebasFinales ?? PruebasMetrologicas();

  void copiarPruebasInicialesAFinales() {
    pruebasFinales = PruebasMetrologicas.fromOther(pruebasIniciales);
  }
}
