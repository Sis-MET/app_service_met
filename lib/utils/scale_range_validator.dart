class ScaleRangeValues {
  const ScaleRangeValues({
    required this.capacity,
    required this.division,
    required this.verificationDivision,
    required this.decimals,
  });

  final Object? capacity;
  final Object? division;
  final Object? verificationDivision;
  final Object? decimals;

  double? get parsedCapacity => _parseNumber(capacity);
  double? get parsedDivision => _parseNumber(division);
  double? get parsedVerificationDivision => _parseNumber(verificationDivision);

  bool get hasAnyValue => [
        capacity,
        division,
        verificationDivision,
        decimals,
      ].any(_isMeaningfulValue);
}

class ScaleRangeValidator {
  const ScaleRangeValidator._();

  static String? validate(List<ScaleRangeValues> ranges) {
    for (var index = 0; index < ranges.length; index++) {
      final range = ranges[index];
      final required = index == 0 || range.hasAnyValue;
      if (!required) continue;

      final number = index + 1;
      if ((range.parsedCapacity ?? 0) <= 0) {
        return 'Falta la Capacidad Máxima (Rango $number).';
      }
      if ((range.parsedDivision ?? 0) <= 0) {
        return 'Falta la división d (Rango $number).';
      }
      if ((range.parsedVerificationDivision ?? 0) <= 0) {
        return 'Falta la división e (Rango $number).';
      }

      if (index > 0 && !ranges[index - 1].hasAnyValue) {
        return 'Debe completar el Rango $index antes del Rango $number.';
      }
    }

    return null;
  }
}

double? _parseNumber(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim().replaceAll(',', '.'));
}

bool _isMeaningfulValue(Object? value) {
  if (value == null) return false;
  final text = value.toString().trim();
  if (text.isEmpty) return false;
  final number = _parseNumber(value);
  return number == null || number != 0;
}
