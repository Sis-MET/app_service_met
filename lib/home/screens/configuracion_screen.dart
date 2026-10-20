import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../login/widgets/setup/connection_profile_selector.dart';
import '../../providers/settings_provider.dart';
import '../../screens/respaldo/respaldo.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../theme/app_icons.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  String appVersion = '6.4.1';
  String appName = 'ServiceMET';
  bool syncBackground = true;
  bool notifications = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      appVersion = info.version;
      appName = info.appName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Abajo sin SafeArea: la lista pasa por detrás de la barra de
      // navegación, como en el inicio, y su margen deja libre lo último.
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppDesign.pagePadding,
            14,
            AppDesign.pagePadding,
            36 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: 30),
                    Text('Ajustes', style: AppDesign.displayStyle(context)),
                    const SizedBox(height: 8),
                    Text(
                      'Personaliza ServiceMET y administra los datos de este dispositivo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppStatusPill(
                        icon: AppIcons.verificado,
                        label: 'Versión $appVersion',
                        color: AppColors.actionPositive,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _sectionTitle(context, 'Apariencia'),
                    const SizedBox(height: 10),
                    AppPanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _themeModeSelector(
                            context,
                            selectedMode: settings.themeMode,
                            isDark: dark,
                            onChanged: settings.setThemeMode,
                          ),
                          _divider(context),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _settingIcon(AppIcons.texto),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Tamaño del texto',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${(settings.textScaleFactor * 100).round()}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.actionPositive,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: settings.textScaleFactor,
                                  min: 0.8,
                                  max: 1.4,
                                  divisions: 6,
                                  activeColor: AppColors.actionPositive,
                                  label: settings.textScaleFactor
                                      .toStringAsFixed(1),
                                  onChanged: settings.setTextScale,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle(context, 'Actividad'),
                    const SizedBox(height: 10),
                    AppPanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _switchTile(
                            context,
                            icon: AppIcons.actualizar,
                            title: 'Sincronización automática',
                            subtitle: 'Mantener actualizados los datos locales',
                            value: syncBackground,
                            onChanged: (value) =>
                                setState(() => syncBackground = value),
                          ),
                          _divider(context),
                          _switchTile(
                            context,
                            icon: AppIcons.notificaciones,
                            title: 'Notificaciones',
                            subtitle: 'Avisos de tareas y mantenimientos',
                            value: notifications,
                            onChanged: (value) =>
                                setState(() => notifications = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle(context, 'Datos y conexión'),
                    const SizedBox(height: 10),
                    AppPanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _actionTile(
                            context,
                            icon: AppIcons.respaldo,
                            title: 'Respaldo de datos',
                            subtitle:
                                'Crear o restaurar una copia de seguridad',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RespaldoScreen(),
                              ),
                            ),
                          ),
                          _divider(context),
                          _actionTile(
                            context,
                            icon: AppIcons.servidor,
                            title: 'Conexión al servidor',
                            subtitle: 'Red Local/VPN y dirección de la API',
                            onTap: () => _showConnectionProfiles(dark),
                          ),
                          _divider(context),
                          _actionTile(
                            context,
                            icon: AppIcons.persona,
                            title: 'Perfil de usuario',
                            subtitle: 'Credenciales y acceso local',
                            onTap: () => _showComingSoon('Perfil de usuario'),
                          ),
                          _divider(context),
                          _actionTile(
                            context,
                            icon: AppIcons.soporteAgente,
                            title: 'Soporte técnico',
                            subtitle: 'Contactar al administrador del sistema',
                            onTap: () => _showComingSoon('Soporte técnico'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      '$appName · $appVersion',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        const AppBackButton(),
        const Spacer(),
        SizedBox(
          width: 122,
          height: 38,
          child: Image.asset(
            'images/logo_met.png',
            fit: BoxFit.contain,
            alignment: Alignment.centerRight,
            filterQuality: FilterQuality.high,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _settingIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.accentYellow.withOpacity(0.11),
        borderRadius: AppDesign.smallRadius,
      ),
      child: Icon(icon, size: 20, color: AppColors.shimmerGold),
    );
  }

  Widget _themeModeSelector(
    BuildContext context, {
    required ThemeMode selectedMode,
    required bool isDark,
    required ValueChanged<ThemeMode> onChanged,
  }) {
    final followsSystem = selectedMode == ThemeMode.system;
    final description = followsSystem
        ? 'Sigue el modo ${isDark ? 'oscuro' : 'claro'} configurado en el dispositivo.'
        : selectedMode == ThemeMode.dark
            ? 'La app permanecerá en modo oscuro.'
            : 'La app permanecerá en modo claro.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _settingIcon(AppIcons.tema),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tema de la aplicación',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(AppIcons.temaAuto),
                label: Text('Sistema'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(AppIcons.claro),
                label: Text('Claro'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(AppIcons.oscuro),
                label: Text('Oscuro'),
              ),
            ],
            selected: {selectedMode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: _settingIcon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: _settingIcon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(AppIcons.siguiente),
      onTap: onTap,
    );
  }

  Widget _divider(BuildContext context) => Divider(
        height: 1,
        indent: 66,
        color: Theme.of(context).colorScheme.outlineVariant,
      );

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('La opción "$title" estará disponible próximamente.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showConnectionProfiles(bool dark) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(AppIcons.servidor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Conexión al servidor',
                        style: AppDesign.titleStyle(context),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(AppIcons.cerrar),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'El perfil seleccionado se utilizará para validar y subir datos.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: ConnectionProfileSelector(isDark: dark),
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
