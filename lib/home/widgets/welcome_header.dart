import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../theme/app_icons.dart';

class WelcomeHeader extends StatelessWidget {
  final String userName;
  final VoidCallback onSettings;

  const WelcomeHeader({
    super.key,
    required this.userName,
    required this.onSettings,
  });

  String _firstName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    for (final part in parts) {
      if (!part.contains('.') && part.length > 1) return part;
    }
    return parts.isEmpty ? 'Usuario' : parts.last;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final today = DateFormat('EEEE, d MMM', 'es_ES').format(DateTime.now());
    final formattedDate = today.isEmpty
        ? today
        : '${today[0].toUpperCase()}${today.substring(1)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 134,
              height: 42,
              child: Image.asset(
                'images/logo_met.png',
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                filterQuality: FilterQuality.high,
              ),
            ),
            const Spacer(),
            IconButton.outlined(
              tooltip: 'Configuración',
              onPressed: onSettings,
              icon: const Icon(AppIcons.ajustes, size: 20),
              style: IconButton.styleFrom(
                foregroundColor: dark ? Colors.white : AppDesign.ink,
                backgroundColor: AppColors.accentYellow.withOpacity(0.07),
                side: BorderSide(
                  color: AppColors.accentYellow.withOpacity(0.32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Text(
          '${_greeting()}, ${_firstName(userName)}',
          style: AppDesign.displayStyle(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          'Este es el estado de tu jornada de servicio.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.45,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: AppStatusPill(
            icon: AppIcons.calendario,
            label: formattedDate,
            color: dark ? Colors.white70 : AppDesign.muted,
          ),
        ),
      ],
    );
  }
}
