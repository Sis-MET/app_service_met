import 'dart:io';
import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/models/campo_estado.dart';
import 'package:service_met/screens/soporte/widgets/shared/all_good_checkbox.dart';
import 'package:service_met/screens/soporte/widgets/shared/campo_inspeccion_widget.dart';

class PasoTerminalCalibracion extends StatefulWidget {
  final Map<String, CampoEstado> camposEstado;
  final VoidCallback onChanged;
  final void Function(String label, File foto) onAddPhoto;
  final void Function(String label, int index) onRemovePhoto;

  const PasoTerminalCalibracion({
    super.key,
    required this.camposEstado,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  State<PasoTerminalCalibracion> createState() => _PasoTerminalCalibracionState();
}

class _PasoTerminalCalibracionState extends State<PasoTerminalCalibracion> {
  final List<String> _terminalCampos = [
    'Carcasa',
    'Voltaje pila de Boton',
    'Estado del teclado',
    'Estado del display',
    'Registros Predictivo solo PDX',
    'Alertas de servicio MT',
    'Estado prensacables:',
    'Comunicación con PC',
  ];

  final List<String> _calibracionCampos = [
    'Balanza apta para Verificación Dentro tolerancias NB23001',
  ];

  bool _isAllGood = false;

  @override
  Widget build(BuildContext context) {
    final allCampos = [..._terminalCampos, ..._calibracionCampos];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AllGoodCheckbox(
            value: _isAllGood,
            onChanged: (value) => _toggleAllGood(value, allCampos),
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: 'TERMINAL',
            subtitle: 'Inspeccione el terminal de pesaje',
            icon: Icons.computer_outlined,
            color: Colors.purple,
            campos: _terminalCampos,
          ),
          const SizedBox(height: 32),
          _buildSection(
            context,
            title: 'CALIBRACIÓN',
            subtitle: 'Verifique la calibración del equipo',
            icon: Icons.tune_outlined,
            color: Colors.green,
            campos: _calibracionCampos,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> campos,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? color.withOpacity(0.1) : color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...campos.map((campo) => CampoInspeccionWidget(
          label: campo,
          campo: widget.camposEstado[campo]!,
          onAddPhoto: widget.onAddPhoto,
          onRemovePhoto: widget.onRemovePhoto,
        )),
      ],
    );
  }

  void _toggleAllGood(bool isGood, List<String> campos) {
    setState(() {
      _isAllGood = isGood;
      if (isGood) {
        for (final fieldName in campos) {
          final campo = widget.camposEstado[fieldName];
          if (campo != null) {
            campo.initialValue = '1 Bueno';
            campo.comentario = 'En buen estado';
            campo.solutionValue = 'No aplica';
          }
        }
        widget.onChanged();
      }
    });
  }
}
