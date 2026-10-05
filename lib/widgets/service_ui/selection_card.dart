// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/theme/app_design.dart';
import '../../theme/app_icons.dart';

/// Tarjeta de selección estilo Calibración:
/// seleccionada → fondo amarillo suave + borde `#f9e300`;
/// avatar 44x44 radius 12 con inicial; check circular amarillo.
class ServiceSelectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const ServiceSelectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = AppColors.accentYellow;
    final initial =
        title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? accent.withOpacity(0.08) : const Color(0xFFFFFDE6))
            : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
        borderRadius: AppDesign.mediumRadius,
        border: Border.all(
          color: isSelected
              ? AppColors.actionPositive
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accent.withOpacity(isDark ? 0.04 : 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : (isDark ? Colors.white12 : const Color(0xFFF0F2F5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFF5A4E00)
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.actionPositive,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(AppIcons.listo,
                      size: 16, color: AppColors.actionPositiveInk),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
