import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import 'data/historial_versiones.dart';
import 'models/version_app.dart';
import 'services/calidad_pdf.dart';
import 'utils/exportar_documento.dart';
import 'widgets/calidad_ui.dart';
import '../../theme/app_icons.dart';

/// Historial de versiones liberadas (control de cambios, 7.11.2).
class HistorialVersionesScreen extends StatefulWidget {
  const HistorialVersionesScreen({
    super.key,
    this.versiones = historialVersiones,
    this.sinLiberar = cambiosSinLiberar,
    this.versionInstalada,
  });

  final List<VersionApp> versiones;
  final List<String> sinLiberar;

  /// Para pruebas; por defecto se lee de la plataforma.
  final String? versionInstalada;

  @override
  State<HistorialVersionesScreen> createState() =>
      _HistorialVersionesScreenState();
}

class _HistorialVersionesScreenState extends State<HistorialVersionesScreen> {
  String? _instalada;
  late final Set<String> _abiertas = {
    if (widget.versiones.isNotEmpty) widget.versiones.first.version,
  };

  @override
  void initState() {
    super.initState();
    _instalada = widget.versionInstalada;
    if (_instalada == null) {
      versionInstalada().then((v) {
        if (mounted) setState(() => _instalada = v);
      });
    }
  }

  bool _esInstalada(VersionApp v) =>
      _instalada != null && _instalada!.split('+').first == v.nombre;

  Future<void> _exportar() => exportarDocumentoCalidad(
        context,
        titulo: 'historial de versiones',
        nombreArchivo: 'Historial_de_versiones_ServiceMET',
        generar: (version) => CalidadPdf.historialVersiones(
          widget.versiones,
          appVersion: version,
          sinLiberar: widget.sinLiberar,
          notaFinal: notaVersionesAnteriores,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final versiones = widget.versiones;
    return CalidadPage(
      titulo: 'Historial de versiones',
      subtitulo: 'Qué cambió en cada versión y cómo afecta a los registros.',
      acciones: [
        CalidadAccion(
          icono: AppIcons.documento,
          tooltip: 'Exportar historial',
          onPressed: _exportar,
        ),
      ],
      encabezado: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppStatusPill(
            icon: AppIcons.telefono,
            label: 'Instalada: ${_instalada ?? '…'}',
            color: AppColors.actionPositive,
          ),
          AppStatusPill(
            icon: AppIcons.historial,
            label: '${versiones.length} versiones registradas',
            color: AppColors.shimmerGold,
          ),
        ],
      ),
      children: [
        _leyendaClases(context),
        const SizedBox(height: 22),
        if (widget.sinLiberar.isNotEmpty) ...[
          const CalidadSeccion('En desarrollo'),
          _SinLiberar(cambios: widget.sinLiberar),
          const SizedBox(height: 22),
        ],
        const CalidadSeccion('Versiones liberadas'),
        for (final (i, v) in versiones.indexed)
          _VersionNodo(
            version: v,
            instalada: _esInstalada(v),
            abierta: _abiertas.contains(v.version),
            primera: i == 0,
            ultima: i == versiones.length - 1,
            onTap: () => setState(() {
              if (!_abiertas.remove(v.version)) _abiertas.add(v.version);
            }),
          ),
        const SizedBox(height: 14),
        Text(
          notaVersionesAnteriores,
          style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: AppDesign.positiveButtonStyle(),
          onPressed: _exportar,
          icon: const Icon(AppIcons.documento),
          label: const Text('Exportar historial en PDF'),
        ),
      ],
    );
  }

  Widget _leyendaClases(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Clases de cambio',
              style: AppDesign.titleStyle(context).copyWith(fontSize: 15)),
          const SizedBox(height: 10),
          for (final clase in ClaseCambio.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CalidadEtiqueta(clase.codigo, color: clase.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${clase.nombre}: ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: clase.descripcion,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ]),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SinLiberar extends StatelessWidget {
  const _SinLiberar({required this.cambios});

  final List<String> cambios;

  @override
  Widget build(BuildContext context) {
    const ambar = Color(0xFFB07F00);
    return AppPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CalidadIcono(AppIcons.herramientas, color: ambar),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Próxima versión',
                    style:
                        AppDesign.titleStyle(context).copyWith(fontSize: 16)),
              ),
              const CalidadEtiqueta('Sin liberar', color: ambar),
            ],
          ),
          const SizedBox(height: 12),
          for (final c in cambios) _Item(c, icono: AppIcons.agregar),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Aún no validado ni autorizado para su uso.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionNodo extends StatelessWidget {
  const _VersionNodo({
    required this.version,
    required this.instalada,
    required this.abierta,
    required this.primera,
    required this.ultima,
    required this.onTap,
  });

  final VersionApp version;
  final bool instalada;
  final bool abierta;
  final bool primera;
  final bool ultima;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = version;
    final color = instalada ? AppColors.actionPositive : v.clase.color;

    return Stack(
      children: [
        // Riel de la línea de tiempo.
        Positioned(
          left: 11,
          top: primera ? 24 : 0,
          bottom: ultima ? null : 0,
          height: ultima ? 24 : null,
          child: Container(width: 2, color: cs.outlineVariant),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36, bottom: 14),
          child: Material(
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppDesign.mediumRadius,
              side: BorderSide(
                color: instalada
                    ? AppColors.actionPositive.withOpacity(0.5)
                    : cs.outlineVariant.withOpacity(0.7),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                v.version,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                              CalidadEtiqueta(
                                '${v.clase.codigo} · ${v.clase.nombre}',
                                color: v.clase.color,
                              ),
                              if (instalada)
                                const CalidadEtiqueta('Instalada',
                                    color: AppColors.success),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: abierta ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(AppIcons.desplegar,
                              color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [v.fecha, if (v.commit != null) 'commit ${v.commit}']
                          .join(' · '),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(v.resumen, style: const TextStyle(height: 1.4)),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: abierta
                          ? _detalle(context)
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Punto de la versión sobre el riel.
        Positioned(
          left: 3,
          top: 18,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: instalada ? color : cs.surface,
              border: Border.all(color: color, width: 3),
              boxShadow: [
                if (instalada)
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 10,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detalle(BuildContext context) {
    final v = version;
    final cs = Theme.of(context).colorScheme;
    final etiqueta = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      color: cs.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (v.nuevo.isNotEmpty) ...[
            Text('NUEVO', style: etiqueta),
            const SizedBox(height: 6),
            for (final n in v.nuevo)
              _Item(n,
                  icono: AppIcons.agregarCirculo,
                  color: AppColors.actionPositive),
            const SizedBox(height: 6),
          ],
          if (v.corregido.isNotEmpty) ...[
            Text('CORREGIDO', style: etiqueta),
            const SizedBox(height: 6),
            for (final c in v.corregido)
              _Item(c, icono: AppIcons.soporte, color: const Color(0xFF3D7BD9)),
            const SizedBox(height: 6),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentYellow.withOpacity(0.1),
              borderRadius: AppDesign.smallRadius,
              border:
                  Border.all(color: AppColors.accentYellow.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMPACTO EN REGISTROS', style: etiqueta),
                const SizedBox(height: 4),
                Text(
                  v.impactoRegistros ?? 'Ninguno en los datos capturados.',
                  style: const TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                v.validacion == null ? AppIcons.pendiente : AppIcons.tareaLista,
                size: 18,
                color: v.validacion == null
                    ? const Color(0xFFB07F00)
                    : AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  v.validacion ?? 'Registro de validación pendiente',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: v.validacion == null
                        ? const Color(0xFFB07F00)
                        : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.texto, {required this.icono, this.color});

  final String texto;
  final IconData icono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icono, size: 17, color: color ?? AppColors.shimmerGold),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(texto, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
