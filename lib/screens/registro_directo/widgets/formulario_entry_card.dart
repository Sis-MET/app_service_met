import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';

/// Acceso a un formulario adicional desde Servicios. Tocar la tarjeta abre
/// la lista de los ya registrados, con el número de los que esperan ser
/// enviados; el botón llena uno nuevo sin estar dentro de un servicio.
class FormularioEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Formularios guardados en el teléfono que todavía no se enviaron.
  final int pending;
  final VoidCallback onOpenList;
  final String newLabel;
  final VoidCallback onNew;

  const FormularioEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pending,
    required this.onOpenList,
    required this.newLabel,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDesign.radiusLarge),
              ),
            ),
            leading: Icon(icon, color: AppColors.shimmerGold),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pending > 0)
                  Badge(
                    label: Text('$pending'),
                    backgroundColor: AppColors.warning,
                  ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: onOpenList,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add_rounded),
              label: Text(newLabel),
            ),
          ),
        ],
      ),
    );
  }
}
