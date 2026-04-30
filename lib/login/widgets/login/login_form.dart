// lib/login/widgets/login/login_form.dart - VERSIÓN SIMPLIFICADA

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_card.dart';
import 'password_field.dart';

class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController passController;
  final TextEditingController userController;
  final bool isDark;
  final bool loading;
  final String? savedUser;
  final String? savedUserFullName;
  final bool isAddingNewUser;
  final VoidCallback onLogin;
  final VoidCallback onLoginDemo;
  final VoidCallback onReconfigure;
  final VoidCallback onShowUserSelector;
  final VoidCallback onStartAddingUser;
  final VoidCallback onCancelAddingUser;
  final VoidCallback onUpdateDatabases;

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
  });

  @override
  Widget build(BuildContext context) {
    // LÓGICA SIMPLIFICADA
    final hasUsers = savedUser != null && savedUser!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // Declaramos el acento una vez para usarlo
          Builder(builder: (context) {
            final accent = isDark ? const Color(0xFF4A90E2) : const Color(0xFF04376E);
            return Column(
              children: [
          const SizedBox(height: 40),

          // Logo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset('images/logo_met.png', height: 80),
          ),
          const SizedBox(height: 40),

          // Card principal
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido.',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAddingNewUser
                        ? 'Ingresa credenciales del nuevo usuario'
                        : hasUsers
                            ? 'Ingresa tu contraseña para continuar'
                            : 'Agrega tu primer usuario para comenzar',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // CAMPO USUARIO (solo si está agregando O no hay usuarios)
                  if (isAddingNewUser || !hasUsers) ...[
                    Text(
                      'Usuario',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: userController,
                      autofocus: true,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ingresa el usuario',
                        hintStyle: GoogleFonts.inter(
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1a1a1a)
                            : const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        prefixIcon: Icon(
                          Icons.person_add_outlined,
                          color: isDark ? Colors.white70 : Colors.black38,
                          size: 22,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese el usuario';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // USUARIO GUARDADO (solo si hay usuarios Y no está agregando)
                  if (hasUsers && !isAddingNewUser) ...[
                    UserCard(
                      isDark: isDark,
                      savedUser: savedUser!,
                      savedUserFullName: savedUserFullName,
                      onShowUserSelector: onShowUserSelector,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Campo Contraseña
                  PasswordField(
                    controller: passController,
                    isDark: isDark,
                    autofocus: hasUsers && !isAddingNewUser,
                  ),
                  const SizedBox(height: 28),

                  // Botón principal
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: loading ? null : onLogin,
                      child: loading
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
                                  isAddingNewUser || !hasUsers
                                      ? Icons.person_add
                                      : Icons.login,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isAddingNewUser || !hasUsers
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
                  ),

                  // Botón cancelar (solo si está agregando Y hay usuarios guardados)
                  if (isAddingNewUser && hasUsers) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: onCancelAddingUser,
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Acciones secundarias en un Wrap limpio
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!isAddingNewUser && hasUsers)
                _buildSecondaryButton(
                  icon: Icons.person_add_outlined,
                  label: 'Cambiar Usuario',
                  onPressed: loading ? null : onStartAddingUser,
                  color: isDark ? Colors.white70 : Colors.black54,
                  isDark: isDark,
                ),
              _buildSecondaryButton(
                icon: Icons.science_outlined,
                label: 'Offline',
                onPressed: loading ? null : onLoginDemo,
                color: const Color(0xFFFF9800),
                isDark: isDark,
              ),
              _buildSecondaryButton(
                icon: Icons.system_update_alt,
                label: 'Actualizar BD',
                onPressed: loading ? null : onUpdateDatabases,
                color: isDark ? Colors.white60 : Colors.black45,
                isDark: isDark,
              ),
              _buildSecondaryButton(
                icon: Icons.settings_backup_restore,
                label: 'Reconfigurar',
                onPressed: loading ? null : onReconfigure,
                color: isDark ? Colors.white60 : Colors.black45,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Footer
          Column(
            children: [
              Text(
                'versión 4.8.3',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DESARROLLADO POR: J.FARFAN',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white30 : Colors.black26,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '© 2026 METRICA LTDA',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white30 : Colors.black26,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      );
    }),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.15),
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
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
