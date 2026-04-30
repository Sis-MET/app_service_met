// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WelcomeHeader extends StatelessWidget {
  final String userName;
  const WelcomeHeader({super.key, required this.userName});

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Buenos días ☀️';
    if (h >= 12 && h < 19) return 'Buenas tardes 🌤️';
    return 'Buenas noches 🌙';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ')
        .where((p) => p.isNotEmpty && !p.contains('.'))
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _getFirstName(String fullName) {
    final parts = fullName.trim().split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    for (final p in parts) {
      if (!p.contains('.') && p.length > 1) return p;
    }
    return parts.isNotEmpty ? parts.last : 'Usuario';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF4A90E2) : const Color(0xFF04376E);

    final initials = _getInitials(userName);
    final firstName = _getFirstName(userName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Texto ──
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                firstName,
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              FutureBuilder(
                future: initializeDateFormatting('es_ES', null),
                builder: (context, snapshot) {
                  String d = snapshot.connectionState == ConnectionState.done
                      ? DateFormat('EEEE, dd MMM yyyy', 'es_ES')
                          .format(DateTime.now())
                      : DateFormat('dd/MM/yyyy').format(DateTime.now());
                  if (d.isNotEmpty) d = d[0].toUpperCase() + d.substring(1);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          d,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // ── Avatar con iniciales ──
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: accent.withOpacity(isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withOpacity(isDark ? 0.35 : 0.25),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.08);
  }
}
