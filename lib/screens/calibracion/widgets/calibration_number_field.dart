import 'package:flutter/material.dart';

import '../../../database/calibration_record_validator.dart';
import '../../../widgets/numeric_keypad.dart';

/// Campo numérico de la calibración.
///
/// Escribe con el teclado propio de la pantalla ([NumericKeypadScope]) o, si
/// no hay uno, con el del sistema filtrado a un número con punto decimal.
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
    _check();
  }

  @override
  void didUpdateWidget(covariant CalibrationNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_check);
      widget.controller.addListener(_check);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.column != widget.column) {
      _check();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    _error.dispose();
    super.dispose();
  }

  void _check() {
    final column = widget.column;
    _error.value = column == null
        ? null
        : CalibrationRecordValidator.fieldError(
            column, widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final allowDecimal = widget._allowDecimal;
    return KeypadInput(
      controller: widget.controller,
      onChanged: widget.onChanged,
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
            onChanged: widget.onChanged,
            decoration: widget.decoration.copyWith(
              errorText: error,
              errorMaxLines: 3,
            ),
          );
        },
      ),
    );
  }
}
