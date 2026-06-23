// Pantalla de configuración inicial (setup wizard).
// Flujo en 2 pasos: 1) Conexión BD por perfiles → 2) Credenciales de usuario.
// Diseño renovado con perfiles de conexión guardables y reutilizables.

// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_met/theme/app_colors.dart';
import '../services/setup_service.dart';
import '../services/connection_profile_service.dart';
import '../widgets/setup/setup_loading.dart';
import '../widgets/setup/step_indicator.dart';
import '../widgets/setup/connection_step.dart';
import '../widgets/setup/user_credentials_step.dart';
import '../widgets/setup/info_card.dart';

class InitialSetupScreen extends StatefulWidget {
  final bool isUpdateMode;

  const InitialSetupScreen({
    super.key,
    this.isUpdateMode = false,
  });

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final SetupService _setupService = SetupService();

  // Controladores - Usuario App
  final TextEditingController _appUserController = TextEditingController();
  final TextEditingController _appPassController = TextEditingController();

  int _currentStep = 0;
  bool _loading = false;

  String _statusMessage = '';
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();
    // Inicializar perfiles de conexión si no se ha hecho
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionProfileService>().inicializar();
    });
  }

  @override
  void dispose() {
    _appUserController.dispose();
    _appPassController.dispose();
    _setupService.disconnect();
    super.dispose();
  }

  // ── Ejecutar configuración ──
  Future<void> _executeSetup(BuildContext context) async {
    // Paso 1: Conexión BD
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;

      final profileService = context.read<ConnectionProfileService>();
      final valores = profileService.getValoresConexion();

      if (valores['ip']!.isEmpty) {
        _showError(context, 'Selecciona o crea un perfil de conexión primero');
        return;
      }

      setState(() => _loading = true);

      final result = await _setupService.validateConnection(
        ip: valores['ip']!,
        port: valores['port']!,
        database: valores['database']!,
        username: valores['username']!,
        password: valores['password']!,
      );

      if (!result.success) {
        _showError(context, result.message);
        setState(() => _loading = false);
        return;
      }

      if (widget.isUpdateMode) {
        await _setupService.saveConfiguration(
          ip: valores['ip']!,
          port: valores['port']!,
          database: valores['database']!,
          dbUser: valores['username']!,
          dbPass: valores['password']!,
        );

        setState(() => _loading = false);

        if (mounted) {
          _showSuccess(context, 'Conexión actualizada correctamente');
          Navigator.pop(context);
        }
        return;
      }

      setState(() {
        _currentStep = 1;
        _loading = false;
      });

      return;
    }

    // Paso 2: Credenciales de usuario
    if (_currentStep == 1) {
      if (!_formKey.currentState!.validate()) return;

      setState(() => _loading = true);

      try {
        // 1. Validar usuario en SQL Server
        final userResult = await _setupService.validateUserInServer(
          _appUserController.text.trim(),
          _appPassController.text.trim(),
        );

        if (!userResult.success || userResult.userData == null) {
          _showError(context, userResult.message);
          setState(() => _loading = false);
          return;
        }

        // 2. Guardar usuario autenticado en SQLite
        final saveResult =
            await _setupService.saveAuthenticatedUser(userResult.userData!);

        if (!saveResult.success) {
          _showError(context, saveResult.message);
          setState(() => _loading = false);
          return;
        }

        // 3. Descargar datos de precarga
        final downloadResult = await _setupService.downloadPrecargaData(
          (message, progress) {
            setState(() {
              _statusMessage = message;
              _progressValue = progress;
            });
          },
        );

        if (!downloadResult.success) {
          _showError(context, downloadResult.message);
          setState(() => _loading = false);
          return;
        }

        // 4. Guardar configuración de conexión (desde el perfil activo)
        final profileService = context.read<ConnectionProfileService>();
        final valores = profileService.getValoresConexion();

        await _setupService.saveConfiguration(
          ip: valores['ip']!,
          port: valores['port']!,
          database: valores['database']!,
          dbUser: valores['username']!,
          dbPass: valores['password']!,
        );

        // 5. Completado
        setState(() {
          _statusMessage = 'Configuración completada exitosamente';
          _progressValue = 1.0;
        });

        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          await _setupService.disconnect();
          _showSuccess(context, 'Todo listo. Inicia sesión.');
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        _showError(context, 'Error en configuración: ${e.toString()}');
        setState(() => _loading = false);
      }

      return;
    }
  }

  void _showError(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppColors.loginBgDark,
                    AppColors.loginBgDarkEnd,
                  ]
                : [
                    AppColors.loginBgLight,
                    AppColors.loginBgLight,
                  ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? SetupLoading(
                  isDark: isDark,
                  statusMessage: _statusMessage,
                  progressValue: _progressValue,
                )
              : _buildSetupForm(context, isDark),
        ),
      ),
    );
  }

  Widget _buildSetupForm(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Logo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              'images/logo_met.png',
              height: 72,
            ),
          ),

          const SizedBox(height: 28),

          // Indicador de pasos
          StepIndicator(
            currentStep: _currentStep,
            isDark: isDark,
          ),

          const SizedBox(height: 24),

          // Card principal del formulario
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark 
                      ? AppColors.surfaceDark.withOpacity(0.6) 
                      : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? AppColors.glassBorder
                        : Colors.white.withOpacity(0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: _currentStep == 0
                      ? ConnectionStep(
                          isDark: isDark,
                          loading: _loading,
                          onContinue: () => _executeSetup(context),
                        )
                      : UserCredentialsStep(
                          isDark: isDark,
                          loading: _loading,
                          appUserController: _appUserController,
                          appPassController: _appPassController,
                          onBack: () => setState(() => _currentStep = 0),
                          onFinish: () => _executeSetup(context),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Card de información del paso actual
          InfoCard(
            isDark: isDark,
            currentStep: _currentStep,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
