// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class TipoServicioSelector extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelected;

  const TipoServicioSelector({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final trackBg = isDark ? AppColors.surfaceDark : cs.surfaceVariant;
    final trackBorder =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: trackBorder, width: 1),
      ),
      child: Row(
        children: [
          _buildTab(
            context: context,
            index: 0,
            icon: FontAwesomeIcons.scaleBalanced,
            label: 'Calibración',
            isSelected: selectedIndex == 0,
          ),
          _buildTab(
            context: context,
            index: 1,
            icon: FontAwesomeIcons.screwdriverWrench,
            label: 'Soporte Técnico',
            isSelected: selectedIndex == 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required BuildContext context,
    required int index,
    required dynamic icon,
    required String label,
    required bool isSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon is IconData ? Icon(
                icon,
                size: 14,
                color: isSelected
                    ? (isDark ? const Color(0xFF292929) : Colors.white)
                    : cs.onSurface.withOpacity(0.38),
              ) : FaIcon(
                icon,
                size: 14,
                color: isSelected
                    ? (isDark ? const Color(0xFF292929) : Colors.white)
                    : cs.onSurface.withOpacity(0.38),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? (isDark ? const Color(0xFF292929) : Colors.white)
                      : cs.onSurface.withOpacity(0.38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
