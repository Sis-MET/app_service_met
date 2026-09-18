import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_design.dart';

/// Teclado numérico propio para las lecturas de una calibración.
///
/// El teclado del sistema lo decide cada fabricante: hay teléfonos sin
/// separador decimal, otros que solo muestran la coma y otros sin signo menos.
/// Este es igual en todos: dígitos, punto decimal, signo y borrar, con teclas
/// grandes para usarlo de pie y con guantes.
///
/// Los campos que lo usan se declaran con [KeypadInput], que les pone
/// `TextInputType.none` para que el sistema no abra el suyo. No se cambia el
/// control de entrada global (`TextInput.setInputControl`): al devolvérselo al
/// sistema, un campo de texto enfocado justo después se quedaba sin teclado.
///
/// Cada tecla edita el campo enfocado a través de su controlador y avisa con el
/// mismo `onChanged` que usa el teclado del sistema, así que la validación y el
/// autoguardado no distinguen de dónde vino la pulsación.
class NumericKeypadController extends ChangeNotifier {
  NumericKeypadController({this.onReadIndicator});

  /// Abre el lector del display de la balanza y devuelve la lectura que el
  /// técnico confirmó, o null si canceló. Sin él, el teclado no ofrece leer.
  final IndicatorReader? onReadIndicator;

  final Set<_KeypadInputState> _fields = <_KeypadInputState>{};
  _KeypadInputState? _active;
  bool _disposed = false;

  /// Hay un campo del teclado enfocado.
  bool get visible => _active != null;

  /// El campo enfocado es una lectura del indicador y hay con qué leerla.
  bool get canRead =>
      onReadIndicator != null && (_active?.widget.readable ?? false);

  /// Lee el indicador y escribe la lectura en el campo enfocado, como si se
  /// hubiera tecleado. Después devuelve el foco al campo para seguir con
  /// "Siguiente".
  Future<void> readIndicator(BuildContext context) async {
    final field = _active;
    final reader = onReadIndicator;
    if (field == null || reader == null || !field.widget.readable) return;
    final reading = await reader(context);
    if (reading == null || _disposed || !field.mounted) return;
    final before = field.widget.controller.value;
    field.widget.controller.value = TextEditingValue(
      text: reading,
      selection: TextSelection.collapsed(offset: reading.length),
    );
    if (reading != before.text) field.widget.onChanged?.call(reading);
    field.focusNode.requestFocus();
  }

  /// El campo enfocado admite valores negativos (indicación, retorno a cero).
  bool get allowNegative => _active?.widget.allowNegative ?? false;

  /// El campo enfocado admite decimales. Las columnas enteras del servidor,
  /// como la cantidad de pesas, no.
  bool get allowDecimal => _active?.widget.allowDecimal ?? true;

  void digit(String value) => _edit((v) => KeypadEdit.digit(v, value));
  void backspace() => _edit(KeypadEdit.backspace);
  void clear() => _edit((_) => TextEditingValue.empty);

  void decimalPoint() {
    if (allowDecimal) _edit(KeypadEdit.decimalPoint);
  }

  void toggleSign() {
    if (allowNegative) _edit(KeypadEdit.toggleSign);
  }

  /// Pasa al siguiente campo del teclado en orden de lectura, de arriba abajo
  /// y de izquierda a derecha. Después del último, cierra el teclado.
  void next() {
    final current = _active;
    if (current == null) return;
    final from = current.focusNode.rect;
    // Solo los campos de la misma lista: el PageView de la calibración puede
    // tener construida otra página, y enfocarla la traería a la vista.
    final scrollable = current._scrollable;
    final following = _fields
        .where(
          (field) =>
              field != current &&
              field.mounted &&
              field.focusNode.context != null &&
              field.focusNode.canRequestFocus &&
              field._scrollable == scrollable &&
              _readingOrder(field.focusNode.rect, from) > 0,
        )
        .toList()
      ..sort((a, b) => _readingOrder(a.focusNode.rect, b.focusNode.rect));
    if (following.isEmpty) {
      close();
    } else {
      following.first.focusNode.requestFocus();
    }
  }

  /// Cierra el teclado quitando el foco al campo.
  void close() => _active?.focusNode.unfocus();

  static int _readingOrder(Rect a, Rect b) => (a.top - b.top).abs() > 1
      ? a.top.compareTo(b.top)
      : a.left.compareTo(b.left);

  void _edit(TextEditingValue Function(TextEditingValue) change) {
    final field = _active;
    if (field == null) return;
    final before = field.widget.controller.value;
    final after = change(before);
    if (after == before) return;
    field.widget.controller.value = after;
    if (after.text != before.text) field.widget.onChanged?.call(after.text);
  }

  void _register(_KeypadInputState field) => _fields.add(field);

  void _unregister(_KeypadInputState field) {
    _fields.remove(field);
    if (_active == field) {
      _active = null;
      // Se llega aquí al desmontar el campo, con el árbol bloqueado: el panel
      // se redibuja en el cuadro siguiente, si la pantalla sigue abierta.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  void _focusChanged(_KeypadInputState field, bool focused) {
    if (focused) {
      _active = field;
      notifyListeners();
      // El panel aparece en este cuadro y le quita alto a la pantalla: el
      // campo se vuelve a mostrar cuando ya se sabe cuánto sitio queda. Va
      // después de que el propio campo lleve el cursor a la vista.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => scheduleMicrotask(() => field._reveal()),
      );
    } else if (_active == field) {
      _active = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Lector de la lectura del indicador: abre su pantalla desde [context] y
/// devuelve el valor confirmado ("12.345"), o null si se canceló.
typedef IndicatorReader = Future<String?> Function(BuildContext context);

/// Ediciones de cada tecla, sin estado, sobre el valor del campo.
abstract final class KeypadEdit {
  static TextEditingValue digit(TextEditingValue value, String digit) =>
      _replaceSelection(value, digit);

  /// El punto entra una sola vez. Al principio del número entra como "0.",
  /// que es como se escribe una lectura menor que uno.
  static TextEditingValue decimalPoint(TextEditingValue value) {
    final selection = _selection(value);
    final kept = value.text.substring(0, selection.start) +
        value.text.substring(selection.end);
    if (kept.contains('.') || kept.contains(',')) return value;
    final before =
        value.text.substring(0, selection.start).replaceFirst('-', '');
    return _replaceSelection(value, before.isEmpty ? '0.' : '.');
  }

  /// El signo va siempre delante, esté donde esté el cursor. Pulsarlo otra
  /// vez lo quita.
  static TextEditingValue toggleSign(TextEditingValue value) {
    final selection = _selection(value);
    if (value.text.startsWith('-')) {
      return TextEditingValue(
        text: value.text.substring(1),
        selection: TextSelection.collapsed(
          offset: (selection.end - 1).clamp(0, value.text.length - 1),
        ),
      );
    }
    return TextEditingValue(
      text: '-${value.text}',
      selection: TextSelection.collapsed(offset: selection.end + 1),
    );
  }

  static TextEditingValue backspace(TextEditingValue value) {
    final selection = _selection(value);
    if (!selection.isCollapsed) return _replaceSelection(value, '');
    if (selection.start == 0) return value;
    return TextEditingValue(
      text: value.text.substring(0, selection.start - 1) +
          value.text.substring(selection.start),
      selection: TextSelection.collapsed(offset: selection.start - 1),
    );
  }

  static TextSelection _selection(TextEditingValue value) =>
      value.selection.isValid
          ? value.selection
          : TextSelection.collapsed(offset: value.text.length);

  static TextEditingValue _replaceSelection(
    TextEditingValue value,
    String insert,
  ) {
    final selection = _selection(value);
    return TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, insert),
      selection: TextSelection.collapsed(
        offset: selection.start + insert.length,
      ),
    );
  }
}

/// Para el teclado del sistema, cuando el campo no tiene teclado propio: deja
/// escribir solo un número con punto decimal y cambia la coma por punto.
class DecimalTextInputFormatter extends TextInputFormatter {
  const DecimalTextInputFormatter({
    this.allowNegative = false,
    this.allowDecimal = true,
  });

  final bool allowNegative;
  final bool allowDecimal;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    final sign = allowNegative ? '-?' : '';
    final fraction = allowDecimal ? r'(\.\d*)?' : '';
    if (!RegExp('^$sign\\d*$fraction\$').hasMatch(text)) return oldValue;
    // La coma y el punto miden lo mismo: la selección sigue siendo válida.
    return newValue.copyWith(text: text);
  }
}

/// Da acceso al teclado a los campos que cuelgan de una pantalla.
class NumericKeypadScope extends InheritedWidget {
  const NumericKeypadScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final NumericKeypadController controller;

  /// Sin dependencia: los campos no se reconstruyen con cada tecla.
  static NumericKeypadController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NumericKeypadScope>()?.controller;

  @override
  bool updateShouldNotify(NumericKeypadScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Conecta un campo de texto al teclado numérico de la pantalla.
///
/// [builder] recibe el [FocusNode] que lo conecta: el campo debe usarlo y
/// declararse con `TextInputType.none`. Sin [NumericKeypadScope] alrededor
/// recibe `null` y el campo se queda con el teclado del sistema.
class KeypadInput extends StatefulWidget {
  const KeypadInput({
    required this.controller,
    required this.builder,
    this.onChanged,
    this.allowNegative = false,
    this.allowDecimal = true,
    this.readable = false,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool allowNegative;
  final bool allowDecimal;

  /// El valor sale del display de la balanza (indicación, retorno): el
  /// teclado ofrece leerlo con la cámara.
  final bool readable;
  final Widget Function(BuildContext context, FocusNode? keypadFocus) builder;

  @override
  State<KeypadInput> createState() => _KeypadInputState();
}

class _KeypadInputState extends State<KeypadInput> {
  final FocusNode focusNode = FocusNode(debugLabel: 'keypad');
  NumericKeypadController? keypad;

  /// Lista que contiene al campo; null dentro de un diálogo sin desplazamiento.
  /// Se busca sin crear dependencia: se consulta fuera de `build`.
  ScrollableState? get _scrollable =>
      context.findAncestorStateOfType<ScrollableState>();

  @override
  void initState() {
    super.initState();
    // Se registra antes que el campo: el panel se pide en el mismo ciclo en
    // que el campo recibe el foco.
    focusNode.addListener(_focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = NumericKeypadScope.maybeOf(context);
    if (scope != keypad) {
      keypad?._unregister(this);
      keypad = scope?.._register(this);
    }
  }

  void _focusChanged() => keypad?._focusChanged(this, focusNode.hasFocus);

  /// Muestra el campo con su rótulo encima y aire debajo, sobre el panel.
  void _reveal() {
    final box = focusNode.context?.findRenderObject();
    if (!mounted || !focusNode.hasFocus || box is! RenderBox || !box.attached) {
      return;
    }
    box.showOnScreen(
      rect: Rect.fromLTRB(0, -36, box.size.width, box.size.height + 48),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    keypad?._unregister(this);
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, keypad == null ? null : focusNode);
}

/// Teclado propio para los campos de una hoja o un diálogo, que quedan fuera
/// del [NumericKeypadScope] de la pantalla. El panel aparece debajo de [child]
/// mientras uno de sus campos está enfocado.
///
/// Necesita alto acotado (un diálogo o una hoja modal): con el panel abierto
/// queda menos sitio y [child] se desplaza.
class NumericKeypadHost extends StatefulWidget {
  const NumericKeypadHost({
    required this.child,
    this.onReadIndicator,
    super.key,
  });

  final Widget child;

  /// Lector del display para los campos marcados como lectura.
  final IndicatorReader? onReadIndicator;

  @override
  State<NumericKeypadHost> createState() => _NumericKeypadHostState();
}

class _NumericKeypadHostState extends State<NumericKeypadHost> {
  late final _keypad =
      NumericKeypadController(onReadIndicator: widget.onReadIndicator);

  @override
  void dispose() {
    _keypad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NumericKeypadScope(
      controller: _keypad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(child: SingleChildScrollView(child: widget.child)),
          ListenableBuilder(
            listenable: _keypad,
            builder: (context, _) => _keypad.visible
                ? NumericKeypad(controller: _keypad, embedded: true)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Panel de teclas. En la calibración ocupa el pie de la pantalla mientras
/// hay un campo del teclado enfocado.
///
/// Distribución de teléfono, con el 1 arriba:
///
///     1  2  3  ⌫
///     4  5  6  −
///     7  8  9  Siguiente
///     .  0  Listo
///
/// Se arma por columnas iguales, sin medir el ancho disponible, para que
/// también funcione dentro de un `AlertDialog`, que pide anchos intrínsecos.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    required this.controller,
    this.embedded = false,
    super.key,
  });

  final NumericKeypadController controller;

  /// Dentro de una hoja o un diálogo: sin fondo propio ni margen del sistema.
  final bool embedded;

  static const double _gap = 6;
  static const double _keyHeight = 52;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final keys = ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        Widget digit(String value) => _KeypadKey(
              key: ValueKey('keypad-$value'),
              label: value,
              onTap: () => controller.digit(value),
            );
        Widget column(List<Widget> children) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _gap,
                children: children,
              ),
            );

        final keys = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: _gap,
          children: [
            column([
              digit('1'),
              digit('4'),
              digit('7'),
              _KeypadKey(
                key: const ValueKey('keypad-point'),
                label: '.',
                glyph: true,
                semanticLabel: 'Punto decimal',
                onTap: controller.allowDecimal ? controller.decimalPoint : null,
              ),
            ]),
            column([digit('2'), digit('5'), digit('8'), digit('0')]),
            column([
              digit('3'),
              digit('6'),
              digit('9'),
              _KeypadKey(
                key: const ValueKey('keypad-done'),
                label: 'Listo',
                small: true,
                semanticLabel: 'Ocultar teclado',
                onTap: controller.close,
              ),
            ]),
            column([
              _KeypadKey(
                key: const ValueKey('keypad-backspace'),
                icon: Icons.backspace_outlined,
                semanticLabel: 'Borrar',
                onTap: controller.backspace,
                onLongPress: controller.clear,
              ),
              _KeypadKey(
                key: const ValueKey('keypad-sign'),
                label: '−',
                glyph: true,
                semanticLabel: 'Signo menos',
                onTap: controller.allowNegative ? controller.toggleSign : null,
              ),
              _KeypadKey(
                key: const ValueKey('keypad-next'),
                height: _keyHeight * 2 + _gap,
                label: 'Siguiente',
                small: true,
                icon: Icons.arrow_downward_rounded,
                semanticLabel: 'Siguiente campo',
                primary: true,
                onTap: controller.next,
              ),
            ]),
          ],
        );
        if (!controller.canRead) return keys;

        // Encima de las teclas, para no mover ninguna de un campo a otro.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: _gap,
          children: [
            _KeypadKey(
              key: const ValueKey('keypad-read'),
              height: 44,
              label: 'Leer del indicador',
              icon: Icons.document_scanner_outlined,
              small: true,
              horizontal: true,
              semanticLabel: 'Leer la lectura del indicador con la cámara',
              onTap: () => controller.readIndicator(context),
            ),
            keys,
          ],
        );
      },
    );

    return TextFieldTapRegion(
      // Las teclas nunca le quitan el foco al campo que están escribiendo.
      child: ExcludeFocus(
        child: embedded
            ? Padding(padding: const EdgeInsets.only(top: 14), child: keys)
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? AppDesign.canvasDark : AppDesign.canvas,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.borderDarkSoft
                          : AppColors.borderLight,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: keys,
                  ),
                ),
              ),
      ),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    this.height = NumericKeypad._keyHeight,
    this.label,
    this.icon,
    this.semanticLabel,
    this.onTap,
    this.onLongPress,
    this.primary = false,
    this.small = false,
    this.glyph = false,
    this.horizontal = false,
    super.key,
  });

  final double height;
  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool primary;

  /// Ícono al lado del rótulo, para la tecla ancha de leer el indicador.
  final bool horizontal;

  /// Rótulo de palabra ("Listo") en vez de cifra: cuerpo más pequeño.
  final bool small;

  /// Punto y signo: a cuerpo de cifra quedaban casi invisibles al lado de
  /// los dígitos.
  final bool glyph;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    final ink = primary
        ? AppColors.actionPositiveInk
        : (isDark ? Colors.white : AppDesign.ink);
    final fill = primary
        ? AppColors.actionPositive
        : (isDark ? AppColors.cardDark : Colors.white);
    final edge = primary
        ? AppColors.actionPositive
        : (isDark ? AppColors.borderDarkSoft : AppColors.borderLight);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Opacity(
        // Una tecla que no aplica se apaga, no desaparece: la distribución no
        // cambia de un campo a otro.
        opacity: enabled ? 1 : 0.35,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: edge),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            onLongPress: onLongPress,
            child: SizedBox(
              height: height,
              child: Flex(
                direction: horizontal ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: horizontal ? 8 : 4,
                children: [
                  if (icon != null)
                    Icon(icon, size: small ? 20 : 24, color: ink),
                  if (label != null)
                    Text(
                      label!,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: small
                            ? 15
                            : glyph
                                ? 34
                                : 26,
                        height: 1,
                        color: ink,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
