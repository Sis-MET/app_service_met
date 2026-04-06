// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ServicioIncompletoDialog extends StatelessWidget {
  final Map<String, dynamic> registro;
  final VoidCallback onRecuperar;
  final VoidCallback onNuevo;

  const ServicioIncompletoDialog({
    super.key,
    required this.registro,
    required this.onRecuperar,
    required this.onNuevo,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final seca = registro['seca']?.toString() ?? 'N/A';
    final cliente = registro['cliente']?.toString() ?? 'N/A';
    final planta = registro['planta']?.toString() ?? 'N/A';
    final codMetrica = registro['cod_metrica']?.toString() ?? 'N/A';
    final fechaServicio = registro['fecha_servicio']?.toString() ?? 'N/A';
    final personal = registro['personal']?.toString() ?? 'N/A';

    final pasoActual = _determinarPasoActual(registro);
    final pasoDescripcion = _getPasoDescripcion(pasoActual);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Servicio Incompleto Detectado',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tarjeta de información con tema naranja
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                    Icons.confirmation_number_outlined, 'SECA', seca, isDark),
                const SizedBox(height: 6),
                _infoRow(Icons.qr_code, 'Cód. Métrica', codMetrica, isDark),
                const SizedBox(height: 6),
                _infoRow(Icons.business_outlined, 'Cliente', cliente, isDark),
                const SizedBox(height: 6),
                _infoRow(Icons.location_on_outlined, 'Planta', planta, isDark),
                const SizedBox(height: 6),
                _infoRow(Icons.calendar_today, 'Fecha', fechaServicio, isDark),
                const SizedBox(height: 6),
                _infoRow(Icons.person_outline, 'Técnico', personal, isDark),
                const SizedBox(height: 10),
                Divider(
                  color: Colors.orange.withOpacity(0.3),
                  height: 1,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.skip_next,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Última actividad: ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        pasoDescripcion,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pregunta de confirmación
          Text(
            '¿Desea continuar con el servicio anterior y recuperar los datos guardados?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onNuevo,
          child: Text(
            'Iniciar Nuevo',
            style: GoogleFonts.inter(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onRecuperar,
          icon: const Icon(Icons.restore, size: 18),
          label: Text(
            'Recuperar',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 15,
            color: isDark ? Colors.orange.shade300 : Colors.orange.shade700),
        const SizedBox(width: 7),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  int _determinarPasoActual(Map<String, dynamic> registro) {
    if (registro['lin1'] != null && registro['lin1'].toString().isNotEmpty) {
      return 5;
    }
    if (registro['repetibilidad1'] != null &&
        registro['repetibilidad1'].toString().isNotEmpty) {
      return 4;
    }
    if (registro['tipo_plataforma'] != null &&
        registro['tipo_plataforma'].toString().isNotEmpty) {
      return 3;
    }
    if (registro['precarga1'] != null &&
        registro['precarga1'].toString().isNotEmpty) {
      return 2;
    }
    if (registro['vibracion'] != null &&
        registro['vibracion'].toString().isNotEmpty) {
      return 1;
    }
    return 0;
  }

  String _getPasoDescripcion(int paso) {
    switch (paso) {
      case 0:
        return 'Datos iniciales registrados';
      case 1:
        return 'Inspección Visual completada';
      case 2:
        return 'Precargas y Ajuste registrados';
      case 3:
        return 'Prueba de Excentricidad completada';
      case 4:
        return 'Prueba de Repetibilidad completada';
      case 5:
        return 'Prueba de Linealidad completada';
      default:
        return 'Servicio en progreso';
    }
  }
}
