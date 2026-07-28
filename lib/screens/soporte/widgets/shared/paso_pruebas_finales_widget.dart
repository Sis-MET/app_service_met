import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte/widgets/shared/pruebas_metrologicas_widget.dart';

class PasoPruebasFinalesWidget extends StatelessWidget {
  final PruebasMetrologicas pruebas;
  final String horaInicio;
  final VoidCallback onChanged;
  final Future<double> Function() getD1FromDatabase;
  final VoidCallback? onCopyFromInitial;

  const PasoPruebasFinalesWidget({
    super.key,
    required this.pruebas,
    required this.horaInicio,
    required this.onChanged,
    required this.getD1FromDatabase,
    this.onCopyFromInitial,
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

          if (onCopyFromInitial != null) _buildCopyButton(context),
          if (onCopyFromInitial != null) const SizedBox(height: 24),

          PruebasMetrologicasWidget(
            pruebas: pruebas,
            isInicial: false,
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
            ? Colors.green.withOpacity(0.1)
            : Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.task_alt_outlined,
            color: Colors.green,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRUEBAS METROL\u00d3GICAS FINALES',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Realice las pruebas metrol\u00f3gicas despu\u00e9s del mantenimiento',
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

  Widget _buildCopyButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Si las pruebas finales son iguales a las iniciales, puede copiarlas autom\u00e1ticamente',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                onCopyFromInitial?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Datos copiados de pruebas iniciales a finales',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.content_copy, color: Colors.white),
              label: const Text('COPIAR PRUEBAS INICIALES'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
