class NewScaleCode {
  static final Map<String, DateTime> _lastIssuedByPrefix = {};

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
