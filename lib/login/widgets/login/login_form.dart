import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import 'password_field.dart';
import '../../../theme/app_icons.dart';

class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController passController;
  final TextEditingController userController;
  final bool loading;
  final String? savedUser;
  final String? savedUserFullName;
  final String? lastUpdate;
  final bool isAddingNewUser;
  final bool deviceAuthAvailable;
  final bool deviceAuthEnabled;
  final VoidCallback onSubmit;
  final VoidCallback onDeviceAuth;
  final VoidCallback onSelectUser;
  final VoidCallback onCancelAddingUser;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.passController,
    required this.userController,
    required this.loading,
    required this.savedUser,
    required this.savedUserFullName,
    required this.lastUpdate,
    required this.isAddingNewUser,
    required this.deviceAuthAvailable,
    required this.deviceAuthEnabled,
    required this.onSubmit,
    required this.onDeviceAuth,
    required this.onSelectUser,
    required this.onCancelAddingUser,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasUser = savedUser?.isNotEmpty == true;
    final enrollment = isAddingNewUser || !hasUser;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            enrollment ? 'Vincula tu acceso' : 'Bienvenido de nuevo',
            style: GoogleFonts.poppins(
              fontSize: 31,
              height: 1.08,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            enrollment
                ? 'Confirma tu usuario corporativo para preparar este dispositivo.'
                : 'Accede a tus servicios y continúa desde donde lo dejaste.',
            style: GoogleFonts.inter(
              height: 1.4,
              fontSize: 14,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 26),
          _AccessOverviewCard(
            enrollment: enrollment,
            status: enrollment
                ? 'Conexión interna requerida'
                : _offlineStatusLabel(),
          ),
          const SizedBox(height: 24),
          if (enrollment) ...[
            Text('USUARIO', style: _fieldLabel(colors)),
            const SizedBox(height: 8),
            TextFormField(
              controller: userController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: _fieldDecoration(
                context,
                hint: 'Usuario corporativo',
                icon: AppIcons.persona,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresa tu usuario'
                  : null,
            ),
            const SizedBox(height: 18),
          ] else ...[
            _UserTile(
              name: savedUserFullName ?? savedUser!,
              username: savedUser!,
              initials: _initials(savedUserFullName ?? savedUser!),
              loading: loading,
              onTap: onSelectUser,
            ),
            const SizedBox(height: 20),
          ],
          PasswordField(
            controller: passController,
            isDark: dark,
            autofocus: false,
          ),
          if (!enrollment && deviceAuthAvailable && deviceAuthEnabled) ...[
            const SizedBox(height: 12),
            Center(
              child: IconButton.filled(
                key: const ValueKey('biometric-login-button'),
                tooltip: 'Ingresar con huella',
                onPressed: loading ? null : onDeviceAuth,
                style: IconButton.styleFrom(
                  fixedSize: const Size(56, 56),
                  backgroundColor: AppColors.actionPositive,
                  foregroundColor: AppColors.actionPositiveInk,
                  disabledBackgroundColor:
                      AppColors.actionPositive.withOpacity(0.42),
                ),
                icon: const Icon(AppIcons.huella, size: 30),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: loading ? null : onSubmit,
              style: AppDesign.positiveButtonStyle(),
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.actionPositiveInk,
                      ),
                    )
                  : Text(
                      enrollment ? 'Vincular usuario' : 'Ingresar',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          if (isAddingNewUser && hasUser) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: loading ? null : onCancelAddingUser,
              child: const Text('Cancelar'),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? Colors.white24 : Colors.black12;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: dark ? Colors.white.withOpacity(0.06) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: dark ? Colors.white : Colors.black,
          width: 1.4,
        ),
      ),
    );
  }

  TextStyle _fieldLabel(ColorScheme colors) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: colors.onSurfaceVariant,
      );

  String _offlineStatusLabel() {
    final parsed = DateTime.tryParse(lastUpdate ?? '');
    if (parsed == null) return 'Datos offline disponibles';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return 'Datos actualizados $day/$month';
  }

  String _initials(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .where((word) => word.isNotEmpty)
        .map((word) => word[0])
        .join()
        .toUpperCase();
  }
}

class _AccessOverviewCard extends StatelessWidget {
  final bool enrollment;
  final String status;

  const _AccessOverviewCard({required this.enrollment, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 178,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -34,
            child: SizedBox(
              width: 150,
              height: 150,
              child: CustomPaint(painter: _DialPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                enrollment ? 'Acceso verificado' : 'Trabajo de campo',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                enrollment
                    ? 'Una sola configuración'
                    : 'Disponible incluso sin conexión',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String name;
  final String username;
  final String initials;
  final bool loading;
  final VoidCallback onTap;

  const _UserTile({
    required this.name,
    required this.username,
    required this.initials,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? Colors.white.withOpacity(0.06) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dark ? Colors.white24 : Colors.black12),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentYellow.withOpacity(dark ? 0.05 : 0.1),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dark ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    color: dark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@$username',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(AppIcons.desplegar),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.2;
    for (var index = 0; index < 40; index++) {
      final angle = index * 6.28318530718 / 40;
      final inner = radius - (index % 5 == 0 ? 13 : 7);
      canvas.drawLine(
        center + Offset.fromDirection(angle, inner),
        center + Offset.fromDirection(angle, radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
