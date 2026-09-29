import 'package:flutter/material.dart';

import '../../screens/oportunidades/widgets/opportunities_entry_tile.dart';
import '../../screens/precarga/descarga_de_datos.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../screens/vencimientos_screen.dart';

class OtrosApartadosTab extends StatelessWidget {
  final String userName;

  const OtrosApartadosTab({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDesign.pagePadding,
        24,
        AppDesign.pagePadding,
        112,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Precarga', style: AppDesign.displayStyle(context)),
              const SizedBox(height: 8),
              Text(
                'Mantén disponibles los datos maestros que necesitas para trabajar sin conexión.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: AppStatusPill(
                  icon: Icons.offline_bolt_outlined,
                  label: 'Preparado para trabajo offline',
                  color: AppColors.actionPositive,
                ),
              ),
              const SizedBox(height: 28),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accentYellow.withOpacity(0.15),
                        borderRadius: AppDesign.mediumRadius,
                      ),
                      child: const Icon(
                        Icons.cloud_download_outlined,
                        color: AppColors.shimmerGold,
                        size: 27,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Base de datos principal',
                      style: AppDesign.titleStyle(context),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Descarga desde DataMET la información actualizada de clientes, plantas, balanzas, equipamientos y servicios anteriores.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        AppStatusPill(
                          icon: Icons.business_outlined,
                          label: 'Clientes y plantas',
                          color: AppColors.shimmerGold,
                        ),
                        AppStatusPill(
                          icon: Icons.scale_outlined,
                          label: 'Balanzas',
                          color: AppColors.shimmerGold,
                        ),
                        AppStatusPill(
                          icon: Icons.history_rounded,
                          label: 'Historial',
                          color: AppColors.shimmerGold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DescargaDeDatosScreen(userName: userName),
                        ),
                      ),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Actualizar datos'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppPanel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                  leading: const Icon(
                    Icons.event_note_outlined,
                    color: AppColors.shimmerGold,
                  ),
                  title: const Text('Vencimientos'),
                  subtitle: const Text(
                    'Patrones y balanzas de clientes vencidos o por vencer.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VencimientosScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const OpportunitiesEntryTile(),
              const SizedBox(height: 18),
              AppPanel(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.actionPositive,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'La descarga reemplaza los datos maestros locales, pero no elimina tus servicios ni las calibraciones pendientes de subir.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
