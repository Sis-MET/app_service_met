import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import 'data/requisitos_17025.dart';
import 'models/cumplimiento.dart';
import 'services/calidad_pdf.dart';
import 'utils/exportar_documento.dart';
import 'widgets/calidad_ui.dart';
import '../../theme/app_icons.dart';

/// Tablero de cumplimiento NB/ISO/IEC 17025 (7.5, 7.11 y 8.4): resumen,
/// avance por cláusula y cada requisito con su evidencia, brecha y acción.
class CumplimientoScreen extends StatefulWidget {
  const CumplimientoScreen({super.key, this.evaluacion, this.clausulaInicial});

  /// Para pruebas; por defecto, [evaluacionCumplimiento].
  final EvaluacionCumplimiento? evaluacion;
  final Clausula? clausulaInicial;

  @override
  State<CumplimientoScreen> createState() => _CumplimientoScreenState();
}

class _CumplimientoScreenState extends State<CumplimientoScreen> {
  late final EvaluacionCumplimiento _evaluacion =
      widget.evaluacion ?? evaluacionCumplimiento;
  late Clausula? _clausula = widget.clausulaInicial;
  EstadoCumplimiento? _estado;
  String _consulta = '';
  final Set<String> _abiertos = {};
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  List<Requisito> get _filtrados => _evaluacion.requisitos
      .where((r) => _clausula == null || r.clausula == _clausula)
      .where((r) => _estado == null || r.estado == _estado)
      .where((r) => r.coincide(_consulta))
      .toList();

  bool get _hayFiltros =>
      _clausula != null || _estado != null || _consulta.isNotEmpty;

  void _limpiar() => setState(() {
        _clausula = null;
        _estado = null;
        _consulta = '';
        _busqueda.clear();
      });

  Future<void> _exportar() => exportarDocumentoCalidad(
        context,
        titulo: 'matriz de cumplimiento',
        nombreArchivo: 'Matriz_Cumplimiento_ISO17025',
        generar: (version) => CalidadPdf.matrizCumplimiento(
          _evaluacion,
          appVersion: version,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return CalidadPage(
      titulo: 'Cumplimiento',
      subtitulo: 'NB/ISO/IEC 17025 · registros técnicos, gestión de la '
          'información y control de registros.',
      acciones: [
        CalidadAccion(
          icono: AppIcons.documento,
          tooltip: 'Exportar matriz',
          onPressed: _exportar,
        ),
      ],
      encabezado: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppStatusPill(
            icon: AppIcons.verificado,
            label: 'Evaluado en v${_evaluacion.version}',
            color: AppColors.actionPositive,
          ),
          AppStatusPill(
            icon: AppIcons.calendario,
            label: DateFormat('dd/MM/yyyy').format(_evaluacion.fecha),
            color: AppColors.shimmerGold,
          ),
        ],
      ),
      children: [
        _resumenGeneral(context),
        const SizedBox(height: 24),
        const CalidadSeccion('Por cláusula'),
        _clausulas(context),
        const SizedBox(height: 24),
        CalidadSeccion(
          'Requisitos · ${filtrados.length}',
          trailing: _hayFiltros
              ? TextButton.icon(
                  onPressed: _limpiar,
                  icon: const Icon(AppIcons.sinFiltro, size: 18),
                  label: const Text('Limpiar'),
                )
              : null,
        ),
        _filtros(context),
        const SizedBox(height: 14),
        if (filtrados.isEmpty)
          _vacio(context)
        else
          ..._lista(context, filtrados),
        const SizedBox(height: 22),
        _pie(context),
      ],
    );
  }

  Widget _resumenGeneral(BuildContext context) {
    final resumen = _evaluacion.resumen;
    final cs = Theme.of(context).colorScheme;
    final leyenda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${resumen[EstadoCumplimiento.cumple]} de ${resumen.total} '
          'requisitos cumplen',
          style: AppDesign.titleStyle(context).copyWith(fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Toca un estado para filtrar la lista.',
          style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        for (final estado in EstadoCumplimiento.values)
          _leyendaItem(context, estado, resumen[estado]),
      ],
    );

    return AppPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final donut = DonutCumplimiento(resumen: resumen);
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: donut),
                const SizedBox(height: 18),
                leyenda,
              ],
            );
          }
          return Row(
            children: [
              donut,
              const SizedBox(width: 22),
              Expanded(child: leyenda),
            ],
          );
        },
      ),
    );
  }

  Widget _leyendaItem(
      BuildContext context, EstadoCumplimiento estado, int cantidad) {
    final seleccionado = _estado == estado;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: AppDesign.smallRadius,
      onTap: () => setState(() => _estado = seleccionado ? null : estado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? estado.color.withOpacity(0.12) : null,
          borderRadius: AppDesign.smallRadius,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: estado.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                estado.etiqueta,
                style: TextStyle(
                  fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              '$cantidad',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                color: estado.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clausulas(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, clausula) in Clausula.values.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 66, color: cs.outlineVariant),
            _clausulaFila(context, clausula),
          ],
        ],
      ),
    );
  }

  Widget _clausulaFila(BuildContext context, Clausula clausula) {
    final resumen = _evaluacion.resumenDe(clausula);
    final seleccionada = _clausula == clausula;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _clausula = seleccionada ? null : clausula),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        color: seleccionada
            ? AppColors.actionPositive.withOpacity(0.08)
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            CalidadIcono(clausula.icono),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${clausula.numero}  ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.shimmerGold,
                        ),
                      ),
                      TextSpan(
                        text: clausula.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  BarraCumplimiento(resumen: resumen, alto: 7),
                  const SizedBox(height: 6),
                  Text(
                    '${resumen[EstadoCumplimiento.cumple]} de ${resumen.total} '
                    'cumplen · ${resumen[EstadoCumplimiento.noCumple]} sin '
                    'cumplir',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: seleccionada
                  ? const Icon(AppIcons.completo,
                      key: ValueKey('sel'), color: AppColors.actionPositive)
                  : Text(
                      '${(resumen.avance * 100).round()}%',
                      key: const ValueKey('pct'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtros(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _busqueda,
          onChanged: (v) => setState(() => _consulta = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar requisito, cláusula o evidencia',
            prefixIcon: const Icon(AppIcons.buscar),
            suffixIcon: _consulta.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(AppIcons.cerrar),
                    onPressed: () => setState(() {
                      _consulta = '';
                      _busqueda.clear();
                    }),
                  ),
            border: OutlineInputBorder(
              borderRadius: AppDesign.mediumRadius,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final estado in EstadoCumplimiento.values) ...[
                FilterChip(
                  label: Text(estado.etiqueta),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight:
                        _estado == estado ? FontWeight.w800 : FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  avatar: Icon(estado.icono, size: 16, color: estado.color),
                  selected: _estado == estado,
                  showCheckmark: false,
                  selectedColor: estado.color.withOpacity(0.16),
                  side: BorderSide(color: estado.color.withOpacity(0.3)),
                  shape: const StadiumBorder(),
                  onSelected: (sel) =>
                      setState(() => _estado = sel ? estado : null),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _lista(BuildContext context, List<Requisito> requisitos) {
    final widgets = <Widget>[];
    for (final clausula in Clausula.values) {
      final grupo = requisitos.where((r) => r.clausula == clausula).toList();
      if (grupo.isEmpty) continue;
      if (_clausula == null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 14, bottom: 8),
          child: Text(
            '${clausula.numero} · ${clausula.nombre}',
            style: AppDesign.titleStyle(context).copyWith(fontSize: 15),
          ),
        ));
      }
      for (final r in grupo) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RequisitoCard(
            requisito: r,
            abierto: _abiertos.contains(r.id),
            onTap: () => setState(() {
              if (!_abiertos.remove(r.id)) _abiertos.add(r.id);
            }),
          ),
        ));
      }
    }
    return widgets;
  }

  Widget _vacio(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPanel(
      child: Column(
        children: [
          Icon(AppIcons.sinResultados, size: 36, color: cs.onSurfaceVariant),
          const SizedBox(height: 10),
          Text('Ningún requisito coincide con los filtros.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextButton(onPressed: _limpiar, child: const Text('Limpiar filtros')),
        ],
      ),
    );
  }

  Widget _pie(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Evaluación interna del software. No reemplaza la evaluación de la '
          'DTA-IBMETRO. Se actualiza al cerrar una brecha o al liberar una '
          'versión.',
          style: GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: AppDesign.positiveButtonStyle(),
          onPressed: _exportar,
          icon: const Icon(AppIcons.documento),
          label: const Text('Exportar matriz en PDF'),
        ),
      ],
    );
  }
}

class _RequisitoCard extends StatelessWidget {
  const _RequisitoCard({
    required this.requisito,
    required this.abierto,
    required this.onTap,
  });

  final Requisito requisito;
  final bool abierto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = requisito;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.mediumRadius,
        side: BorderSide(
          color: abierto
              ? r.estado.color.withOpacity(0.45)
              : cs.outlineVariant.withOpacity(0.7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: r.estado.color),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                CalidadEtiqueta(r.id),
                                Text(
                                  r.literal,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              r.titulo,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(r.estado.icono,
                          color: r.estado.color,
                          semanticLabel: r.estado.etiqueta),
                      AnimatedRotation(
                        turns: abierto ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(AppIcons.desplegar,
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: abierto
                        ? _detalle(context)
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detalle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = requisito;
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
          EstadoPillAlineado(r.estado),
          const SizedBox(height: 12),
          Text('QUÉ EXIGE', style: etiqueta),
          const SizedBox(height: 4),
          Text(r.exige, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          Text('CÓMO LO CUMPLE LA APP', style: etiqueta),
          const SizedBox(height: 6),
          for (final e in r.evidencias)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(AppIcons.listo,
                        size: 16, color: AppColors.actionPositive),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e, style: const TextStyle(height: 1.35)),
                  ),
                ],
              ),
            ),
          if (r.brecha != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: r.estado.color.withOpacity(0.09),
                borderRadius: AppDesign.smallRadius,
                border: Border.all(color: r.estado.color.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BRECHA',
                      style: etiqueta.copyWith(color: r.estado.color)),
                  const SizedBox(height: 4),
                  Text(r.brecha!, style: const TextStyle(height: 1.4)),
                  if (r.accion != null) ...[
                    const SizedBox(height: 10),
                    Text('ACCIÓN PROPUESTA', style: etiqueta),
                    const SizedBox(height: 4),
                    Text(r.accion!, style: const TextStyle(height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
          if (r.cierre != null || r.riesgo != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.cierre != null)
                  CalidadEtiqueta('Cierre: ${r.cierre!.etiqueta}'),
                if (r.riesgo != null)
                  CalidadEtiqueta(
                    'Riesgo ${r.riesgo!.etiqueta.toLowerCase()}',
                    color: switch (r.riesgo!) {
                      Riesgo.alto => AppColors.actionNegative,
                      Riesgo.medio => const Color(0xFFB07F00),
                      Riesgo.bajo => cs.onSurfaceVariant,
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Píldora de estado alineada a la izquierda dentro de una columna estirada.
class EstadoPillAlineado extends StatelessWidget {
  const EstadoPillAlineado(this.estado, {super.key});

  final EstadoCumplimiento estado;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.centerLeft, child: EstadoPill(estado));
}
