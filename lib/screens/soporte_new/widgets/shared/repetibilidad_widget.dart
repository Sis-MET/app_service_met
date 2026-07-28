import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';

class RepetibilidadWidget extends StatefulWidget {
  final List<Repetibilidad> repetibilidad;
  final VoidCallback onChanged;

  const RepetibilidadWidget({
    super.key,
    required this.repetibilidad,
    required this.onChanged,
  });

  @override
  State<RepetibilidadWidget> createState() => _RepetibilidadWidgetState();
}

class _RepetibilidadWidgetState extends State<RepetibilidadWidget> {
  static const _cargasOptions = ['1', '2', '3'];
  static const _medicionesOptions = ['3', '5', '10'];

  String _cargasCount = '1';
  String _medicionesCount = '5';

  final List<TextEditingController> _cargasCtrls = [];
  final List<List<TextEditingController>> _indCtrls = [];
  final List<List<TextEditingController>> _retCtrls = [];

  @override
  void initState() {
    super.initState();
    _rebuildStructure();
  }

  void _rebuildStructure() {
    final nCargas = int.tryParse(_cargasCount) ?? 1;
    final nMediciones = int.tryParse(_medicionesCount) ?? 5;

    for (final c in _cargasCtrls) {
      c.dispose();
    }
    for (final row in _indCtrls) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _retCtrls) {
      for (final c in row) {
        c.dispose();
      }
    }

    _cargasCtrls.clear();
    _indCtrls.clear();
    _retCtrls.clear();

    for (int i = 0; i < nCargas; i++) {
      final repItem = i < widget.repetibilidad.length
          ? widget.repetibilidad[i]
          : Repetibilidad();
      _cargasCtrls.add(TextEditingController(text: repItem.carga));

      final indRow = <TextEditingController>[];
      final retRow = <TextEditingController>[];

      for (int j = 0; j < nMediciones; j++) {
        String valInd = '';
        if (j == 0) valInd = repItem.indicacion1;
        if (j == 1) valInd = repItem.indicacion2;
        if (j == 2) valInd = repItem.indicacion3;

        indRow.add(TextEditingController(text: valInd));
        retRow.add(TextEditingController(text: '0'));
      }

      _indCtrls.add(indRow);
      _retCtrls.add(retRow);
    }
  }

  void _syncToModel() {
    final nCargas = int.tryParse(_cargasCount) ?? 1;
    for (int i = 0; i < nCargas; i++) {
      final item = i < widget.repetibilidad.length
          ? widget.repetibilidad[i]
          : Repetibilidad();
      item.carga = _cargasCtrls[i].text;
      if (_indCtrls[i].isNotEmpty) item.indicacion1 = _indCtrls[i][0].text;
      if (_indCtrls[i].length > 1) item.indicacion2 = _indCtrls[i][1].text;
      if (_indCtrls[i].length > 2) item.indicacion3 = _indCtrls[i][2].text;
    }
    widget.onChanged();
  }

  @override
  void dispose() {
    for (final c in _cargasCtrls) {
      c.dispose();
    }
    for (final row in _indCtrls) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _retCtrls) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nCargas = int.tryParse(_cargasCount) ?? 1;
    final nMediciones = int.tryParse(_medicionesCount) ?? 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selectores de N° de Cargas y Mediciones
        Row(
          children: [
            Expanded(
              child: _dropdownField(
                label: 'N° de Cargas',
                value: _cargasCount,
                items: _cargasOptions,
                isDark: isDark,
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _cargasCount = v;
                      _rebuildStructure();
                    });
                    _syncToModel();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdownField(
                label: 'N° de Mediciones',
                value: _medicionesCount,
                items: _medicionesOptions,
                isDark: isDark,
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _medicionesCount = v;
                      _rebuildStructure();
                    });
                    _syncToModel();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Bloques de ensayo por Carga
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: nCargas,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final cargaCtrl = _cargasCtrls[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFf9e300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Carga ${i + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cargaCtrl,
                          onChanged: (_) => _syncToModel(),
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A)),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'))
                          ],
                          decoration: InputDecoration(
                            labelText: 'Valor Carga Patrón (kg/g)',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tabla de mediciones
                  Text(
                    'Lecturas de Repetición ($nMediciones mediciones)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: nMediciones,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, j) {
                      final indCtrl = _indCtrls[i][j];
                      final retCtrl = _retCtrls[i][j];

                      return Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              '#${j + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: indCtrl,
                              onChanged: (_) => _syncToModel(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'))
                              ],
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A)),
                              decoration: InputDecoration(
                                labelText: 'Indicación',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: retCtrl,
                              onChanged: (_) => _syncToModel(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'))
                              ],
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A)),
                              decoration: InputDecoration(
                                labelText: 'Retorno 0',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
        labelStyle:
            GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
}
