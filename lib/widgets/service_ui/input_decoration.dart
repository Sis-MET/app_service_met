import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';

/// Decoración estándar de inputs estilo Calibración:
/// OutlineInputBorder radius 12, bordes sutiles, label Inter.
InputDecoration serviceInputDeco(String label, bool isDark,
        {Widget? prefixIcon, Widget? suffixIcon, String? hintText}) =>
    InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: isDark ? AppColors.cardDark : const Color(0xFFF5F3EC),
      labelStyle: GoogleFonts.inter(
        color: isDark ? Colors.white70 : AppDesign.muted,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
          borderRadius: AppDesign.mediumRadius,
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
      enabledBorder: OutlineInputBorder(
          borderRadius: AppDesign.mediumRadius,
          borderSide: BorderSide(
              color: isDark ? Colors.white12 : AppColors.borderLight)),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppDesign.mediumRadius,
        borderSide: const BorderSide(
          color: AppColors.actionPositive,
          width: 1.4,
        ),
      ),
    );

/// Header estándar de paso estilo Calibración:
/// título Poppins 26 w700 + subtítulo Inter 13.
class ServiceStepHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const ServiceStepHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppDesign.displayStyle(context).copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Header de sección dentro de un paso: Poppins 16 bold.
class ServiceSectionHeader extends StatelessWidget {
  final String title;

  const ServiceSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: AppDesign.titleStyle(context).copyWith(fontSize: 16),
      ),
    );
  }
}
