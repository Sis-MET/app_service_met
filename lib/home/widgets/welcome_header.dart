// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';

class WelcomeHeader extends StatelessWidget {
  final String userName;
  const WelcomeHeader({super.key, required this.userName});

  Widget _buildGreetingRow(Color color) {
    final h = DateTime.now().hour;
    String text;
    IconData icon;
    if (h >= 5 && h < 12) {
      text = 'Buenos días';
      icon = Icons.wb_sunny_rounded;
    } else if (h >= 12 && h < 19) {
      text = 'Buenas tardes';
      icon = Icons.cloud_rounded;
    } else {
      text = 'Buenas noches';
      icon = Icons.nightlight_round;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 14, color: color),
      ],
    );
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              _buildGreetingRow(cs.onSurface.withOpacity(isDark ? 0.54 : 0.45)),
              const SizedBox(height: 4),
              Text(
                firstName,
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
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
                          ? AppColors.cardDark
                          : const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: cs.onSurface.withOpacity(0.38),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          d,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(isDark ? 0.54 : 0.45),
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
            color: cs.primary.withOpacity(isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cs.primary.withOpacity(isDark ? 0.35 : 0.25),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.08);
  }
}
