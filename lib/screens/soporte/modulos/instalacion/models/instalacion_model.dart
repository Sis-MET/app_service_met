import 'package:service_met/screens/soporte/models/campo_estado.dart';
import 'package:service_met/screens/soporte/models/shared_metrology_models.dart';

export 'package:service_met/screens/soporte/models/campo_estado.dart';
export 'package:service_met/screens/soporte/models/shared_metrology_models.dart';

class InstalacionModel {
  final String codMetrica;
  final String sessionId;
  final String secaValue;

  // Campos de condiciones de instalación
  Map<String, CampoEstado> camposCondiciones;

  // Pruebas metrológicas (Solo iniciales para este módulo)
  PruebasMetrologicas pruebasIniciales;

  // Comentarios adicionales (hasta 10)
  List<String?> comentariosAdicionales;

  // Datos de servicio
  String horaInicio;
  String horaFin;
  String estadoServicio;

  // NUEVOS CAMPOS (V3)
  String comentarioGeneral;
  String recomendacion;
  String fechaProxServicio;
  String estadoFisico;
  String estadoOperacional;
  String estadoMetrologico;

  InstalacionModel({
    required this.codMetrica,
    required this.sessionId,
    required this.secaValue,
    required this.camposCondiciones,
    PruebasMetrologicas? pruebasIniciales,
    List<String?>? comentariosAdicionales,
    this.horaInicio = '',
    this.horaFin = '',
    this.estadoServicio = 'Completo',
    this.comentarioGeneral = '',
    this.recomendacion = '',
    this.fechaProxServicio = '',
    this.estadoFisico = '',
    this.estadoOperacional = '',
    this.estadoMetrologico = '',
  })  : pruebasIniciales = pruebasIniciales ?? PruebasMetrologicas(),
        comentariosAdicionales =
            comentariosAdicionales ?? List.filled(10, null);

  // Método para resetear el modelo
  void reset() {
    camposCondiciones.forEach((key, value) {
      value.initialValue = ''; // Vacío por defecto
      value.solutionValue = '';
      value.comentario = '';
      value.fotos.clear();
    });

    pruebasIniciales = PruebasMetrologicas();
    comentariosAdicionales = List.filled(10, null);

    horaInicio = '';
    horaFin = '';

    comentarioGeneral = '';
    recomendacion = '';
    fechaProxServicio = '';
    estadoFisico = '';
    estadoOperacional = '';
    estadoMetrologico = '';
  }
}


