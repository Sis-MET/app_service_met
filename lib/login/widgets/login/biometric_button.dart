// Botón animado para autenticación biométrica
// Diseño corporativo y elegante

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_colors.dart';

class BiometricButton extends StatefulWidget {
  final bool isDark;
  final bool isLoading;
  final VoidCallback onAuthenticate;

  const BiometricButton({
    super.key,
    required this.isDark,
    required this.isLoading,
    required this.onAuthenticate,
  });

  @override
  State<BiometricButton> createState() => _BiometricButtonState();
}

class _BiometricButtonState extends State<BiometricButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isDark ? Colors.white : AppColors.primary;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'o accede con',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: widget.isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: widget.isLoading ? null : widget.onAuthenticate,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isDark 
                    ? color.withOpacity(0.1 + (_pulseController.value * 0.05))
                    : color.withOpacity(0.05 + (_pulseController.value * 0.05)),
                  border: Border.all(
                    color: color.withOpacity(0.2 + (_pulseController.value * 0.2)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.05 + (_pulseController.value * 0.05)),
                      blurRadius: 8 + (_pulseController.value * 4),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 32,
                  color: widget.isDark ? Colors.white70 : color,
                ),
              );
            },
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        const SizedBox(height: 8),
        Text(
          'Huella digital',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: widget.isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
