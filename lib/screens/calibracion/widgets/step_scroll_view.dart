import 'package:flutter/material.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';

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

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        // Abajo deja libre la píldora de navegación y la barra del sistema.
        padding: ServiceNavPill.pagePadding(context, top: 20),
        child: RepaintBoundary(child: child),
      );
}
