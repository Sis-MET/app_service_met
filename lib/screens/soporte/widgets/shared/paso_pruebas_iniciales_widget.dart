import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte/widgets/shared/pruebas_metrologicas_widget.dart';

class PasoPruebasInicialesWidget extends StatelessWidget {
  final PruebasMetrologicas pruebas;
  final String horaInicio;
  final VoidCallback onChanged;
  final Future<double> Function() getD1FromDatabase;

  const PasoPruebasInicialesWidget({
    super.key,
    required this.pruebas,
    required this.horaInicio,
    required this.onChanged,
    required this.getD1FromDatabase,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, isDarkMode),
          const SizedBox(height: 24),

          _buildReadOnlyField(
            label: 'Hora de Inicio',
            value: horaInicio,
            icon: Icons.access_time,
            context: context,
          ),
          const SizedBox(height: 16),
          _buildInfoBox(
            'La hora se extrae autom\u00e1ticamente del sistema y no es editable.',
            Colors.blue,
          ),
          const SizedBox(height: 24),

          PruebasMetrologicasWidget(
            pruebas: pruebas,
            isInicial: true,
            onChanged: onChanged,
            getD1FromDatabase: getD1FromDatabase,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.withOpacity(0.1)
            : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            color: Colors.blue,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRUEBAS METROL\u00d3GICAS INICIALES',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Realice las pruebas metrol\u00f3gicas antes del mantenimiento',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required BuildContext context,
  }) {
    return TextField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200],
      ),
      controller: TextEditingController(text: value),
    );
  }

  Widget _buildInfoBox(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
