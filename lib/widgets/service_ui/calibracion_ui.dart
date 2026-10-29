// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_icons.dart';

/// Piezas visuales de los pasos de Calibración (Cliente, Planta, SECA,
/// Instrumento): las mismas medidas, colores y tipografías, para que otro
/// tipo de calibración se vea como el mismo módulo. Cada pieza resuelve sus
/// colores para claro y oscuro: no dependen de los estilos de texto del tema.
abstract final class CalUi {
  static const accent = Color(0xFFf9e300);
  static const ink = Color(0xFF1A1A1A);
  static const accentInk = Color(0xFF5A4E00);

  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color texto(bool isDark) => isDark ? Colors.white : ink;
  static Color secundario(bool isDark) =>
      isDark ? Colors.white54 : Colors.black45;
  static Color borde(bool isDark) =>
      isDark ? Colors.white12 : const Color(0xFFE2E8F0);
  static Color fondo(bool isDark) =>
      isDark ? const Color(0xFF2A2A2A) : Colors.white;

  /// El panel blanco de los formularios de Instrumento.
  static BoxDecoration panel(bool isDark) => BoxDecoration(
        color: fondo(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borde(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// La decoración de los campos de Instrumento.
  static InputDecoration campo(
    String label,
    bool isDark, {
    IconData? icon,
    String? suffix,
    String? hint,
    bool readOnly = false,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
        hintStyle: GoogleFonts.inter(
            color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
        suffixText: suffix,
        suffixStyle:
            GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black54),
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: isDark ? Colors.white54 : Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        filled: readOnly,
        fillColor: readOnly
            ? (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.05))
            : null,
      );

  static TextStyle valorCampo(bool isDark) =>
      GoogleFonts.inter(color: texto(isDark));
}

/// Título y subtítulo de un paso, como "Instrumento" en Calibración.
class CalStepHeader extends StatelessWidget {
  const CalStepHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: CalUi.texto(isDark),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: CalUi.secundario(isDark),
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }
}

/// Panel de formulario (Identificación, Fabricante…).
class CalPanel extends StatelessWidget {
  const CalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: CalUi.panel(CalUi.dark(context)),
        child: child,
      );
}

/// Título de grupo dentro de un panel: ícono y MAYÚSCULAS chicas.
class CalGroupTitle extends StatelessWidget {
  const CalGroupTitle(this.title, this.icon, {super.key, this.trailing});

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Título de sección fuera de los paneles ("Rangos de pesaje").
class CalSectionTitle extends StatelessWidget {
  const CalSectionTitle(this.title, this.icon, {super.key, this.trailing});

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white54 : Colors.black54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CalUi.texto(isDark),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Campo de texto de los formularios de Instrumento. Mantiene su texto
/// aunque el padre se reconstruya; si el valor cambia por fuera, se
/// actualiza.
class CalTextField extends StatefulWidget {
  const CalTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final IconData? icon;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final String? hint;

  @override
  State<CalTextField> createState() => _CalTextFieldState();
}

class _CalTextFieldState extends State<CalTextField> {
  late final _controller = TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(CalTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value ?? '';
    if (value.trim() != _controller.text.trim()) _controller.text = value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return TextField(
      controller: _controller,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      textCapitalization: TextCapitalization.sentences,
      style: CalUi.valorCampo(isDark),
      decoration: CalUi.campo(widget.label, isDark,
          icon: widget.icon, readOnly: widget.readOnly, hint: widget.hint),
      onChanged: widget.onChanged,
    );
  }
}

/// Campo numérico con el teclado del sistema.
class CalNumberField extends StatefulWidget {
  const CalNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.suffix,
    this.decimals = true,
    this.signed = true,
    this.readOnly = false,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final IconData? icon;
  final String? suffix;
  final bool decimals;
  final bool signed;
  final bool readOnly;

  @override
  State<CalNumberField> createState() => _CalNumberFieldState();
}

class _CalNumberFieldState extends State<CalNumberField> {
  late final _controller = TextEditingController(text: _texto(widget.value));

  static String _texto(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  double? get _actual =>
      double.tryParse(_controller.text.trim().replaceAll(',', '.'));

  @override
  void didUpdateWidget(CalNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_actual != widget.value) _controller.text = _texto(widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final allowed = widget.decimals
        ? (widget.signed ? r'[-0-9.,]' : r'[0-9.,]')
        : (widget.signed ? r'[-0-9]' : r'[0-9]');
    return TextField(
      controller: _controller,
      readOnly: widget.readOnly,
      keyboardType: TextInputType.numberWithOptions(
          decimal: widget.decimals, signed: widget.signed),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(allowed))],
      style: CalUi.valorCampo(isDark),
      decoration: CalUi.campo(widget.label, isDark,
          icon: widget.icon, suffix: widget.suffix, readOnly: widget.readOnly),
      onChanged: (_) => widget.onChanged(_actual),
    );
  }
}

/// Lista desplegable de los formularios de Instrumento (Categoría, Unidad).
class CalDropdown<T> extends StatelessWidget {
  const CalDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.icon,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?>? onChanged;
  final String Function(T)? itemLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final current = items.contains(value) ? value : null;
    return DropdownButtonFormField<T>(
      value: current,
      isExpanded: true,
      icon: Icon(AppIcons.desplegar,
          size: 18, color: isDark ? Colors.white54 : Colors.black54),
      dropdownColor: CalUi.fondo(isDark),
      style: CalUi.valorCampo(isDark),
      decoration: CalUi.campo(label, isDark, icon: icon),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(
              itemLabel?.call(item) ?? '$item',
              style: CalUi.valorCampo(isDark),
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// El buscador de Cliente: un panel con el campo sin borde.
class CalSearchField extends StatelessWidget {
  const CalSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final none = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CalUi.fondo(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CalUi.borde(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 14, color: CalUi.texto(isDark)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
            prefixIcon: Icon(AppIcons.buscar,
                color: isDark ? Colors.white54 : Colors.black38, size: 20),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(AppIcons.cerrar,
                        size: 18,
                        color: isDark ? Colors.white54 : Colors.black38),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            border: none,
            enabledBorder: none,
            focusedBorder: none,
            filled: false,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          ),
        ),
      ),
    );
  }
}

/// Un elemento de la lista de clientes: inicial, nombre y detalle; al
/// elegirlo se pinta de amarillo.
class CalListItem extends StatelessWidget {
  const CalListItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.leadingIcon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  /// En lugar de la inicial.
  final IconData? leadingIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final initial = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                  ? CalUi.accent.withOpacity(0.08)
                  : const Color(0xFFFFFDE6))
              : CalUi.fondo(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? CalUi.accent : CalUi.borde(isDark),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.06 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? CalUi.accent
                    : (isDark ? Colors.white12 : const Color(0xFFF0F2F5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: leadingIcon != null
                    ? Icon(leadingIcon,
                        size: 20,
                        color: selected
                            ? CalUi.ink
                            : (isDark ? Colors.white60 : Colors.black45))
                    : Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: selected
                              ? CalUi.ink
                              : (isDark ? Colors.white60 : Colors.black45),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected
                          ? (isDark ? CalUi.accent : CalUi.accentInk)
                          : CalUi.texto(isDark),
                    ),
                  ),
                  if ((subtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selected
                      ? Container(
                          key: const ValueKey('check'),
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: CalUi.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(AppIcons.listo,
                              size: 14, color: CalUi.ink),
                        )
                      : Icon(AppIcons.siguiente,
                          key: const ValueKey('arrow'),
                          size: 16,
                          color: isDark ? Colors.white24 : Colors.black26),
                ),
          ],
        ),
      ),
    );
  }
}

/// La tarjeta amarilla de "Cliente Seleccionado" / "Planta Seleccionada".
class CalSelectedCard extends StatelessWidget {
  const CalSelectedCard({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.isNew = false,
    this.icon,
    this.details = const [],
    this.trailing,
  });

  final String label;
  final String title;
  final String? subtitle;

  /// Naranja, como un cliente o una planta nuevos.
  final bool isNew;
  final IconData? icon;

  /// Filas debajo (dirección, departamento…): ícono y texto.
  final List<(IconData, String)> details;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final accentColor = isNew ? Colors.orange[700]! : CalUi.accent;
    final bgColor = isNew
        ? (isDark ? Colors.orange.withOpacity(0.08) : Colors.orange[50]!)
        : (isDark ? CalUi.accent.withOpacity(0.08) : const Color(0xFFFFFDE6));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon ?? (isNew ? AppIcons.agregar : AppIcons.listo),
                  color: isNew ? Colors.white : CalUi.ink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isNew
                            ? accentColor
                            : (isDark ? CalUi.accent : CalUi.accentInk),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CalUi.texto(isDark),
                      ),
                    ),
                    if ((subtitle ?? '').isNotEmpty)
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < details.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(details[i].$1,
                            size: 14, color: accentColor.withOpacity(0.8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            details[i].$2,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2);
  }
}

/// La franja "Cliente para este servicio" de Planta.
class CalContextBanner extends StatelessWidget {
  const CalContextBanner({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CalUi.fondo(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CalUi.borde(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: isDark ? Colors.white70 : Colors.black54, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CalUi.secundario(isDark),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CalUi.texto(isDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2);
  }
}

/// "Resumen de la Información" de SECA: filas etiqueta · valor.
class CalInfoSummary extends StatelessWidget {
  const CalInfoSummary({
    super.key,
    required this.title,
    required this.rows,
    this.icon = AppIcons.info,
  });

  final String title;
  final List<(String, String?)> rows;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CalUi.fondo(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CalUi.borde(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: isDark ? Colors.white54 : Colors.black54, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CalUi.texto(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            CalSummaryRow(rows[i].$1, rows[i].$2),
          ],
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: -0.2);
  }
}

class CalSummaryRow extends StatelessWidget {
  const CalSummaryRow(this.label, this.value,
      {super.key, this.labelWidth = 110});

  final String label;
  final String? value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final texto = (value ?? '').trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            texto.isEmpty ? 'N/A' : texto,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CalUi.texto(isDark),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sin resultados, cargando o error, como en la lista de clientes.
class CalEmptyState extends StatelessWidget {
  const CalEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = AppIcons.sinResultados,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: CalUi.secundario(isDark),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ).animate().fadeIn();
  }
}

/// Aviso ámbar como el del código temporal de SECA.
class CalNotice extends StatelessWidget {
  const CalNotice(this.text,
      {super.key, this.icon = AppIcons.info, this.error = false});

  final String text;
  final IconData icon;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final color = error ? Colors.red : Colors.amber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isDark ? color[300] : color[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La hoja "Buscar Instrumento" de Calibración.
Future<T?> showCalSearchSheet<T>(
  BuildContext context, {
  required String title,
  required String hint,
  required List<T> items,
  required bool Function(T item, String query) matches,
  required Widget Function(BuildContext context, T item, VoidCallback select)
      itemBuilder,
  String empty = 'Sin resultados',
}) {
  final isDark = CalUi.dark(context);
  final search = TextEditingController();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final query = search.text.trim().toLowerCase();
      final filtered = query.isEmpty
          ? items
          : items.where((i) => matches(i, query)).toList();
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: CalUi.texto(isDark),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                style:
                    GoogleFonts.inter(fontSize: 14, color: CalUi.texto(isDark)),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38),
                  prefixIcon: Icon(AppIcons.buscar,
                      color: isDark ? Colors.white54 : Colors.black38,
                      size: 20),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setSheet(() {}),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? CalEmptyState(title: empty)
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => itemBuilder(
                          ctx,
                          filtered[i],
                          () => Navigator.pop(ctx, filtered[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }),
  );
}
