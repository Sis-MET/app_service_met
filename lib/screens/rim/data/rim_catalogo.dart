/// Opción de una lista del RIM. La [key] es la misma que usa el formulario
/// web (RimMET), para que un RIM emitido en cualquiera de los dos se lea igual.
class RimOpcion {
  final String key;
  final String label;

  const RimOpcion(this.key, this.label);
}

/// Estado de un componente del inventario.
enum RimEstadoComponente {
  present('Presente'),
  missing('Faltante'),
  na('N/A');

  final String label;
  const RimEstadoComponente(this.label);

  static RimEstadoComponente? fromName(String? value) {
    for (final estado in values) {
      if (estado.name == value) return estado;
    }
    return null;
  }
}

/// Componente fijo del inventario; con [conCantidad] se registra además
/// cuántas piezas se reciben (celdas, patas).
class RimComponente {
  final String key;
  final String label;
  final bool conCantidad;

  const RimComponente(this.key, this.label, {this.conCantidad = false});
}

/// Listas del formulario "Recepción de instrumentos de pesaje" (RIM).
class RimCatalogo {
  RimCatalogo._();

  static const componentes = [
    RimComponente('indicator', 'Indicador'),
    RimComponente('voltageAdapter', 'Adaptador de voltaje'),
    RimComponente('powerCable', 'Cable de poder'),
    RimComponente('bracket', 'Bracket'),
    RimComponente('column', 'Columna'),
    RimComponente('weighingPan', 'Bandeja de pesaje'),
    RimComponente('windShield', 'Cabina corta aire'),
    RimComponente('structure', 'Estructura'),
    RimComponente('loadCells', 'Celda(s) de carga', conCantidad: true),
    RimComponente('loadCellCable', 'Cable de celda'),
    RimComponente('loadCellConnector', 'Conector de celda'),
    RimComponente('junctionBox', 'Caja sumadora'),
    RimComponente('feet', 'Patas', conCantidad: true),
    RimComponente('manual', 'Manual'),
    RimComponente('originalPackaging', 'Embalaje original'),
  ];

  static const estadosGenerales = [
    RimOpcion('excellent', 'Excelente'),
    RimOpcion('good', 'Bueno'),
    RimOpcion('fair', 'Regular'),
    RimOpcion('poor', 'Malo'),
    RimOpcion('critical', 'Crítico'),
  ];

  static const tiposDano = [
    RimOpcion('scratches', 'Rayones'),
    RimOpcion('dents', 'Abolladuras'),
    RimOpcion('corrosion', 'Corrosión'),
    RimOpcion('cracks', 'Grietas'),
    RimOpcion('broken', 'Piezas rotas'),
    RimOpcion('wear', 'Desgaste'),
    RimOpcion('other', 'Otros'),
  ];

  static const ubicacionesDano = [
    RimOpcion('platform', 'Plataforma'),
    RimOpcion('display', 'Display'),
    RimOpcion('structure', 'Estructura'),
    RimOpcion('loadCells', 'Celdas'),
    RimOpcion('wiring', 'Cableado'),
  ];

  static const nivelesSuciedad = [
    RimOpcion('clean', 'Limpio'),
    RimOpcion('light', 'Polvo ligero'),
    RimOpcion('moderate', 'Moderado'),
    RimOpcion('heavy', 'Muy sucio'),
  ];

  /// Texto visible de [key] en [opciones]; la clave misma si es de una
  /// versión posterior del catálogo.
  static String etiqueta(List<RimOpcion> opciones, String? key) {
    if (key == null || key.isEmpty) return '';
    for (final opcion in opciones) {
      if (opcion.key == key) return opcion.label;
    }
    return key;
  }

  static String componente(String key) {
    for (final item in componentes) {
      if (item.key == key) return item.label;
    }
    return key;
  }
}
