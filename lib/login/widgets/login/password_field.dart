// Campo de contraseña reutilizable con soporte alfanumérico,
// visibilidad alternable y validación integrada.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_colors.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final bool autofocus;
  final bool alphanumeric;

  const PasswordField({
    super.key,
    required this.controller,
    required this.isDark,
    this.autofocus = true,
    this.alphanumeric = false,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contraseña',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white70 : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscurePassword,
          keyboardType:
              widget.alphanumeric ? TextInputType.text : TextInputType.number,
          autofocus: widget.autofocus,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Ingresa tu contraseña',
            hintStyle: GoogleFonts.inter(
              color: widget.isDark ? Colors.white38 : Colors.black38,
              fontSize: 14,
            ),
            filled: true,
            fillColor: widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white : AppColors.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: widget.isDark ? Colors.white70 : AppColors.primary,
              size: 22,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: widget.isDark ? Colors.white70 : AppColors.primary.withOpacity(0.6),
                size: 22,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingrese su contraseña';
            }
            if (value.length < 4) {
              return 'La contraseña debe tener al menos 4 caracteres';
            }
            return null;
          },
        ),
      ],
    );
  }
}
