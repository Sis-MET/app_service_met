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
class CalibrationNumberField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final allowDecimal = _allowDecimal;
    return KeypadInput(
      controller: controller,
      onChanged: onChanged,
      allowNegative: allowNegative,
      allowDecimal: allowDecimal,
      readable: readable,
      builder: (context, keypadFocus) =>
          ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final error = column == null
              ? null
              : CalibrationRecordValidator.fieldError(column!, value.text);
          return TextField(
            controller: controller,
            focusNode: keypadFocus,
            enabled: enabled,
            autofocus: autofocus,
            style: style,
            keyboardType: keypadFocus != null
                ? TextInputType.none
                : TextInputType.numberWithOptions(
                    decimal: allowDecimal,
                    signed: allowNegative,
                  ),
            inputFormatters: [
              DecimalTextInputFormatter(
                allowNegative: allowNegative,
                allowDecimal: allowDecimal,
              ),
            ],
            onChanged: onChanged,
            decoration: decoration.copyWith(
              errorText: error,
              errorMaxLines: 3,
            ),
          );
        },
      ),
    );
  }
}
