import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../services/connection_profile_service.dart';
import '../services/setup_service.dart';
import '../widgets/setup/connection_profile_selector.dart';
import '../widgets/setup/setup_loading.dart';
import '../../theme/app_icons.dart';

class InitialSetupScreen extends StatefulWidget {
  final bool isUpdateMode;

  const InitialSetupScreen({super.key, this.isUpdateMode = false});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _setupService = SetupService();
  int _step = 0;
  bool _loading = false;
  String _status = '';
  double _progress = 0;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final profile = context.read<ConnectionProfileService>().perfilSeleccionado;
    if (_step == 0) {
      if (profile == null || profile.apiUrl.isEmpty) {
        _message('Selecciona un servidor para continuar.', error: true);
        return;
      }
      setState(() {
        _loading = true;
        _status = 'Comprobando servidor...';
        _progress = 0.25;
      });
      final result =
          await _setupService.validateConnection(apiUrl: profile.apiUrl);
      if (!mounted) return;
      if (!result.success) {
        setState(() => _loading = false);
        _message(result.message, error: true);
        return;
      }
      if (widget.isUpdateMode) {
        await _setupService.saveConfiguration(apiUrl: profile.apiUrl);
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }
      setState(() {
        _step = 1;
        _loading = false;
      });
      return;
    }

    if (_formKey.currentState?.validate() != true || profile == null) return;
    setState(() {
      _loading = true;
      _status = 'Iniciando configuración...';
      _progress = 0;
    });
    final result = await _setupService.configureDevice(
      apiUrl: profile.apiUrl,
      usuario: _userController.text.trim(),
      password: _passwordController.text,
      onProgress: (message, progress) {
        if (!mounted) return;
        setState(() {
          _status = message;
          _progress = progress;
        });
      },
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() => _loading = false);
      _message(result.message, error: true);
      return;
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _message(String message, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : Colors.black;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF101010) : const Color(0xFFFAFAF8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _step == 1
            ? IconButton(
                onPressed: _loading ? null : () => setState(() => _step = 0),
                icon: const Icon(AppIcons.atras),
              )
            : widget.isUpdateMode
                ? const BackButton()
                : null,
      ),
      // Sin SafeArea abajo: la lista pasa por detrás de la barra de
      // navegación, como en el inicio.
      body: SafeArea(
        top: false,
        bottom: false,
        child: _loading
            ? SetupLoading(
                isDark: dark,
                statusMessage: _status,
                progressValue: _progress,
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                          20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: dark
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                widget.isUpdateMode
                                    ? 'SERVIDOR'
                                    : '${_step + 1} DE 2',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            for (var index = 0; index < 2; index++) ...[
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: index <= _step
                                        ? foreground
                                        : dark
                                            ? Colors.white12
                                            : Colors.black12,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                              if (index == 0) const SizedBox(width: 8),
                            ],
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text(
                          _step == 0
                              ? 'Configura tu espacio de trabajo'
                              : 'Vincula tu usuario',
                          style: GoogleFonts.poppins(
                            fontSize: 31,
                            height: 1.08,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _step == 0
                              ? 'Selecciona cómo llegar a la API interna desde este dispositivo.'
                              : 'Validaremos tu acceso y prepararemos los datos para trabajar sin conexión.',
                          style: GoogleFonts.inter(
                            height: 1.4,
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _SetupOverviewCard(step: _step, dark: dark),
                        const SizedBox(height: 20),
                        if (_step == 0)
                          ConnectionProfileSelector(isDark: dark)
                        else
                          _CredentialsPanel(
                            userController: _userController,
                            passwordController: _passwordController,
                            dark: dark,
                            onSubmitted: _continue,
                          ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: _continue,
                            style: AppDesign.positiveButtonStyle(),
                            child: Text(
                              _step == 0
                                  ? 'Comprobar y continuar'
                                  : 'Validar y preparar datos',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _SetupOverviewCard extends StatelessWidget {
  final int step;
  final bool dark;

  const _SetupOverviewCard({required this.step, required this.dark});

  @override
  Widget build(BuildContext context) {
    final background = dark ? const Color(0xFFF1F1ED) : const Color(0xFF1C1C1C);
    final foreground = dark ? Colors.black : Colors.white;
    return Container(
      height: 164,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step == 0 ? 'CONEXIÓN INTERNA' : 'ACCESO SEGURO',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: foreground.withOpacity(0.55),
                  ),
                ),
                const Spacer(),
                Text(
                  step == 0 ? 'Local o VPN' : 'Una sola vez',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.7,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step == 0
                      ? 'Elige la red disponible'
                      : 'Luego podrás trabajar offline',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: foreground.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: foreground.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step == 0 ? AppIcons.red : AppIcons.seguridadVerificada,
              color: foreground,
              size: 29,
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialsPanel extends StatelessWidget {
  final TextEditingController userController;
  final TextEditingController passwordController;
  final bool dark;
  final VoidCallback onSubmitted;

  const _CredentialsPanel({
    required this.userController,
    required this.passwordController,
    required this.dark,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? Colors.white24 : Colors.black12;
    InputDecoration decoration(String label, IconData icon) => InputDecoration(
          labelText: label,
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

    return Column(
      children: [
        TextFormField(
          controller: userController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          decoration: decoration('Usuario', AppIcons.persona),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Ingresa tu usuario'
              : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: passwordController,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => onSubmitted(),
          decoration: decoration('Contraseña', AppIcons.bloqueado),
          validator: (value) =>
              value == null || value.isEmpty ? 'Ingresa tu contraseña' : null,
        ),
      ],
    );
  }
}
