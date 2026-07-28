import 'dart:io';

class CampoEstado {
  String initialValue;
  String solutionValue;
  String comentario;
  List<File> fotos;

  CampoEstado({
    this.initialValue = '',
    this.solutionValue = '',
    this.comentario = '',
    List<File>? fotos,
  }) : fotos = fotos ?? [];

  void agregarFoto(File foto) {
    fotos.add(foto);
  }

  void eliminarFoto(int index) {
    if (index >= 0 && index < fotos.length) {
      fotos.removeAt(index);
    }
  }

  void limpiarFotos() {
    fotos.clear();
  }
}
