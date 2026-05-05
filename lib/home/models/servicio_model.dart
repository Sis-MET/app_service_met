enum TipoServicio { calibracion, soporte }

class ServicioResumen {
  final TipoServicio tipo;
  final String codigo; // "SECA XXX" o "OTST XXX"
  final int cantidad; // cantidadBalanzas o cantidadServicios
  final List<Map<String, dynamic>> items; // balanzas o servicios

  ServicioResumen({
    required this.tipo,
    required this.codigo,
    required this.cantidad,
    required this.items,
  });

  String get prefijo => tipo == TipoServicio.calibracion ? 'SECA' : 'OTST';
  String get nombreTipo => tipo == TipoServicio.calibracion ? 'Calibración' : 'Soporte Técnico';
  String get nombreItem => tipo == TipoServicio.calibracion ? 'balanza' : 'servicio';
}
