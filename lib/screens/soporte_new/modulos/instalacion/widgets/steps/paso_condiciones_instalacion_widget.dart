import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';

class PasoCondicionesInstalacionWidget extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String comentario) onChanged;
  final String seca;
  final String codMetrica;

  const PasoCondicionesInstalacionWidget({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.seca,
    required this.codMetrica,
  });

  @override
  State<PasoCondicionesInstalacionWidget> createState() =>
      _PasoCondicionesInstalacionWidgetState();
}

class _PasoCondicionesInstalacionWidgetState
    extends State<PasoCondicionesInstalacionWidget> {
  bool _allGood = false;

  static const options = <List<String>>[
    ['Seco', 'Polvoso', 'Muy polvoso', 'Húmedo parcial', 'Húmedo constante'],
    ['Bueno', 'Malo', 'Aceptable'],
    ['Estable', 'Inestable', 'Con picos', 'Fuera de rango'],
    ['Correcto', 'Deficiente', 'Inexistente', 'No verificado'],
    ['Correcta', 'Intermitente', 'Sin conexión', 'No aplica'],
    ['Ninguna', 'Dentro el área', 'Fuera del área', 'Fuera del sector'],
    ['Nula', 'Leve', 'Moderada', 'Alta'],
    [
      '1 a 10 por día',
      '10 a 50 por día',
      '50 a 100 por día',
      'Más de 100 por día'
    ],
  ];

  static const optimalValues = [
    'Seco',
    'Bueno',
    'Estable',
    'Correcto',
    'Correcta',
    'Ninguna',
    'Nula',
    '1 a 10 por día',
  ];

  @override
  void initState() {
    super.initState();
    _allGood = _hasAllOptimalValues();
  }

  bool _hasAllOptimalValues() {
    if (widget.campos.length != optimalValues.length) return false;
    for (var i = 0; i < widget.campos.length; i++) {
      if (widget.campos[i].value != optimalValues[i]) return false;
    }
    return true;
  }

  void _toggleAllGood(bool value) {
    setState(() => _allGood = value);
    if (!value) return;
    for (var i = 0; i < widget.campos.length; i++) {
      widget.campos[i].value = optimalValues[i];
      widget.campos[i].solutionValue = 'En buenas condiciones';
      widget.onChanged(
        i,
        widget.campos[i].value,
        widget.campos[i].solutionValue,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = Color(0xFF46824B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _allGood
                  ? activeColor.withOpacity(0.45)
                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _allGood
                    ? Icons.check_circle_outline_rounded
                    : Icons.checklist_rounded,
                color: _allGood
                    ? activeColor
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Todas las condiciones son adecuadas',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _allGood
                          ? 'Se aplicaron los valores recomendados'
                          : 'Active para completar las ocho condiciones',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _allGood,
                onChanged: _toggleAllGood,
                activeColor: Colors.white,
                activeTrackColor: activeColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(widget.campos.length, (index) {
          return CampoInspeccionWidget(
            key: ValueKey('${widget.campos[index].nombre}-$_allGood'),
            campoEstado: widget.campos[index],
            customOptions: options[index],
            solutionAsComment: true,
            onChanged: (value, comentario) {
              if (_allGood) setState(() => _allGood = false);
              widget.onChanged(index, value, comentario);
            },
            seca: widget.seca,
            codMetrica: widget.codMetrica,
          );
        }),
      ],
    );
  }
}
