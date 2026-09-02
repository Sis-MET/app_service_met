import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/bulk_estado_toggle.dart';
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
  BulkEstadoMode _bulkMode = BulkEstadoMode.none;

  static const options = <List<String>>[
    ['Seco', 'Polvoso', 'Muy polvoso', 'Húmedo parcial', 'Húmedo constante'],
    ['Bueno', 'Malo', 'Aceptable', 'No aplica'],
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
    if (_hasAllOptimalValues()) _bulkMode = BulkEstadoMode.buenEstado;
  }

  bool _hasAllOptimalValues() {
    if (widget.campos.length != optimalValues.length) return false;
    for (var i = 0; i < widget.campos.length; i++) {
      if (widget.campos[i].value != optimalValues[i]) return false;
    }
    return true;
  }

  /// Opciones del campo [index] garantizando que "No aplica" sea seleccionable.
  List<String> _optionsFor(int index) {
    final base = options[index];
    if (base.contains('No aplica')) return base;
    return [...base, 'No aplica'];
  }

  void _onBulkModeChanged(BulkEstadoMode mode) {
    setState(() => _bulkMode = mode);
    if (mode == BulkEstadoMode.none) return;
    for (var i = 0; i < widget.campos.length; i++) {
      if (mode == BulkEstadoMode.buenEstado) {
        widget.campos[i].value = optimalValues[i];
        widget.campos[i].solutionValue = 'En buenas condiciones';
      } else {
        widget.campos[i].value = 'No aplica';
        widget.campos[i].solutionValue = 'No aplica';
      }
      widget.onChanged(
        i,
        widget.campos[i].value,
        widget.campos[i].solutionValue,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BulkEstadoToggles(
          mode: _bulkMode,
          onModeChanged: _onBulkModeChanged,
          buenEstadoTitle: 'Todas las condiciones son adecuadas',
        ),
        const SizedBox(height: 20),
        ...List.generate(widget.campos.length, (index) {
          return CampoInspeccionWidget(
            key: ValueKey('${widget.campos[index].nombre}-${_bulkMode.name}'),
            campoEstado: widget.campos[index],
            customOptions: _optionsFor(index),
            solutionAsComment: true,
            onChanged: (value, comentario) {
              if (_bulkMode != BulkEstadoMode.none) {
                setState(() => _bulkMode = BulkEstadoMode.none);
              }
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
