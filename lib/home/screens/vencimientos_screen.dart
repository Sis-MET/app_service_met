import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../services/notifications/notification_rules.dart';
import '../../services/notifications/notification_snapshot_loader.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../../theme/app_icons.dart';

enum VencimientosTab { patrones, balanzas }

/// Patrones y balanzas de clientes vencidos o por vencer, según la precarga.
/// Es el destino de las notificaciones de vencimiento.
class VencimientosScreen extends StatefulWidget {
  final VencimientosTab initialTab;

  const VencimientosScreen({
    super.key,
    this.initialTab = VencimientosTab.patrones,
  });

  @override
  State<VencimientosScreen> createState() => _VencimientosScreenState();
}

class _VencimientosScreenState extends State<VencimientosScreen> {
  late Future<_VencimientosData> _data = _load();

  Future<_VencimientosData> _load() async {
    final path = p.join(await getDatabasesPath(), 'precarga_database.db');
    if (!await databaseExists(path)) return const _VencimientosData.empty();
    final (patrones, balanzas) = await (
      NotificationSnapshotLoader.loadPatrones(),
      NotificationSnapshotLoader.loadBalanzas(),
    ).wait;
    final now = DateTime.now();
    return _VencimientosData(
      precarga: true,
      patrones: evaluatePatrones(patrones, now),
      plantas: evaluateBalanzas(balanzas, now),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: VencimientosTab.values.length,
      initialIndex: widget.initialTab.index,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: ServiceAppBar(
          title: 'Vencimientos',
          actions: [
            IconButton(
              onPressed: () => setState(() => _data = _load()),
              tooltip: 'Actualizar',
              icon: const Icon(AppIcons.actualizar),
            ),
          ],
        ),
        body: FutureBuilder<_VencimientosData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _Message(
                icon: AppIcons.error,
                text: 'No se pudo leer la precarga: ${snapshot.error}',
              );
            }
            final data = snapshot.data!;
            if (!data.precarga) {
              return const _Message(
                icon: AppIcons.descargarNube,
                text: 'Descarga la precarga para ver los vencimientos de '
                    'patrones y balanzas.',
              );
            }
            return Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: 'Patrones (${data.patrones.length})'),
                    Tab(text: 'Balanzas (${data.totalBalanzas})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _PatronesList(items: data.patrones),
                      _PlantasList(plantas: data.plantas),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VencimientosData {
  final bool precarga;
  final List<DueItem> patrones;
  final List<PlantaDue> plantas;

  const _VencimientosData({
    required this.precarga,
    required this.patrones,
    required this.plantas,
  });

  const _VencimientosData.empty()
      : precarga = false,
        patrones = const [],
        plantas = const [];

  int get totalBalanzas =>
      plantas.fold(0, (sum, planta) => sum + planta.balanzas.length);
}

const _listPadding = EdgeInsets.fromLTRB(
  AppDesign.pagePadding,
  16,
  AppDesign.pagePadding,
  32,
);

class _PatronesList extends StatelessWidget {
  final List<DueItem> items;

  const _PatronesList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Message(
        icon: AppIcons.verificado,
        text: 'Todos los patrones activos tienen la calibración al día.',
      );
    }
    return ListView(
      padding: _listPadding,
      children: [
        _Note(
          'Certificados de un año. Se listan los vencidos y los que vencen en '
          'los próximos ${expiryWarning.inDays} días.',
        ),
        const SizedBox(height: 12),
        AppPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final item in items)
                _DueTile(
                  item: item,
                  title: item.codigo,
                  subtitle: item.descripcion,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlantasList extends StatelessWidget {
  final List<PlantaDue> plantas;

  const _PlantasList({required this.plantas});

  @override
  Widget build(BuildContext context) {
    if (plantas.isEmpty) {
      return const _Message(
        icon: AppIcons.fechaLista,
        text: 'No hay balanzas de clientes por vencer en los próximos días.',
      );
    }
    return ListView.separated(
      padding: _listPadding,
      itemCount: plantas.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Note(
            'Según la última calibración registrada en el historial: vencen '
            'en los próximos ${expiryWarning.inDays} días o vencieron hace '
            'menos de ${overdueTrackingWindow.inDays}.',
          );
        }
        final planta = plantas[index - 1];
        return AppPanel(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            initiallyExpanded: index == 1,
            leading: const Icon(AppIcons.empresa),
            title: Text(
              planta.cliente,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                if (planta.planta.isNotEmpty) planta.planta,
                plural(planta.balanzas.length, 'balanza', 'balanzas'),
              ].join(' · '),
            ),
            children: [
              for (final item in planta.balanzas)
                _DueTile(
                  item: item,
                  title: item.codigo,
                  subtitle: item.descripcion,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DueTile extends StatelessWidget {
  final DueItem item;
  final String title;
  final String subtitle;

  const _DueTile({
    required this.item,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.vencido ? AppColors.error : AppColors.warning;
    final vence = item.item.vence;
    return ListTile(
      leading: Icon(
        item.vencido ? AppIcons.error : AppIcons.hora,
        color: color,
      ),
      title: Text(title),
      subtitle: Text(
        [
          if (subtitle.isNotEmpty) subtitle,
          'Vence ${vence.day.toString().padLeft(2, '0')}/'
              '${vence.month.toString().padLeft(2, '0')}/${vence.year}',
        ].join('\n'),
      ),
      isThreeLine: subtitle.isNotEmpty,
      trailing: Text(
        item.plazo,
        textAlign: TextAlign.end,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.shimmerGold),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
