enum TipoServicio { calibracion, soporte }

class ServicioResumen {
  final TipoServicio tipo;
  final String codigo;
  final int cantidad;
  final List<Map<String, dynamic>> items;
  final String? fecha;

  ServicioResumen({
    required this.tipo,
    required this.codigo,
    required this.cantidad,
    required this.items,
    this.fecha,
  });

  String get prefijo => tipo == TipoServicio.calibracion ? 'SECA' : 'OTST';
  String get nombreTipo => tipo == TipoServicio.calibracion ? 'Calibración' : 'Soporte Técnico';
  String get nombreItem => tipo == TipoServicio.calibracion ? 'balanza' : 'servicio';
}
