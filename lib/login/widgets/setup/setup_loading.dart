import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_icons.dart';

class SetupLoading extends StatelessWidget {
  final bool isDark;
  final String statusMessage;
  final double progressValue;

  const SetupLoading({
    super.key,
    required this.isDark,
    required this.statusMessage,
    required this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progressValue.clamp(0, 1) * 100).round();
    final cardColor =
        isDark ? const Color(0xFFF1F1ED) : const Color(0xFF1C1C1C);
    final foreground = isDark ? Colors.black : Colors.white;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: foreground.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.actualizar,
                      color: foreground,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$percent%',
                    style: GoogleFonts.inter(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1.2,
                      color: foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                'Preparando ServiceMET',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                statusMessage,
                style: GoogleFonts.inter(
                  height: 1.4,
                  fontSize: 13,
                  color: foreground.withOpacity(0.58),
                ),
              ),
              const SizedBox(height: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progressValue.clamp(0, 1),
                  minHeight: 7,
                  backgroundColor: foreground.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
