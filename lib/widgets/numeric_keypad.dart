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

  /// Si el panel se ve, aparte de los demás avisos: lo que solo depende de
  /// esto —el panel, los botones que le dejan el sitio— no se rehace al
  /// pasar de un campo a otro.
  final ValueNotifier<bool> visibility = ValueNotifier<bool>(false);

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
    // El rectángulo de cada campo se mide una sola vez: pedirlo al ordenar lo
    // recalculaba en cada comparación, y una linealidad tiene decenas.
    _KeypadInputState? next;
    Rect? nextRect;
    for (final field in _fields) {
      if (field == current ||
          !field.mounted ||
          field._scrollable != scrollable ||
          field.focusNode.context == null ||
          !field.focusNode.canRequestFocus) {
        continue;
      }
      final rect = field.focusNode.rect;
      if (_readingOrder(rect, from) <= 0) continue;
      if (nextRect == null || _readingOrder(rect, nextRect) < 0) {
        next = field;
        nextRect = rect;
      }
    }
    if (next == null) {
      close();
    } else {
      next.focusNode.requestFocus();
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
        if (_disposed) return;
        visibility.value = visible;
        notifyListeners();
      });
    }
  }

  void _focusChanged(_KeypadInputState field, bool focused) {
    if (focused) {
      _active = field;
      visibility.value = true;
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
      // Al pasar de un campo a otro, este pierde el foco antes de que el
      // siguiente lo gane, dentro del mismo cambio de foco: se decide después
      // si el panel se oculta, para no ocultarlo y volverlo a mostrar.
      scheduleMicrotask(() {
        if (!_disposed) visibility.value = visible;
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    visibility.dispose();
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
  /// Se guarda al montarlo: buscarla recorre el árbol hacia arriba y hace
  /// falta para cada campo al pasar al siguiente.
  ScrollableState? _scrollable;

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
    _scrollable = Scrollable.maybeOf(context);
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
          NumericKeypadSlot(controller: _keypad, embedded: true),
        ],
      ),
    );
  }
}

/// Sitio del panel al pie de una pantalla o de un diálogo.
///
/// Arma el teclado la primera vez que hace falta y después lo deja montado,
/// oculto. Volverlo a armar en cada campo enfocado costaba un cuadro entero:
/// son catorce teclas, y con ellas todo su estado, que el teléfono rehacía
/// cada vez que el técnico tocaba una casilla.
class NumericKeypadSlot extends StatefulWidget {
  const NumericKeypadSlot({
    required this.controller,
    this.embedded = false,
    super.key,
  });

  final NumericKeypadController controller;

  /// Dentro de una hoja o un diálogo: sin fondo propio ni margen del sistema.
  final bool embedded;

  @override
  State<NumericKeypadSlot> createState() => _NumericKeypadSlotState();
}

class _NumericKeypadSlotState extends State<NumericKeypadSlot> {
  /// El panel ya se armó alguna vez: de aquí en adelante solo se oculta.
  bool _built = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.visibility,
      builder: (context, visible, child) {
        if (!visible && !_built) return const SizedBox.shrink();
        _built = true;
        return Offstage(offstage: !visible, child: child);
      },
      child: NumericKeypad(
        controller: widget.controller,
        embedded: widget.embedded,
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
///
/// Normalmente se usa a través de [NumericKeypadSlot], que lo deja montado
/// entre un campo y otro.
class NumericKeypad extends StatefulWidget {
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
  State<NumericKeypad> createState() => _NumericKeypadState();
}

class _NumericKeypadState extends State<NumericKeypad> {
  late bool _allowDecimal = widget.controller.allowDecimal;
  late bool _allowNegative = widget.controller.allowNegative;
  late bool _canRead = widget.controller.canRead;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_keysChanged);
  }

  @override
  void didUpdateWidget(covariant NumericKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_keysChanged);
      widget.controller.addListener(_keysChanged);
      _keysChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_keysChanged);
    super.dispose();
  }

  /// El panel se rehace solo cuando alguna tecla cambia, no cada vez que se
  /// enfoca un campo: entre dos campos del mismo tipo no hay nada que hacer.
  /// Al cerrarse tampoco, que ya no se ve y el próximo foco lo dirá.
  void _keysChanged() {
    final controller = widget.controller;
    if (!controller.visible ||
        (controller.allowDecimal == _allowDecimal &&
            controller.allowNegative == _allowNegative &&
            controller.canRead == _canRead)) {
      return;
    }
    setState(() {
      _allowDecimal = controller.allowDecimal;
      _allowNegative = controller.allowNegative;
      _canRead = controller.canRead;
    });
  }

  @override
  Widget build(BuildContext context) {
    const gap = NumericKeypad._gap;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = widget.controller;

    Widget digit(String value) => _KeypadKey(
          key: ValueKey('keypad-$value'),
          isDark: isDark,
          label: value,
          onTap: () => controller.digit(value),
        );
    Widget column(List<Widget> children) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: children,
          ),
        );

    Widget keys = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: gap,
      children: [
        column([
          digit('1'),
          digit('4'),
          digit('7'),
          _KeypadKey(
            key: const ValueKey('keypad-point'),
            isDark: isDark,
            label: '.',
            glyph: true,
            semanticLabel: 'Punto decimal',
            onTap: _allowDecimal ? controller.decimalPoint : null,
          ),
        ]),
        column([digit('2'), digit('5'), digit('8'), digit('0')]),
        column([
          digit('3'),
          digit('6'),
          digit('9'),
          _KeypadKey(
            key: const ValueKey('keypad-done'),
            isDark: isDark,
            label: 'Listo',
            small: true,
            semanticLabel: 'Ocultar teclado',
            onTap: controller.close,
          ),
        ]),
        column([
          _KeypadKey(
            key: const ValueKey('keypad-backspace'),
            isDark: isDark,
            icon: Icons.backspace_outlined,
            semanticLabel: 'Borrar',
            onTap: controller.backspace,
            onLongPress: controller.clear,
          ),
          _KeypadKey(
            key: const ValueKey('keypad-sign'),
            isDark: isDark,
            label: '−',
            glyph: true,
            semanticLabel: 'Signo menos',
            onTap: _allowNegative ? controller.toggleSign : null,
          ),
          _KeypadKey(
            key: const ValueKey('keypad-next'),
            isDark: isDark,
            height: NumericKeypad._keyHeight * 2 + gap,
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

    if (_canRead) {
      // Encima de las teclas, para no mover ninguna de un campo a otro.
      keys = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          _KeypadKey(
            key: const ValueKey('keypad-read'),
            isDark: isDark,
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
    }

    return TextFieldTapRegion(
      // Las teclas nunca le quitan el foco al campo que están escribiendo.
      child: ExcludeFocus(
        child: widget.embedded
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

/// Una tecla.
///
/// Sin `Material` ni `InkWell`: la onda de Material cuesta, por tecla, un
/// controlador de animación, un nodo de foco y una capa de recorte, y son
/// catorce. Un destello al pulsar es lo que hace el teclado del sistema y se
/// dibuja de una pasada.
class _KeypadKey extends StatefulWidget {
  const _KeypadKey({
    required this.isDark,
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

  final bool isDark;
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
  State<_KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<_KeypadKey> {
  /// La fuente se pide una sola vez: `GoogleFonts.inter` busca y registra la
  /// familia en cada llamada, y aquí serían catorce por cuadro.
  static final TextStyle _font =
      GoogleFonts.inter(fontWeight: FontWeight.w600, height: 1);

  static final BorderRadius _radius = BorderRadius.circular(10);

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final primary = widget.primary;
    final isDark = widget.isDark;

    var ink = primary
        ? AppColors.actionPositiveInk
        : (isDark ? Colors.white : AppDesign.ink);
    var fill = primary
        ? AppColors.actionPositive
        : (isDark ? AppColors.cardDark : Colors.white);
    var edge = primary
        ? AppColors.actionPositive
        : (isDark ? AppColors.borderDarkSoft : AppColors.borderLight);
    if (!enabled) {
      // Una tecla que no aplica se apaga, no desaparece: la distribución no
      // cambia de un campo a otro.
      ink = ink.withValues(alpha: 0.35);
      edge = edge.withValues(alpha: 0.35);
    } else if (_pressed) {
      fill = Color.alphaBlend(ink.withValues(alpha: 0.18), fill);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        onLongPress: widget.onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: _radius,
            border: Border.all(color: edge),
          ),
          child: SizedBox(
            height: widget.height,
            child: Flex(
              direction: widget.horizontal ? Axis.horizontal : Axis.vertical,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: widget.horizontal ? 8 : 4,
              children: [
                if (widget.icon != null)
                  Icon(widget.icon, size: widget.small ? 20 : 24, color: ink),
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: _font.copyWith(
                      fontSize: widget.small
                          ? 15
                          : widget.glyph
                              ? 34
                              : 26,
                      color: ink,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
