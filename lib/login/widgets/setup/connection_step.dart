// Paso 1 del setup: Configuración de conexión mediante perfiles.
// Muestra selector de perfiles guardados y permite editar, agregar
// o eliminar configuraciones de conexión al servidor.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/theme/app_colors.dart';
import '../../services/connection_profile_service.dart';
import 'connection_profile_selector.dart';
import '../../../theme/app_icons.dart';

class ConnectionStep extends StatelessWidget {
  final bool isDark;
  final bool loading;
  final VoidCallback onContinue;

  const ConnectionStep({
    super.key,
    required this.isDark,
    required this.loading,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ConnectionProfileService>();
    final valores = profileService.getValoresConexion();
    final tienePerfil = profileService.perfilSeleccionado != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : AppColors.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AppIcons.datos,
                color: isDark ? Colors.white : AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paso 1: Conexión',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Selecciona o agrega una configuración de conexión',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Selector de perfiles
        const Text(
          'Perfiles de conexión',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ConnectionProfileSelector(isDark: isDark),

        const SizedBox(height: 24),

        // Vista previa de la configuración seleccionada
        if (tienePerfil) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.success.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.completo, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(
                      'Configuración seleccionada',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('Servidor', valores['ip']!, valores['port']!),
                const SizedBox(height: 8),
                _infoRow('Base de Datos', valores['database']!, ''),
                const SizedBox(height: 8),
                _infoRow('Usuario BD', valores['username']!, ''),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        // Botón validar
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : AppColors.primary,
              foregroundColor: isDark ? const Color(0xFF292929) : Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: (loading || !tienePerfil) ? null : onContinue,
            icon: const Icon(AppIcons.adelante),
            label: Text(
              'Validar Conexión y Continuar',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, String extra) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            extra.isNotEmpty ? '$value:$extra' : value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
