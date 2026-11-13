import 'dart:convert';

import '../utils/fecha_iso.dart';

/// Cargas sustitutivas del ensayo de error de indicación (linealidad).
///
/// Cuando las pesas no alcanzan, se construyen cargas más grandes con
/// material de sustitución (EURAMET cg-18 v4.0, 4.3.3; Guía SIM, 4.3.3 y
/// 7.1.2.6). La carga real de cada carga sustitutiva se obtiene con la
/// indicación de la balanza y el error de una carga conocida, y se suma a
/// otra carga ya registrada:
///
///     carga sustitutiva = I(sustitutiva) − E(referencia)
///     carga resultante  = carga base + carga sustitutiva
///
/// El método declarado en el procedimiento del laboratorio (P-VMET-02-7.2)
/// decide qué filas se usan:
///
/// * **Método 1.** Cada carga sustitutiva se parece a la carga anterior y se
///   pesa sola: la referencia es la carga anterior y la base, la carga de
///   pesas. 500 kg de pesas → 500 + s₁ → 500 + s₂ (s₂ ≈ 500 + s₁) …
/// * **Método 2.** Cada carga sustitutiva se parece a la carga de pesas y se
///   pesa sola: la referencia es la carga de pesas y la base, la carga
///   anterior. 500 kg de pesas → 500 + s₁ → 500 + s₁ + s₂ …
///
/// Se guardan los datos de cada paso, no solo la carga que resulta, para que
/// DataMET+ pueda rehacer la cadena y su incertidumbre (NB/ISO/IEC 17025,
/// 7.5.1 y 7.11.2).
enum MetodoSustitucion {
  metodo1('Método 1', 'M1'),
  metodo2('Método 2', 'M2');

  const MetodoSustitucion(this.etiqueta, this.codigo);

  /// Como aparece en la pantalla y en `metodo_carga`.
  final String etiqueta;

  /// Como viaja al servidor.
  final String codigo;

  static MetodoSustitucion? deEtiqueta(String? etiqueta) {
    for (final metodo in values) {
      if (metodo.etiqueta == etiqueta) return metodo;
    }
    return null;
  }

  static MetodoSustitucion? deCodigo(String? codigo) {
    for (final metodo in values) {
      if (metodo.codigo == codigo) return metodo;
    }
    return null;
  }
}

/// Filas (índices desde 0) que el método fija para una nueva sustitución.
({int base, int referencia}) filasDelMetodo(
  MetodoSustitucion metodo, {
  required int filaPesas,
  required int filaAnterior,
}) =>
    switch (metodo) {
      MetodoSustitucion.metodo1 => (base: filaPesas, referencia: filaAnterior),
      MetodoSustitucion.metodo2 => (base: filaAnterior, referencia: filaPesas),
    };

/// Desvío de la carga sustitutiva respecto de su referencia a partir del cual
/// se avisa al técnico: su error deja de representar el de la sustitutiva.
/// Lo puede ajustar el laboratorio.
const desvioMaximoSustitucion = 0.25;

/// Un paso de sustitución: lo que se leyó y qué filas se usaron. La carga
/// que resulta se recalcula siempre con los valores vigentes de esas filas.
class PasoSustitucion {
  /// Fila de linealidad que resulta (índice desde 0).
  final int fila;
  final MetodoSustitucion metodo;

  /// Indicación con la carga sustitutiva sola sobre la balanza.
  final double indicacionSustitutiva;

  /// Fila cuyo error corrige la indicación de la carga sustitutiva.
  final int filaReferencia;

  /// Fila a la que se suma la carga sustitutiva.
  final int filaBase;

  /// Hora del teléfono al registrar el paso.
  final DateTime? registradoEn;

  const PasoSustitucion({
    required this.fila,
    required this.metodo,
    required this.indicacionSustitutiva,
    required this.filaReferencia,
    required this.filaBase,
    this.registradoEn,
  });

  Map<String, Object?> toJson() => {
        'fila': fila,
        'metodo': metodo.codigo,
        'indicacion_sustitutiva': indicacionSustitutiva,
        'fila_referencia': filaReferencia,
        'fila_base': filaBase,
        if (registradoEn != null)
          'registrado_en': fechaIsoConDesfase(registradoEn!),
      };

  static PasoSustitucion? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final fila = _entero(raw['fila']);
    final metodo = MetodoSustitucion.deCodigo(raw['metodo']?.toString());
    final indicacion = _numero(raw['indicacion_sustitutiva']);
    final referencia = _entero(raw['fila_referencia']);
    final base = _entero(raw['fila_base']);
    if (fila == null ||
        metodo == null ||
        indicacion == null ||
        referencia == null ||
        base == null ||
        referencia >= fila ||
        base >= fila ||
        referencia < 0 ||
        base < 0) {
      return null;
    }
    return PasoSustitucion(
      fila: fila,
      metodo: metodo,
      indicacionSustitutiva: indicacion,
      filaReferencia: referencia,
      filaBase: base,
      registradoEn: DateTime.tryParse(raw['registrado_en']?.toString() ?? ''),
    );
  }
}

/// Carga e indicación vigentes de una fila de linealidad.
typedef FilaCarga = ({double? carga, double? indicacion});

/// Valores con que se calcula un paso.
class ResultadoPaso {
  final double cargaReferencia;
  final double indicacionReferencia;
  final double cargaBase;
  final double indicacionSustitutiva;

  const ResultadoPaso({
    required this.cargaReferencia,
    required this.indicacionReferencia,
    required this.cargaBase,
    required this.indicacionSustitutiva,
  });

  double get errorReferencia => indicacionReferencia - cargaReferencia;
  double get cargaSustitutiva => indicacionSustitutiva - errorReferencia;
  double get cargaResultante => cargaBase + cargaSustitutiva;

  /// |I(sustitutiva) − carga de referencia| / carga de referencia.
  double? get desvio => cargaReferencia == 0
      ? null
      : (indicacionSustitutiva - cargaReferencia).abs() / cargaReferencia.abs();

  bool get fueraDeRango => (desvio ?? 0) > desvioMaximoSustitucion;
}

/// Calcula [paso] con las filas vigentes. Null si falta la carga o la
/// indicación de la referencia, o la carga de la base.
ResultadoPaso? calcularPaso(PasoSustitucion paso, List<FilaCarga> filas) {
  return calcularSustitucion(
    indicacionSustitutiva: paso.indicacionSustitutiva,
    referencia:
        paso.filaReferencia < filas.length ? filas[paso.filaReferencia] : null,
    base: paso.filaBase < filas.length ? filas[paso.filaBase] : null,
  );
}

ResultadoPaso? calcularSustitucion({
  required double indicacionSustitutiva,
  required FilaCarga? referencia,
  required FilaCarga? base,
}) {
  final cargaReferencia = referencia?.carga;
  final indicacionReferencia = referencia?.indicacion;
  final cargaBase = base?.carga;
  if (cargaReferencia == null ||
      indicacionReferencia == null ||
      cargaBase == null) {
    return null;
  }
  return ResultadoPaso(
    cargaReferencia: cargaReferencia,
    indicacionReferencia: indicacionReferencia,
    cargaBase: cargaBase,
    indicacionSustitutiva: indicacionSustitutiva,
  );
}

/// Estado de las cargas sustitutivas de una linealidad: cuántas filas se
/// validaron como cargas de pesas y los pasos de sustitución. Vive en la
/// columna local [columna] de `registros_calibracion`, como JSON; al subir
/// viaja aparte del registro (ver [pasosParaServidor]).
class SustitucionLinealidad {
  static const columna = 'linealidad_sustitucion';
  static const _version = 1;

  /// Filas de pesas validadas (las primeras). 0: sin validar.
  final int cargasPatron;
  final List<PasoSustitucion> pasos;

  const SustitucionLinealidad({this.cargasPatron = 0, this.pasos = const []});

  static const vacia = SustitucionLinealidad();

  bool get estaVacia => cargasPatron <= 0 && pasos.isEmpty;

  PasoSustitucion? pasoDeFila(int fila) {
    for (final paso in pasos) {
      if (paso.fila == fila) return paso;
    }
    return null;
  }

  /// Texto de la columna; vacío si no hay nada que guardar.
  String toColumn() => estaVacia
      ? ''
      : jsonEncode({
          'version': _version,
          'cargas_patron': cargasPatron,
          'pasos': [for (final paso in pasos) paso.toJson()],
        });

  static SustitucionLinealidad fromColumn(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return vacia;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return vacia;
      final pasos = <PasoSustitucion>[];
      final filas = <int>{};
      for (final item in decoded['pasos'] as List? ?? const []) {
        final paso = PasoSustitucion.fromJson(item);
        if (paso != null && filas.add(paso.fila)) pasos.add(paso);
      }
      pasos.sort((a, b) => a.fila.compareTo(b.fila));
      return SustitucionLinealidad(
        cargasPatron: _entero(decoded['cargas_patron']) ?? 0,
        pasos: pasos,
      );
    } on FormatException {
      return vacia;
    }
  }

  /// Pasos de un registro de `registros_calibracion` como los recibe el
  /// servidor: cada uno con los valores de sus filas al subir, para que la
  /// cadena se pueda rehacer sin la app. Filas desde 1, como `lin1`.
  static List<Map<String, Object?>> pasosParaServidor(
    Map<String, dynamic> registro,
  ) {
    final sustitucion = fromColumn(registro[columna]);
    if (sustitucion.pasos.isEmpty) return const [];
    FilaCarga fila(int indice) => (
          carga: _numero(registro['lin${indice + 1}']),
          indicacion: _numero(registro['ind${indice + 1}']),
        );
    final resultado = <Map<String, Object?>>[];
    for (final paso in sustitucion.pasos) {
      final calculo = calcularPaso(
        paso,
        [for (var i = 0; i <= paso.fila; i++) fila(i)],
      );
      final cargaResultante = _numero(registro['lin${paso.fila + 1}']);
      if (calculo == null || cargaResultante == null) continue;
      resultado.add({
        'paso': resultado.length + 1,
        'fila': paso.fila + 1,
        'metodo': paso.metodo.codigo,
        'indicacion_sustitutiva': paso.indicacionSustitutiva,
        'fila_referencia': paso.filaReferencia + 1,
        'carga_referencia': calculo.cargaReferencia,
        'indicacion_referencia': calculo.indicacionReferencia,
        'error_referencia': calculo.errorReferencia,
        'carga_sustitutiva': calculo.cargaSustitutiva,
        'fila_base': paso.filaBase + 1,
        'carga_base': calculo.cargaBase,
        // La que quedó registrada en lin{fila}, con los decimales de d.
        'carga_resultante': cargaResultante,
        'registrado_en': paso.registradoEn == null
            ? null
            : fechaIsoConDesfase(paso.registradoEn!),
      });
    }
    return resultado;
  }
}

int? _entero(Object? raw) {
  if (raw is int) return raw;
  if (raw is num && raw == raw.roundToDouble()) return raw.toInt();
  return int.tryParse(raw?.toString().trim() ?? '');
}

double? _numero(Object? raw) {
  if (raw is num) return raw.isFinite ? raw.toDouble() : null;
  final text = raw?.toString().trim().replaceAll(',', '.') ?? '';
  if (text.isEmpty) return null;
  final value = double.tryParse(text);
  return value != null && value.isFinite ? value : null;
}
