class PruebasMetrologicas {
  RetornoCero retornoCero;
  Excentricidad? excentricidad;
  Repetibilidad? repetibilidad;
  Linealidad? linealidad;
  String pMaxBruto;
  String pMinNeto;

  PruebasMetrologicas({
    RetornoCero? retornoCero,
    this.excentricidad,
    this.repetibilidad,
    this.linealidad,
    this.pMaxBruto = '',
    this.pMinNeto = '',
  }) : retornoCero = retornoCero ?? RetornoCero();

  PruebasMetrologicas.fromOther(PruebasMetrologicas other)
      : retornoCero = RetornoCero.fromOther(other.retornoCero),
        excentricidad = other.excentricidad != null
            ? Excentricidad.fromOther(other.excentricidad!)
            : null,
        repetibilidad = other.repetibilidad != null
            ? Repetibilidad.fromOther(other.repetibilidad!)
            : null,
        linealidad = other.linealidad != null
            ? Linealidad.fromOther(other.linealidad!)
            : null,
        pMaxBruto = other.pMaxBruto,
        pMinNeto = other.pMinNeto;
}

class RetornoCero {
  String estado;
  String estabilidad;
  String valor;
  String unidad;

  RetornoCero({
    this.estado = '',
    this.estabilidad = '',
    this.valor = '',
    this.unidad = 'kg',
  });

  RetornoCero.fromOther(RetornoCero other)
      : estado = other.estado,
        estabilidad = other.estabilidad,
        valor = other.valor,
        unidad = other.unidad;
}

class Excentricidad {
  bool activo;
  String? tipoPlataforma;
  String? puntosIndicador;
  String? imagenPath;
  String carga;
  List<PosicionExcentricidad> posiciones;

  Excentricidad({
    this.activo = false,
    this.tipoPlataforma,
    this.puntosIndicador,
    this.imagenPath,
    this.carga = '',
    List<PosicionExcentricidad>? posiciones,
  }) : posiciones = posiciones ?? [];

  Excentricidad.fromOther(Excentricidad other)
      : activo = other.activo,
        tipoPlataforma = other.tipoPlataforma,
        puntosIndicador = other.puntosIndicador,
        imagenPath = other.imagenPath,
        carga = other.carga,
        posiciones = other.posiciones
            .map((pos) => PosicionExcentricidad.fromOther(pos))
            .toList();
}

class PosicionExcentricidad {
  String posicion;
  String indicacion;
  String retorno;

  PosicionExcentricidad({
    required this.posicion,
    this.indicacion = '',
    this.retorno = '0',
  });

  PosicionExcentricidad.fromOther(PosicionExcentricidad other)
      : posicion = other.posicion,
        indicacion = other.indicacion,
        retorno = other.retorno;
}

class Repetibilidad {
  bool activo;
  int cantidadCargas;
  int cantidadPruebas;
  List<CargaRepetibilidad> cargas;

  Repetibilidad({
    this.activo = false,
    this.cantidadCargas = 1,
    this.cantidadPruebas = 3,
    List<CargaRepetibilidad>? cargas,
  }) : cargas = cargas ?? [CargaRepetibilidad()];

  Repetibilidad.fromOther(Repetibilidad other)
      : activo = other.activo,
        cantidadCargas = other.cantidadCargas,
        cantidadPruebas = other.cantidadPruebas,
        cargas = other.cargas
            .map((carga) => CargaRepetibilidad.fromOther(carga))
            .toList();
}

class CargaRepetibilidad {
  String valor;
  List<PruebaRepetibilidad> pruebas;

  CargaRepetibilidad({
    this.valor = '',
    List<PruebaRepetibilidad>? pruebas,
  }) : pruebas = pruebas ?? List.generate(3, (index) => PruebaRepetibilidad());

  CargaRepetibilidad.fromOther(CargaRepetibilidad other)
      : valor = other.valor,
        pruebas = other.pruebas
            .map((prueba) => PruebaRepetibilidad.fromOther(prueba))
            .toList();
}

class PruebaRepetibilidad {
  String indicacion;
  String retorno;

  PruebaRepetibilidad({
    this.indicacion = '',
    this.retorno = '0',
  });

  PruebaRepetibilidad.fromOther(PruebaRepetibilidad other)
      : indicacion = other.indicacion,
        retorno = other.retorno;
}

class Linealidad {
  bool activo;
  String ultimaCargaLt;
  String carga;
  String incremento;

  String iLsubn;
  String lsubn;
  String io;
  String ltn;

  List<PuntoLinealidad> puntos;

  Linealidad({
    this.activo = false,
    this.ultimaCargaLt = '0',
    this.carga = '',
    this.incremento = '',
    this.iLsubn = '',
    this.lsubn = '',
    this.io = '0',
    this.ltn = '',
    List<PuntoLinealidad>? puntos,
  }) : puntos = puntos ?? [];

  Linealidad.fromOther(Linealidad other)
      : activo = other.activo,
        ultimaCargaLt = other.ultimaCargaLt,
        carga = other.carga,
        incremento = other.incremento,
        iLsubn = other.iLsubn,
        lsubn = other.lsubn,
        io = other.io,
        ltn = other.ltn,
        puntos = other.puntos
            .map((punto) => PuntoLinealidad.fromOther(punto))
            .toList();
}

class PuntoLinealidad {
  String lt;
  String indicacion;
  String retorno;

  PuntoLinealidad({
    this.lt = '',
    this.indicacion = '',
    this.retorno = '0',
  });

  PuntoLinealidad.fromOther(PuntoLinealidad other)
      : lt = other.lt,
        indicacion = other.indicacion,
        retorno = other.retorno;
}
