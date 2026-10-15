class NewScaleCode {
  static final Map<String, DateTime> _lastIssuedByPrefix = {};

  static final RegExp _provisional =
      RegExp(r'^([^-]+)-([^-]+)-(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$');

  /// Si [code] es el código provisional de una balanza nueva
  /// (`CLIENTE-PLANTA-DDMMAAHHMMSS`), todavía sin registrar en DataMET.
  ///
  /// Es la misma regla que `isNewScaleCode` en `backend/src/validation.js`:
  /// la marca de tiempo debe ser una fecha y hora reales.
  static bool isProvisional(String? code) {
    final match = _provisional.firstMatch(code?.trim() ?? '');
    if (match == null) return false;
    final [day, month, year, hour, minute, second] = [
      for (var group = 3; group <= 8; group++) int.parse(match.group(group)!),
    ];
    final parsed = DateTime.utc(2000 + year, month, day, hour, minute, second);
    return parsed.year == 2000 + year &&
        parsed.month == month &&
        parsed.day == day &&
        parsed.hour == hour &&
        parsed.minute == minute &&
        parsed.second == second;
  }

  /// `CLIENTE-PLANTA` de un código provisional, o null si no lo es.
  static String? provisionalPrefix(String? code) {
    if (!isProvisional(code)) return null;
    final value = code!.trim();
    return value.substring(0, value.lastIndexOf('-'));
  }

  static String generate({
    String? clientCode,
    String? plantCode,
    DateTime? now,
  }) {
    final prefix = _prefix(clientCode, plantCode);
    final current = now ?? DateTime.now();
    var issued = DateTime(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute,
      current.second,
    );
    final previous = _lastIssuedByPrefix[prefix];
    if (previous != null && !issued.isAfter(previous)) {
      issued = previous.add(const Duration(seconds: 1));
    }
    _lastIssuedByPrefix[prefix] = issued;
    return '$prefix-${_timestamp(issued)}';
  }

  static String _prefix(String? clientCode, String? plantCode) {
    final client = clientCode?.trim() ?? '';
    final plant = plantCode?.trim() ?? '';
    if (plant.contains('-')) return plant;
    if (client.isNotEmpty && plant.isNotEmpty) return '$client-$plant';
    if (plant.isNotEmpty) return plant;
    if (client.isNotEmpty) return '$client-NN';
    return 'NNNN-NN';
  }

  static String _timestamp(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(value.day)}${two(value.month)}${two(value.year % 100)}'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}
