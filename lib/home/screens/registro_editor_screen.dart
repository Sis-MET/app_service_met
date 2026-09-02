import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../models/servicio_model.dart';
import '../services/local_service_record_repository.dart';

/// Editor de un registro individual (una fila de la base local).
///
/// Reemplaza al antiguo diálogo `_mostrarDialogoEdicion`, que no persistía nada
/// y creaba un `TextEditingController` por campo dentro de un único diálogo.
///
/// Diferencias clave:
/// * Persiste realmente vía [LocalServiceRecordRepository.update].
/// * Muestra **todas** las columnas de datos, incluidas las vacías o en `0`.
/// * Lista perezosa (`ListView.builder`); cada fila administra su propio
///   controlador. La fuente de verdad del texto vive en el padre (`_values`),
///   así que filtrar por búsqueda no pierde ediciones sin guardar.
/// * Buscador fijo para saltar a cualquier columna sin scrollear.
class RegistroEditorScreen extends StatefulWidget {
  final ServicioResumen servicio;
  final int index;
  final Map<String, dynamic> item;

  const RegistroEditorScreen({
    super.key,
    required this.servicio,
    required this.index,
    required this.item,
  });

  @override
  State<RegistroEditorScreen> createState() => _RegistroEditorScreenState();
}

class _RegistroEditorScreenState extends State<RegistroEditorScreen> {
  final _searchController = TextEditingController();
  final ValueNotifier<bool> _dirty = ValueNotifier(false);

  late final Map<String, dynamic> _original;
  late final List<String> _editableKeys;
  late final List<String> _systemKeys;
  final Map<String, String> _values = {};

  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _original = Map<String, dynamic>.from(widget.item);

    _editableKeys = _original.keys
        .where((k) => !kLocalRecordSystemKeys.contains(k))
        .toList();
    _systemKeys = _original.keys
        .where((k) => kLocalRecordSystemKeys.contains(k))
        .toList();

    for (final key in _editableKeys) {
      _values[key] = _stringify(_original[key]);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dirty.dispose();
    super.dispose();
  }

  static String _stringify(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  String _formatearNombreCampo(String campo) {
    return campo
        .replaceAll('_', ' ')
        .split(' ')
        .map((palabra) => palabra.isEmpty
            ? ''
            : palabra[0].toUpperCase() + palabra.substring(1).toLowerCase())
        .join(' ')
        .trim();
  }

  List<String> get _visibleKeys {
    if (_query.isEmpty) return _editableKeys;
    final q = _query.toLowerCase();
    return _editableKeys
        .where((k) =>
            k.toLowerCase().contains(q) ||
            _formatearNombreCampo(k).toLowerCase().contains(q))
        .toList();
  }

  Map<String, dynamic> _buildChanges() {
    final changes = <String, dynamic>{};
    for (final key in _editableKeys) {
      final current = _values[key] ?? '';
      if (current != _stringify(_original[key])) changes[key] = current;
    }
    return changes;
  }

  void _onFieldChanged(String key, String text) {
    _values[key] = text;
    final hasChanges = _buildChanges().isNotEmpty;
    if (_dirty.value != hasChanges) _dirty.value = hasChanges;
  }

  Future<void> _guardar() async {
    final changes = _buildChanges();
    if (changes.isEmpty) {
      _snack('No hay cambios para guardar', AppColors.warning);
      return;
    }

    setState(() => _saving = true);
    try {
      final affected = await LocalServiceRecordRepository.update(
        widget.servicio.tipo,
        _original,
        changes,
      );
      if (!mounted) return;
      if (affected <= 0) {
        setState(() => _saving = false);
        _snack('No se encontró el registro para actualizar', AppColors.warning);
        return;
      }
      _snack('${changes.length} campo(s) actualizado(s)', Colors.green);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Error al guardar: $e', AppColors.actionNegative);
    }
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleKeys = _visibleKeys;
    final titulo = _stringify(_original['cod_metrica']).isNotEmpty
        ? _stringify(_original['cod_metrica'])
        : '${widget.servicio.nombreItem} ${widget.index + 1}';

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: ServiceAppBar(
          title: 'Editar registro',
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _dirty,
              builder: (_, dirty, __) => TextButton.icon(
                onPressed: (_saving || !dirty) ? null : _guardar,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.servicio.prefijo} ${widget.servicio.codigo}  ·  $titulo',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Buscar campo…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      isDense: true,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${visibleKeys.length} de ${_editableKeys.length} campos',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: visibleKeys.length + (_systemKeys.isEmpty ? 0 : 1),
                itemBuilder: (context, i) {
                  if (i == visibleKeys.length) {
                    return _SystemFieldsSection(
                      keys: _systemKeys,
                      original: _original,
                      label: _formatearNombreCampo,
                      stringify: _stringify,
                    );
                  }
                  final key = visibleKeys[i];
                  return _CampoEditorTile(
                    key: ValueKey(key),
                    fieldKey: key,
                    label: _formatearNombreCampo(key),
                    initialValue: _values[key] ?? '',
                    onChanged: _onFieldChanged,
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _dirty,
          builder: (_, dirty, __) => dirty
              ? FloatingActionButton.extended(
                  onPressed: _saving ? null : _guardar,
                  backgroundColor: AppColors.actionPositive,
                  foregroundColor: AppColors.actionPositiveInk,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Guardar cambios'),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Fila editable: administra su propio [TextEditingController]. El texto vive
/// realmente en el padre; esta fila sólo lo refleja y notifica cambios.
class _CampoEditorTile extends StatefulWidget {
  final String fieldKey;
  final String label;
  final String initialValue;
  final void Function(String key, String value) onChanged;

  const _CampoEditorTile({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_CampoEditorTile> createState() => _CampoEditorTileState();
}

class _CampoEditorTileState extends State<_CampoEditorTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _controller,
        onChanged: (v) => widget.onChanged(widget.fieldKey, v),
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SystemFieldsSection extends StatelessWidget {
  final List<String> keys;
  final Map<String, dynamic> original;
  final String Function(String) label;
  final String Function(dynamic) stringify;

  const _SystemFieldsSection({
    required this.keys,
    required this.original,
    required this.label,
    required this.stringify,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const FaIcon(FontAwesomeIcons.lock, size: 14),
        title: Text(
          'Campos del sistema (${keys.length})',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Solo lectura',
          style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        children: [
          for (final key in keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      label(key),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Text(
                      stringify(original[key]).isEmpty
                          ? '—'
                          : stringify(original[key]),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.end,
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
