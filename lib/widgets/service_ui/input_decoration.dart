import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Decoración estándar de inputs estilo Calibración:
/// OutlineInputBorder radius 12, bordes sutiles, label Inter.
InputDecoration serviceInputDeco(String label, bool isDark,
        {Widget? prefixIcon, Widget? suffixIcon, String? hintText}) =>
    InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle:
          GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
    );

/// Header estándar de paso estilo Calibración:
/// título Poppins 26 w700 + subtítulo Inter 13.
class ServiceStepHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const ServiceStepHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

/// Header de sección dentro de un paso: Poppins 16 bold.
class ServiceSectionHeader extends StatelessWidget {
  final String title;

  const ServiceSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}
