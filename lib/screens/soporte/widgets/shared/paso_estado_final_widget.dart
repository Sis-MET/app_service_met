import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class PasoEstadoFinalWidget extends StatelessWidget {
  final String horaInicio;
  final String horaFin;
  final String comentarioGeneral;
  final String recomendacion;
  final String fechaProxServicio;
  final String estadoFisico;
  final String estadoOperacional;
  final String estadoMetrologico;

  final List<String> recomendacionesOptions;

  final ValueChanged<String> onComentarioGeneralChanged;
  final ValueChanged<String> onRecomendacionChanged;
  final ValueChanged<String> onFechaProxServicioChanged;
  final ValueChanged<String> onEstadoFisicoChanged;
  final ValueChanged<String> onEstadoOperacionalChanged;
  final ValueChanged<String> onEstadoMetrologicoChanged;
  final VoidCallback onRegistrarHoraFin;

  const PasoEstadoFinalWidget({
    super.key,
    required this.horaInicio,
    required this.horaFin,
    required this.comentarioGeneral,
    required this.recomendacion,
    required this.fechaProxServicio,
    required this.estadoFisico,
    required this.estadoOperacional,
    required this.estadoMetrologico,
    required this.recomendacionesOptions,
    required this.onComentarioGeneralChanged,
    required this.onRecomendacionChanged,
    required this.onFechaProxServicioChanged,
    required this.onEstadoFisicoChanged,
    required this.onEstadoOperacionalChanged,
    required this.onEstadoMetrologicoChanged,
    required this.onRegistrarHoraFin,
  });

  String _calcularFechaFutura(int meses) {
    final fechaActual = DateTime.now();
    final fechaFutura = DateTime(
      fechaActual.year,
      fechaActual.month + meses,
      fechaActual.day,
    );
    return DateFormat('dd/MM/yyyy').format(fechaFutura);
  }

  Future<void> _mostrarSelectorMeses(BuildContext context) async {
    final opciones = [
      {'meses': 3, 'label': '3 meses'},
      {'meses': 6, 'label': '6 meses'},
      {'meses': 12, 'label': '12 meses'},
    ];

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'SELECCIONE PER\u00cdODO',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: opciones.map((opcion) {
              final meses = opcion['meses'] as int;
              final label = opcion['label'] as String;
              final fechaCalculada = _calcularFechaFutura(meses);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    Icons.calendar_today,
                    color: meses == 3
                        ? Colors.green
                        : meses == 6
                            ? Colors.orange
                            : Colors.blue,
                  ),
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Fecha: $fechaCalculada',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    onFechaProxServicioChanged(fechaCalculada);
                    Navigator.of(context).pop();
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }

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

          TextField(
            decoration: InputDecoration(
              labelText: 'Comentario General *',
              hintText: 'Describa el estado general del servicio...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.comment),
              helperText: '* Campo obligatorio',
            ),
            maxLines: 4,
            onChanged: onComentarioGeneralChanged,
            controller: TextEditingController(text: comentarioGeneral)
              ..selection = TextSelection.collapsed(
                offset: comentarioGeneral.length,
              ),
          ),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            value: recomendacion.isEmpty ? null : recomendacion,
            hint: const Text('Seleccione...'),
            decoration: InputDecoration(
              labelText: 'Recomendaci\u00f3n *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.recommend),
            ),
            items: recomendacionesOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              onRecomendacionChanged(newValue ?? '');
            },
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: () => _mostrarSelectorMeses(context),
            child: AbsorbPointer(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Fecha Sugerida del Pr\u00f3ximo Servicio *',
                  hintText: 'Toque para seleccionar per\u00edodo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon:
                      const Icon(Icons.event_repeat, color: Colors.blue),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  helperText: 'Seleccione 3, 6 o 12 meses',
                ),
                controller: TextEditingController(text: fechaProxServicio),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'ESTADO FINAL DEL INSTRUMENTO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildEstadoDropdown(
            label: 'Estado F\u00edsico *',
            value: estadoFisico,
            icon: Icons.build_circle_outlined,
            color: _getColorForEstado(estadoFisico),
            onChanged: (value) => onEstadoFisicoChanged(value ?? ''),
          ),
          const SizedBox(height: 16),

          _buildEstadoDropdown(
            label: 'Estado Operacional *',
            value: estadoOperacional,
            icon: Icons.settings_outlined,
            color: _getColorForEstado(estadoOperacional),
            onChanged: (value) => onEstadoOperacionalChanged(value ?? ''),
          ),
          const SizedBox(height: 16),

          _buildEstadoDropdown(
            label: 'Estado Metrol\u00f3gico *',
            value: estadoMetrologico,
            icon: Icons.speed_outlined,
            color: _getColorForEstado(estadoMetrologico),
            onChanged: (value) => onEstadoMetrologicoChanged(value ?? ''),
          ),
          const SizedBox(height: 24),

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
                onPressed: onRegistrarHoraFin,
                tooltip: 'Registrar hora actual',
              ),
            ),
            controller: TextEditingController(text: horaFin),
          ),
          const SizedBox(height: 12),
          _buildInfoBox(
            'Para registrar la hora final, presione el bot\u00f3n del reloj. '
            'Una vez registrada, no se podr\u00e1 modificar.',
            Colors.blue,
          ),
          const SizedBox(height: 24),

          _buildResumenCard(context, isDarkMode),
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
                  'Complete la evaluaci\u00f3n final del servicio',
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

  Widget _buildEstadoDropdown({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      hint: const Text('Seleccione...'),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(icon, color: color),
      ),
      items: ['Bueno', 'Aceptable', 'Malo', 'No aplica'].map((String estado) {
        final estadoColor = _getColorForEstado(estado);
        return DropdownMenuItem<String>(
          value: estado,
          child: Row(
            children: [
              Icon(
                _getIconForEstado(estado),
                color: estadoColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                estado,
                style: TextStyle(
                  color: estadoColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Color _getColorForEstado(String estado) {
    switch (estado) {
      case 'Bueno':
        return Colors.green;
      case 'Aceptable':
        return Colors.orange;
      case 'Malo':
        return Colors.red;
      case 'No aplica':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForEstado(String estado) {
    switch (estado) {
      case 'Bueno':
        return Icons.check_circle;
      case 'Aceptable':
        return Icons.warning;
      case 'Malo':
        return Icons.error;
      case 'No aplica':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
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

  Widget _buildResumenCard(BuildContext context, bool isDarkMode) {
    final tieneComentario = comentarioGeneral.isNotEmpty;
    final tieneRecomendacion = recomendacion.isNotEmpty;
    final tieneFechaProxServicio = fechaProxServicio.isNotEmpty;
    final tieneEstados = estadoFisico.isNotEmpty &&
        estadoOperacional.isNotEmpty &&
        estadoMetrologico.isNotEmpty;
    final tieneHoraFinal = horaFin.isNotEmpty;

    final completado = tieneComentario &&
        tieneRecomendacion &&
        tieneFechaProxServicio &&
        tieneEstados &&
        tieneHoraFinal;

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
          _buildCheckItem('Recomendaci\u00f3n', tieneRecomendacion),
          _buildCheckItem('Fecha Pr\u00f3ximo Servicio', tieneFechaProxServicio),
          _buildCheckItem('Estados Finales', tieneEstados),
          _buildCheckItem('Hora Final', tieneHoraFinal),
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
