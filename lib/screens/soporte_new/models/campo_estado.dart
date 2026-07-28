class CampoEstado {
  String nombre;
  String value;
  String solutionValue;
  String solutionLabel;
  List<String> fotos;

  CampoEstado({
    this.nombre = '',
    this.value = '',
    this.solutionValue = 'No aplica',
    this.solutionLabel = '',
    List<String>? fotos,
  }) : fotos = fotos ?? [];
}
