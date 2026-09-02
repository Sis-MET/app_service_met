// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:provider/provider.dart';

import '../../database/precarga_bd.dart';
import '../../login/services/setup_service.dart';
import '../../login/services/connection_profile_service.dart';
import '../../login/widgets/setup/setup_loading.dart';
import '../../login/screens/initial_setup_screen.dart';
import 'widgets/autorizar_actualizacion_dialog.dart';

class DescargaDeDatosScreen extends StatefulWidget {
  final String userName;
  const DescargaDeDatosScreen({
    super.key,
    required this.userName,
  });

  @override
  State<DescargaDeDatosScreen> createState() => _DescargaDeDatosScreenState();
}

class _DescargaDeDatosScreenState extends State<DescargaDeDatosScreen> {
  final SetupService _setupService = SetupService();
  bool _loading = false;
  String _statusMessage = '';
  double _progressValue = 0.0;
  String? _lastUpdate;

  String _savedIp = 'Desconocida';
  String _savedDb = 'Desconocida';

  int _clientesCount = 0;
  int _plantasCount = 0;
  int _equiposCount = 0;

  @override
  void initState() {
    super.initState();
    _loadConfigAndSummary();
  }

  @override
  void dispose() {
    _setupService.disconnect();
    super.dispose();
  }

  Future<void> _loadConfigAndSummary() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastUpdate = prefs.getString('lastUpdate');
      _savedIp = prefs.getString('api_url') ?? 'Desconocida';
      _savedDb = 'API Node.js';
    });

    try {
      final dbPath = await getDatabasesPath();
      final precargaDbPath = path.join(dbPath, 'precarga_database.db');
      if (await databaseExists(precargaDbPath)) {
        // Se abre a través del helper: garantiza el esquema en `onOpen`, en
        // vez de crear un archivo vacío y sin tablas como hacía el
        // `openDatabase` directo.
        final db = await DatabaseHelperPrecarga().database;
        final c = await _contarFilas(db, 'clientes');
        final p = await _contarFilas(db, 'plantas');
        final e = await _contarFilas(db, 'balanzas');
        if (mounted) {
          setState(() {
            _clientesCount = c;
            _plantasCount = p;
            _equiposCount = e;
          });
        }
      }
    } catch (_) {}
  }

  /// Devuelve 0 si la tabla todavía no existe, en vez de propagar el error.
  Future<int> _contarFilas(Database db, String tabla) async {
    try {
      return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tabla'),
          ) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _showUpdateDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final accent = Theme.of(context).colorScheme.primary;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.cloud_sync, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Actualizar Datos',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas precargar los datos utilizando la última configuración registrada?',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONFIGURACIÓN ACTUAL:',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'IP: $_savedIp',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'DB: $_savedDb',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'nueva'),
            child: Text(
              'Ingresar nueva',
              style: GoogleFonts.inter(
                color: cs.onSurface.withOpacity(0.54),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'actual'),
            child: const Text('Usar actual'),
          ),
        ],
      ),
    );

    if (result == 'actual') {
      _updateData();
    } else if (result == 'nueva') {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const InitialSetupScreen(isUpdateMode: true),
          ),
        ).then((_) {
          // Recargar configuración si volvió de setup
          _loadConfigAndSummary();
        });
      }
    }
  }

  Future<void> _updateData() async {
    final profile = context.read<ConnectionProfileService>().perfilSeleccionado;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final usuario = prefs.getString('logged_user');
    final apiUrl = profile?.apiUrl ?? prefs.getString('api_url');
    if (usuario == null || apiUrl == null || apiUrl.isEmpty) {
      _showError('No hay un usuario o servidor configurado.');
      return;
    }
    // El controller vive dentro del diálogo, no aquí: ver la nota en
    // [AutorizarActualizacionDialog].
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const AutorizarActualizacionDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;
    setState(() {
      _loading = true;
      _statusMessage = 'Conectando al servidor...';
      _progressValue = 0.0;
    });

    try {
      final downloadResult = await _setupService.refreshBootstrap(
        apiUrl: apiUrl,
        usuario: usuario,
        password: password,
        onProgress: (message, progress) {
          setState(() {
            _statusMessage = message;
            _progressValue = progress;
          });
        },
      );

      if (!downloadResult.success) {
        _showError(downloadResult.message);
        setState(() => _loading = false);
        return;
      }

      await _setupService.disconnect();

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      await prefs.setString('lastUpdate', now);

      setState(() {
        _loading = false;
        _lastUpdate = now;
        _statusMessage = '';
        _progressValue = 0.0;
      });

      // Recargar el resumen
      await _loadConfigAndSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Datos precargados exitosamente',
                style: GoogleFonts.inter()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      _showError('Error inesperado: $e');
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: const ServiceAppBar(title: 'Precarga de datos'),
      body: _loading
          ? SetupLoading(
              isDark: isDark,
              statusMessage: _statusMessage,
              progressValue: _progressValue,
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado de sincronización',
                    style: AppDesign.displayStyle(context),
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 8),
                  Text(
                    'Resumen actual de los datos descargados en este dispositivo para trabajar desconectado.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.54),
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),

                  const SizedBox(height: 28),

                  // ── Tarjeta Resumen Principal ──
                  AppPanel(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniStat(
                              icon: FontAwesomeIcons.buildingUser,
                              value: _clientesCount.toString(),
                              label: 'Clientes',
                              accent: accent,
                              isDark: isDark,
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: isDark
                                  ? AppColors.borderDarkSoft
                                  : AppColors.borderLight,
                            ),
                            _buildMiniStat(
                              icon: FontAwesomeIcons.industry,
                              value: _plantasCount.toString(),
                              label: 'Plantas',
                              accent: accent,
                              isDark: isDark,
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: isDark
                                  ? AppColors.borderDarkSoft
                                  : AppColors.borderLight,
                            ),
                            _buildMiniStat(
                              icon: FontAwesomeIcons.scaleBalanced,
                              value: _equiposCount.toString(),
                              label: 'Equipos',
                              accent: accent,
                              isDark: isDark,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        Divider(
                            color: isDark
                                ? AppColors.borderDarkSoft
                                : AppColors.borderLight),
                        const SizedBox(height: 16),

                        // Última actualización info
                        Row(
                          children: [
                            Icon(Icons.history,
                                size: 18,
                                color:
                                    isDark ? Colors.white38 : Colors.black38),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Última actualización:',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: cs.onSurface.withOpacity(0.54),
                                    ),
                                  ),
                                  Text(
                                    _lastUpdate != null
                                        ? _formatDate(_lastUpdate!)
                                        : 'Nunca',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),

                  const SizedBox(height: 32),

                  // ── Configuración Info ──
                  AppPanel(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.server,
                            color: accent, size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Origen de datos actual',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'IP: $_savedIp  •  DB: $_savedDb',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: cs.onSurface.withOpacity(0.54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1),

                  const SizedBox(height: 40),

                  Center(
                    child: SizedBox(
                      width: 250,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _showUpdateDialog,
                        icon: const Icon(Icons.cloud_sync_outlined),
                        label: Text(
                          'Actualizar Datos',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.actionPositiveInk,
                          ),
                        ),
                      ),
                    ),
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildMiniStat({
    required dynamic icon,
    required String value,
    required String label,
    required Color accent,
    required bool isDark,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: icon is IconData
              ? Icon(icon, size: 16, color: accent)
              : FaIcon(icon, size: 16, color: accent),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: cs.onSurface.withOpacity(0.54),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} a las ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }
}
