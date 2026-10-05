import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../models/home_dashboard_data.dart';
import '../screens/calibration_upload_screen.dart';
import '../services/home_dashboard_service.dart';
import '../widgets/service_card.dart';
import '../widgets/tipo_servicio_selector.dart';
import '../widgets/welcome_header.dart';
import '../../theme/app_icons.dart';

class HomeDashboardTab extends StatefulWidget {
  final String userName;
  final VoidCallback goToServicios;
  final VoidCallback onSettings;

  const HomeDashboardTab({
    super.key,
    required this.userName,
    required this.goToServicios,
    required this.onSettings,
  });

  @override
  State<HomeDashboardTab> createState() => _HomeDashboardTabState();
}

class _HomeDashboardTabState extends State<HomeDashboardTab> {
  final HomeDashboardService _service = HomeDashboardService();
  late Future<HomeDashboardData> _dashboard;
  int _selectedServiceType = 0;
  bool _showAllServices = false;

  @override
  void initState() {
    super.initState();
    _dashboard = _service.load();
  }

  Future<void> _refresh() async {
    final next = _service.load();
    setState(() => _dashboard = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.actionPositive,
      onRefresh: _refresh,
      child: FutureBuilder<HomeDashboardData>(
        future: _dashboard,
        builder: (context, snapshot) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppDesign.pagePadding,
              14,
              AppDesign.pagePadding,
              112,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WelcomeHeader(
                      userName: widget.userName,
                      onSettings: widget.onSettings,
                    ),
                    const SizedBox(height: 26),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const AppPanel(
                        child: SizedBox(
                          height: 190,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (snapshot.hasError)
                      _buildErrorPanel(snapshot.error)
                    else
                      ..._buildDashboard(snapshot.requireData),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDashboard(HomeDashboardData data) {
    final services = _selectedServiceType == 0
        ? data.calibrationServices
        : data.supportServiceGroups;

    return [
      _buildSummary(data),
      const SizedBox(height: 16),
      _buildSyncPanel(data),
      const SizedBox(height: 32),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Actividad local', style: AppDesign.titleStyle(context)),
                const SizedBox(height: 3),
                Text(
                  'Servicios guardados en este dispositivo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: widget.goToServicios,
            child: const Text('Nuevo servicio'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      TipoServicioSelector(
        selectedIndex: _selectedServiceType,
        onSelected: (index) => setState(() {
          _selectedServiceType = index;
          _showAllServices = false;
        }),
      ),
      const SizedBox(height: 16),
      if (services.isEmpty)
        _buildEmptyState()
      else
        ...(_showAllServices ? services : services.take(8))
            .map((service) => ServiceCard(
                  servicio: service,
                  onChanged: _refresh,
                )),
      if (services.length > 8)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: OutlinedButton(
            onPressed: () => setState(() {
              _showAllServices = !_showAllServices;
            }),
            child: Text(_showAllServices
                ? 'Ver menos servicios'
                : 'Ver los ${services.length} servicios'),
          ),
        ),
    ];
  }

  Widget _buildSummary(HomeDashboardData data) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Resumen de trabajo',
                  style: AppDesign.titleStyle(context),
                ),
              ),
              AppStatusPill(
                icon: data.servicesInProgress == 0
                    ? AppIcons.completo
                    : AppIcons.pendiente,
                label: data.servicesInProgress == 0
                    ? 'Todo al día'
                    : '${data.servicesInProgress} en proceso',
                color: data.servicesInProgress == 0
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final metrics = [
                _MetricData(
                  icon: AppIcons.balanza,
                  value: data.calibratedScales,
                  label: 'Balanzas calibradas',
                  color: AppColors.actionPositive,
                ),
                _MetricData(
                  icon: AppIcons.soporte,
                  value: data.supportServices,
                  label: 'Servicios de soporte',
                  color: AppColors.shimmerGold,
                ),
                _MetricData(
                  icon: AppIcons.subir,
                  value: data.pendingUploads,
                  label: 'Pendientes de subir',
                  color: data.pendingUploads == 0
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ];
              if (compact) {
                return Column(
                  children: metrics
                      .map((metric) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildMetric(metric, horizontal: true),
                          ))
                      .toList(),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: metrics
                    .map((metric) => Expanded(child: _buildMetric(metric)))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                AppIcons.descargarNube,
                size: 17,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Última precarga',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.lastPreload,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(_MetricData metric, {bool horizontal = false}) {
    final colors = Theme.of(context).colorScheme;
    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: metric.color.withOpacity(0.12),
        borderRadius: AppDesign.smallRadius,
      ),
      child: Icon(metric.icon, color: metric.color, size: 21),
    );
    final text = Column(
      crossAxisAlignment:
          horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          metric.value.toString(),
          style: GoogleFonts.poppins(
            fontSize: 25,
            height: 1,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          metric.label,
          textAlign: horizontal ? TextAlign.start : TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            height: 1.25,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (horizontal) {
      return Row(
        children: [
          icon,
          const SizedBox(width: 13),
          Expanded(child: text),
        ],
      );
    }
    return Column(children: [icon, const SizedBox(height: 10), text]);
  }

  Widget _buildSyncPanel(HomeDashboardData data) {
    final hasPending = data.pendingUploads > 0;
    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (hasPending
                      ? AppColors.accentYellow
                      : AppColors.actionPositive)
                  .withOpacity(0.16),
              borderRadius: AppDesign.mediumRadius,
            ),
            child: Icon(
              hasPending ? AppIcons.subir : AppIcons.nubeLista,
              color:
                  hasPending ? AppColors.shimmerGold : AppColors.actionPositive,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPending
                      ? '${data.pendingUploads} balanzas por sincronizar'
                      : 'Datos sincronizados',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  hasPending
                      ? 'Revisa y envía las calibraciones listas al servidor.'
                      : 'No tienes calibraciones terminadas pendientes de envío.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (hasPending) ...[
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Ver pendientes',
              onPressed: () => _openPendingUploads(data.pendingUploadGroups),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.actionPositive,
                foregroundColor: AppColors.actionPositiveInk,
              ),
              icon: const Icon(AppIcons.adelante),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPendingUploads(List<PendingUploadGroup> groups) async {
    if (groups.length == 1) {
      await _openUpload(groups.first.seca);
      return;
    }
    final seca = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pendientes por SECA', style: AppDesign.titleStyle(context)),
            const SizedBox(height: 6),
            Text(
              'Selecciona el grupo de balanzas que deseas revisar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final group = groups[index];
                  return AppPanel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(AppIcons.balanza),
                      title: Text('SECA ${group.seca}'),
                      subtitle: Text('${group.count} pendientes'),
                      trailing: const Icon(AppIcons.siguiente),
                      onTap: () => Navigator.pop(sheetContext, group.seca),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (seca != null && mounted) await _openUpload(seca);
  }

  Future<void> _openUpload(String seca) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalibrationUploadScreen(seca: seca),
      ),
    );
    if (mounted) await _refresh();
  }

  Widget _buildEmptyState() {
    return AppPanel(
      child: Column(
        children: [
          Icon(
            AppIcons.bandeja,
            size: 38,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('Aún no hay servicios', style: AppDesign.titleStyle(context)),
          const SizedBox(height: 6),
          Text(
            'Cuando comiences tu trabajo, los registros aparecerán aquí.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.goToServicios,
            icon: const Icon(AppIcons.agregar),
            label: const Text('Crear servicio'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPanel(Object? error) {
    return AppPanel(
      child: Column(
        children: [
          const Icon(
            AppIcons.sinConexion,
            color: AppColors.actionNegative,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text('No pudimos cargar el resumen',
              style: AppDesign.titleStyle(context)),
          const SizedBox(height: 6),
          Text(
            'Tus datos siguen guardados. Intenta actualizar nuevamente.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(AppIcons.actualizar),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  const _MetricData({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}
