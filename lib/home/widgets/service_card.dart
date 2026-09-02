import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../models/servicio_model.dart';
import '../screens/servicio_detalles_screen.dart';

class ServiceCard extends StatelessWidget {
  final ServicioResumen servicio;

  /// Se invoca al volver de la pantalla de detalle, para que el dashboard
  /// recargue si hubo ediciones o eliminaciones de registros.
  final VoidCallback? onChanged;

  const ServiceCard({super.key, required this.servicio, this.onChanged});

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
                      const SizedBox(height: 7),
                      _detailLine(context, 'Cliente', _itemValue('cliente')),
                      _detailLine(context, 'Planta', _itemValue('planta')),
                      _detailLine(context, 'Fecha', date),
                      _detailLine(
                        context,
                        calibration
                            ? 'Cantidad de balanzas'
                            : 'Cantidad de servicios',
                        servicio.cantidad.toString(),
                      ),
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

  Widget _detailLine(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value.isEmpty ? '—' : value),
          ],
        ),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  String _itemValue(String key) {
    for (final item in servicio.items) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<void> _open(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServicioDetallesScreen(servicio: servicio),
      ),
    );
    onChanged?.call();
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '';
    final parts = value.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    return value;
  }
}
