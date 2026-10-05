import 'package:flutter/material.dart';

import '../../screens/calidad/cumplimiento_screen.dart';
import '../../screens/calidad/historial_versiones_screen.dart';
import '../../screens/calidad/manual_screen.dart';
import '../../screens/calidad/widgets/calidad_resumen_panel.dart';
import '../../screens/calidad/widgets/calidad_ui.dart';
import '../../theme/app_design.dart';
import '../../theme/app_icons.dart';

/// Pestaña "Otros" de la barra inferior: lo que no es trabajo de campo. Reúne
/// "Calidad y normativa": el cumplimiento NB/ISO/IEC 17025, el manual de uso
/// y el historial de versiones.
class OtrosTab extends StatelessWidget {
  const OtrosTab({super.key});

  @override
  Widget build(BuildContext context) {
    void abrir(Widget pantalla) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => pantalla),
        );

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
              Text('Otros', style: AppDesign.displayStyle(context)),
              const SizedBox(height: 8),
              Text(
                'Información de calidad del laboratorio y documentos de la '
                'app.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              const CalidadSeccion('Calidad y normativa'),
              CalidadResumenPanel(
                onAbrir: (clausula) =>
                    abrir(CumplimientoScreen(clausulaInicial: clausula)),
              ),
              const SizedBox(height: 12),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Opcion(
                      icono: AppIcons.manual,
                      titulo: 'Manual de uso',
                      detalle: 'Guía interactiva de la app, exportable en PDF',
                      onTap: () => abrir(const ManualScreen()),
                    ),
                    Divider(
                      height: 1,
                      indent: 66,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    _Opcion(
                      icono: AppIcons.historial,
                      titulo: 'Historial de versiones',
                      detalle:
                          'Cambios por versión y su impacto en los registros',
                      onTap: () => abrir(const HistorialVersionesScreen()),
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

class _Opcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: CalidadIcono(icono),
        title:
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detalle),
        trailing: const Icon(AppIcons.siguiente),
        onTap: onTap,
      );
}
