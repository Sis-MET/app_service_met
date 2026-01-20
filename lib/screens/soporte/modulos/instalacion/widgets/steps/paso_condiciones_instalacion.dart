import 'package:flutter/material.dart';
import '../../controllers/instalacion_controller.dart';
import '../../models/instalacion_model.dart';
import '../campo_condicion_widget.dart';

class PasoCondicionesInstalacion extends StatefulWidget {
  final InstalacionModel model;
  final InstalacionController controller;
  final VoidCallback onChanged;

  const PasoCondicionesInstalacion({
    super.key,
    required this.model,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<PasoCondicionesInstalacion> createState() =>
      _PasoCondicionesInstalacionState();
}

class _PasoCondicionesInstalacionState
    extends State<PasoCondicionesInstalacion> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONDICIONES GENERALES DEL ENTORNO',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF195375),
            ),
          ),
          const SizedBox(height: 20),
          _buildCampo(
            'Entorno',
            [
              'Seco',
              'Polvoso',
              'Muy polvoso',
              'Húmedo parcial',
              'Húmedo constante'
            ],
          ),
          const SizedBox(height: 8),
          _buildCampo(
            'Nivelación',
            [
              'Irregular',
              'Liso',
              'Nivelación correcta',
              'Nivelación deficiente'
            ],
          ),
          const SizedBox(height: 8),
          _buildCampo(
            'Movilización',
            ['Ninguna', 'Dentro el área', 'Fuera del área', 'Fuera del sector'],
          ),
          const SizedBox(height: 8),
          _buildCampo(
            'Flujo de Pesadas',
            [
              '1 a 10 por día',
              '10 a 50 por día',
              '50 a 100 por día',
              'Más de 100 por día'
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampo(String label, List<String> opciones) {
    final campo = widget.model.camposCondiciones[label];
    if (campo == null) return const SizedBox.shrink();

    return CampoCondicionWidget(
      label: label,
      campo: campo,
      opciones: opciones,
      controller: widget.controller,
      onChanged: widget.onChanged,
    );
  }
}
