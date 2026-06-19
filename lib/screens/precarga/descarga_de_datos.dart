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

import '../../login/services/setup_service.dart';
import '../../login/widgets/setup/setup_loading.dart';
import '../../login/screens/initial_setup_screen.dart';

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
      _savedIp = prefs.getString('ip') ?? 'Desconocida';
      _savedDb = prefs.getString('database') ?? 'Desconocida';
    });

    try {
      final dbPath = await getDatabasesPath();
      final precargaDbPath = path.join(dbPath, 'precarga_database.db');
      if (await databaseExists(precargaDbPath)) {
        final db = await openDatabase(precargaDbPath);
        final c = Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM clientes')) ??
            0;
        final p = Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM plantas')) ??
            0;
        final e = Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM balanzas')) ??
            0;
        await db.close();
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'actual'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              'Usar actual',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    setState(() {
      _loading = true;
      _statusMessage = 'Conectando al servidor...';
      _progressValue = 0.0;
    });

    try {
      final connectionResult =
          await _setupService.connectFromSavedConfiguration();

      if (!connectionResult.success) {
        _showError(connectionResult.message);
        setState(() => _loading = false);
        return;
      }

      final downloadResult = await _setupService.downloadPrecargaData(
        (message, progress) {
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
      appBar: AppBar(
        title: Text(
          'Precarga de Datos',
          style: GoogleFonts.poppins(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18.0,
          ),
        ),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
            color: cs.onSurface),
      ),
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
                    'Estado de Sincronización',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
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
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.server, color: accent, size: 20),
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
                                  color:
                                      cs.onSurface.withOpacity(0.54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1),

                  const SizedBox(height: 40),

                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _showUpdateDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.cloud_sync_outlined),
                      label: Text(
                        'ACTUALIZAR DATOS',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
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
          child: icon is IconData ? Icon(icon, size: 16, color: accent) : FaIcon(icon, size: 16, color: accent),
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
