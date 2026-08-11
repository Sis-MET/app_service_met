import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';

class LinealidadWidget extends StatefulWidget {
  final List<Linealidad> linealidad;
  final VoidCallback onChanged;

  const LinealidadWidget({
    super.key,
    required this.linealidad,
    required this.onChanged,
  });

  @override
  State<LinealidadWidget> createState() => _LinealidadWidgetState();
}

class _LinealidadWidgetState extends State<LinealidadWidget> {
  static const _metodoCargaOptions = [
    'Sin método de carga',
    'Ascenso evaluando a ceros',
    'Ascenso Continuo por pasos',
  ];

  static const _metodoCargasSustitutivasOptions = [
    'Sin método',
    'Método 1',
    'Método 2',
  ];

  String _metodoCarga = 'Sin método de carga';
  String _metodoCargasSustitutivas = 'Sin método';

  final List<TextEditingController> _cargaCtrls = [];
  final List<TextEditingController> _indCtrls = [];
  final List<TextEditingController> _retCtrls = [];

  @override
  void initState() {
    super.initState();
    _rebuildControllers();
  }

  void _rebuildControllers() {
    for (final c in _cargaCtrls) {
      c.dispose();
    }
    for (final c in _indCtrls) {
      c.dispose();
    }
    for (final c in _retCtrls) {
      c.dispose();
    }
    _cargaCtrls.clear();
    _indCtrls.clear();
    _retCtrls.clear();

    final items = widget.linealidad;
    for (var item in items) {
      _cargaCtrls.add(TextEditingController(text: item.carga));
      _indCtrls.add(TextEditingController(text: item.indicacion1));
      _retCtrls.add(TextEditingController(text: item.indicacion2));
    }
  }

  void _syncToModel() {
    for (int i = 0; i < _cargaCtrls.length; i++) {
      if (i < widget.linealidad.length) {
        widget.linealidad[i].carga = _cargaCtrls[i].text;
        widget.linealidad[i].indicacion1 = _indCtrls[i].text;
        widget.linealidad[i].indicacion2 = _retCtrls[i].text;
      }
    }
    widget.onChanged();
  }

  void _addPunto() {
    setState(() {
      widget.linealidad.add(Linealidad());
      _rebuildControllers();
    });
    _syncToModel();
  }

  void _removePunto(int index) {
    if (widget.linealidad.length <= 1) return;
    setState(() {
      widget.linealidad.removeAt(index);
      _rebuildControllers();
    });
    _syncToModel();
  }

  @override
  void dispose() {
    for (final c in _cargaCtrls) {
      c.dispose();
    }
    for (final c in _indCtrls) {
      c.dispose();
    }
    for (final c in _retCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Métodos de Carga y Cargas Sustitutivas
        _dropdownField(
          label: 'Método de Carga',
          value: _metodoCarga,
          items: _metodoCargaOptions,
          isDark: isDark,
          onChanged: (v) {
            if (v != null) setState(() => _metodoCarga = v);
          },
        ),
        const SizedBox(height: 12),
        _dropdownField(
          label: 'Método Cargas Sustitutivas',
          value: _metodoCargasSustitutivas,
          items: _metodoCargasSustitutivasOptions,
          isDark: isDark,
          onChanged: (v) {
            if (v != null) setState(() => _metodoCargasSustitutivas = v);
          },
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Puntos de Linealidad (${widget.linealidad.length} puntos)',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addPunto,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar Punto'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.linealidad.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFf9e300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _numInput(
                      controller: _cargaCtrls[i],
                      label: 'Carga Patrón',
                      isDark: isDark,
                      onChanged: (_) => _syncToModel(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _numInput(
                      controller: _indCtrls[i],
                      label: 'Indicación',
                      isDark: isDark,
                      onChanged: (_) => _syncToModel(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _numInput(
                      controller: _retCtrls[i],
                      label: 'Retorno 0',
                      isDark: isDark,
                      onChanged: (_) => _syncToModel(),
                    ),
                  ),
                  if (widget.linealidad.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 20),
                      onPressed: () => _removePunto(i),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      style: GoogleFonts.inter(
          fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items
          .map((v) => DropdownMenuItem(
                value: v,
                child: Text(v, style: GoogleFonts.inter(fontSize: 13)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _numInput({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      style: GoogleFonts.inter(
          fontSize: 12, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            fontSize: 10, color: isDark ? Colors.white54 : Colors.black45),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
    );
  }
}
