import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Clase del cambio según su impacto sobre datos y registros (7.11.2).
enum ClaseCambio {
  critico(
      'A',
      'Crítico',
      'Afecta captura, cálculos, esquema, subida o seguridad',
      AppColors.actionNegative),
  funcional('B', 'Funcional', 'Cambia flujos o pantallas sin alterar datos',
      Color(0xFFE0A100)),
  menor('C', 'Menor', 'Textos, estilos o compilación', Color(0xFF7E8A97));

  const ClaseCambio(this.codigo, this.nombre, this.descripcion, this.color);

  final String codigo;
  final String nombre;
  final String descripcion;
  final Color color;
}

/// Una versión liberada de ServiceMET y lo que cambió en ella.
class VersionApp {
  const VersionApp({
    required this.version,
    required this.fecha,
    required this.clase,
    required this.resumen,
    this.nuevo = const [],
    this.corregido = const [],
    this.impactoRegistros,
    this.commit,
    this.validacion,
  });

  /// Versión y build tal como figuran en pubspec.yaml ("6.3.3+15").
  final String version;
  final String fecha;
  final ClaseCambio clase;
  final String resumen;
  final List<String> nuevo;
  final List<String> corregido;

  /// Qué cambia para los datos capturados; null si no hay impacto.
  final String? impactoRegistros;

  /// Commit que fijó la versión.
  final String? commit;

  /// Referencia al registro de validación (VAL-…); null si aún no existe.
  final String? validacion;

  /// "6.3.3" sin el número de build.
  String get nombre => version.split('+').first;
}
