// Pantalla de inicio de sesión con soporte biométrico,
// auto-login seguro, y experiencia de usuario renovada.

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../models/user_model.dart';
import '../widgets/login/auto_login_loading.dart';
import '../widgets/login/login_form.dart';
import '../widgets/login/user_selector_dialog.dart';
import '../../services/database_maintenance_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();

  bool _loading = false;
  String? _savedUser;
  String? _savedUserFullName;
  bool _autoLoginEnabled = false;
  bool _isFirstLogin = true;
  bool _isAddingNewUser = false;

  // Estado biométrico
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _loadPrefsAndCheckAutoLogin();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passController.dispose();
    _userController.dispose();
    super.dispose();
  }

  // ── Verificar disponibilidad y estado biométrico ──
  Future<void> _checkBiometricStatus() async {
    final status = await _biometricService.checkFullStatus(_savedUser);

    if (mounted) {
      setState(() {
        _biometricAvailable = status.available;
        _biometricEnabled = status.enabled;
      });
    }
  }

  // ── Cargar preferencias y verificar auto-login ──
  Future<void> _loadPrefsAndCheckAutoLogin() async {
    final prefs = await _authService.loadPreferences();

    if (!mounted) return;

    setState(() {
      _savedUser = prefs['savedUser'];
      _savedUserFullName = prefs['savedUserFullName'];
      _autoLoginEnabled = prefs['autoLoginEnabled'];
      _isFirstLogin = prefs['isFirstLogin'];
    });

    if (_savedUser != null) {
      final exists = await _authService.userExists(_savedUser!);
      if (!exists) {
        await _clearSavedUser();
        if (!mounted) return;
        setState(() {
          _savedUser = null;
          _savedUserFullName = null;
          _autoLoginEnabled = false;
        });
      }
    }

    // Check biometric status now that we have _savedUser
    await _checkBiometricStatus();

    if (_savedUser != null) {
      if (_biometricAvailable && _biometricEnabled) {
        // Siempre solicitar biometría cuando está habilitada al abrir la app.
        // Un pequeño delay para que la UI se pinte primero.
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          await _performBiometricAutoLogin();
        }
      } else if (_autoLoginEnabled && _isFirstLogin) {
        // Auto-login con contraseña guardada (sin biometría)
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await _performAutoLogin();
        }
      }
    }
  }

  // ── Auto-login / solicitud biométrica al arranque ──
  Future<void> _performBiometricAutoLogin() async {
    // No ponemos _loading = true aquí para no mostrar el overlay de AutoLoginLoading;
    // queremos que el formulario quede visible debajo del modal del sistema.
    final authenticated = await _biometricService.authenticate(
      reason: 'Acceso rápido a ServiceMET',
    );

    if (!mounted) return;

    if (authenticated && _savedUser != null) {
      setState(() => _loading = true);
      final result = await _authService.loginWithBiometrics(_savedUser!);

      if (!mounted) return;

      if (result.success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_first_login', false);

        if (mounted) {
          _showSnackBar(context, result.message, AppColors.success);
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }

      // Si loginWithBiometrics falló, dejar al usuario intentar manualmente.
      setState(() => _loading = false);
    }
    // Si el usuario cancela el modal biométrico, simplemente vuelve al
    // formulario de contraseña con el botón de huella visible para reintentar.
  }

  // ── Auto-login tradicional ──
  Future<void> _performAutoLogin() async {
    setState(() => _loading = true);

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_login', false);

      if (!mounted) return;
      _showSnackBar(context, 'Bienvenido de vuelta', AppColors.success);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // ── Autenticación biométrica manual ──
  Future<void> _authenticateWithBiometrics() async {
    setState(() => _loading = true);

    final authenticated = await _biometricService.authenticate(
      reason: 'Acceso a ServiceMET con huella digital',
    );

    if (!mounted) return;

    if (!authenticated) {
      setState(() => _loading = false);
      _showSnackBar(
          context, 'Autenticación biométrica cancelada', Colors.orange);
      return;
    }

    if (_savedUser == null) {
      setState(() => _loading = false);
      _showSnackBar(context, 'No hay usuario seleccionado', Colors.red);
      return;
    }

    final result = await _authService.loginWithBiometrics(_savedUser!);

    setState(() => _loading = false);

    if (!mounted) return;

    if (result.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_login', false);

      _showSnackBar(context, result.message, AppColors.success);
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      if (result.message.contains('[ACCESO_DENEGADO]')) {
        _showAccessDeniedDialog(result.message);
      } else {
        _showSnackBar(context, result.message, Colors.red);
      }
    }
  }

  // ── Login con contraseña ──
  Future<void> _login(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    LoginResult result;

    if (_isAddingNewUser) {
      result = await _authService.addNewUser(
        usuario: _userController.text.trim(),
        password: _passController.text.trim(),
      );
    } else if (_savedUser != null) {
      result = await _authService.login(
        usuario: _savedUser,
        password: _passController.text.trim(),
        isChangingUser: false,
      );
    } else {
      result = LoginResult(
        success: false,
        message: 'No hay usuario seleccionado',
      );
    }

    setState(() => _loading = false);

    if (!mounted) return;

    if (result.success) {
      _showSnackBar(context, result.message, AppColors.success);

      if (_isAddingNewUser) {
        await _loadPrefsAndCheckAutoLogin();
        if (!mounted) return;
        setState(() => _isAddingNewUser = false);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_login', false);

      // Preguntar si desea habilitar biometría (solo si disponible y no habilitado)
      if (_biometricAvailable && !_biometricEnabled && _savedUser != null) {
        await _offerBiometricEnrollment();
        if (!mounted) return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      if (result.message.contains('[ACCESO_DENEGADO]')) {
        _showAccessDeniedDialog(result.message);
      } else {
        _showSnackBar(context, result.message, Colors.red);
      }
    }
  }

  // ── Ofrecer habilitar biometría tras login exitoso ──
  Future<void> _offerBiometricEnrollment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.fingerprint, color: AppColors.success),
            const SizedBox(width: 12),
            const Flexible(
              child: Text('¿Habilitar huella digital?'),
            ),
          ],
        ),
        content: const Text(
          'Puedes acceder rápidamente usando tu huella digital '
          'en lugar de ingresar tu contraseña cada vez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentYellow,
              foregroundColor: const Color(0xFF1A1A1A),
            ),
            child: const Text('Habilitar'),
          ),
        ],
      ),
    );

    if (confirm == true && _savedUser != null) {
      await _biometricService.enableBiometric(_savedUser!);
      if (mounted) {
        setState(() => _biometricEnabled = true);
        _showSnackBar(
            context, 'Huella digital habilitada correctamente', AppColors.success);
      }
    }
  }

  // ── Login demo ──
  Future<void> _loginDemo(BuildContext context) async {
    setState(() => _loading = true);

    await Future.delayed(const Duration(milliseconds: 800));
    await _authService.loginDemo();

    if (mounted) {
      _showSnackBar(
          context, 'Ingresando en Modo DESCONECTADO', Colors.orange);
      setState(() => _loading = false);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // ── Mostrar diálogo de acceso denegado ──
  void _showAccessDeniedDialog(String message) {
    final cleanMessage =
        message.replaceAll('[ACCESO_DENEGADO]', '').trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red[700]),
            const SizedBox(width: 10),
            const Text('Acceso Denegado'),
          ],
        ),
        content: Text(
          cleanMessage,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── SnackBar unificada ──
  void _showSnackBar(BuildContext context, String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ── Diálogo de reconfiguración ──
  Future<void> _showReconfigureDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.settings_backup_restore, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('Reconfigurar'),
          ],
        ),
        content: const Text(
          '¿Desea reconfigurar la aplicación? Esto eliminará la configuración '
          'actual y volverá a solicitar los datos de conexión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            child: const Text('Reconfigurar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.reconfigure();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/setup');
      }
    }
  }

  // ── Selector de usuarios ──
  Future<void> _showUserSelector(BuildContext context) async {
    final users = await _authService.getSavedUsers();

    if (users.isEmpty) {
      _showSnackBar(context, 'No hay usuarios guardados', Colors.orange);
      return;
    }

    if (!mounted) return;

    final selectedUser = await showDialog<UserModel>(
      context: context,
      builder: (dialogContext) => UserSelectorDialog(
        users: users,
        onDelete: (user) async {
          final success = await _authService.deleteUser(user.usuario);

          if (success) {
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext);
            }

            if (!mounted) return;

            if (user.usuario == _savedUser) {
              await _clearSavedUser();
              if (mounted) {
                setState(() {
                  _savedUser = null;
                  _savedUserFullName = null;
                  _biometricEnabled = false;
                });
              }
            }

            if (mounted) {
              _showSnackBar(context, 'Usuario eliminado', AppColors.success);
              await _loadPrefsAndCheckAutoLogin();
            }
          } else {
            if (mounted) {
              _showSnackBar(context, 'Error al eliminar usuario', Colors.red);
            }
          }
        },
      ),
    );

    if (selectedUser != null) {
      setState(() {
        _savedUser = selectedUser.usuario;
        _savedUserFullName = selectedUser.fullName;
        _isAddingNewUser = false;
        _passController.clear();
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_user', selectedUser.usuario);
      await prefs.setString('logged_user_nombre', selectedUser.fullName);

      // Actualizar estado biométrico para el nuevo usuario
      await _checkBiometricStatus();
    }
  }

  // ── Iniciar agregar nuevo usuario ──
  void _startAddingNewUser() {
    setState(() {
      _isAddingNewUser = true;
      _userController.clear();
      _passController.clear();
    });
  }

  // ── Cancelar agregar usuario ──
  void _cancelAddingUser() {
    setState(() {
      _isAddingNewUser = false;
      _userController.clear();
      _passController.clear();
    });
  }

  // ── Limpiar usuario guardado ──
  Future<void> _clearSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_user');
    await prefs.remove('logged_user_nombre');
    await prefs.remove('logged_user_titulo');
    await prefs.setBool('auto_login_enabled', false);
  }

  // ── Actualizar bases de datos locales ──
  Future<void> _showUpdateDatabaseDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.system_update_alt, color: Colors.blue[700]),
            const SizedBox(width: 10),
            const Text(
              'ACTUALIZAR BASES DE DATOS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: const Text(
          'Esta operación actualizará la estructura de las bases de datos '
          'preservando su información.\n\n'
          'Se realizará una copia de seguridad temporal, se recrearán las '
          'tablas y se restaurarán los datos.\n'
          '¿Desea continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;

      setState(() => _loading = true);
      _showSnackBar(context, 'Iniciando actualización...', Colors.blue);

      await Future.delayed(const Duration(milliseconds: 100));

      try {
        await DatabaseMaintenanceService.migrateAllDatabases();
        if (mounted) {
          _showSnackBar(
            context,
            'Bases de datos actualizadas correctamente',
            AppColors.success,
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar(context, 'Error al actualizar: $e', Colors.red);
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
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
          child: _loading && _autoLoginEnabled
              ? AutoLoginLoading(
                  isDark: isDark,
                  savedUserFullName: _savedUserFullName,
                  savedUser: _savedUser,
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: LoginForm(
                    formKey: _formKey,
                    passController: _passController,
                    userController: _userController,
                    isDark: isDark,
                    loading: _loading,
                    savedUser: _savedUser,
                    savedUserFullName: _savedUserFullName,
                    isAddingNewUser: _isAddingNewUser,
                    biometricAvailable: _biometricAvailable,
                    biometricEnabled: _biometricEnabled,
                    onLogin: () => _login(context),
                    onLoginDemo: () => _loginDemo(context),
                    onReconfigure: () => _showReconfigureDialog(context),
                    onShowUserSelector: () => _showUserSelector(context),
                    onStartAddingUser: _startAddingNewUser,
                    onCancelAddingUser: _cancelAddingUser,
                    onUpdateDatabases:
                        () => _showUpdateDatabaseDialog(context),
                    onBiometricAuth: _authenticateWithBiometrics,
                  ),
                ),
        ),
      ),
    );
  }
}
