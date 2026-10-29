import 'dart:math' as math;

/// Las horas de las lecturas de un punto: la lectura 0 en [inicio] y una
/// cada [intervalo], hasta completar [lecturas].
///
/// Cada lectura tiene dos plazos:
/// * la **ventana** en la que la cámara intenta leerla (la mitad del
///   intervalo, entre 2 y 10 segundos), y
/// * el **límite** hasta el que el técnico puede escribirla a mano si la
///   cámara no pudo: la hora de la siguiente. Pasado el límite, la lectura
///   queda «sin lectura».
class MedicionProgramada {
  MedicionProgramada({
    required this.inicio,
    required this.intervalo,
    required this.lecturas,
  }) : assert(intervalo > Duration.zero && lecturas > 0);

  final DateTime inicio;
  final Duration intervalo;
  final int lecturas;

  Duration get ventana {
    final mitad = intervalo.inMilliseconds ~/ 2;
    return Duration(milliseconds: math.max(2000, math.min(10000, mitad)));
  }

  DateTime horaDe(int n) => inicio.add(intervalo * n);

  /// Segundos desde el inicio de la lectura [n].
  int segundosDe(int n) => (intervalo.inMilliseconds * n / 1000).round();

  /// Hora de la última lectura.
  DateTime get ultima => horaDe(lecturas - 1);

  /// Hasta cuándo se acepta la lectura [n].
  DateTime limiteDe(int n) => horaDe(n + 1);

  /// La lectura cuya hora ya llegó y sigue abierta a [ahora]; null antes de
  /// la primera o después del límite de la última.
  int? actual(DateTime ahora) {
    final transcurrido = ahora.difference(inicio);
    if (transcurrido.isNegative) return null;
    final n = transcurrido.inMilliseconds ~/ intervalo.inMilliseconds;
    return n >= lecturas ? null : n;
  }

  /// Si [ahora] está dentro de la ventana de la cámara de la lectura [n].
  bool enVentana(int n, DateTime ahora) {
    final hora = horaDe(n);
    return !ahora.isBefore(hora) && ahora.isBefore(hora.add(ventana));
  }

  /// Las lecturas cuyo límite ya pasó a [ahora] y que no están en [hechas].
  List<int> vencidas(DateTime ahora, Set<int> hechas) => [
        for (var n = 0; n < lecturas; n++)
          if (!hechas.contains(n) && !ahora.isBefore(limiteDe(n))) n,
      ];

  /// Ya no queda ninguna lectura por tomar.
  bool terminada(DateTime ahora, Set<int> hechas) =>
      hechas.length >= lecturas || !ahora.isBefore(limiteDe(lecturas - 1));

  /// Cuánto falta para la próxima lectura; null si no queda ninguna.
  Duration? hastaLaProxima(DateTime ahora) {
    final transcurrido = ahora.difference(inicio);
    if (transcurrido.isNegative) return -transcurrido;
    final siguiente =
        transcurrido.inMilliseconds ~/ intervalo.inMilliseconds + 1;
    if (siguiente >= lecturas) return null;
    return horaDe(siguiente).difference(ahora);
  }
}
