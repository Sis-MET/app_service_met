import 'package:flutter/material.dart';

class PasoInformacionGeneralWidget extends StatelessWidget {
  final String reporteFalla;
  final String evaluacion;
  final ValueChanged<String> onReporteFallaChanged;
  final ValueChanged<String> onEvaluacionChanged;

  const PasoInformacionGeneralWidget({
    super.key,
    required this.reporteFalla,
    required this.evaluacion,
    required this.onReporteFallaChanged,
    required this.onEvaluacionChanged,
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
          TextFormField(
            initialValue: reporteFalla,
            decoration: InputDecoration(
              labelText: 'Reporte de falla:',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              alignLabelWithHint: true,
            ),
            maxLength: 800,
            maxLines: 8,
            minLines: 4,
            onChanged: onReporteFallaChanged,
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: evaluacion,
            decoration: InputDecoration(
              labelText: 'Evaluación y análisis técnico de fallas:',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              alignLabelWithHint: true,
            ),
            maxLength: 800,
            maxLines: 8,
            minLines: 4,
            onChanged: onEvaluacionChanged,
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
            Icons.info_outlined,
            color: Colors.blue,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INFORMACIÓN GENERAL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Datos iniciales del servicio de diagnóstico',
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
}
