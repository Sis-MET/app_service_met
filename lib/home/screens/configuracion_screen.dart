// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/providers/settings_provider.dart';
import 'package:service_met/screens/respaldo/respaldo.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  _ConfiguracionScreenState createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  String appVersion = '4.8.3';
  String appName = 'METRICA LTDA';
  bool syncBackground = true;
  bool notifications = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = packageInfo.version;
      appName = packageInfo.appName;
    });
  }

  void _showMockDialog(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('La opción "$title" estará disponible próximamente.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF4A90E2)
            : const Color(0xFF04376E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF4A90E2) : const Color(0xFF04376E);
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE);
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF555555);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          'CONFIGURACIÓN',
          style: GoogleFonts.poppins(
            fontSize: 17.0,
            fontWeight: FontWeight.w700,
            color: titleColor,
            letterSpacing: 0.4,
          ),
        ),
        backgroundColor: cardColor, // Same as appbar in home
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
        iconTheme: IconThemeData(color: iconColor),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // SECCIÓN: PREFERENCIAS
                _buildSectionTitle('Preferencias de Sistema', isDark),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Modo Oscuro',
                        subtitle: 'Activar tema oscuro en la app',
                        value: settings.themeMode == ThemeMode.dark ||
                            (settings.themeMode == ThemeMode.system && isDark),
                        onChanged: (value) => settings.toggleTheme(value),
                        accent: accent,
                        isDark: isDark,
                      ),
                      _buildDivider(borderColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.text_fields,
                                    size: 22, color: accent),
                                const SizedBox(width: 16),
                                Text(
                                  'Tamaño de Texto',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('A',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54)),
                                Expanded(
                                  child: Slider(
                                    value: settings.textScaleFactor,
                                    min: 0.8,
                                    max: 1.4,
                                    divisions: 6,
                                    activeColor: accent,
                                    inactiveColor: accent.withOpacity(0.2),
                                    label: settings.textScaleFactor
                                        .toStringAsFixed(1),
                                    onChanged: (value) =>
                                        settings.setTextScale(value),
                                  ),
                                ),
                                Text('A',
                                    style: GoogleFonts.inter(
                                        fontSize: 20,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // SECCIÓN: FUNCIONALIDAD
                _buildSectionTitle('Funcionalidad', isDark),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.sync,
                        title: 'Sincronización Automática',
                        subtitle: 'Descarga datos en segundo plano',
                        value: syncBackground,
                        onChanged: (value) =>
                            setState(() => syncBackground = value),
                        accent: accent,
                        isDark: isDark,
                      ),
                      _buildDivider(borderColor),
                      _buildSwitchTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notificaciones',
                        subtitle: 'Avisos de tareas y mantenimientos',
                        value: notifications,
                        onChanged: (value) =>
                            setState(() => notifications = value),
                        accent: accent,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // SECCIÓN: GESTIÓN
                _buildSectionTitle('Gestión', isDark),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildActionTile(
                        icon: Icons.backup_outlined,
                        title: 'Respaldo de Datos',
                        subtitle: 'Crear o restaurar copias de seguridad',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => RespaldoScreen()),
                          );
                        },
                        accent: accent,
                        isDark: isDark,
                      ),
                      _buildDivider(borderColor),
                      _buildActionTile(
                        icon: Icons.person_outline,
                        title: 'Perfil de Usuario',
                        subtitle: 'Gestionar credenciales locales',
                        onTap: () => _showMockDialog('Perfil de Usuario'),
                        accent: accent,
                        isDark: isDark,
                      ),
                      _buildDivider(borderColor),
                      _buildActionTile(
                        icon: Icons.help_outline,
                        title: 'Soporte Técnico',
                        subtitle: 'Contactar administrador del sistema',
                        onTap: () => _showMockDialog('Soporte Técnico'),
                        accent: accent,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              children: [
                Text(
                  '© 2026 $appName. Todos los derechos reservados.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Versión $appVersion',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white54 : Colors.black54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDivider(Color borderColor) {
    return Divider(
      height: 1,
      thickness: 1,
      color: borderColor,
      indent: 56, // para que alinee con el texto y no bajo el ícono
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required Color accent,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: accent,
        inactiveThumbColor: isDark ? Colors.white70 : Colors.white,
        inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color accent,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
      onTap: onTap,
    );
  }
}
