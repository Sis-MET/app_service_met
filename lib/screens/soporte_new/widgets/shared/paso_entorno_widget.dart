import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';

class PasoEntornoWidget extends StatelessWidget {
  final String temperatura;
  final String humedad;
  final String presion;
  final ValueChanged<String> onTemperaturaChanged;
  final ValueChanged<String> onHumedadChanged;
  final ValueChanged<String> onPresionChanged;

  const PasoEntornoWidget({
    super.key,
    required this.temperatura,
    required this.humedad,
    required this.presion,
    required this.onTemperaturaChanged,
    required this.onHumedadChanged,
    required this.onPresionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = GoogleFonts.inter(
      fontSize: 14,
      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: temperatura,
          style: textStyle,
          decoration: serviceInputDeco('Temperatura (°C)', isDark),
          keyboardType: TextInputType.number,
          onChanged: onTemperaturaChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: humedad,
          style: textStyle,
          decoration: serviceInputDeco('Humedad (%)', isDark),
          keyboardType: TextInputType.number,
          onChanged: onHumedadChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: presion,
          style: textStyle,
          decoration: serviceInputDeco('Presión (hPa)', isDark),
          keyboardType: TextInputType.number,
          onChanged: onPresionChanged,
        ),
      ],
    );
  }
}
