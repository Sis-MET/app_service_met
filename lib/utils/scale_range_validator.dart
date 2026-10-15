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

/// Orden en que se muestran los rangos de una balanza: de menor a mayor
/// capacidad máxima, para que el Rango 1 sea siempre el menor.
///
/// Es solo de presentación. Las columnas `cap_max1..3`, `d1..3`, `e1..3` y
/// `dec1..3` conservan el orden en que vinieron de DataMET o en que las
/// escribió el técnico: no se reordenan ni se migran.
class ScaleRangeOrder {
  const ScaleRangeOrder._();

  /// Índices guardados (0, 1, 2...) en el orden en que se muestran. Los
  /// rangos sin capacidad van al final, en su orden original.
  static List<int> displayOrder(List<Object?> capacities) {
    final indices = List<int>.generate(capacities.length, (i) => i);
    double? capacity(int i) {
      final value = _parseNumber(capacities[i]);
      return value != null && value > 0 ? value : null;
    }

    indices.sort((a, b) {
      final ca = capacity(a);
      final cb = capacity(b);
      if (ca == null && cb == null) return a.compareTo(b);
      if (ca == null) return 1;
      if (cb == null) return -1;
      final byCapacity = ca.compareTo(cb);
      return byCapacity != 0 ? byCapacity : a.compareTo(b);
    });
    return indices;
  }

  /// Número que ve el técnico para cada rango guardado: `[2, 1, 3]` indica
  /// que cap_max1 se muestra como Rango 2 y cap_max2 como Rango 1.
  static List<int> displayNumbers(List<Object?> capacities) {
    final order = displayOrder(capacities);
    final numbers = List<int>.filled(capacities.length, 0);
    for (var position = 0; position < order.length; position++) {
      numbers[order[position]] = position + 1;
    }
    return numbers;
  }
}

class ScaleRangeValidator {
  const ScaleRangeValidator._();

  /// Valida los rangos en el orden en que se guardan. Con [displayNumbers]
  /// (ver [ScaleRangeOrder.displayNumbers]) los mensajes nombran cada rango
  /// como se ve en pantalla.
  static String? validate(
    List<ScaleRangeValues> ranges, {
    List<int>? displayNumbers,
  }) {
    int shown(int index) =>
        displayNumbers != null && index < displayNumbers.length
            ? displayNumbers[index]
            : index + 1;

    for (var index = 0; index < ranges.length; index++) {
      final range = ranges[index];
      final required = index == 0 || range.hasAnyValue;
      if (!required) continue;

      final number = shown(index);
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
        return 'Debe completar el Rango ${shown(index - 1)} antes del '
            'Rango $number.';
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
