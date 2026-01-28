// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diagnostico_model.dart';

class PasoEstadoFinalDiagnostico extends StatelessWidget {
  final DiagnosticoModel model;
  final VoidCallback onChanged;

  const PasoEstadoFinalDiagnostico({
    super.key,
    required this.model,
    required this.onChanged,
  });

  @override
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

          // Hora de inicio (solo lectura)
          _buildReadOnlyField(
            label: 'Hora de Inicio',
            value: model.horaInicio,
            icon: Icons.access_time,
            context: context,
          ),
          const SizedBox(height: 16),

          // Comentario General
          TextField(
            decoration: InputDecoration(
              labelText: 'Comentario General *',
              hintText:
                  'Describa el diagnóstico realizado (Máx 800 caracteres)...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.comment),
              helperText: '* Campo obligatorio',
              counterText: '${model.comentarioGeneral.length}/800',
            ),
            maxLength: 800,
            maxLines: 8,
            onChanged: (value) {
              model.comentarioGeneral = value;
              onChanged();
            },
            controller: TextEditingController(text: model.comentarioGeneral)
              ..selection = TextSelection.collapsed(
                offset: model.comentarioGeneral.length,
              ),
          ),
          const SizedBox(height: 24),

          // Hora Final
          TextField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Hora Final del Servicio *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.access_time),
              suffixIcon: IconButton(
                icon: const Icon(Icons.update),
                onPressed: () {
                  final ahora = DateTime.now();
                  final horaFormateada = DateFormat('HH:mm:ss').format(ahora);
                  model.horaFin = horaFormateada;
                  onChanged();
                },
                tooltip: 'Registrar hora actual',
              ),
            ),
            controller: TextEditingController(text: model.horaFin),
          ),
          const SizedBox(height: 12),
          _buildInfoBox(
            'Para registrar la hora final, presione el botón del reloj. '
            'Una vez registrada, no se podrá modificar.',
            Colors.blue,
          ),
          const SizedBox(height: 24),

          // Resumen Simplificado
          _buildResumenSimplificado(context, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildResumenSimplificado(BuildContext context, bool isDarkMode) {
    final tieneComentario = model.comentarioGeneral.isNotEmpty;
    final tieneHoraFinal = model.horaFin.isNotEmpty;
    final completado = tieneComentario && tieneHoraFinal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? (completado ? Colors.green : Colors.orange).withOpacity(0.1)
            : (completado ? Colors.green : Colors.orange).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (completado ? Colors.green : Colors.orange).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                completado ? Icons.check_circle : Icons.warning,
                color: completado ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 12),
              Text(
                completado ? 'SERVICIO COMPLETADO' : 'CAMPOS PENDIENTES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: completado ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckItem('Comentario General', tieneComentario),
          _buildCheckItem('Hora Final', tieneHoraFinal),
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
            Icons.assignment_turned_in_outlined,
            color: Colors.green,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTADO FINAL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete la evaluación final del servicio de diagnóstico',
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

  Widget _buildCheckItem(String label, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: completed ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
