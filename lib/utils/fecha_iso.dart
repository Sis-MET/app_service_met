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

/// Como [fechaIsoConDesfase], con milisegundos: `2026-10-15T09:30:00.250-04:00`.
/// Para las lecturas programadas, que se toman cada pocos segundos.
String fechaIsoConMilisegundos(DateTime valor) {
  final base = fechaIsoConDesfase(valor);
  final ms = valor.toLocal().millisecond.toString().padLeft(3, '0');
  // El desfase empieza en el signo que sigue a los segundos (posición 19).
  return '${base.substring(0, 19)}.$ms${base.substring(19)}';
}
