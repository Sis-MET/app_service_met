// lib/login/widgets/login/user_card.dart - VERSIÓN SIMPLIFICADA

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserCard extends StatelessWidget {
  final bool isDark;
  final String savedUser;
  final String? savedUserFullName;
  final VoidCallback onShowUserSelector;

  const UserCard({
    super.key,
    required this.isDark,
    required this.savedUser,
    this.savedUserFullName,
    required this.onShowUserSelector,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? const Color(0xFF4A90E2) : const Color(0xFF04376E);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      savedUserFullName ?? savedUser,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '@$savedUser',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // SIMPLIFICADO: Botón directo para cambiar
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                color: accent,
                tooltip: 'Cambiar usuario',
                onPressed: onShowUserSelector,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
