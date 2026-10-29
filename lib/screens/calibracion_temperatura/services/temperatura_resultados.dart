import 'dart:math' as math;

import '../models/temperatura_models.dart';

/// Estadística de un canal en un punto, con las lecturas que cuentan
/// (válidas, no excluidas).
class ResumenCanal {
  const ResumenCanal({
    required this.canal,
    required this.validas,
    required this.programadas,
    this.promedio,
    this.minimo,
    this.maximo,
    this.desviacion,
  });

  final TempCanal canal;
  final int validas;
  final int programadas;
  final double? promedio;
  final double? minimo;
  final double? maximo;

  /// Desviación estándar experimental (n − 1); null con menos de 2.
  final double? desviacion;

  /// Máximo − mínimo: cuánto varió en la medición (estabilidad).
  double? get variacion =>
      minimo == null || maximo == null ? null : maximo! - minimo!;
}

/// Resultados preliminares de un punto.
class ResumenPunto {
  const ResumenPunto({
    required this.punto,
    required this.canales,
    this.patron,
    this.uniformidad,
    this.errores = const {},
    this.sinLectura = 0,
    this.excluidas = 0,
  });

  final TempPunto punto;
  final List<ResumenCanal> canales;

  /// Temperatura de referencia: el promedio de los canales del patrón.
  final double? patron;

  /// Con dos sensores del patrón o más: la mayor diferencia entre ellos en
  /// una misma lectura.
  final double? uniformidad;

  /// Error de indicación de cada canal del equipo: su promedio menos la
  /// temperatura del patrón.
  final Map<int, double> errores;
  final int sinLectura;
  final int excluidas;
}

/// Cálculos preliminares de la calibración de temperatura: sin las
/// correcciones del certificado del patrón ni la incertidumbre, que se
/// calculan en el laboratorio con las lecturas crudas. No se suben: se
/// recalculan desde las lecturas (NB/ISO/IEC 17025 7.11.6: cubiertos por
/// pruebas).
abstract final class TemperaturaResultados {
  static ResumenPunto punto(
    TempPunto punto,
    List<TempCanal> canales,
    Iterable<TempLectura> lecturas,
  ) {
    final delPunto = lecturas.where((l) => l.nPunto == punto.n).toList();
    // Los sensores que graban en su software no tienen lecturas aquí.
    final leidos = canales.where((c) => c.metodo.seLee).toList();
    final resumenes = [
      for (final canal in leidos)
        _canal(canal, punto, delPunto.where((l) => l.nCanal == canal.n)),
    ];
    final patrones = [
      for (final resumen in resumenes)
        if (resumen.canal.rol == RolCanal.patron && resumen.promedio != null)
          resumen.promedio!,
    ];
    final patron = patrones.isEmpty
        ? null
        : patrones.reduce((a, b) => a + b) / patrones.length;

    // Uniformidad: en cada lectura, la diferencia entre el sensor más
    // caliente y el más frío; se informa la mayor.
    final canalesPatron =
        leidos.where((c) => c.rol == RolCanal.patron).map((c) => c.n).toSet();
    double? uniformidad;
    if (canalesPatron.length >= 2) {
      final porLectura = <int, List<double>>{};
      for (final lectura in delPunto) {
        if (!lectura.cuenta || !canalesPatron.contains(lectura.nCanal)) {
          continue;
        }
        porLectura.putIfAbsent(lectura.nLectura, () => []).add(lectura.valor!);
      }
      for (final valores in porLectura.values) {
        if (valores.length < 2) continue;
        final diferencia = valores.reduce(math.max) - valores.reduce(math.min);
        if (uniformidad == null || diferencia > uniformidad) {
          uniformidad = diferencia;
        }
      }
    }

    return ResumenPunto(
      punto: punto,
      canales: resumenes,
      patron: patron,
      uniformidad: uniformidad,
      errores: {
        if (patron != null)
          for (final resumen in resumenes)
            if (resumen.canal.rol == RolCanal.equipo &&
                resumen.promedio != null)
              resumen.canal.n: resumen.promedio! - patron,
      },
      sinLectura:
          delPunto.where((l) => l.estado == EstadoLectura.sinLectura).length,
      excluidas:
          delPunto.where((l) => l.estado == EstadoLectura.excluida).length,
    );
  }

  static List<ResumenPunto> todos(TempPaquete paquete) => [
        for (final punto in paquete.puntos)
          if (punto.estado != EstadoPunto.pendiente)
            TemperaturaResultados.punto(
                punto, paquete.canales, paquete.lecturas),
      ];

  static ResumenCanal _canal(
    TempCanal canal,
    TempPunto punto,
    Iterable<TempLectura> lecturas,
  ) {
    final valores = [
      for (final lectura in lecturas)
        if (lectura.cuenta) lectura.valor!,
    ];
    if (valores.isEmpty) {
      return ResumenCanal(
          canal: canal, validas: 0, programadas: punto.lecturas);
    }
    final n = valores.length;
    final promedio = valores.reduce((a, b) => a + b) / n;
    double? desviacion;
    if (n >= 2) {
      var suma = 0.0;
      for (final valor in valores) {
        suma += (valor - promedio) * (valor - promedio);
      }
      desviacion = math.sqrt(suma / (n - 1));
    }
    return ResumenCanal(
      canal: canal,
      validas: n,
      programadas: punto.lecturas,
      promedio: promedio,
      minimo: valores.reduce(math.min),
      maximo: valores.reduce(math.max),
      desviacion: desviacion,
    );
  }
}
