import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/estado_general_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';

class PasoEstadoFinalWidget extends StatelessWidget {
  final String comentarioGeneral;
  final String recomendacion;
  final String estadoFisico;
  final String estadoOperacional;
  final String estadoMetrologico;
  final ValueChanged<String> onComentarioGeneralChanged;
  final ValueChanged<String> onRecomendacionChanged;
  final ValueChanged<String> onEstadoFisicoChanged;
  final ValueChanged<String> onEstadoOperacionalChanged;
  final ValueChanged<String> onEstadoMetrologicoChanged;
  final List<CampoEstado> camposEstado;
  final void Function(int index, String value, String solutionValue)
      onCampoChanged;

  // ── Campos opcionales (módulos que los proveen obtienen la UI extra) ──

  /// Hora de inicio del servicio (readonly). Si es null no se muestra.
  final String? horaInicio;

  /// Hora final del servicio (readonly + botón registrar).
  /// Requiere [onRegistrarHoraFin]. Si es null no se muestra.
  final String? horaFin;
  final VoidCallback? onRegistrarHoraFin;

  /// Fecha sugerida del próximo servicio (selector 3/6/12 meses).
  /// Requiere [onFechaProxServicioChanged]. Si es null no se muestra.
  final String? fechaProxServicio;
  final ValueChanged<String>? onFechaProxServicioChanged;

  /// Si se provee, la recomendación se muestra como dropdown con estas
  /// opciones en lugar de un campo de texto libre.
  final List<String>? recomendacionesOptions;

  /// Usa los valores legacy (Bueno / Aceptable / Malo / No aplica) en los
  /// dropdowns de estado general.
  final bool useLegacyEstados;

  const PasoEstadoFinalWidget({
    super.key,
    required this.comentarioGeneral,
    required this.recomendacion,
    required this.estadoFisico,
    required this.estadoOperacional,
    required this.estadoMetrologico,
    required this.onComentarioGeneralChanged,
    required this.onRecomendacionChanged,
    required this.onEstadoFisicoChanged,
    required this.onEstadoOperacionalChanged,
    required this.onEstadoMetrologicoChanged,
    required this.camposEstado,
    required this.onCampoChanged,
    this.horaInicio,
    this.horaFin,
    this.onRegistrarHoraFin,
    this.fechaProxServicio,
    this.onFechaProxServicioChanged,
    this.recomendacionesOptions,
    this.useLegacyEstados = false,
  });

  String _calcularFechaFutura(int meses) {
    final ahora = DateTime.now();
    final futura = DateTime(ahora.year, ahora.month + meses, ahora.day);
    return DateFormat('dd/MM/yyyy').format(futura);
  }

  Future<void> _mostrarSelectorMeses(BuildContext context) async {
    final opciones = [
      {'meses': 3, 'label': '3 meses'},
      {'meses': 6, 'label': '6 meses'},
      {'meses': 12, 'label': '12 meses'},
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'SELECCIONE PERÍODO',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
                    onFechaProxServicioChanged?.call(fechaCalculada);
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = GoogleFonts.inter(
      fontSize: 14,
      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
    );

    final showResumen = horaFin != null && fechaProxServicio != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (horaInicio != null) ...[
          TextFormField(
            initialValue: horaInicio,
            readOnly: true,
            style: textStyle,
            decoration: serviceInputDeco('Hora de Inicio', isDark).copyWith(
              prefixIcon: const Icon(Icons.access_time),
            ),
          ),
          const SizedBox(height: 16),
        ],
        EstadoGeneralWidget(
          estadoFisico: estadoFisico,
          estadoOperacional: estadoOperacional,
          estadoMetrologico: estadoMetrologico,
          onEstadoFisicoChanged: onEstadoFisicoChanged,
          onEstadoOperacionalChanged: onEstadoOperacionalChanged,
          onEstadoMetrologicoChanged: onEstadoMetrologicoChanged,
          useLegacyEstados: useLegacyEstados,
        ),
        const SizedBox(height: 16),
        ...List.generate(camposEstado.length, (i) {
          return CampoInspeccionWidget(
            campoEstado: camposEstado[i],
            onChanged: (value, solutionValue) {
              onCampoChanged(i, value, solutionValue);
            },
            onAddPhoto: (label, foto) {},
            onRemovePhoto: (index) {},
          );
        }),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: comentarioGeneral,
          style: textStyle,
          decoration: serviceInputDeco('Comentario General *', isDark),
          maxLines: 3,
          onChanged: onComentarioGeneralChanged,
        ),
        const SizedBox(height: 12),
        if (recomendacionesOptions != null)
          DropdownButtonFormField<String>(
            value: recomendacion.isEmpty ? null : recomendacion,
            isExpanded: true,
            decoration: serviceInputDeco('Recomendación *', isDark),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            items: recomendacionesOptions!.map((opcion) {
              return DropdownMenuItem(
                value: opcion,
                child: Text(
                  opcion,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              );
            }).toList(),
            onChanged: (v) => onRecomendacionChanged(v ?? ''),
          )
        else
          TextFormField(
            initialValue: recomendacion,
            style: textStyle,
            decoration: serviceInputDeco('Recomendación', isDark),
            maxLines: 3,
            onChanged: onRecomendacionChanged,
          ),
        if (fechaProxServicio != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _mostrarSelectorMeses(context),
            child: AbsorbPointer(
              child: TextFormField(
                controller:
                    TextEditingController(text: fechaProxServicio),
                style: textStyle,
                decoration:
                    serviceInputDeco('Fecha Próximo Servicio *', isDark)
                        .copyWith(
                  prefixIcon:
                      const Icon(Icons.event_repeat, color: Colors.blue),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  helperText: 'Toque para seleccionar 3, 6 o 12 meses',
                ),
              ),
            ),
          ),
        ],
        if (horaFin != null) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('horaFin_$horaFin'),
            initialValue: horaFin,
            readOnly: true,
            style: textStyle,
            decoration:
                serviceInputDeco('Hora Final del Servicio *', isDark).copyWith(
              prefixIcon: const Icon(Icons.access_time),
              suffixIcon: IconButton(
                icon: const Icon(Icons.update),
                onPressed: onRegistrarHoraFin,
                tooltip: 'Registrar hora actual',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoBox(
            'Para registrar la hora final, presione el botón del reloj. '
            'Una vez registrada, no se podrá modificar.',
            Colors.blue,
            isDark,
          ),
        ],
        if (showResumen) ...[
          const SizedBox(height: 24),
          _buildResumenCard(isDark),
        ],
      ],
    );
  }

  Widget _buildInfoBox(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard(bool isDark) {
    final tieneComentario = comentarioGeneral.isNotEmpty;
    final tieneRecomendacion = recomendacion.isNotEmpty;
    final tieneFecha = (fechaProxServicio ?? '').isNotEmpty;
    final tieneEstados = estadoFisico.isNotEmpty &&
        estadoOperacional.isNotEmpty &&
        estadoMetrologico.isNotEmpty;
    final tieneHoraFin = (horaFin ?? '').isNotEmpty;

    final completado = tieneComentario &&
        tieneRecomendacion &&
        tieneFecha &&
        tieneEstados &&
        tieneHoraFin;

    final color = completado ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                completado ? Icons.check_circle : Icons.warning,
                color: color,
              ),
              const SizedBox(width: 12),
              Text(
                completado ? 'SERVICIO COMPLETADO' : 'CAMPOS PENDIENTES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckItem('Comentario General', tieneComentario),
          _buildCheckItem('Recomendación', tieneRecomendacion),
          _buildCheckItem('Fecha Próximo Servicio', tieneFecha),
          _buildCheckItem('Estados Finales', tieneEstados),
          _buildCheckItem('Hora Final', tieneHoraFin),
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
