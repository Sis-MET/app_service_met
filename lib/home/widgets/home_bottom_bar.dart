// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeBottomBar extends StatelessWidget {
  final int currentIndex;
  final bool modoDemo;
  final Function(int) onTap;

  const HomeBottomBar({
    super.key,
    required this.currentIndex,
    required this.modoDemo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accent = isDarkMode ? const Color(0xFF4A90E2) : const Color(0xFF04376E);

    final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    final items = [
      _NavItem(icon: FontAwesomeIcons.house, label: 'Inicio', index: 0),
      _NavItem(icon: FontAwesomeIcons.wrench, label: 'Servicios', index: 1),
      _NavItem(icon: FontAwesomeIcons.download, label: 'Precarga', index: 2),
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
              final isDisabled = modoDemo && item.index != 1;

              final iconColor = isDisabled
                  ? (isDarkMode ? Colors.white24 : Colors.black26)
                  : isSelected
                      ? accent
                      : (isDarkMode ? Colors.white54 : Colors.black38);

              final labelColor = isDisabled
                  ? (isDarkMode ? Colors.white24 : Colors.black26)
                  : isSelected
                      ? accent
                      : (isDarkMode ? Colors.white54 : Colors.black38);

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (isDisabled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.lock_outline,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'En modo DESCONECTADO solo puedes acceder a Servicios',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: accent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        ),
                      );
                      return;
                    }
                    onTap(item.index);
                  },
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(item.icon,
                            size: 18, color: iconColor),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
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
  final IconData icon;
  final String label;
  final int index;
  _NavItem({required this.icon, required this.label, required this.index});
}
