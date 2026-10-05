// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/theme/app_design.dart';
import '../../theme/app_icons.dart';

/// Pill flotante de navegación (Atrás + acción dinámica),
/// idéntica a la usada en el workspace de Calibración.
///
/// Se ubica en un `Positioned(bottom: ServiceNavPill.bottomOffset(context),
/// right: 20)`, y los pasos que pasan por debajo usan [pagePadding].
class ServiceNavPill extends StatelessWidget {
  /// Distancia de la píldora al borde inferior de la pantalla. La app dibuja
  /// detrás de la barra de navegación (edge-to-edge), así que la píldora va
  /// encima de ella: con tres botones la barra es alta y la tapaba.
  static double bottomOffset(BuildContext context) =>
      20 + MediaQuery.paddingOf(context).bottom;

  /// Margen de un paso que se desplaza por debajo de la píldora. El contenido
  /// llega hasta el borde de la pantalla, por detrás de la barra, como en el
  /// inicio; abajo deja libre la píldora y la barra para que lo último se
  /// pueda leer.
  static EdgeInsets pagePadding(BuildContext context, {double top = 24}) =>
      EdgeInsets.fromLTRB(
          20, top, 20, 100 + MediaQuery.paddingOf(context).bottom);

  /// Texto del botón de acción ("Siguiente", "Guardar Datos", "Finalizar"...).
  final String label;

  /// Color del botón de acción.
  final Color actionColor;

  /// Acción del botón principal. Si es null, el botón se muestra deshabilitado.
  final VoidCallback? onNext;

  /// Acción del botón atrás. Si es null, se muestra deshabilitado.
  final VoidCallback? onBack;

  /// Si false, la píldora queda solo con el botón atrás: en el último paso no
  /// hay a dónde seguir y un "Siguiente" apagado confunde.
  final bool showNext;

  const ServiceNavPill({
    super.key,
    required this.label,
    this.actionColor = AppColors.actionPositive,
    this.onNext,
    this.onBack,
    this.showNext = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark ? AppColors.cardDark : Colors.white;
    final backColor = AppColors.accentYellow.withOpacity(isDark ? 0.10 : 0.12);
    final canGoBack = onBack != null;

    return Container(
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: AppDesign.largeRadius,
        border: Border.all(
          color: isDark
              ? AppColors.borderDarkSoft
              : AppColors.accentYellow.withOpacity(0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentYellow.withOpacity(isDark ? 0.04 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back button
          Tooltip(
            message: 'Anterior',
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(50),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: canGoBack ? backColor : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.anterior,
                  size: 18,
                  color: canGoBack
                      ? (isDark ? Colors.white70 : Colors.black54)
                      : (isDark ? Colors.white24 : Colors.black26),
                ),
              ),
            ),
          ),
          if (showNext) const SizedBox(width: 6),
          // Dynamic action button
          if (showNext)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Material(
                key: ValueKey<String>(label),
                color: onNext != null
                    ? AppColors.actionPositive
                    : Colors.grey[400],
                borderRadius: BorderRadius.circular(50),
                child: InkWell(
                  onTap: onNext,
                  borderRadius: BorderRadius.circular(50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.actionPositiveInk,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (label == 'Siguiente') ...[
                          const SizedBox(width: 6),
                          const Icon(AppIcons.siguiente,
                              size: 14, color: AppColors.actionPositiveInk),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
