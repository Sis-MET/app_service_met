// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';

class InspeccionVisualStep extends StatefulWidget {
  const InspeccionVisualStep({super.key});

  @override
  State<InspeccionVisualStep> createState() => _InspeccionVisualStepState();
}

class _InspeccionVisualStepState extends State<InspeccionVisualStep> {
  bool _setAllToGood = false;

  static const _tiemposOpciones = ['Mayor a 15 minutos', 'Mayor a 30 minutos'];

  // Mapa de campos de inspección: key DB → label mostrado
  static const _entornoFields = {
    'vibracion':      'Vibración',
    'polvo':          'Polvo',
    'temp':           'Temperatura',
    'humedad':        'Humedad',
    'mesada':         'Mesada',
    'iluminacion':    'Iluminación',
    'limp_foza':      'Limpieza de Fosa',
    'estado_drenaje': 'Estado de Drenaje',
  };

  static const _balanzaFields = {
    'limp_general':    'Limpieza General',
    'golpes_terminal': 'Golpes al Terminal',
    'nivelacion':      'Nivelación',
    'limp_recepto':    'Limpieza Receptor',
    'golpes_receptor': 'Golpes al receptor de Carga',
    'encendido':       'Encendido',
  };

  static const _opciones = ['Bueno', 'Regular', 'Malo', 'N/A'];

  void _initFromSession(ServiceSessionProvider provider) {
    final insp = provider.session?.inspeccion;
    if (insp == null) return;
    // Check if all are 'Bueno'
    final allGood = {..._entornoFields.keys, ..._balanzaFields.keys}
        .every((k) => (insp.campos[k] ?? '') == 'Bueno');
    if (allGood && insp.campos.isNotEmpty) {
      setState(() => _setAllToGood = true);
    }
  }

  void _setAll(ServiceSessionProvider provider, bool value) {
    setState(() => _setAllToGood = value);
    final campos = Map<String, String>.from(provider.session?.inspeccion?.campos ?? {});
    if (value) {
      for (final k in {..._entornoFields.keys, ..._balanzaFields.keys}) {
        campos[k] = 'Bueno';
      }
    } else {
      for (final k in {..._entornoFields.keys, ..._balanzaFields.keys}) {
        campos.remove(k);
      }
    }
    _updateInspeccion(provider, campos: campos);
  }

  void _setCampo(ServiceSessionProvider provider, String key, String? val) {
    final campos = Map<String, String>.from(provider.session?.inspeccion?.campos ?? {});
    campos[key] = val ?? '';
    _updateInspeccion(provider, campos: campos);
  }

  void _setComentario(ServiceSessionProvider provider, String key, String val) {
    final comentarios = Map<String, String>.from(provider.session?.inspeccion?.comentarios ?? {});
    comentarios[key] = val;
    _updateInspeccion(provider, comentarios: comentarios);
  }

  void _updateInspeccion(ServiceSessionProvider provider,
      {Map<String, String>? campos, Map<String, String>? comentarios}) {
    final curr = provider.session?.inspeccion;
    provider.updateInspeccionVisual(InspeccionVisual(
      horaInicio:      curr?.horaInicio ?? _currentTime(),
      tiempoEstab:     curr?.tiempoEstab,
      tiempoOperacion: curr?.tiempoOperacion,
      campos:          campos      ?? curr?.campos      ?? {},
      comentarios:     comentarios ?? curr?.comentarios ?? {},
    ));
  }

  String _currentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ServiceSessionProvider>();
      _initFromSession(provider);
      // Set hora inicio if not set
      if (provider.session?.inspeccion?.horaInicio == null) {
        _updateInspeccion(provider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        final insp = provider.session?.inspeccion;
        final campos = insp?.campos ?? {};
        final comentarios = insp?.comentarios ?? {};

        return SingleChildScrollView(
          padding: ServiceNavPill.pagePadding(context, top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 24),

              // Hora inicio
              _buildHoraInicio(insp?.horaInicio ?? _currentTime(), isDark),
              const SizedBox(height: 20),

              // Tiempos
              DropdownButtonFormField<String>(
                value: _validarOpcion(insp?.tiempoEstab),
                decoration: _deco('Tiempo de estabilización de Pesas (minutos)', isDark),
                hint: const Text('Seleccione una opción'),
                borderRadius: BorderRadius.circular(12),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: _tiemposOpciones.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) {
                  final curr = insp;
                  provider.updateInspeccionVisual(InspeccionVisual(
                    horaInicio:      curr?.horaInicio ?? _currentTime(),
                    tiempoEstab:     v,
                    tiempoOperacion: curr?.tiempoOperacion,
                    campos:          curr?.campos ?? {},
                    comentarios:     curr?.comentarios ?? {},
                  ));
                },
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _validarOpcion(insp?.tiempoOperacion),
                decoration: _deco('Tiempo previo a operación de la Balanza', isDark),
                hint: const Text('Seleccione una opción'),
                borderRadius: BorderRadius.circular(12),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: _tiemposOpciones.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) {
                  final curr = insp;
                  provider.updateInspeccionVisual(InspeccionVisual(
                    horaInicio:      curr?.horaInicio ?? _currentTime(),
                    tiempoEstab:     curr?.tiempoEstab,
                    tiempoOperacion: v,
                    campos:          curr?.campos ?? {},
                    comentarios:     curr?.comentarios ?? {},
                  ));
                },
              ).animate(delay: 300.ms).fadeIn(),
              const SizedBox(height: 24),

              // Sección: Entorno
              _sectionHeader('Entorno de Instalación', isDark),
              SwitchListTile(
                title: Text('Establecer todo en Buen Estado', style: GoogleFonts.inter()),
                value: _setAllToGood,
                onChanged: (v) => _setAll(provider, v),
                activeThumbColor: Colors.green,
                secondary: Icon(
                  _setAllToGood ? Icons.check_circle : Icons.circle_outlined,
                  color: _setAllToGood ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              ..._entornoFields.entries.map((e) => _buildInspeccionField(
                provider, e.key, e.value, campos, comentarios, isDark,
              )),

              const SizedBox(height: 24),
              _sectionHeader('Estado General de la Balanza', isDark),
              const SizedBox(height: 12),
              ..._balanzaFields.entries.map((e) => _buildInspeccionField(
                provider, e.key, e.value, campos, comentarios, isDark,
              )),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inspección Visual',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Registro de condiciones del equipo a calibrar',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildHoraInicio(String hora, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_filled_rounded, color: isDark ? const Color(0xFFf9e300) : const Color(0xFF5A4E00), size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hora de inicio',
                  style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500)),
              Text(hora, style: GoogleFonts.robotoMono(
                  fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            ],
          ),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: -0.2);
  }

  Widget _buildInspeccionField(
      ServiceSessionProvider provider, String key, String label,
      Map<String, String> campos, Map<String, String> comentarios, bool isDark) {
    final comentarioKey = '${key}_comentario';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8F9FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1A1A)))),
            DropdownButton<String>(
              value: _opciones.contains(campos[key]) ? campos[key] : null,
              hint: Text('Estado', style: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.black38)),
              dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              underline: const SizedBox(),
              items: _opciones.map((v) => DropdownMenuItem(
                value: v,
                child: Text(v, style: TextStyle(
                  color: v == 'Bueno' ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                       : v == 'Regular' ? (isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00))
                       : v == 'Malo' ? (isDark ? const Color(0xFFE57373) : const Color(0xFFD32F2F))
                       : (isDark ? Colors.white54 : Colors.black54),
                  fontWeight: FontWeight.w600,
                )),
              )).toList(),
              onChanged: (v) => _setCampo(provider, key, v),
            ),
          ]),
          if (campos[key] != null && campos[key] != 'Bueno') ...[
            const SizedBox(height: 4),
            TextField(
              style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'Comentario (opcional)',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))
                ),
                filled: true,
                fillColor: isDark ? Colors.black12 : Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              controller: TextEditingController(text: comentarios[comentarioKey] ?? '')
                ..selection = TextSelection.fromPosition(
                    TextPosition(offset: (comentarios[comentarioKey] ?? '').length)),
              onChanged: (v) => _setComentario(provider, comentarioKey, v),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
    ).animate().fadeIn().slideX(begin: -0.3);
  }

  InputDecoration _deco(String label, bool isDark) => InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
  );

  static const _tiemposValidos = ['Mayor a 15 minutos', 'Mayor a 30 minutos'];
  String? _validarOpcion(String? v) => _tiemposValidos.contains(v) ? v : null;
}
