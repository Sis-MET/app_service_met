/// ISO-8601 en hora local con su desfase: `2026-10-15T09:30:00-04:00`.
///
/// Se lee la hora de la planta y, a la vez, el instante exacto queda sin
/// ambigüedad (para registros técnicos y su historial).
String fechaIsoConDesfase(DateTime valor) {
  final local = valor.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  final desfase = local.timeZoneOffset;
  final signo = desfase.isNegative ? '-' : '+';
  final minutos = desfase.inMinutes.abs();
  return '${local.year.toString().padLeft(4, '0')}-${dos(local.month)}-'
      '${dos(local.day)}T${dos(local.hour)}:${dos(local.minute)}:'
      '${dos(local.second)}$signo${dos(minutos ~/ 60)}:${dos(minutos % 60)}';
}
