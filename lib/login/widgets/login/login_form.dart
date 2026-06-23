// Formulario de login rediseñado con glassmorphism, biometría
// y experiencia de usuario corporativa.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:service_met/theme/app_colors.dart';
import 'user_card.dart';
import 'password_field.dart';
import 'biometric_button.dart';

class LoginForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController passController;
  final TextEditingController userController;
  final bool isDark;
  final bool loading;
  final String? savedUser;
  final String? savedUserFullName;
  final bool isAddingNewUser;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final VoidCallback onLogin;
  final VoidCallback onLoginDemo;
  final VoidCallback onReconfigure;
  final VoidCallback onShowUserSelector;
  final VoidCallback onStartAddingUser;
  final VoidCallback onCancelAddingUser;
  final VoidCallback onUpdateDatabases;
  final VoidCallback onBiometricAuth;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.passController,
    required this.userController,
    required this.isDark,
    required this.loading,
    this.savedUser,
    this.savedUserFullName,
    required this.isAddingNewUser,
    required this.onLogin,
    required this.onLoginDemo,
    required this.onReconfigure,
    required this.onShowUserSelector,
    required this.onStartAddingUser,
    required this.onCancelAddingUser,
    required this.onUpdateDatabases,
    required this.onBiometricAuth,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = info.version);
      }
    } catch (_) {
      _appVersion = '1.0.0';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUsers = widget.savedUser != null && widget.savedUser!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 48),

          // ── Logo con glow sutil ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.cardDark.withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isDark
                    ? AppColors.borderDark.withOpacity(0.5)
                    : AppColors.borderLight.withOpacity(0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDark ? 0.25 : 0.06),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Image.asset('images/logo_met.png', height: 72),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0),

          const SizedBox(height: 32),

          // ── Card principal (Glassmorphism) ──
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.surfaceDark.withOpacity(0.6)
                      : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: widget.isDark
                        ? AppColors.glassBorder
                        : Colors.white.withOpacity(0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(widget.isDark ? 0.3 : 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: widget.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      Text(
                        'Bienvenido',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                      const SizedBox(height: 4),

                      Text(
                        widget.isAddingNewUser
                            ? 'Ingresa credenciales del nuevo usuario'
                            : hasUsers
                                ? 'Ingresa tu contraseña para continuar'
                                : 'Agrega tu primer usuario para comenzar',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color:
                              widget.isDark ? Colors.white70 : Colors.black54,
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

                      const SizedBox(height: 28),

                      // ── Campo de usuario (nuevo o sin usuarios) ──
                      if (widget.isAddingNewUser || !hasUsers) ...[
                        _buildLabel('Usuario'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: widget.userController,
                          autofocus: true,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color:
                                widget.isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: _buildInputDecoration(
                            hint: 'Ingresa el usuario',
                            icon: Icons.person_outline,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese el usuario';
                            }
                            return null;
                          },
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                        const SizedBox(height: 20),
                      ],

                      // ── Usuario guardado ──
                      if (hasUsers && !widget.isAddingNewUser) ...[
                        UserCard(
                          isDark: widget.isDark,
                          savedUser: widget.savedUser!,
                          savedUserFullName: widget.savedUserFullName,
                          onShowUserSelector: widget.onShowUserSelector,
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                        const SizedBox(height: 20),
                      ],

                      // ── Campo de contraseña ──
                      PasswordField(
                        controller: widget.passController,
                        isDark: widget.isDark,
                        autofocus: hasUsers && !widget.isAddingNewUser,
                      ).animate().fadeIn(duration: 400.ms, delay: 250.ms),

                      const SizedBox(height: 32),

                      // ── Botón principal ──
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 36, 92, 45),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: AppColors.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: widget.loading ? null : widget.onLogin,
                          child: widget.loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      widget.isAddingNewUser || !hasUsers
                                          ? Icons.person_add_outlined
                                          : Icons.login_outlined,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.isAddingNewUser || !hasUsers
                                          ? 'Agregar Usuario'
                                          : 'Iniciar sesión',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                      // ── Botón cancelar ──
                      if (widget.isAddingNewUser && hasUsers) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: widget.onCancelAddingUser,
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: widget.isDark
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

          // ── Separador biométrico ──
          if (widget.biometricAvailable &&
              widget.biometricEnabled &&
              hasUsers) ...[
            const SizedBox(height: 24),
            BiometricButton(
              isDark: widget.isDark,
              isLoading: widget.loading,
              onAuthenticate: widget.onBiometricAuth,
            ),
          ],

          const SizedBox(height: 24),

          // ── Acciones secundarias ──
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!widget.isAddingNewUser && hasUsers)
                _buildActionChip(
                  icon: Icons.people_alt_outlined,
                  label: 'Cambiar Usuario',
                  onPressed: widget.loading ? null : widget.onStartAddingUser,
                  color: widget.isDark ? Colors.white70 : AppColors.primary,
                ),
              _buildActionChip(
                icon: Icons.cloud_off_outlined,
                label: 'Offline',
                onPressed: widget.loading ? null : widget.onLoginDemo,
                color: const Color(0xFFFF9800),
              ),
              _buildActionChip(
                icon: Icons.sync_rounded,
                label: 'Actualizar BD',
                onPressed: widget.loading ? null : widget.onUpdateDatabases,
                color: widget.isDark ? Colors.white70 : AppColors.primary,
              ),
              _buildActionChip(
                icon: Icons.settings_outlined,
                label: 'Reconfigurar',
                onPressed: widget.loading ? null : widget.onReconfigure,
                color: widget.isDark ? Colors.white70 : AppColors.primary,
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 350.ms),

          const SizedBox(height: 32),

          // ── Footer ──
          Column(
            children: [
              if (_appVersion != null)
                Text(
                  'versión $_appVersion',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'DESARROLLADO POR: J.FARFAN',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: widget.isDark ? Colors.white30 : Colors.black26,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '© ${DateTime.now().year} METRICA LTDA',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: widget.isDark ? Colors.white30 : Colors.black26,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Label de campo ──
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: widget.isDark ? Colors.white70 : AppColors.textPrimaryLight,
      ),
    );
  }

  // ── Decoración de input ──
  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
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
      prefixIcon: Icon(icon,
          color: widget.isDark ? Colors.white70 : AppColors.primary, size: 22),
    );
  }

  // ── Chip de acción secundaria ──
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
