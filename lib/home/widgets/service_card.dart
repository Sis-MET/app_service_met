import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/servicio_detalles_screen.dart';
import '../models/servicio_model.dart';
import '../../theme/app_colors.dart';

class ServiceCard extends StatelessWidget {
  final ServicioResumen servicio;

  const ServiceCard({super.key, required this.servicio});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final isCalibracion = servicio.tipo == TipoServicio.calibracion;
    final Color flatColor = const Color(0xFF4CAF50);
    final icon = isCalibracion
        ? FontAwesomeIcons.scaleBalanced
        : FontAwesomeIcons.screwdriverWrench;
    final String labelSuffix = isCalibracion ? 'calibrada' : 'técnico';
    final String pluralSuffixItem = servicio.cantidad != 1 ? 's' : '';
    final String pluralSuffixLabel = servicio.cantidad != 1 ? 's' : '';
    final String fechaStr = _formatFecha(servicio.fecha);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDarkSoft : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ServicioDetallesScreen(servicio: servicio),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: flatColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FaIcon(icon, color: flatColor, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${servicio.prefijo} ${servicio.codigo}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          height: 1.2,
                        ),
                      ),
                      if (fechaStr.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          fechaStr,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(0.45),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        '${servicio.cantidad} ${servicio.nombreItem}$pluralSuffixItem $labelSuffix$pluralSuffixLabel',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.54),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ServicioDetallesScreen(servicio: servicio),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: flatColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Ver',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return '';
    try {
      final parts = fecha.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return fecha;
    } catch (_) {
      return fecha;
    }
  }
}
