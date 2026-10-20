import 'package:service_met/models/service_session.dart' as session;
import 'package:service_met/screens/soporte_new/utils/pruebas_omitidas.dart';

/// Las tres pruebas iniciales leídas de la tabla, y si cada una se hizo.
typedef PruebasIniciales = ({
  session.ExcentricidadData excentricidad,
  bool excentricidadRealizada,
  session.RepetibilidadData repetibilidad,
  bool repetibilidadRealizada,
  session.LinealidadData linealidad,
  bool linealidadRealizada,
});

/// Pruebas iniciales en las columnas planas de la tabla del módulo, las que
/// sube el servidor: `posicion_inicial_1`, `indicacion1_inicial_3`,
/// `lin_inicial_12`... Las usan Instalación y Verificaciones internas, que
/// tienen las mismas columnas.
abstract final class PruebasInicialesColumnas {
  static const _posiciones = 12;
  static const _posicionesConNumero = 6;
  static const _mediciones = 10;
  static const _filas = 12;

  /// Escribe las tres pruebas en [data]. Las casillas que la prueba no usa, y
  /// las de una prueba no realizada, quedan vacías: no se conservan valores
  /// de filas que el técnico quitó.
  static void escribir(
    Map<String, dynamic> data, {
    required session.ExcentricidadData excentricidad,
    required bool excentricidadRealizada,
    required session.RepetibilidadData repetibilidad,
    required bool repetibilidadRealizada,
    required session.LinealidadData linealidad,
    required bool linealidadRealizada,
  }) {
    data['tipo_plataforma_inicial'] = '';
    data['puntos_ind_inicial'] = '';
    data['carga_exc_inicial'] = '';
    data['repetibilidad1_inicial'] = '';
    data['linealidad_inicial_cantidad_puntos'] = 0;
    for (var i = 1; i <= _posiciones; i++) {
      if (i <= _posicionesConNumero) data['posicion_inicial_$i'] = '';
      data['indicacion_inicial_$i'] = '';
      data['retorno_inicial_$i'] = '';
    }
    for (var i = 1; i <= _mediciones; i++) {
      data['indicacion1_inicial_$i'] = '';
      data['retorno1_inicial_$i'] = '';
    }
    for (var i = 1; i <= _filas; i++) {
      data['lin_inicial_$i'] = '';
      data['ind_inicial_$i'] = '';
      data['retorno_lin_inicial_$i'] = '';
    }

    data[PruebasOmitidas.columna] = PruebasOmitidas.escribir((
      excentricidad: excentricidadRealizada,
      repetibilidad: repetibilidadRealizada,
      linealidad: linealidadRealizada,
    ));

    if (excentricidadRealizada) {
      data['tipo_plataforma_inicial'] = excentricidad.tipoPlataforma ?? '';
      data['puntos_ind_inicial'] = excentricidad.puntosIndicacion ?? '';
      data['carga_exc_inicial'] = excentricidad.carga ?? '';
      for (var i = 0;
          i < excentricidad.posiciones.length && i < _posiciones;
          i++) {
        final posicion = excentricidad.posiciones[i];
        final number = i + 1;
        if (number <= _posicionesConNumero) {
          data['posicion_inicial_$number'] = posicion.posicion ?? '';
        }
        data['indicacion_inicial_$number'] = posicion.indicacion ?? '';
        data['retorno_inicial_$number'] = posicion.retorno ?? '';
      }
    }

    if (repetibilidadRealizada && repetibilidad.cargas.isNotEmpty) {
      final carga = repetibilidad.cargas.first;
      data['repetibilidad1_inicial'] = carga.carga ?? '';
      for (var i = 0; i < carga.indicaciones.length && i < _mediciones; i++) {
        final number = i + 1;
        data['indicacion1_inicial_$number'] = carga.indicaciones[i] ?? '';
        data['retorno1_inicial_$number'] =
            i < carga.retornos.length ? carga.retornos[i] ?? '' : '';
      }
    }

    if (linealidadRealizada) {
      data['linealidad_inicial_cantidad_puntos'] =
          linealidad.filas.length.clamp(0, _filas);
      for (var i = 0; i < linealidad.filas.length && i < _filas; i++) {
        final fila = linealidad.filas[i];
        final number = i + 1;
        data['lin_inicial_$number'] = fila.carga ?? '';
        data['ind_inicial_$number'] = fila.indicacion ?? '';
        data['retorno_lin_inicial_$number'] = fila.retorno ?? '';
      }
    }
  }

  /// Lee las tres pruebas de [row]. Si se hizo cada una lo dice
  /// [PruebasOmitidas]; en un registro anterior a esa columna, una prueba
  /// cuenta como realizada si quedó algún dato de ella.
  static PruebasIniciales leer(Map<String, dynamic> row) {
    String texto(String column) => row[column]?.toString() ?? '';

    final posiciones = <session.PosicionData>[];
    for (var i = 1; i <= _posiciones; i++) {
      final posicion =
          i <= _posicionesConNumero ? texto('posicion_inicial_$i') : '';
      final indicacion = texto('indicacion_inicial_$i');
      final retorno = texto('retorno_inicial_$i');
      if (posicion.isEmpty && indicacion.isEmpty && retorno.isEmpty) continue;
      posiciones.add(session.PosicionData(
        posicion: posicion,
        indicacion: indicacion,
        retorno: retorno,
      ));
    }
    final excentricidad = session.ExcentricidadData(
      tipoPlataforma: row['tipo_plataforma_inicial']?.toString(),
      puntosIndicacion: row['puntos_ind_inicial']?.toString(),
      carga: row['carga_exc_inicial']?.toString(),
      posiciones: posiciones,
    );

    // Hasta la última lectura escrita: antes volvían siempre las diez y una
    // prueba de 3 mediciones pedía 7 más para avanzar.
    final cargaRepetibilidad = texto('repetibilidad1_inicial');
    var ultimaLectura = 0;
    for (var i = 1; i <= _mediciones; i++) {
      if (texto('indicacion1_inicial_$i').isNotEmpty ||
          texto('retorno1_inicial_$i').isNotEmpty) {
        ultimaLectura = i;
      }
    }
    final indicaciones = <String?>[
      for (var i = 1; i <= ultimaLectura; i++) texto('indicacion1_inicial_$i'),
    ];
    final retornos = <String?>[
      for (var i = 1; i <= ultimaLectura; i++) texto('retorno1_inicial_$i'),
    ];
    final tieneRepetibilidad =
        cargaRepetibilidad.isNotEmpty || ultimaLectura > 0;

    final filas = <session.FilaLinealidad>[];
    for (var i = 1; i <= _filas; i++) {
      final carga = texto('lin_inicial_$i');
      final indicacion = texto('ind_inicial_$i');
      final retorno = texto('retorno_lin_inicial_$i');
      if (carga.isEmpty && indicacion.isEmpty && retorno.isEmpty) continue;
      filas.add(session.FilaLinealidad(
        carga: carga,
        indicacion: indicacion,
        retorno: retorno,
      ));
    }

    final realizadas = PruebasOmitidas.leer(row);
    return (
      excentricidad: excentricidad,
      excentricidadRealizada: realizadas?.excentricidad ??
          (posiciones.isNotEmpty ||
              (excentricidad.tipoPlataforma?.isNotEmpty ?? false) ||
              (excentricidad.carga?.isNotEmpty ?? false)),
      repetibilidad: session.RepetibilidadData(
        cargas: tieneRepetibilidad
            ? [
                session.CargaRepetibilidad(
                  carga: cargaRepetibilidad,
                  indicaciones: indicaciones,
                  retornos: retornos,
                ),
              ]
            : const [],
      ),
      repetibilidadRealizada: realizadas?.repetibilidad ?? tieneRepetibilidad,
      linealidad: session.LinealidadData(filas: filas),
      linealidadRealizada: realizadas?.linealidad ?? filas.isNotEmpty,
    );
  }
}
