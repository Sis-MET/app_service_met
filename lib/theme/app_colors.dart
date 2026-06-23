import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Colores de texto corporativo ──
  // Dark mode: texto blanco | Light mode: #292929 oscuro
  static const Color primary = Color(0xFF292929);       // Texto e íconos en light mode
  static const Color primaryDark = Color(0xFF1A1A1A);   // Variante oscura para contrastes

  // ── Acento (Amarillo Métrica - uso puntual: logo, badges) ──
  static const Color accentYellow = Color(0xFFf9e300);
  static const Color shimmerGold = Color(0xFFD4A017);

  // ── Colores semánticos de servicio ──
  static const Color calibracion = Color(0xFF667EEA);
  static const Color calibracionGradientEnd = Color(0xFF764BA2);
  static const Color soporte = Color(0xFF4CAF50);
  static const Color soporteGradientEnd = Color(0xFF45a049);

  // ── Fondos de pantalla de Login/Setup ──
  // Dark: tono gris oscuro #292929
  // Light: blanco hueso #FCFAFA
  static const Color loginBgDark = Color(0xFF292929);
  static const Color loginBgDarkEnd = Color(0xFF1F1F1F);
  static const Color loginBgLight = Color(0xFFFCFAFA);

  // ── Borde glass sutil (para BackdropFilter) ──
  static const Color glassBorder = Color(0x22FFFFFF);   // Blanco 13% opacidad

  // ── Superficies (dark) ──
  static const Color surfaceDark = Color(0xFF333333);   // Cards en dark
  static const Color cardDark = Color(0xFF3A3A3A);      // Cards secundarias
  static const Color backgroundDark = Color(0xFF292929);
  static const Color borderDark = Color(0xFF444444);
  static const Color borderDarkSoft = Color(0xFF3D3D3D);

  // ── Superficies (light) ──
  static const Color backgroundLight = Color(0xFFFCFAFA);
  static const Color borderLight = Color(0xFFE5E5E5);

  // ── Texto ──
  static const Color textPrimaryLight = Color(0xFF292929);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color iconLight = Color(0xFF555555);

  // ── Estados ──
  static const Color success = Color(0xFF0E8833);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFF9800);

  // ── Navegación (soporte) ──
  static const Color navNext = Color(0xFF195375);
  static const Color navFinalize = Color(0xFF167D1D);
}
