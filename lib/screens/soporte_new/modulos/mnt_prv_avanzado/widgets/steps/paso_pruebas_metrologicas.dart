import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/excentricidad_bascula_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/linealidad_prueba_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/prueba_common_widgets.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas/repetibilidad_prueba_widget.dart';

class PasoPruebasMetrologicas extends StatelessWidget {
  final BalanzaInfo balanza;
  final bool esInicial;

  final String? horaInicio;

  final String retornoCero;
  final String estabilidad;
  final ValueChanged<String> onRetornoCeroChanged;
  final ValueChanged<String> onEstabilidadChanged;
  final bool showRetornoCero;

  final bool excentricidadActiva;
  final bool repetibilidadActiva;
  final bool linealidadActiva;
  final ValueChanged<bool> onExcentricidadActivaChanged;
  final ValueChanged<bool> onRepetibilidadActivaChanged;
  final ValueChanged<bool> onLinealidadActivaChanged;

  final ExcentricidadData excentricidad;
  final RepetibilidadData repetibilidad;
  final LinealidadData linealidad;
  final ValueChanged<ExcentricidadData> onExcentricidadChanged;
  final ValueChanged<RepetibilidadData> onRepetibilidadChanged;
  final ValueChanged<LinealidadData> onLinealidadChanged;

  final int copyTick;

  final VoidCallback? onCopiarDeIniciales;

  const PasoPruebasMetrologicas({
    super.key,
    required this.balanza,
    required this.esInicial,
    this.horaInicio,
    required this.retornoCero,
    required this.estabilidad,
    required this.onRetornoCeroChanged,
    required this.onEstabilidadChanged,
    this.showRetornoCero = true,
    required this.excentricidadActiva,
    required this.repetibilidadActiva,
    required this.linealidadActiva,
    required this.onExcentricidadActivaChanged,
    required this.onRepetibilidadActivaChanged,
    required this.onLinealidadActivaChanged,
    required this.excentricidad,
    required this.repetibilidad,
    required this.linealidad,
    required this.onExcentricidadChanged,
    required this.onRepetibilidadChanged,
    required this.onLinealidadChanged,
    this.copyTick = 0,
    this.onCopiarDeIniciales,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (esInicial && horaInicio != null) ...[
          _buildHoraInicioCard(isDark),
          const SizedBox(height: 20),
        ],
        if (!esInicial && onCopiarDeIniciales != null) ...[
          _buildCopiarCard(isDark),
          const SizedBox(height: 20),
        ],
        if (showRetornoCero) ...[
          _buildRetornoCeroSection(isDark),
          const SizedBox(height: 24),
        ],
        _buildSectionTitle('EXCENTRICIDAD', Icons.adjust_rounded, isDark),
        const SizedBox(height: 12),
        PruebaSkipCard(
          realizada: excentricidadActiva,
          onChanged: onExcentricidadActivaChanged,
          nombrePrueba: 'excentricidad',
        ),
        if (excentricidadActiva) ...[
          const SizedBox(height: 16),
          ExcentricidadBasculaWidget(
            balanza: balanza,
            data: excentricidad,
            onChanged: onExcentricidadChanged,
            copyTick: copyTick,
          ),
        ],
        const SizedBox(height: 28),
        _buildSectionTitle('REPETIBILIDAD', Icons.repeat_rounded, isDark),
        const SizedBox(height: 12),
        PruebaSkipCard(
          realizada: repetibilidadActiva,
          onChanged: onRepetibilidadActivaChanged,
          nombrePrueba: 'repetibilidad',
        ),
        if (repetibilidadActiva) ...[
          const SizedBox(height: 16),
          RepetibilidadPruebaWidget(
            balanza: balanza,
            data: repetibilidad,
            onChanged: onRepetibilidadChanged,
            copyTick: copyTick,
          ),
        ],
        const SizedBox(height: 28),
        _buildSectionTitle('LINEALIDAD', Icons.show_chart_rounded, isDark),
        const SizedBox(height: 12),
        PruebaSkipCard(
          realizada: linealidadActiva,
          onChanged: onLinealidadActivaChanged,
          nombrePrueba: 'linealidad',
        ),
        if (linealidadActiva) ...[
          const SizedBox(height: 16),
          LinealidadPruebaWidget(
            balanza: balanza,
            data: linealidad,
            onChanged: onLinealidadChanged,
            copyTick: copyTick,
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHoraInicioCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time_rounded,
                size: 20, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hora de Inicio',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Se registra automáticamente del sistema',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Text(
            horaInicio!,
            style: GoogleFonts.robotoMono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildRetornoCeroSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            esInicial ? 'Condiciones Iniciales' : 'Condiciones Finales',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          _dropdown(
            label: 'Retorno a Cero',
            value: retornoCero,
            onChanged: onRetornoCeroChanged,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _dropdown(
            label: 'Estabilidad',
            value: estabilidad,
            onChanged: onEstabilidadChanged,
            isDark: isDark,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _dropdown({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: isDark ? Colors.white70 : Colors.black87,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      items: const [
        DropdownMenuItem(value: '1 Bueno', child: Text('1 Bueno')),
        DropdownMenuItem(value: '2 Aceptable', child: Text('2 Aceptable')),
        DropdownMenuItem(value: '3 Malo', child: Text('3 Malo')),
        DropdownMenuItem(value: '4 No aplica', child: Text('4 No aplica')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            thickness: 1,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildCopiarCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.blue[600], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Si las pruebas finales son iguales a las iniciales, '
                  'puede copiarlas automáticamente y luego ajustarlas.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCopiarDeIniciales,
              icon: const Icon(Icons.content_copy_rounded, size: 20),
              label: Text(
                'COPIAR DE PRUEBAS INICIALES',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
