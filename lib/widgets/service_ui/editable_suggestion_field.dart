import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_icons.dart';

/// Campo de texto libre que conserva un catalogo como lista de sugerencias.
///
/// A diferencia de un dropdown, el valor escrito no tiene que pertenecer a
/// [options]. Esto permite registrar tipos de equipo que aun no forman parte
/// del catalogo local.
class EditableSuggestionField extends StatefulWidget {
  const EditableSuggestionField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.options,
    required this.onChanged,
    required this.isDark,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool isDark;

  @override
  State<EditableSuggestionField> createState() =>
      _EditableSuggestionFieldState();
}

class _EditableSuggestionFieldState extends State<EditableSuggestionField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return widget.options;
        return widget.options.where(
          (option) => option.toLowerCase().contains(query),
        );
      },
      onSelected: (option) {
        widget.controller.value = TextEditingValue(
          text: option,
          selection: TextSelection.collapsed(offset: option.length),
        );
        widget.onChanged(option);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: widget.onChanged,
          onSubmitted: (_) => onSubmitted(),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              color: widget.isDark ? Colors.white70 : Colors.black87,
            ),
            prefixIcon: Icon(
              widget.icon,
              size: 20,
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
            suffixIcon: Icon(
              AppIcons.desplegar,
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.isDark ? Colors.white12 : Colors.black12,
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final suggestions = options.toList(growable: false);
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: widget.isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 520),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final option = suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      option,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
