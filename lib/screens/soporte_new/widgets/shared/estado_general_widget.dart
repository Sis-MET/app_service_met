import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/utils/estado_maps.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';

/// Mapa legacy del módulo antiguo: Bueno / Aceptable / Malo / No aplica.
const Map<String, Color> _legacyEstadoColorMap = {
  'Bueno': Colors.green,
  'Aceptable': Colors.orange,
  'Malo': Colors.red,
  'No aplica': Colors.grey,
};

const Map<String, IconData> _legacyEstadoIconMap = {
  'Bueno': Icons.check_circle,
  'Aceptable': Icons.warning,
  'Malo': Icons.error,
  'No aplica': Icons.block,
};

class EstadoGeneralWidget extends StatelessWidget {
  final String estadoFisico;
  final String estadoOperacional;
  final String estadoMetrologico;
  final ValueChanged<String> onEstadoFisicoChanged;
  final ValueChanged<String> onEstadoOperacionalChanged;
  final ValueChanged<String> onEstadoMetrologicoChanged;

  /// Si es true, usa los valores legacy del módulo antiguo:
  /// Bueno / Aceptable / Malo / No aplica.
  /// Si es false (default), usa [estadoColorMap]: Bueno / Regular / Malo.
  final bool useLegacyEstados;

  const EstadoGeneralWidget({
    super.key,
    required this.estadoFisico,
    required this.estadoOperacional,
    required this.estadoMetrologico,
    required this.onEstadoFisicoChanged,
    required this.onEstadoOperacionalChanged,
    required this.onEstadoMetrologicoChanged,
    this.useLegacyEstados = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ServiceSectionHeader('Estado General'),
        const SizedBox(height: 8),
        _dropdown('Estado Físico', estadoFisico, onEstadoFisicoChanged, isDark),
        const SizedBox(height: 8),
        _dropdown('Estado Operacional', estadoOperacional,
            onEstadoOperacionalChanged, isDark),
        const SizedBox(height: 8),
        _dropdown('Estado Metrológico', estadoMetrologico,
            onEstadoMetrologicoChanged, isDark),
      ],
    );
  }

  Widget _dropdown(String label, String value, ValueChanged<String> onChanged,
      bool isDark) {
    final colorMap = useLegacyEstados ? _legacyEstadoColorMap : estadoColorMap;
    final iconMap = useLegacyEstados ? _legacyEstadoIconMap : estadoIconMap;

    return DropdownButtonFormField<String>(
      value: value.isNotEmpty ? value : null,
      decoration: serviceInputDeco(label, isDark),
      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      items: colorMap.keys.map((key) {
        return DropdownMenuItem(
          value: key,
          child: Row(
            children: [
              Icon(iconMap[key], color: colorMap[key], size: 20),
              const SizedBox(width: 8),
              Text(key),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
