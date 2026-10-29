import 'package:flutter/material.dart';

import '../../../models/service_session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../../../theme/app_icons.dart';

/// Los textos del selector: las pesas de balanzas o, con otros textos, los
/// patrones de otra calibración (termómetros, termohigrómetros).
class PatronSelectorTexts {
  const PatronSelectorTexts({
    required this.title,
    required this.emptyHint,
    required this.filledHint,
    required this.sheetTitle,
    required this.searchHint,
    required this.chooseLabel,
    required this.loadingLabel,
    required this.loadFailed,
    required this.noMatches,
    required this.noMatchesHint,
    required this.emptyCatalog,
    required this.emptyCatalogHint,
    required this.defaultType,
    required this.footer,
  });

  static const pesas = PatronSelectorTexts(
    title: 'Patrones utilizados',
    emptyHint: 'Añade las pesas o juegos que usaste en la calibración.',
    filledHint: 'Revisa la cantidad utilizada de cada patrón.',
    sheetTitle: 'Pesas patrón',
    searchHint: 'Buscar código o tipo de pesa',
    chooseLabel: 'Seleccionar pesas patrón',
    loadingLabel: 'Cargando pesas…',
    loadFailed: 'No se pudo cargar el catálogo de pesas.',
    noMatches: 'No hay pesas que coincidan',
    noMatchesHint: 'Prueba con otro código o tipo de pesa.',
    emptyCatalog: 'No hay pesas en la precarga',
    emptyCatalogHint: 'Actualiza la precarga para disponer del catálogo.',
    defaultType: 'Pesa patrón',
    footer: 'Hasta 5 patrones · La cantidad se indica por separado',
  );

  final String title;
  final String emptyHint;
  final String filledHint;
  final String sheetTitle;
  final String searchHint;
  final String chooseLabel;
  final String loadingLabel;
  final String loadFailed;
  final String noMatches;
  final String noMatchesHint;
  final String emptyCatalog;
  final String emptyCatalogHint;

  /// Tipo que se muestra si el equipo no tiene uno en la precarga.
  final String defaultType;
  final String footer;
}

/// Selección de patrones del servicio. El catálogo se confirma como un conjunto;
/// cerrar el selector conserva las pesas y cantidades que ya estaban guardadas.
class PatronWeightsSelector extends StatelessWidget {
  const PatronWeightsSelector({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onChanged,
    this.onEditQuantity,
    this.loading = false,
    this.loadFailed = false,
    this.onRetry,
    this.texts = PatronSelectorTexts.pesas,
    this.icon = AppIcons.balanza,
    this.maxSelection = maxWeights,
  });

  static const maxWeights = 5;
  final List<EquipoInfo> catalog;
  final List<EquipoInfo> selected;
  final ValueChanged<List<EquipoInfo>> onChanged;

  /// Sin él no se muestra la cantidad (un termómetro no se cuenta por
  /// unidades como un juego de pesas).
  final ValueChanged<EquipoInfo>? onEditQuantity;
  final bool loading;
  final bool loadFailed;
  final VoidCallback? onRetry;
  final PatronSelectorTexts texts;
  final IconData icon;
  final int maxSelection;

  Future<void> _choose(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<List<EquipoInfo>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WeightsSheet(
        catalog: catalog,
        selected: selected,
        texts: texts,
        maxSelection: maxSelection,
      ),
    );
    if (result != null && context.mounted) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppDesign.mediumRadius,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _WeightIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texts.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          _CountPill(count: selected.length, max: maxSelection),
        ]),
        const SizedBox(height: 10),
        Text(
          selected.isEmpty ? texts.emptyHint : texts.filledHint,
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
        ),
        for (final weight in selected) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(weight.codInstrumento ?? 'Sin código',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    IconButton(
                      tooltip: 'Quitar ${weight.codInstrumento}',
                      onPressed: () => onChanged(selected
                          .where(
                              (e) => e.codInstrumento != weight.codInstrumento)
                          .toList()),
                      icon: const Icon(AppIcons.cerrar, size: 20),
                    ),
                  ]),
                  Text(weight.tipo ?? texts.defaultType,
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  _Certificate(weight: weight),
                  if (onEditQuantity != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => onEditQuantity!(weight),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.outlineVariant),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(children: [
                        const Expanded(child: Text('Cantidad utilizada')),
                        Text(weight.cantidad ?? '1',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(width: 12),
                        const Icon(AppIcons.editar, size: 18),
                      ]),
                    ),
                  ],
                ]),
          ),
        ],
        const SizedBox(height: 16),
        if (loadFailed) ...[
          Text(texts.loadFailed, style: TextStyle(color: colors.error)),
          TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(AppIcons.actualizar),
              label: const Text('Reintentar')),
        ] else
          FilledButton.icon(
            style: AppDesign.positiveButtonStyle()
                .copyWith(elevation: const WidgetStatePropertyAll(0)),
            onPressed: loading ? null : () => _choose(context),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(selected.isEmpty ? AppIcons.agregar : AppIcons.filtros),
            label: Text(loading
                ? texts.loadingLabel
                : selected.isEmpty
                    ? texts.chooseLabel
                    : 'Cambiar selección'),
          ),
        const SizedBox(height: 8),
        Text(texts.footer,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
      ]),
    );
  }
}

class _WeightsSheet extends StatefulWidget {
  const _WeightsSheet({
    required this.catalog,
    required this.selected,
    required this.texts,
    required this.maxSelection,
  });
  final List<EquipoInfo> catalog;
  final List<EquipoInfo> selected;
  final PatronSelectorTexts texts;
  final int maxSelection;

  @override
  State<_WeightsSheet> createState() => _WeightsSheetState();
}

class _WeightsSheetState extends State<_WeightsSheet> {
  final _search = TextEditingController();
  late final List<EquipoInfo> _draft = List.of(widget.selected);
  late final List<EquipoInfo> _catalog = _allWeights();
  bool _onlySelected = false;

  List<EquipoInfo> _allWeights() {
    // Un patrón ya guardado sigue siendo visible aunque falte en la precarga.
    final byCode = <String, EquipoInfo>{};
    for (final e in [...widget.catalog, ...widget.selected]) {
      if (e.codInstrumento?.trim().isNotEmpty ?? false) {
        byCode[e.codInstrumento!] = e;
      }
    }
    return byCode.values.toList()
      ..sort((a, b) => a.codInstrumento!.compareTo(b.codInstrumento!));
  }

  bool _contains(EquipoInfo weight) =>
      _draft.any((e) => e.codInstrumento == weight.codInstrumento);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final visible = _catalog
        .where((e) =>
            (!_onlySelected || _contains(e)) &&
            '${e.codInstrumento} ${e.tipo} ${e.enteCalibrador}'
                .toLowerCase()
                .contains(query))
        .toList();
    final texts = widget.texts;
    final max = widget.maxSelection;
    final atLimit = _draft.length >= max;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height - keyboard) * .9,
        child: Material(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
              top: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                  child: Row(children: [
                    Expanded(
                        child: Text(texts.sheetTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800))),
                    _CountPill(count: _draft.length, max: max),
                    IconButton(
                        tooltip: 'Cancelar selección',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(AppIcons.cerrar)),
                  ]),
                ),
                Expanded(
                    child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        sliver: SliverToBoxAdapter(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Text(
                                  'Marca los patrones utilizados y confirma tu selección.',
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant)),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: texts.searchHint,
                                  prefixIcon: const Icon(AppIcons.buscar),
                                  suffixIcon: query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Limpiar búsqueda',
                                          icon: const Icon(AppIcons.cerrar),
                                          onPressed: () =>
                                              setState(_search.clear)),
                                  filled: true,
                                  fillColor: colors.surfaceContainerLow,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, runSpacing: 4, children: [
                                ChoiceChip(
                                    label: Text('Todas (${_catalog.length})'),
                                    selected: !_onlySelected,
                                    onSelected: (_) =>
                                        setState(() => _onlySelected = false)),
                                ChoiceChip(
                                    label: Text(
                                        'Seleccionadas (${_draft.length})'),
                                    selected: _onlySelected,
                                    onSelected: (_) =>
                                        setState(() => _onlySelected = true)),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                  atLimit
                                      ? 'Límite de $max alcanzado. Quita una para elegir otra.'
                                      : 'Puedes elegir hasta $max patrones.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant)),
                            ]))),
                    if (visible.isEmpty)
                      SliverToBoxAdapter(
                          child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: Column(children: [
                          Icon(AppIcons.sinResultados,
                              size: 40, color: colors.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                              query.isNotEmpty
                                  ? texts.noMatches
                                  : _onlySelected
                                      ? 'Aún no seleccionaste patrones'
                                      : texts.emptyCatalog,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                              query.isNotEmpty
                                  ? texts.noMatchesHint
                                  : _onlySelected
                                      ? 'Abre «Todas» para añadirlas.'
                                      : texts.emptyCatalogHint,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant)),
                        ]),
                      ))
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        sliver: SliverList.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final weight = visible[index];
                            final selected = _contains(weight);
                            final enabled = selected || !atLimit;
                            void toggle() => setState(() {
                                  if (selected) {
                                    _draft.removeWhere((e) =>
                                        e.codInstrumento ==
                                        weight.codInstrumento);
                                  } else if (!atLimit) {
                                    // Conserva la cantidad al desmarcar y volver a marcar.
                                    _draft.add(weight);
                                  }
                                });
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Semantics(
                                checked: selected,
                                enabled: enabled,
                                child: Material(
                                  color: selected
                                      ? AppColors.actionPositive
                                          .withOpacity(.12)
                                      : colors.surface,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: selected
                                              ? AppColors.actionPositive
                                              : colors.outlineVariant,
                                          width: selected ? 1.5 : 1)),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: enabled ? toggle : null,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          14, 12, 4, 14),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(weight.codInstrumento!,
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: enabled
                                                              ? colors.onSurface
                                                              : colors
                                                                  .onSurfaceVariant)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      weight.tipo ??
                                                          texts.defaultType,
                                                      style: TextStyle(
                                                          color: colors
                                                              .onSurfaceVariant)),
                                                  const SizedBox(height: 10),
                                                  _Certificate(weight: weight),
                                                ])),
                                            ExcludeSemantics(
                                                child: Checkbox(
                                              value: selected,
                                              onChanged: enabled
                                                  ? (_) => toggle()
                                                  : null,
                                              activeColor:
                                                  AppColors.actionPositive,
                                              checkColor:
                                                  AppColors.actionPositiveInk,
                                            )),
                                          ]),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: colors.outlineVariant))),
                  child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: AppDesign.positiveButtonStyle().copyWith(
                            elevation: const WidgetStatePropertyAll(0)),
                        onPressed: () =>
                            Navigator.pop(context, List<EquipoInfo>.of(_draft)),
                        icon: const Icon(AppIcons.listo),
                        label: Text('Confirmar selección (${_draft.length})'),
                      )),
                ),
              ])),
        ),
      ),
    );
  }
}

class _WeightIcon extends StatelessWidget {
  const _WeightIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: AppColors.accentYellow.withOpacity(.15),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 24),
      );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, this.max = 5});
  final int count;
  final int max;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20)),
        child: Text('$count / $max',
            semanticsLabel: '$count de $max patrones seleccionados',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

/// Mantiene el criterio de vigencia de 365 días usado por la calibración.
class WeightCertificateStatus {
  WeightCertificateStatus(String? raw) {
    final date = DateTime.tryParse(raw?.trim() ?? '');
    if (date == null) {
      label = 'Sin fecha válida';
      color = Colors.grey;
      expired = false;
      return;
    }
    final remaining = 365 - DateTime.now().difference(date).inDays;
    expired = remaining < 0;
    label = expired
        ? 'Vencido'
        : remaining <= 90
            ? 'Por vencer ($remaining días)'
            : 'Vigente ($remaining días)';
    color = expired
        ? const Color(0xFFB23B32)
        : remaining <= 90
            ? const Color(0xFF946000)
            : const Color(0xFF287343);
  }
  late final String label;
  late final Color color;
  late final bool expired;
}

class _Certificate extends StatelessWidget {
  const _Certificate({required this.weight});
  final EquipoInfo weight;
  @override
  Widget build(BuildContext context) {
    final status = WeightCertificateStatus(weight.certFecha);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        dark ? Color.lerp(status.color, Colors.white, .5)! : status.color;
    final date = DateTime.tryParse(weight.certFecha?.trim() ?? '');
    final formatted = date == null
        ? null
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: status.color.withOpacity(dark ? .22 : .09),
                borderRadius: BorderRadius.circular(6)),
            child: Text(status.label,
                style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          if (formatted != null)
            Text('Cert. $formatted',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]);
  }
}
