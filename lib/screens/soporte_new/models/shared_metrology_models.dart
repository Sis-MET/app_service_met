import 'dart:convert';

class PruebasMetrologicas {
  List<Excentricidad> excentricidad;
  List<Repetibilidad> repetibilidad;
  List<Linealidad> linealidad;

  PruebasMetrologicas({
    List<Excentricidad>? excentricidad,
    List<Repetibilidad>? repetibilidad,
    List<Linealidad>? linealidad,
  })  : excentricidad = excentricidad ?? [Excentricidad(), Excentricidad(), Excentricidad(), Excentricidad(), Excentricidad()],
        repetibilidad = repetibilidad ?? [Repetibilidad(), Repetibilidad(), Repetibilidad()],
        linealidad = linealidad ?? [Linealidad(), Linealidad(), Linealidad(), Linealidad(), Linealidad()];

  PruebasMetrologicas.fromOther(PruebasMetrologicas other)
      : excentricidad = other.excentricidad.map((e) => Excentricidad.fromOther(e)).toList(),
        repetibilidad = other.repetibilidad.map((r) => Repetibilidad.fromOther(r)).toList(),
        linealidad = other.linealidad.map((l) => Linealidad.fromOther(l)).toList();

  Map<String, dynamic> toMap() => {
        'excentricidad': jsonEncode(excentricidad.map((e) => e.toMap()).toList()),
        'repetibilidad': jsonEncode(repetibilidad.map((r) => r.toMap()).toList()),
        'linealidad': jsonEncode(linealidad.map((l) => l.toMap()).toList()),
      };
}

class Excentricidad {
  String posicion;
  String carga;
  String indicacion1;
  String indicacion2;
  String indicacion3;
  String diferencia;
  String error;
  String errorMaximo;

  Excentricidad({
    this.posicion = '',
    this.carga = '',
    this.indicacion1 = '',
    this.indicacion2 = '',
    this.indicacion3 = '',
    this.diferencia = '',
    this.error = '',
    this.errorMaximo = '',
  });

  Excentricidad.fromOther(Excentricidad other)
      : posicion = other.posicion,
        carga = other.carga,
        indicacion1 = other.indicacion1,
        indicacion2 = other.indicacion2,
        indicacion3 = other.indicacion3,
        diferencia = other.diferencia,
        error = other.error,
        errorMaximo = other.errorMaximo;

  Map<String, dynamic> toMap() => {
        'posicion': posicion,
        'carga': carga,
        'indicacion1': indicacion1,
        'indicacion2': indicacion2,
        'indicacion3': indicacion3,
        'diferencia': diferencia,
        'error': error,
        'errorMaximo': errorMaximo,
      };
}

class Repetibilidad {
  String carga;
  String indicacion1;
  String indicacion2;
  String indicacion3;
  String diferencia;
  String errorMaximo;

  Repetibilidad({
    this.carga = '',
    this.indicacion1 = '',
    this.indicacion2 = '',
    this.indicacion3 = '',
    this.diferencia = '',
    this.errorMaximo = '',
  });

  Repetibilidad.fromOther(Repetibilidad other)
      : carga = other.carga,
        indicacion1 = other.indicacion1,
        indicacion2 = other.indicacion2,
        indicacion3 = other.indicacion3,
        diferencia = other.diferencia,
        errorMaximo = other.errorMaximo;

  Map<String, dynamic> toMap() => {
        'carga': carga,
        'indicacion1': indicacion1,
        'indicacion2': indicacion2,
        'indicacion3': indicacion3,
        'diferencia': diferencia,
        'errorMaximo': errorMaximo,
      };
}

class Linealidad {
  String carga;
  String indicacion1;
  String indicacion2;
  String error;
  String errorMaximo;
  String incertidumbre;

  Linealidad({
    this.carga = '',
    this.indicacion1 = '',
    this.indicacion2 = '',
    this.error = '',
    this.errorMaximo = '',
    this.incertidumbre = '',
  });

  Linealidad.fromOther(Linealidad other)
      : carga = other.carga,
        indicacion1 = other.indicacion1,
        indicacion2 = other.indicacion2,
        error = other.error,
        errorMaximo = other.errorMaximo,
        incertidumbre = other.incertidumbre;

  Map<String, dynamic> toMap() => {
        'carga': carga,
        'indicacion1': indicacion1,
        'indicacion2': indicacion2,
        'error': error,
        'errorMaximo': errorMaximo,
        'incertidumbre': incertidumbre,
      };
}
