import 'package:service_met/models/service_session.dart';

/// Qué les falta a las pruebas metrológicas de un paso de soporte; null si
/// están completas.
///
/// Mismas exigencias que la calibración para lo que Soporte registra: cada
/// prueba marcada como realizada, con todas sus lecturas. Una prueba que no
/// se hizo se desmarca; no se deja a medias. [momento] ("iniciales" o
/// "finales") va en el aviso.
String? faltaEnPruebas({
  required String momento,
  required bool excentricidadRealizada,
  required ExcentricidadData excentricidad,
  required bool repetibilidadRealizada,
  required RepetibilidadData repetibilidad,
  required bool linealidadRealizada,
  required LinealidadData linealidad,
}) {
  String? aviso(String prueba, String? falta) =>
      falta == null ? null : '$prueba ($momento): $falta';

  return (excentricidadRealizada
          ? aviso('Excentricidad', faltaEnExcentricidad(excentricidad))
          : null) ??
      (repetibilidadRealizada
          ? aviso('Repetibilidad', faltaEnRepetibilidad(repetibilidad))
          : null) ??
      (linealidadRealizada
          ? aviso('Linealidad', faltaEnLinealidad(linealidad))
          : null);
}

bool _vacio(String? valor) => valor == null || valor.trim().isEmpty;

/// Plataforma, puntos, posición del indicador, carga y la indicación y el
/// retorno de cada posición.
String? faltaEnExcentricidad(ExcentricidadData prueba) {
  if (_vacio(prueba.tipoPlataforma)) return 'elija el tipo de plataforma.';
  final puntos = prueba.puntosCount;
  if (puntos == null) return 'elija los puntos de indicación.';
  if (!RegExp(r'\d[FAID]$').hasMatch(prueba.puntosIndicacion?.trim() ?? '')) {
    return 'elija la posición del indicador.';
  }
  if (_vacio(prueba.carga)) return 'ingrese la carga.';
  if (prueba.posiciones.length < puntos) {
    return 'faltan posiciones: la prueba es de $puntos puntos.';
  }
  for (var i = 0; i < puntos; i++) {
    final posicion = prueba.posiciones[i];
    if (_vacio(posicion.indicacion)) {
      return 'falta la indicación de la posición ${i + 1}.';
    }
    if (_vacio(posicion.retorno)) {
      return 'falta el retorno de la posición ${i + 1}.';
    }
  }
  return null;
}

/// La carga y cada indicación con su retorno.
String? faltaEnRepetibilidad(RepetibilidadData prueba) {
  if (prueba.cargas.isEmpty) return 'ingrese la carga.';
  for (var i = 0; i < prueba.cargas.length; i++) {
    final carga = prueba.cargas[i];
    final cual = prueba.cargas.length == 1 ? '' : ' ${i + 1}';
    if (_vacio(carga.carga)) return 'ingrese la carga$cual.';
    if (carga.indicaciones.isEmpty) return 'elija el número de mediciones.';
    for (var j = 0; j < carga.indicaciones.length; j++) {
      if (_vacio(carga.indicaciones[j])) {
        return 'falta la indicación ${j + 1}$cual.';
      }
      if (j >= carga.retornos.length || _vacio(carga.retornos[j])) {
        return 'falta el retorno ${j + 1}$cual.';
      }
    }
  }
  return null;
}

/// Al menos una carga con su indicación, y ninguna fila a medias.
String? faltaEnLinealidad(LinealidadData prueba) {
  var puntos = 0;
  for (var i = 0; i < prueba.filas.length; i++) {
    final fila = prueba.filas[i];
    final tieneCarga = !_vacio(fila.carga);
    final tieneIndicacion = !_vacio(fila.indicacion);
    if (tieneCarga && !tieneIndicacion) {
      return 'falta la indicación de la carga ${i + 1}.';
    }
    if (!tieneCarga && tieneIndicacion) {
      return 'falta la carga ${i + 1}.';
    }
    if (tieneCarga) puntos++;
  }
  if (puntos == 0) return 'registre al menos una carga con su indicación.';
  return null;
}
