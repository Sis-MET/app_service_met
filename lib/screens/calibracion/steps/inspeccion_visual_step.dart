// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';

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
    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        final insp = provider.session?.inspeccion;
        final campos = insp?.campos ?? {};
        final comentarios = insp?.comentarios ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'REGISTRO DE CONDICIONES\nDEL EQUIPO A CALIBRAR',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white : const Color(0xFF2C3E50)),
                ).animate().fadeIn(duration: 600.ms),
              ),
              const SizedBox(height: 24),

              // Hora inicio
              _buildHoraInicio(insp?.horaInicio ?? _currentTime()),
              const SizedBox(height: 20),

              // Tiempos
              DropdownButtonFormField<String>(
                value: _validarOpcion(insp?.tiempoEstab),
                decoration: _deco('Tiempo de estabilización de Pesas (minutos)'),
                hint: const Text('Seleccione una opción'),
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
                decoration: _deco('Tiempo previo a operación de la Balanza'),
                hint: const Text('Seleccione una opción'),
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
              _sectionHeader('ENTORNO DE INSTALACIÓN'),
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
                provider, e.key, e.value, campos, comentarios,
              )),

              const SizedBox(height: 24),
              _sectionHeader('ESTADO GENERAL DE LA BALANZA'),
              const SizedBox(height: 12),
              ..._balanzaFields.entries.map((e) => _buildInspeccionField(
                provider, e.key, e.value, campos, comentarios,
              )),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHoraInicio(String hora) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.blue[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hora de inicio de la Calibración',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[600])),
              Text(hora, style: GoogleFonts.robotoMono(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800])),
            ],
          ),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: -0.2);
  }

  Widget _buildInspeccionField(
      ServiceSessionProvider provider, String key, String label,
      Map<String, String> campos, Map<String, String> comentarios) {
    final comentarioKey = '${key}_comentario';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
            DropdownButton<String>(
              value: _opciones.contains(campos[key]) ? campos[key] : null,
              hint: const Text('Estado'),
              underline: const SizedBox(),
              items: _opciones.map((v) => DropdownMenuItem(
                value: v,
                child: Text(v, style: TextStyle(
                  color: v == 'Bueno' ? Colors.green[700]
                       : v == 'Regular' ? Colors.orange[700]
                       : v == 'Malo' ? Colors.red[700]
                       : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                )),
              )).toList(),
              onChanged: (v) => _setCampo(provider, key, v),
            ),
          ]),
          if (campos[key] != null && campos[key] != 'Bueno') ...[
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'Comentario (opcional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              controller: TextEditingController(text: comentarios[comentarioKey] ?? '')
                ..selection = TextSelection.fromPosition(
                    TextPosition(offset: (comentarios[comentarioKey] ?? '').length)),
              onChanged: (v) => _setComentario(provider, comentarioKey, v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[700])),
    ).animate().fadeIn().slideX(begin: -0.3);
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  static const _tiemposValidos = ['Mayor a 15 minutos', 'Mayor a 30 minutos'];
  String? _validarOpcion(String? v) => _tiemposValidos.contains(v) ? v : null;
}
