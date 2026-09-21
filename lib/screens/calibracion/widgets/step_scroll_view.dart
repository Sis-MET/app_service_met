import 'package:flutter/material.dart';

/// Cuerpo desplazable de un paso de la calibración.
///
/// Guarda lo dibujado en una capa aparte ([RepaintBoundary]). Sin ella, cada
/// vez que la pantalla cambia de alto —cuando se abre el teclado numérico— o
/// el técnico desplaza la lista, el teléfono vuelve a dibujar todas las
/// casillas del paso. En una linealidad de sesenta filas eso es un tirón bien
/// visible; con la capa aparte, la de siempre se reutiliza.
class StepScrollView extends StatelessWidget {
  const StepScrollView({required this.child, super.key});

  /// El contenido del paso, normalmente una `Column`.
  final Widget child;

  /// Abajo queda sitio para los botones flotantes de navegación.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(20, 20, 20, 100);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: padding,
        child: RepaintBoundary(child: child),
      );
}
