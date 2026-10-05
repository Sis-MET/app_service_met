import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_icons.dart';

/// Tokens visuales compartidos para que Login, Home y los siguientes módulos
/// mantengan la misma identidad sin repetir valores mágicos.
class AppDesign {
  AppDesign._();

  static const double radiusSmall = 12;
  static const double radiusMedium = 18;
  static const double radiusLarge = 28;
  static const double pagePadding = 20;
  static const double controlHeight = 54;

  static const Color ink = Color(0xFF171714);
  static const Color canvas = Color(0xFFF5F3EC);
  static const Color canvasDark = Color(0xFF1C1C1A);
  static const Color muted = Color(0xFF6C6B64);

  static BorderRadius get smallRadius => BorderRadius.circular(radiusSmall);
  static BorderRadius get mediumRadius => BorderRadius.circular(radiusMedium);
  static BorderRadius get largeRadius => BorderRadius.circular(radiusLarge);

  static ButtonStyle positiveButtonStyle() => FilledButton.styleFrom(
        minimumSize: const Size(0, controlHeight),
        backgroundColor: AppColors.actionPositive,
        foregroundColor: AppColors.actionPositiveInk,
        disabledBackgroundColor: AppColors.actionPositive.withOpacity(0.42),
        disabledForegroundColor: AppColors.actionPositiveInk.withOpacity(0.55),
        elevation: 3,
        shadowColor: AppColors.accentYellow.withOpacity(0.42),
        shape: RoundedRectangleBorder(borderRadius: mediumRadius),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800),
      );

  static ButtonStyle negativeButtonStyle() => FilledButton.styleFrom(
        minimumSize: const Size(0, controlHeight),
        backgroundColor: AppColors.actionNegative,
        foregroundColor: AppColors.actionNegativeInk,
        disabledBackgroundColor: AppColors.actionNegative.withOpacity(0.42),
        disabledForegroundColor: AppColors.actionNegativeInk.withOpacity(0.65),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: mediumRadius),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800),
      );

  static ButtonStyle neutralButtonStyle(BuildContext context) =>
      OutlinedButton.styleFrom(
        minimumSize: const Size(0, controlHeight),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        backgroundColor: AppColors.accentYellow.withOpacity(
          Theme.of(context).brightness == Brightness.dark ? 0.07 : 0.06,
        ),
        side: BorderSide(color: AppColors.accentYellow.withOpacity(0.34)),
        shape: RoundedRectangleBorder(borderRadius: mediumRadius),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
      );

  static TextStyle displayStyle(BuildContext context) => GoogleFonts.poppins(
        fontSize: 30,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle titleStyle(BuildContext context) => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );
}

/// Botón de regreso compartido para las pantallas secundarias de la app.
///
/// Mantiene el tratamiento delineado usado en Configuración y usa
/// [Navigator.maybePop] por defecto para no forzar el cierre de una ruta raíz.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? foregroundColor;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Volver',
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      icon: const Icon(AppIcons.atras),
      style: IconButton.styleFrom(
        foregroundColor:
            foregroundColor ?? (isDark ? Colors.white : AppDesign.ink),
      ),
    );
  }
}

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppDesign.largeRadius,
        border: Border.all(color: colors.outlineVariant.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentYellow.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.04 : 0.08,
            ),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.05,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      // Las filas táctiles (ListTile, InkWell) pintan su efecto en el
      // Material más cercano; sin esta capa quedaría oculto bajo el fondo.
      // No recorta: el contenido cercano a las esquinas debe verse entero.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class AppStatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const AppStatusPill({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.success,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
