import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../models/servicio_model.dart';
import '../screens/servicio_detalles_screen.dart';

class ServiceCard extends StatelessWidget {
  final ServicioResumen servicio;

  const ServiceCard({super.key, required this.servicio});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final calibration = servicio.tipo == TipoServicio.calibracion;
    final accent =
        calibration ? AppColors.actionPositive : AppColors.shimmerGold;
    final icon = calibration
        ? FontAwesomeIcons.scaleBalanced
        : FontAwesomeIcons.screwdriverWrench;
    final date = _formatDate(servicio.fecha);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppPanel(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: AppDesign.largeRadius,
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.13),
                    borderRadius: AppDesign.smallRadius,
                  ),
                  child: Center(child: FaIcon(icon, color: accent, size: 19)),
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
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _description(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(date,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Ver detalle',
                  onPressed: () => _open(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentYellow.withOpacity(0.12),
                    foregroundColor: colors.onSurface,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _description() {
    final plural = servicio.cantidad == 1 ? '' : 's';
    final item = servicio.tipo == TipoServicio.calibracion
        ? 'balanza calibrada'
        : 'registro técnico';
    return '${servicio.cantidad} $item$plural';
  }

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServicioDetallesScreen(servicio: servicio),
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '';
    final parts = value.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    return value;
  }
}
