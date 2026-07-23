// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/screens/calibracion/calibration_workspace_screen.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_screen.dart';
import '../../theme/app_colors.dart';

const _stepNames = [
  'Cliente', 'Planta', 'SECA', 'Instrumento', 'Inspección Visual',
  'Precarga/Ajuste', 'Excentricidad', 'Repetibilidad', 'Linealidad',
  'Foto Carga', 'Condiciones Finales', 'Exportación'
];

class ServiciosTab extends StatelessWidget {
  final String userName;

  const ServiciosTab({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado ──
            _buildHeader(context),
            const SizedBox(height: 40),

            // ── Lista de Servicios ──
            _buildServiceCard(
              context,
              icon: FontAwesomeIcons.scaleBalanced,
              title: 'Calibración',
              subtitle:
                  'Procesos de calibración de balanzas, tanques y pesas patrón',
              onTap: () => _openCalibracion(context),
              delay: 300.ms,
            ),

            _buildServiceCard(
              context,
              icon: FontAwesomeIcons.screwdriverWrench,
              title: 'Soporte Técnico',
              subtitle:
                  'Soporte y mantenimiento de balanzas y básculas de camiones',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrecargaScreenSop(
                      userName: userName,
                      clienteId: '',
                      plantaCodigo: '',
                      tableName: '',
                    ),
                  ),
                );
              },
              delay: 400.ms,
            ),

            const SizedBox(height: 30),

            // ── Información ──
            _buildInfoSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Área de Servicios',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecciona un módulo para continuar con tu trabajo',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.54),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required dynamic icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDarkSoft : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Center(
                  child: icon is IconData ? Icon(icon, size: 30, color: (isDark ? Colors.white : cs.primary)) : FaIcon(icon, size: 30, color: (isDark ? Colors.white : cs.primary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.54),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: cs.onSurface.withOpacity(0.54),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: delay).fadeIn().slideX(begin: 0.1);
  }

  Widget _buildInfoSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDarkSoft : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(FontAwesomeIcons.lightbulb, color: (isDark ? Colors.white : cs.primary), size: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona el módulo que deseas utilizar. Cada uno tiene herramientas específicas para realizar tu trabajo diario.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.54),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.1);
  }

  Future<void> _openCalibracion(BuildContext context) async {
    final incompletos = await CalibrationRepository().getServiciosIncompletos(userName);

    if (incompletos.isNotEmpty && context.mounted) {
      final ultimo = incompletos.first;
      final step = _inferStep(ultimo);
      final stepName = step < _stepNames.length ? _stepNames[step] : 'Desconocido';

      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          final isDark = cs.brightness == Brightness.dark;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: isDark ? Colors.amber[300] : Colors.amber[800],
                    size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Servicio Pendiente',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiene un proceso de calibración sin finalizar:',
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? cs.onSurface.withOpacity(0.7) : cs.onSurface.withOpacity(0.87)),
                ),
                const SizedBox(height: 16),
                _detRow('Cliente', ultimo['cliente']?.toString() ?? '-', isDark),
                const SizedBox(height: 8),
                _detRow('Planta', ultimo['planta']?.toString() ?? '-', isDark),
                const SizedBox(height: 8),
                _detRow('SECA', ultimo['seca']?.toString() ?? '-', isDark),
                const SizedBox(height: 8),
                _detRow('Instrumento', ultimo['cod_metrica']?.toString() ?? '-', isDark),
                const SizedBox(height: 8),
                _detRow('Paso', stepName, isDark),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Nuevo Servicio',
                    style: TextStyle(
                        color: isDark ? cs.onSurface.withOpacity(0.6) : cs.onSurface.withOpacity(0.54))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF326677),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continuar Servicio'),
              ),
            ],
          );
        },
      );

      if (continuar == true && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CalibrationWorkspaceScreen(
              userName: userName,
              secaValue: ultimo['seca']?.toString(),
              sessionId: ultimo['session_id']?.toString(),
            ),
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalibrationWorkspaceScreen(userName: userName),
      ),
    );
  }

  int _inferStep(Map<String, dynamic> map) {
    if (_hasData(map['emp'])) return 11;
    if (_hasData(map['hora_fin'])) return 10;
    if (_hasData(map['lin1'])) return 8;
    if (_hasData(map['repetibilidad1'])) return 7;
    if (_hasData(map['carga'])) return 6;
    if (_hasData(map['precarga1'])) return 5;
    if (_hasData(map['hora_inicio'])) return 4;
    if (_hasData(map['cod_metrica'])) return 3;
    if (_hasData(map['seca'])) return 2;
    return 0;
  }

  bool _hasData(dynamic value) => value != null && value.toString().isNotEmpty;

  Widget _detRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black54)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
        ),
      ],
    );
  }
}
