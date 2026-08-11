// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/theme/app_design.dart';

/// Pill flotante de navegación (Atrás + acción dinámica),
/// idéntica a la usada en el workspace de Calibración.
///
/// Se ubica típicamente en un `Positioned(bottom: 20, right: 20)`.
class ServiceNavPill extends StatelessWidget {
  /// Texto del botón de acción ("Siguiente", "Guardar Datos", "Finalizar"...).
  final String label;

  /// Color del botón de acción.
  final Color actionColor;

  /// Acción del botón principal. Si es null, el botón se muestra deshabilitado.
  final VoidCallback? onNext;

  /// Acción del botón atrás. Si es null, se muestra deshabilitado.
  final VoidCallback? onBack;

  const ServiceNavPill({
    super.key,
    required this.label,
    this.actionColor = AppColors.actionPositive,
    this.onNext,
    this.onBack,
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
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: canGoBack
                      ? (isDark ? Colors.white70 : Colors.black54)
                      : (isDark ? Colors.white24 : Colors.black26),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Dynamic action button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Material(
              key: ValueKey<String>(label),
              color:
                  onNext != null ? AppColors.actionPositive : Colors.grey[400],
              borderRadius: BorderRadius.circular(50),
              child: InkWell(
                onTap: onNext,
                borderRadius: BorderRadius.circular(50),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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
                        const Icon(Icons.arrow_forward_ios_rounded,
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
