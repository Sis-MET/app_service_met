import 'calibration_server_schema.dart';

class CalibrationDataException implements Exception {
  final String column;
  final Object? value;
  final String code;
  final String message;

  const CalibrationDataException({
    required this.column,
    required this.value,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'Columna $column: $message (valor: $value)';
}

class CalibrationDataNormalizer {
  static const _uploadExcludedFields = {
    'n',
    'codigo_registro',
    'id',
    'foto_balanza',
    'nombre_zip',
    'nombre_csv',
    'finalized_at',
    // Progreso local (servicio_status) que la consulta por SECA agrega a
    // cada fila; no son columnas de DATA_SERVICIOS_DATOS_CALIBRACION.
    'servicio_status',
    'balanza_confirmed',
    'directorio_zip',
    'estado_servicio_csv',
    // Ubicación GPS: no es columna del detalle. Viaja aparte, al resumen
    // DATA_SERVICIOS_DATOS (CalibrationUploadApiService).
    'latitud',
    'longitud',
    'precision_gps',
    'fecha_gps',
  };
  static final RegExp _integerPattern = RegExp(r'^-?\d+(?:[\.,]0+)?$');
  static final RegExp _decimalPattern = RegExp(r'^-?(?:\d+\.?\d*|\.\d+)$');
  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _timePattern =
      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,7})?)?$');

  const CalibrationDataNormalizer._();

  static bool isLocalFileField(String column) =>
      column == 'foto_balanza' || column.endsWith('_foto');

  static Map<String, dynamic> normalizeRecord(
    Map<String, dynamic> record, {
    bool rejectUnknownColumns = true,
  }) {
    final normalized = <String, dynamic>{};
    for (final entry in record.entries) {
      if (isLocalFileField(entry.key)) {
        normalized[entry.key] = entry.value;
        continue;
      }
      final definition = calibrationServerSchema[entry.key];
      if (definition == null) {
        if (rejectUnknownColumns) {
          throw CalibrationDataException(
            column: entry.key,
            value: entry.value,
            code: 'UNKNOWN_COLUMN',
            message: 'no existe en DATA_SERVICIOS_DATOS_CALIBRACION',
          );
        }
        normalized[entry.key] = entry.value;
        continue;
      }
      normalized[entry.key] = normalizeValue(
        entry.key,
        entry.value,
        definition,
      );
    }
    return normalized;
  }

  static Map<String, dynamic> normalizeForUpload(
    Map<String, dynamic> record,
  ) {
    final nombreCsv = record['nombre_csv']?.toString().trim();
    final filtered = Map<String, dynamic>.fromEntries(
      record.entries.where(
        (entry) =>
            !_uploadExcludedFields.contains(entry.key) &&
            !isLocalFileField(entry.key),
      ),
    );
    final normalized = normalizeRecord(filtered);
    if (nombreCsv != null && nombreCsv.isNotEmpty) {
      normalized['nombre_csv'] = nombreCsv;
    }
    return normalized;
  }

  static dynamic normalizeValue(
    String column,
    Object? raw,
    CalibrationColumnDefinition definition,
  ) {
    if (raw == null || raw.toString().trim().isEmpty) {
      if (!definition.nullable && column != 'n') {
        throw CalibrationDataException(
          column: column,
          value: raw,
          code: 'REQUIRED',
          message: 'no admite valores vacíos',
        );
      }
      // La UI histórica usa cadenas vacías para los campos opcionales.
      return '';
    }

    switch (definition.type) {
      case CalibrationSqlType.nvarchar:
        return _normalizeText(column, raw, definition);
      case CalibrationSqlType.integer:
        return _normalizeInteger(column, raw);
      case CalibrationSqlType.decimal:
        return _normalizeDecimal(column, raw, definition);
      case CalibrationSqlType.date:
        return _normalizeDate(column, raw);
      case CalibrationSqlType.time:
        return _normalizeTime(column, raw);
      case CalibrationSqlType.bit:
        return _normalizeBit(column, raw);
    }
  }

  static String _normalizeText(
    String column,
    Object raw,
    CalibrationColumnDefinition definition,
  ) {
    final value = raw.toString().trim();
    final maxLength = definition.maxLength;
    if (maxLength != null && value.length > maxLength) {
      throw CalibrationDataException(
        column: column,
        value: raw,
        code: 'MAX_LENGTH',
        message: 'supera el máximo de $maxLength caracteres',
      );
    }
    return value;
  }

  static int _normalizeInteger(String column, Object raw) {
    if (raw is int) return _validateIntegerRange(column, raw, raw);
    if (raw is double) {
      if (!raw.isFinite || raw.truncateToDouble() != raw) {
        throw _invalidInteger(column, raw);
      }
      return _validateIntegerRange(column, raw.toInt(), raw);
    }

    final value = raw.toString().trim();
    if (!_integerPattern.hasMatch(value)) throw _invalidInteger(column, raw);
    final integerPart = value.split(RegExp(r'[\.,]')).first;
    final parsed = int.tryParse(integerPart);
    if (parsed == null) throw _invalidInteger(column, raw);
    return _validateIntegerRange(column, parsed, raw);
  }

  static int _validateIntegerRange(String column, int value, Object raw) {
    if (value < -2147483648 || value > 2147483647) {
      throw CalibrationDataException(
        column: column,
        value: raw,
        code: 'INTEGER_OVERFLOW',
        message: 'debe estar entre -2147483648 y 2147483647',
      );
    }
    return value;
  }

  static CalibrationDataException _invalidInteger(
    String column,
    Object raw,
  ) {
    return CalibrationDataException(
      column: column,
      value: raw,
      code: 'INVALID_INTEGER',
      message:
          'debe ser un entero; se acepta una terminación decimal solo si es cero',
    );
  }

  static String _normalizeDecimal(
    String column,
    Object raw,
    CalibrationColumnDefinition definition,
  ) {
    final value = raw.toString().trim().replaceAll(',', '.');
    if (!_decimalPattern.hasMatch(value)) {
      throw CalibrationDataException(
        column: column,
        value: raw,
        code: 'INVALID_DECIMAL',
        message: 'debe ser un número decimal válido',
      );
    }

    final unsigned = value.startsWith('-') ? value.substring(1) : value;
    final parts = unsigned.split('.');
    final integerPart = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final fraction = parts.length == 2 ? parts[1] : '';
    final precision = definition.precision!;
    final scale = definition.scale!;
    if (integerPart.length > precision - scale || fraction.length > scale) {
      throw CalibrationDataException(
        column: column,
        value: raw,
        code: 'DECIMAL_OVERFLOW',
        message: 'excede decimal($precision,$scale)',
      );
    }

    final normalizedInteger = integerPart.isEmpty ? '0' : integerPart;
    final normalizedFraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    final sign = value.startsWith('-') &&
            (normalizedInteger != '0' || normalizedFraction.isNotEmpty)
        ? '-'
        : '';
    return normalizedFraction.isEmpty
        ? '$sign$normalizedInteger'
        : '$sign$normalizedInteger.$normalizedFraction';
  }

  static String _normalizeDate(String column, Object raw) {
    final value = raw.toString().trim();
    if (!_datePattern.hasMatch(value)) {
      throw CalibrationDataException(
        column: column,
        value: raw,
        code: 'INVALID_DATE',
        message: 'debe usar el formato AAAA-MM-DD',
      );
    }
    final parts = value.split('-').map(int.parse).toList();
    final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
    if (parsed.year != parts[0] ||
        parsed.month != parts[1] ||
        parsed.day != parts[2]) {
      throw CalibrationDataException(
        column: column,
        value: raw,
        code: 'INVALID_DATE',
        message: 'no representa una fecha existente',
      );
    }
    return value;
  }

  static String _normalizeTime(String column, Object raw) {
    final value = raw.toString().trim();
    if (!_timePattern.hasMatch(value)) {
      throw CalibrationDataException(
        column: column,
        value: raw,
        code: 'INVALID_TIME',
        message: 'debe usar HH:mm o HH:mm:ss',
      );
    }
    return value;
  }

  static int _normalizeBit(String column, Object raw) {
    if (raw == true || raw == 1 || raw == '1') return 1;
    if (raw == false || raw == 0 || raw == '0') return 0;
    throw CalibrationDataException(
      column: column,
      value: raw,
      code: 'INVALID_BOOLEAN',
      message: 'debe ser 0, 1, true o false',
    );
  }
}
