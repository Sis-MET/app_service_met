// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
    final accent = isDark ? const Color(0xFF4A90E2) : const Color(0xFF04376E);

    final trackBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final trackBorder =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFECECEC);

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
            accent: accent,
            isDark: isDark,
          ),
          _buildTab(
            context: context,
            index: 1,
            icon: FontAwesomeIcons.screwdriverWrench,
            label: 'Soporte Técnico',
            isSelected: selectedIndex == 1,
            accent: accent,
            isDark: isDark,
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
    required Color accent,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.25),
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
                    ? Colors.white
                    : (isDark ? Colors.white38 : Colors.black38),
              ) : FaIcon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
