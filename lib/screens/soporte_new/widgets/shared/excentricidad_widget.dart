import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';

class ExcentricidadWidget extends StatefulWidget {
  final List<Excentricidad> excentricidad;
  final VoidCallback onChanged;

  const ExcentricidadWidget({
    super.key,
    required this.excentricidad,
    required this.onChanged,
  });

  @override
  State<ExcentricidadWidget> createState() => _ExcentricidadWidgetState();
}

class _ExcentricidadWidgetState extends State<ExcentricidadWidget> {
  static const _plataformas = [
    'Cuadrada',
    'Rectangular',
    'Circular',
    'Triangular'
  ];

  String _tipoPlataforma = 'Cuadrada';
  String _puntosIndicacion = '5';
  int? _selectedPosition;

  final TextEditingController _cargaPatronCtrl = TextEditingController();

  List<String> _getPuntosOptions() {
    switch (_tipoPlataforma) {
      case 'Cuadrada':
        return ['5'];
      case 'Rectangular':
        return ['3', '5'];
      case 'Circular':
        return ['4', '5'];
      case 'Triangular':
        return ['4'];
      default:
        return ['5'];
    }
  }

  List<Offset> _getPositionCoords(int n) {
    switch (_tipoPlataforma) {
      case 'Cuadrada':
        return const [
          Offset(0.50, 0.50),
          Offset(0.73, 0.27),
          Offset(0.73, 0.73),
          Offset(0.27, 0.73),
          Offset(0.27, 0.27),
        ];
      case 'Rectangular':
        if (n == 3) {
          return const [
            Offset(0.50, 0.50),
            Offset(0.22, 0.50),
            Offset(0.78, 0.50),
          ];
        }
        return const [
          Offset(0.50, 0.50),
          Offset(0.78, 0.35),
          Offset(0.78, 0.65),
          Offset(0.22, 0.65),
          Offset(0.22, 0.35),
        ];
      case 'Circular':
        if (n == 4) {
          return const [
            Offset(0.50, 0.50),
            Offset(0.691, 0.309),
            Offset(0.50, 0.77),
            Offset(0.309, 0.309),
          ];
        }
        return const [
          Offset(0.50, 0.50),
          Offset(0.691, 0.309),
          Offset(0.691, 0.691),
          Offset(0.309, 0.691),
          Offset(0.309, 0.309),
        ];
      case 'Triangular':
        return const [
          Offset(0.50, 0.53),
          Offset(0.50, 0.30),
          Offset(0.66, 0.66),
          Offset(0.34, 0.66),
        ];
      default:
        return [];
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.excentricidad.isNotEmpty && widget.excentricidad[0].carga.isNotEmpty) {
      _cargaPatronCtrl.text = widget.excentricidad[0].carga;
    }
  }

  @override
  void dispose() {
    _cargaPatronCtrl.dispose();
    super.dispose();
  }

  void _syncCargaPatron(String val) {
    for (var item in widget.excentricidad) {
      item.carga = val;
    }
    widget.onChanged();
  }

  void _updateRow(int index, String field, String val) {
    if (index >= widget.excentricidad.length) return;
    final item = widget.excentricidad[index];
    switch (field) {
      case 'indicacion1':
        item.indicacion1 = val;
        break;
      case 'indicacion2':
        item.indicacion2 = val;
        break;
      case 'indicacion3':
        item.indicacion3 = val;
        break;
      case 'diferencia':
        item.diferencia = val;
        break;
      case 'error':
        item.error = val;
        break;
      case 'errorMaximo':
        item.errorMaximo = val;
        break;
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nPuntos = int.tryParse(_puntosIndicacion) ?? 5;
    final coords = _getPositionCoords(nPuntos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selectores de forma y puntos
        Row(
          children: [
            Expanded(
              child: _dropdownField(
                label: 'Forma de Plataforma',
                value: _tipoPlataforma,
                items: _plataformas,
                isDark: isDark,
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _tipoPlataforma = v;
                      final options = _getPuntosOptions();
                      if (!options.contains(_puntosIndicacion)) {
                        _puntosIndicacion = options.first;
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdownField(
                label: 'Puntos de Indicación',
                value: _puntosIndicacion,
                items: _getPuntosOptions(),
                isDark: isDark,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _puntosIndicacion = v);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Carga Patrón
        TextField(
          controller: _cargaPatronCtrl,
          onChanged: _syncCargaPatron,
          style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
          ],
          decoration: InputDecoration(
            labelText: 'Carga Patrón de Excentricidad',
            hintText: 'Ej. 50 kg',
            prefixIcon: Icon(Icons.fitness_center_rounded,
                color: isDark ? Colors.white54 : Colors.black54, size: 20),
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
          ),
        ),
        const SizedBox(height: 20),

        // Diagrama visual 2D de la plataforma
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: _tipoPlataforma == 'Circular'
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: _tipoPlataforma == 'Circular'
                          ? null
                          : BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white30 : Colors.black26,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                ...List.generate(coords.length, (i) {
                  final posIndex = i + 1;
                  final isSel = _selectedPosition == posIndex;
                  return Positioned(
                    left: coords[i].dx * 220 - 18,
                    top: coords[i].dy * 220 - 18,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedPosition = posIndex);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFFf9e300)
                              : (isDark
                                  ? const Color(0xFF3E3E3E)
                                  : Colors.white),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF1A1A1A)
                                : (isDark
                                    ? Colors.white38
                                    : Colors.black26),
                            width: isSel ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$posIndex',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSel
                                  ? const Color(0xFF1A1A1A)
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Tabla de mediciones por posición
        Text(
          'Registro de Mediciones por Posición',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: nPuntos,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final posNumber = i + 1;
            final item = (i < widget.excentricidad.length)
                ? widget.excentricidad[i]
                : Excentricidad(posicion: 'Posición $posNumber');
            item.posicion = 'Posición $posNumber';

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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFf9e300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '$posNumber',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _cellInput(
                      label: 'Indicación',
                      value: item.indicacion1,
                      onChanged: (v) => _updateRow(i, 'indicacion1', v),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _cellInput(
                      label: 'Retorno a 0',
                      value: item.indicacion2,
                      onChanged: (v) => _updateRow(i, 'indicacion2', v),
                      isDark: isDark,
                    ),
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

  Widget _cellInput({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      style: GoogleFonts.inter(
          fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        ),
      ),
    );
  }
}
