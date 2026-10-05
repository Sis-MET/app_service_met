// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class HomeBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const HomeBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final bgColor = isDarkMode ? AppColors.surfaceDark : Colors.white;

    final items = [
      _NavItem(icon: FontAwesomeIcons.house, label: 'Inicio', index: 0),
      _NavItem(icon: FontAwesomeIcons.wrench, label: 'Servicios', index: 1),
      _NavItem(icon: FontAwesomeIcons.download, label: 'Precarga', index: 2),
      _NavItem(icon: FontAwesomeIcons.ellipsis, label: 'Otros', index: 3),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        // Márgenes laterales y bottom para que "flote"
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final isSelected = currentIndex == item.index;
              final iconColor = isSelected
                  ? (isDarkMode ? Colors.white : cs.primary)
                  : (cs.onSurface.withOpacity(isDarkMode ? 0.54 : 0.38));

              final labelColor = isSelected
                  ? (isDarkMode ? Colors.white : cs.primary)
                  : (cs.onSurface.withOpacity(isDarkMode ? 0.54 : 0.38));

              return Expanded(
                child: InkWell(
                  onTap: () {
                    onTap(item.index);
                  },
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: item.icon is IconData
                            ? Icon(item.icon, size: 22, color: iconColor)
                            : FaIcon(item.icon, size: 22, color: iconColor),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: labelColor,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final dynamic icon;
  final String label;
  final int index;
  _NavItem({required this.icon, required this.label, required this.index});
}
