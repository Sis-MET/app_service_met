import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../widgets/foto_viewer.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../../theme/app_icons.dart';

/// Todas las fotos de una balanza, agrupadas por la sección donde se tomaron
/// (Balanza, Linealidad, Carcasa...). Es solo para ver: no abre el editor ni
/// cambia el registro. Tocar una foto la abre en el visor.
class FotosRegistroScreen extends StatelessWidget {
  final List<FotoItem> fotos;

  /// La balanza: su código métrica o "Balanza 3".
  final String titulo;

  /// El servicio: "SECA 0087-11-C01-26".
  final String servicio;

  /// Prefijo de los archivos al compartir o guardar.
  final String nombreBase;

  const FotosRegistroScreen({
    super.key,
    required this.fotos,
    required this.titulo,
    required this.servicio,
    required this.nombreBase,
  });

  static Future<void> open(
    BuildContext context, {
    required List<FotoItem> fotos,
    required String titulo,
    required String servicio,
    required String nombreBase,
  }) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FotosRegistroScreen(
            fotos: fotos,
            titulo: titulo,
            servicio: servicio,
            nombreBase: nombreBase,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final grupos = <String, List<int>>{};
    for (var i = 0; i < fotos.length; i++) {
      grupos.putIfAbsent(fotos[i].grupo, () => []).add(i);
    }
    final disponibles = fotos.where((foto) => foto.existe).toList();
    final faltantes = fotos.length - disponibles.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: ServiceAppBar(
        title: 'Fotografías',
        subtitle: '$titulo · $servicio',
        actions: [
          IconButton(
            tooltip: 'Compartir todas',
            onPressed: disponibles.isEmpty
                ? null
                : () => compartirFotos(context, disponibles, nombreBase),
            icon: const Icon(AppIcons.compartir),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: fotos.isEmpty
          ? const _SinFotos()
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppDesign.pagePadding, 8, AppDesign.pagePadding, 4),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppStatusPill(
                              icon: AppIcons.fotos,
                              label: fotos.length == 1
                                  ? '1 foto'
                                  : '${fotos.length} fotos',
                              color: AppColors.actionPositive,
                            ),
                            AppStatusPill(
                              icon: AppIcons.carpeta,
                              label: grupos.length == 1
                                  ? '1 sección'
                                  : '${grupos.length} secciones',
                              color: AppColors.shimmerGold,
                            ),
                            if (faltantes > 0)
                              AppStatusPill(
                                icon: AppIcons.imagenNoDisponible,
                                label: faltantes == 1
                                    ? '1 no está en el teléfono'
                                    : '$faltantes no están en el teléfono',
                                color: AppColors.warning,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Toque una foto para verla en grande, acercarla y '
                          'compartirla.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                for (final grupo in grupos.entries) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppDesign.pagePadding, 20, AppDesign.pagePadding, 10),
                    sliver: SliverToBoxAdapter(
                      child: _EncabezadoGrupo(
                        titulo: grupo.key,
                        cantidad: grupo.value.length,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDesign.pagePadding),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: grupo.value.length,
                      itemBuilder: (context, i) {
                        final index = grupo.value[i];
                        return Hero(
                          tag: FotoViewerScreen.heroTag(index),
                          child: FotoMiniatura(
                            foto: fotos[index],
                            radius: AppDesign.radiusSmall,
                            onTap: () => abrirVisorFotos(
                              context,
                              fotos: fotos,
                              index: index,
                              nombreBase: nombreBase,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 32 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
    );
  }
}

class _EncabezadoGrupo extends StatelessWidget {
  final String titulo;
  final int cantidad;

  const _EncabezadoGrupo({required this.titulo, required this.cantidad});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          cantidad == 1 ? '1 foto' : '$cantidad fotos',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SinFotos extends StatelessWidget {
  const _SinFotos();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.sinFotos,
                size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Esta balanza no tiene fotografías.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
