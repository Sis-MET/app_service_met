import 'dart:async';
import 'package:flutter/material.dart';

import '../../../database/calibration_record_validator.dart';
import '../../../widgets/numeric_keypad.dart';

/// Encuentra un campo numérico de la página activa por su columna de guardado.
class CalibrationFieldNavigator {
  final Map<String, _CalibrationNumberFieldState> _fields = {};
  final List<({String column, String previous})> _edits = [];

  void recordEdit(String column, String previous, String current) {
    if (previous == current) return;
    _edits.add((column: column, previous: previous));
    if (_edits.length > 50) _edits.removeAt(0);
  }

  bool canUndoInStep(int step) => _edits.any(
      (edit) => CalibrationRecordValidator.labelFor(edit.column).step == step);

  Future<bool> undoInStep(int step) async {
    final index = _edits.lastIndexWhere((edit) =>
        CalibrationRecordValidator.labelFor(edit.column).step == step);
    if (index < 0) return false;
    final edit = _edits.removeAt(index);
    final field = _fields[edit.column];
    if (field == null || !field.mounted) return false;
    field.widget.controller.value = TextEditingValue(
      text: edit.previous,
      selection: TextSelection.collapsed(offset: edit.previous.length),
    );
    field.widget.onChanged?.call(edit.previous);
    return reveal(edit.column);
  }

  void clearHistory() => _edits.clear();

  Future<bool> reveal(String column) async {
    final field = _fields[column];
    if (field == null || !field.mounted) return false;
    await Scrollable.ensureVisible(field.context,
        duration: const Duration(milliseconds: 250), alignment: 0.25);
    if (!field.mounted) return false;
    field.highlight();
    return true;
  }
}

class CalibrationFieldNavigationScope extends InheritedWidget {
  const CalibrationFieldNavigationScope({
    super.key,
    required this.navigator,
    required super.child,
  });
  final CalibrationFieldNavigator navigator;

  static CalibrationFieldNavigator? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<CalibrationFieldNavigationScope>()
      ?.navigator;

  @override
  bool updateShouldNotify(CalibrationFieldNavigationScope oldWidget) =>
      navigator != oldWidget.navigator;
}

/// Campo numérico de la calibración y de las pruebas de soporte técnico.
///
/// Escribe con el teclado propio de la pantalla ([NumericKeypadScope]) o, si
/// no hay uno, con el del sistema filtrado a un número con punto decimal. En
/// soporte se usa sin [column]: sus registros los valida el servidor al subir.
///
/// Con [column] valida lo escrito contra esa columna del servidor mientras se
/// escribe y muestra el motivo debajo del campo: lo que aquí se acepta es lo
/// mismo que acepta el guardado. Si la columna es entera, el punto decimal se
/// apaga.
class CalibrationNumberField extends StatefulWidget {
  const CalibrationNumberField({
    super.key,
    required this.controller,
    this.onChanged,
    this.column,
    this.allowNegative = false,
    this.allowDecimal,
    this.decoration = const InputDecoration(),
    this.style,
    this.enabled = true,
    this.autofocus = false,
    this.readable = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  /// Columna de `registros_calibracion` donde se guarda el valor.
  final String? column;

  final bool allowNegative;

  /// Por defecto, lo que diga la columna: las enteras no admiten decimales.
  final bool? allowDecimal;

  final InputDecoration decoration;
  final TextStyle? style;
  final bool enabled;
  final bool autofocus;

  /// Es una lectura del display (indicación, retorno): el teclado ofrece
  /// leerla con la cámara.
  final bool readable;

  bool get _allowDecimal =>
      allowDecimal ?? !CalibrationRecordValidator.isIntegerColumn(column);

  @override
  State<CalibrationNumberField> createState() => _CalibrationNumberFieldState();
}

class _CalibrationNumberFieldState extends State<CalibrationNumberField> {
  /// El motivo del rechazo, o null. El campo solo se rehace cuando aparece o
  /// desaparece: al teclear, el `TextField` ya se pinta solo.
  final ValueNotifier<String?> _error = ValueNotifier(null);
  CalibrationFieldNavigator? _navigator;
  Timer? _highlightTimer;
  bool _highlighted = false;
  late String _lastSeen = widget.controller.text;
  String _previousText = '';

  void highlight() {
    _highlightTimer?.cancel();
    setState(() => _highlighted = true);
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlighted = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = CalibrationFieldNavigationScope.maybeOf(context);
    if (next == _navigator) return;
    if (widget.column != null &&
        identical(_navigator?._fields[widget.column], this)) {
      _navigator?._fields.remove(widget.column);
    }
    _navigator = next;
    if (widget.column != null) _navigator?._fields[widget.column!] = this;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
    _check();
  }

  @override
  void didUpdateWidget(covariant CalibrationNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.column != widget.column) {
      if (oldWidget.column != null &&
          identical(_navigator?._fields[oldWidget.column], this)) {
        _navigator?._fields.remove(oldWidget.column);
      }
      if (widget.column != null) _navigator?._fields[widget.column!] = this;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_check);
      widget.controller.addListener(_check);
      _lastSeen = widget.controller.text;
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.column != widget.column) {
      _check();
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    if (widget.column != null &&
        identical(_navigator?._fields[widget.column], this)) {
      _navigator?._fields.remove(widget.column);
    }
    widget.controller.removeListener(_check);
    _error.dispose();
    super.dispose();
  }

  void _check() {
    if (widget.controller.text != _lastSeen) {
      _previousText = _lastSeen;
      _lastSeen = widget.controller.text;
    }
    final column = widget.column;
    _error.value = column == null
        ? null
        : CalibrationRecordValidator.fieldError(column, widget.controller.text);
  }

  void _onChanged(String text) {
    final column = widget.column;
    if (column != null) _navigator?.recordEdit(column, _previousText, text);
    widget.onChanged?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final allowDecimal = widget._allowDecimal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        border: Border.all(
            color: _highlighted
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: KeypadInput(
        controller: widget.controller,
        onChanged: _onChanged,
        allowNegative: widget.allowNegative,
        allowDecimal: allowDecimal,
        readable: widget.readable,
        builder: (context, keypadFocus) => ValueListenableBuilder<String?>(
          valueListenable: _error,
          builder: (context, error, _) {
            return TextField(
              controller: widget.controller,
              focusNode: keypadFocus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              style: widget.style,
              // Con el teclado propio el campo no se escribe desde el sistema:
              // así no se abre una conexión con el teclado de Android, que es
              // lo que trababa el primer toque en cada campo.
              readOnly: keypadFocus != null,
              showCursor: true,
              keyboardType: keypadFocus != null
                  ? TextInputType.none
                  : TextInputType.numberWithOptions(
                      decimal: allowDecimal,
                      signed: widget.allowNegative,
                    ),
              inputFormatters: [
                DecimalTextInputFormatter(
                  allowNegative: widget.allowNegative,
                  allowDecimal: allowDecimal,
                ),
              ],
              onChanged: _onChanged,
              decoration: widget.decoration.copyWith(
                errorText: error,
                errorMaxLines: 3,
              ),
            );
          },
        ),
      ),
    );
  }
}
