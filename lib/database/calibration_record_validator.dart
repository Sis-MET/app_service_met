import 'calibration_data_normalizer.dart';
import 'calibration_server_schema.dart';

/// Un dato de la calibración que la base rechazaría, dicho como lo ve el
/// técnico: en qué paso está, cómo se llama en pantalla y qué tiene mal.
class CalibrationFieldIssue {
  const CalibrationFieldIssue({
    required this.column,
    required this.label,
    required this.step,
    required this.message,
  });

  final String column;

  /// Rótulo de pantalla, con la sección delante: "Excentricidad › Carga".
  final String label;

  /// Paso del asistente de calibración donde se corrige; -1 si no tiene.
  final int step;

  final String message;

  @override
  String toString() => '$label: $message';
}

/// Valida los datos de una calibración contra las columnas del servidor, con
/// las mismas reglas que [CalibrationDataNormalizer] aplica al guardar.
///
/// El guardado local normaliza el registro completo y un solo valor fuera de
/// esquema lo rechaza entero. Aquí se ven todos los problemas a la vez, con
/// nombre de pantalla, para mostrarlos antes de que el guardado falle.
abstract final class CalibrationRecordValidator {
  /// La columna del servidor es entera: el campo no admite decimales.
  static bool isIntegerColumn(String? column) =>
      column != null &&
      calibrationServerSchema[column]?.type == CalibrationSqlType.integer;

  /// Qué tiene mal [text] para [column], o null si el guardado lo acepta.
  /// Pensado para mostrarlo debajo del campo mientras se escribe.
  static String? fieldError(String column, String text) {
    final definition = calibrationServerSchema[column];
    if (definition == null) return null;
    try {
      CalibrationDataNormalizer.normalizeValue(column, text, definition);
      return null;
    } on CalibrationDataException catch (error) {
      return describeError(error);
    }
  }

  /// Todos los valores de [record] que el guardado rechazaría.
  static List<CalibrationFieldIssue> schemaIssues(Map<String, dynamic> record) {
    final issues = <CalibrationFieldIssue>[];
    for (final entry in record.entries) {
      if (CalibrationDataNormalizer.isLocalField(entry.key)) continue;
      final definition = calibrationServerSchema[entry.key];
      if (definition == null) {
        issues.add(issueFor(CalibrationDataException(
          column: entry.key,
          value: entry.value,
          code: 'UNKNOWN_COLUMN',
          message: 'no existe en DATA_SERVICIOS_DATOS_CALIBRACION',
        )));
        continue;
      }
      try {
        CalibrationDataNormalizer.normalizeValue(
          entry.key,
          entry.value,
          definition,
        );
      } on CalibrationDataException catch (error) {
        issues.add(issueFor(error));
      }
    }
    // Por paso y, dentro de cada paso, en el orden del registro, que es el de
    // la pantalla: List.sort no garantiza conservarlo.
    final ordered = issues.asMap().entries.toList()
      ..sort((a, b) {
        final byStep = a.value.step.compareTo(b.value.step);
        return byStep != 0 ? byStep : a.key.compareTo(b.key);
      });
    return [for (final entry in ordered) entry.value];
  }

  static CalibrationFieldIssue issueFor(CalibrationDataException error) {
    final place = labelFor(error.column);
    return CalibrationFieldIssue(
      column: error.column,
      label: place.label,
      step: place.step,
      message: describeError(error),
    );
  }

  static String describeError(CalibrationDataException error) {
    final definition = calibrationServerSchema[error.column];
    switch (error.code) {
      case 'REQUIRED':
        return 'es obligatorio';
      case 'MAX_LENGTH':
        final length = error.value?.toString().trim().length ?? 0;
        return 'admite hasta ${definition?.maxLength} caracteres '
            '(tiene $length)';
      case 'INVALID_INTEGER':
        return 'debe ser un número entero, sin decimales';
      case 'INTEGER_OVERFLOW':
        return 'es un número demasiado grande';
      case 'INVALID_DECIMAL':
        return 'no es un número válido';
      case 'DECIMAL_OVERFLOW':
        final precision = definition?.precision ?? 0;
        final scale = definition?.scale ?? 0;
        return 'admite hasta ${precision - scale} cifras enteras '
            'y $scale decimales';
      case 'INVALID_DATE':
        return 'no es una fecha válida (AAAA-MM-DD)';
      case 'INVALID_TIME':
        return 'no es una hora válida (HH:mm)';
      case 'UNKNOWN_COLUMN':
        return 'no existe en el servidor';
      default:
        return error.message;
    }
  }

  /// Rótulo y paso del asistente donde se escribe [column].
  static ({String label, int step}) labelFor(String column) {
    final fixed = _fixedLabels[column];
    if (fixed != null) return fixed;

    for (final rule in _patternLabels) {
      final match = rule.pattern.firstMatch(column);
      if (match != null) return (label: rule.label(match), step: rule.step);
    }
    return (label: column, step: -1);
  }

  /// Pruebas de la calibración que [record] no tiene guardadas.
  ///
  /// [record] es una fila de `registros_calibracion` (o el mapa de la sesión):
  /// sirve para revisar lo que realmente quedó en la base antes de finalizar,
  /// exportar o subir.
  static List<String> missingTests(Map<String, dynamic> record) {
    bool filled(String column) =>
        (record[column]?.toString().trim() ?? '').isNotEmpty;
    bool any(Iterable<String> columns) => columns.any(filled);

    final missing = <String>[];
    if (!any([for (var i = 1; i <= 6; i++) 'precarga$i'])) {
      missing.add('Precargas');
    }
    if (!filled('ti') || !filled('hri') || !filled('patmi')) {
      missing.add('Condiciones ambientales iniciales');
    }
    if (!filled('carga') ||
        !any([for (var i = 1; i <= 6; i++) 'indicacion$i'])) {
      missing.add('Excentricidad');
    }
    if (!filled('repetibilidad1') ||
        !any([for (var j = 1; j <= 10; j++) 'indicacion1_$j'])) {
      missing.add('Repetibilidad');
    }
    final hasLinealidad = Iterable<int>.generate(60, (i) => i + 1)
        .any((i) => filled('lin$i') && filled('ind$i'));
    if (!hasLinealidad) missing.add('Linealidad');
    if (!filled('ti_fin') || !filled('hri_fin') || !filled('patmi_fin')) {
      missing.add('Condiciones ambientales finales');
    }
    return missing;
  }

  static const _cliente = 0;
  static const _planta = 1;
  static const _seca = 2;
  static const _instrumento = 3;
  static const _inspeccion = 4;
  static const _precargas = 5;
  static const _excentricidad = 6;
  static const _repetibilidad = 7;
  static const _linealidad = 8;
  static const _condicionesFinales = 9;
  static const _finalizar = 10;

  static const _inspeccionCampos = {
    'vibracion': 'Vibración',
    'polvo': 'Polvo',
    'temp': 'Temperatura',
    'humedad': 'Humedad',
    'mesada': 'Mesada',
    'iluminacion': 'Iluminación',
    'limp_foza': 'Limpieza de fosa',
    'estado_drenaje': 'Estado de drenaje',
    'limp_general': 'Limpieza general',
    'golpes_terminal': 'Golpes al terminal',
    'nivelacion': 'Nivelación',
    'limp_recepto': 'Limpieza del receptor',
    'golpes_receptor': 'Golpes al receptor de carga',
    'encendido': 'Encendido',
  };

  static final Map<String, ({String label, int step})> _fixedLabels = {
    'cliente': (label: 'Cliente › Nombre comercial', step: _cliente),
    'razon_social': (label: 'Cliente › Razón social', step: _cliente),
    'planta': (label: 'Planta › Nombre', step: _planta),
    'dir_planta': (label: 'Planta › Dirección', step: _planta),
    'dep_planta': (label: 'Planta › Departamento', step: _planta),
    'cod_planta': (label: 'Planta › Código', step: _planta),
    'seca': (label: 'SECA', step: _seca),
    'session_id': (label: 'SECA › Sesión', step: _seca),
    'personal': (label: 'SECA › Técnico', step: _seca),
    'fecha_servicio': (label: 'SECA › Fecha del servicio', step: _seca),
    'n_reca': (label: 'Instrumento › N° RECA', step: _instrumento),
    'sticker': (label: 'Instrumento › N° Sticker', step: _instrumento),
    'cod_metrica': (label: 'Instrumento › Código Métrica', step: _instrumento),
    'categoria_balanza': (
      label: 'Instrumento › Categoría',
      step: _instrumento,
    ),
    'tipo_equipo': (label: 'Instrumento › Tipo de equipo', step: _instrumento),
    'marca': (label: 'Instrumento › Marca', step: _instrumento),
    'modelo': (label: 'Instrumento › Modelo', step: _instrumento),
    'serie': (label: 'Instrumento › Serie', step: _instrumento),
    'unidades': (label: 'Instrumento › Unidad', step: _instrumento),
    'ubicacion': (label: 'Instrumento › Ubicación', step: _instrumento),
    'rango': (label: 'Instrumento › Rango', step: _instrumento),
    'n_celdas': (label: 'Instrumento › N° Celdas', step: _instrumento),
    'cod_int': (label: 'Instrumento › Código interno', step: _instrumento),
    'inf_bal': (label: 'Instrumento › Información', step: _instrumento),
    'hora_inicio': (label: 'Inspección › Hora de inicio', step: _inspeccion),
    'tiempo_estab': (
      label: 'Inspección › Tiempo de estabilización',
      step: _inspeccion,
    ),
    't_ope_balanza': (
      label: 'Inspección › Tiempo previo de operación',
      step: _inspeccion,
    ),
    'ajuste': (label: 'Ajuste › ¿Se realizó ajuste?', step: _precargas),
    'tipo': (label: 'Ajuste › Tipo de ajuste', step: _precargas),
    'cargas_pesas': (
      label: 'Ajuste › Cargas de pesas patrón',
      step: _precargas
    ),
    'hora': (label: 'Condiciones ambientales › Hora', step: _precargas),
    'ti': (label: 'Condiciones ambientales › Ti', step: _precargas),
    'hri': (label: 'Condiciones ambientales › HRi', step: _precargas),
    'patmi': (label: 'Condiciones ambientales › Patmi', step: _precargas),
    'tipo_plataforma': (
      label: 'Excentricidad › Tipo de plataforma',
      step: _excentricidad,
    ),
    'puntos_ind': (
      label: 'Excentricidad › Puntos de indicación',
      step: _excentricidad,
    ),
    'carga': (label: 'Excentricidad › Carga', step: _excentricidad),
    'excentricidad_comentario': (
      label: 'Excentricidad › Nota',
      step: _excentricidad,
    ),
    'repetibilidad_comentario': (
      label: 'Repetibilidad › Nota',
      step: _repetibilidad,
    ),
    'metodo': (label: 'Linealidad › Método de carga', step: _linealidad),
    'metodo_carga': (
      label: 'Linealidad › Método de cargas sustitutivas',
      step: _linealidad,
    ),
    'linealidad_comentario': (label: 'Linealidad › Nota', step: _linealidad),
    'hora_fin': (
      label: 'Condiciones finales › Hora fin',
      step: _condicionesFinales,
    ),
    'hri_fin': (
      label: 'Condiciones finales › HRi fin',
      step: _condicionesFinales,
    ),
    'ti_fin': (
      label: 'Condiciones finales › Ti fin',
      step: _condicionesFinales
    ),
    'patmi_fin': (
      label: 'Condiciones finales › Patmi fin',
      step: _condicionesFinales,
    ),
    'mant_soporte': (
      label: 'Recomendaciones › Mantenimiento con ST',
      step: _condicionesFinales,
    ),
    'venta_pesas': (
      label: 'Recomendaciones › Venta de pesas',
      step: _condicionesFinales,
    ),
    'reemplazo': (
      label: 'Recomendaciones › Reemplazo',
      step: _condicionesFinales,
    ),
    'observaciones': (
      label: 'Condiciones finales › Observaciones',
      step: _condicionesFinales,
    ),
    'emp': (label: 'Certificado › EMP NB 23001', step: _finalizar),
    'indicar': (label: 'Certificado › Indicar (%)', step: _finalizar),
    'factor': (label: 'Certificado › Factor de seguridad', step: _finalizar),
    'regla_aceptacion': (
      label: 'Certificado › Regla de aceptación',
      step: _finalizar,
    ),
    for (final campo in _inspeccionCampos.entries) ...{
      campo.key: (label: 'Inspección › ${campo.value}', step: _inspeccion),
      '${campo.key}_comentario': (
        label: 'Inspección › ${campo.value} (comentario)',
        step: _inspeccion,
      ),
    },
  };

  static final List<_PatternLabel> _patternLabels = [
    _PatternLabel(
      RegExp(r'^(cap_max|d|e|dec)([1-3])$'),
      _instrumento,
      (m) => 'Rango ${m[2]} › ${const {
        'cap_max': 'Cap. Max',
        'd': 'd',
        'e': 'e',
        'dec': 'Dec.',
      }[m[1]]}',
    ),
    _PatternLabel(
      RegExp(r'^(equipo|certificado|ente_calibrador|estado|cantidad)([1-5])$'),
      _condicionesFinales,
      (m) => 'Pesas patrón › Pesa ${m[2]}: ${_equipoCampo(m[1]!)}',
    ),
    _PatternLabel(
      RegExp(r'^(equipo|certificado|ente_calibrador|estado|cantidad)([6-7])$'),
      _finalizar,
      (m) => 'Instrumentos de medición › Instrumento '
          '${int.parse(m[2]!) - 5}: ${_equipoCampo(m[1]!)}',
    ),
    _PatternLabel(
      RegExp(r'^precarga(\d)$'),
      _precargas,
      (m) => 'Precargas › Precarga ${m[1]}',
    ),
    _PatternLabel(
      RegExp(r'^p_indicador(\d)$'),
      _precargas,
      (m) => 'Precargas › Indicación ${m[1]}',
    ),
    _PatternLabel(
      RegExp(r'^posicion(\d)$'),
      _excentricidad,
      (m) => 'Excentricidad › Posición ${m[1]}',
    ),
    _PatternLabel(
      RegExp(r'^(indicacion|retorno)(\d)$'),
      _excentricidad,
      (m) => 'Excentricidad › Posición ${m[2]}: '
          '${m[1] == 'indicacion' ? 'indicación' : 'retorno'}',
    ),
    _PatternLabel(
      RegExp(r'^repetibilidad(\d)$'),
      _repetibilidad,
      (m) => 'Repetibilidad › Carga ${m[1]}',
    ),
    _PatternLabel(
      RegExp(r'^(indicacion|retorno)(\d)_(\d+)$'),
      _repetibilidad,
      (m) => 'Repetibilidad › Carga ${m[2]}, medición ${m[3]}: '
          '${m[1] == 'indicacion' ? 'indicación' : 'retorno'}',
    ),
    _PatternLabel(
      RegExp(r'^lin(\d+)$'),
      _linealidad,
      (m) => 'Linealidad › Carga ${m[1]}: carga real',
    ),
    _PatternLabel(
      RegExp(r'^ind(\d+)$'),
      _linealidad,
      (m) => 'Linealidad › Carga ${m[1]}: indicación',
    ),
    _PatternLabel(
      RegExp(r'^retorno_lin(\d+)$'),
      _linealidad,
      (m) => 'Linealidad › Carga ${m[1]}: retorno a cero',
    ),
  ];

  static String _equipoCampo(String campo) => const {
        'equipo': 'código',
        'certificado': 'certificado',
        'ente_calibrador': 'ente calibrador',
        'estado': 'estado',
        'cantidad': 'cantidad',
      }[campo]!;
}

class _PatternLabel {
  const _PatternLabel(this.pattern, this.step, this.label);

  final RegExp pattern;
  final int step;
  final String Function(RegExpMatch match) label;
}
