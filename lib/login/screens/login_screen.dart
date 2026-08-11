import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/connection_profile_service.dart';
import '../widgets/login/login_form.dart';
import '../widgets/login/user_selector_dialog.dart';
import 'initial_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _userController = TextEditingController();
  final _authService = AuthService();
  final _deviceAuth = BiometricService();

  bool _initializing = true;
  bool _loading = false;
  bool _addingUser = false;
  bool _deviceAuthAvailable = false;
  bool _deviceAuthEnabled = false;
  bool _authenticatingDevice = false;
  bool _automaticDeviceAuthAttempted = false;
  String? _savedUser;
  String? _savedUserFullName;
  String? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _userController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _authService.migrateDatabase();
    final prefs = await _authService.loadPreferences();
    var savedUser = prefs['savedUser'] as String?;
    if (savedUser != null && !await _authService.userExists(savedUser)) {
      savedUser = null;
      await _authService.changeUser();
    }
    final status = await _deviceAuth.checkFullStatus(savedUser);
    final legacyPrefs = await SharedPreferences.getInstance();
    await legacyPrefs.remove('modoDemo');
    await legacyPrefs.remove('auto_login_enabled');
    await legacyPrefs.remove('is_first_login');
    if (!mounted) return;
    setState(() {
      _savedUser = savedUser;
      _savedUserFullName =
          savedUser == null ? null : prefs['savedUserFullName'] as String?;
      _lastUpdate = prefs['lastUpdate'] as String?;
      _deviceAuthAvailable = status.available;
      _deviceAuthEnabled = status.enabled;
      _initializing = false;
    });
    if (status.available && status.enabled && savedUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _automaticDeviceAuthAttempted) return;
        _automaticDeviceAuthAttempted = true;
        _unlockWithDevice();
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _loading = true);
    LoginResult result;
    if (_addingUser || _savedUser == null) {
      final profile =
          context.read<ConnectionProfileService>().perfilSeleccionado;
      if (profile == null || profile.apiUrl.isEmpty) {
        result = const LoginResult(
          success: false,
          message: 'Selecciona un servidor antes de vincular el usuario.',
        );
      } else {
        result = await _authService.addNewUser(
          apiUrl: profile.apiUrl,
          usuario: _userController.text.trim(),
          password: _passwordController.text,
        );
      }
    } else {
      result = await _authService.login(
        usuario: _savedUser,
        password: _passwordController.text,
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.success) {
      _showMessage(result.message, error: true);
      return;
    }
    if (_addingUser || _savedUser == null) {
      await _reloadSelectedUser();
    }
    if (_deviceAuthAvailable && !_deviceAuthEnabled && _savedUser != null) {
      await _offerDeviceUnlock();
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _unlockWithDevice() async {
    final user = _savedUser;
    if (user == null || _loading || _authenticatingDevice) return;
    setState(() => _authenticatingDevice = true);
    final authenticated = await _deviceAuth.authenticate(
      reason: 'Usa tu huella para ingresar a ServiceMET',
    );
    if (!mounted) return;
    setState(() => _authenticatingDevice = false);
    if (!authenticated) return;
    setState(() => _loading = true);
    final result = await _authService.loginWithBiometrics(user);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.success) {
      _showMessage(result.message, error: true);
      return;
    }
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _offerDeviceUnlock() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.fingerprint_rounded, size: 34),
        title: const Text('Acceso rápido y seguro'),
        content: const Text(
          '¿Quieres usar la huella, rostro, PIN o patrón configurado en este dispositivo para futuros accesos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Habilitar'),
          ),
        ],
      ),
    );
    if (accepted == true && _savedUser != null) {
      await _deviceAuth.enableBiometric(_savedUser!);
      if (mounted) setState(() => _deviceAuthEnabled = true);
    }
  }

  Future<void> _reloadSelectedUser() async {
    final prefs = await _authService.loadPreferences();
    final user = prefs['savedUser'] as String?;
    final status = await _deviceAuth.checkFullStatus(user);
    if (!mounted) return;
    setState(() {
      _savedUser = user;
      _savedUserFullName = prefs['savedUserFullName'] as String?;
      _addingUser = false;
      _deviceAuthAvailable = status.available;
      _deviceAuthEnabled = status.enabled;
      _passwordController.clear();
      _userController.clear();
    });
  }

  Future<void> _selectUser() async {
    final users = await _authService.getSavedUsers();
    if (!mounted) return;
    var addRequested = false;
    final selected = await showModalBottomSheet<UserModel>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => UserSelectorSheet(
        users: users,
        selectedUsername: _savedUser,
        onAdd: () {
          addRequested = true;
          Navigator.pop(sheetContext);
        },
        onDelete: (user) async {
          final fallback = await _authService.deleteUser(user.usuario);
          final biometricUser = await _deviceAuth.getBiometricUser();
          if (biometricUser == user.usuario) {
            await _deviceAuth.disableBiometric();
          }
          return fallback;
        },
      ),
    );
    if (selected == null) {
      if (addRequested) {
        _beginAddingUser();
        return;
      }
      await _reloadSelectedUser();
      return;
    }
    await _authService.selectUser(selected);
    await _reloadSelectedUser();
  }

  void _beginAddingUser() {
    if (!mounted) return;
    setState(() {
      _addingUser = true;
      _userController.clear();
      _passwordController.clear();
    });
  }

  Future<void> _showOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Vincular otro usuario'),
                subtitle: const Text('Requiere conexión al servidor'),
                onTap: () => Navigator.pop(sheetContext, 'add'),
              ),
              if (_savedUser != null)
                ListTile(
                  leading: const Icon(Icons.people_outline_rounded),
                  title: const Text('Cambiar usuario'),
                  onTap: () => Navigator.pop(sheetContext, 'switch'),
                ),
              ListTile(
                leading: const Icon(Icons.settings_ethernet_rounded),
                title: const Text('Configurar servidor'),
                onTap: () => Navigator.pop(sheetContext, 'setup'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'add':
        _beginAddingUser();
      case 'switch':
        await _selectUser();
      case 'setup':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InitialSetupScreen(isUpdateMode: true),
          ),
        );
    }
  }

  void _showMessage(String message, {required bool error}) {
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
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF101010) : const Color(0xFFFAFAF8),
      body: SafeArea(
        child: _initializing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            IconButton.outlined(
                              tooltip: 'Opciones de acceso',
                              onPressed: _loading || _authenticatingDevice
                                  ? null
                                  : _showOptions,
                              icon: const Icon(Icons.tune_rounded, size: 20),
                              style: IconButton.styleFrom(
                                foregroundColor:
                                    dark ? Colors.white : Colors.black,
                                side: BorderSide(
                                  color: dark ? Colors.white24 : Colors.black12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 34),
                        LoginForm(
                          formKey: _formKey,
                          passController: _passwordController,
                          userController: _userController,
                          loading: _loading || _authenticatingDevice,
                          savedUser: _savedUser,
                          savedUserFullName: _savedUserFullName,
                          lastUpdate: _lastUpdate,
                          isAddingNewUser: _addingUser,
                          deviceAuthAvailable: _deviceAuthAvailable,
                          deviceAuthEnabled: _deviceAuthEnabled,
                          onSubmit: _submit,
                          onDeviceAuth: _unlockWithDevice,
                          onSelectUser: _selectUser,
                          onCancelAddingUser: () => setState(() {
                            _addingUser = false;
                            _passwordController.clear();
                          }),
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
