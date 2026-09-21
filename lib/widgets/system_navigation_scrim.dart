import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_design.dart';

/// Oscurece de a poco la parte de abajo de la pantalla, donde va la barra de
/// navegación del sistema.
///
/// La app dibuja detrás de esa barra (edge-to-edge), así que sus botones
/// quedaban sobre el fondo plano de cada pantalla. El degradado empieza un
/// poco más arriba, casi transparente, y se oscurece hacia el borde: lo que
/// queda encima de la barra —la píldora de Siguiente, el teclado numérico—
/// apenas se toca.
///
/// Es un degradado y no un desenfoque a propósito: el degradado se pinta una
/// vez, y un desenfoque obligaría a difuminar esa franja en cada cuadro, en
/// todas las pantallas. No recibe toques.
class SystemNavigationScrim extends StatelessWidget {
  const SystemNavigationScrim({required this.child, super.key});

  final Widget child;

  /// Cuánto sube el degradado por encima de la barra.
  static const double fadeAbove = 48;

  /// Oscuridad en el borde de la pantalla. En el tema claro es más suave: los
  /// botones de la barra son oscuros y tienen que seguir viéndose.
  static const double _lightAlpha = 0.32;
  static const double _darkAlpha = 0.85;

  /// La oscuridad crece más rápido hacia abajo (potencia de la posición): el
  /// comienzo es casi invisible, sin una línea donde empieza.
  static const double _curve = 1.6;
  static const List<double> _stops = [0, 0.2, 0.4, 0.6, 0.8, 1];

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.black : AppDesign.ink;
    final alpha = isDark ? _darkAlpha : _lightAlpha;

    // [child] va siempre primero en el mismo Stack: si la barra aparece o
    // desaparece, la app no se vuelve a montar ni pierde su estado.
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // Sin barra de navegación no hay nada que oscurecer.
        if (inset > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: inset + fadeAbove,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('system-navigation-scrim'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: _stops,
                    colors: [
                      for (final t in _stops)
                        color.withValues(alpha: alpha * math.pow(t, _curve)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
