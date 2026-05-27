import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';

class ExcentricidadStep extends StatefulWidget {
  const ExcentricidadStep({super.key});

  @override
  State<ExcentricidadStep> createState() => _ExcentricidadStepState();
}

class _ExcentricidadStepState extends State<ExcentricidadStep> {
  static const _plataformas = ['Cuadrada', 'Rectangular', 'Circular'];
  static const _puntosOpciones = ['4', '5', '6'];

  String? _tipoPlataforma;
  String? _puntosIndicacion;
  final _cargaCtrl = TextEditingController();
  final _notaCtrl  = TextEditingController();
  List<List<TextEditingController>> _rows = []; // [posicion, indicacion, retorno]

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final exc = provider.session?.excentricidad;
    if (exc != null) {
      setState(() {
        _tipoPlataforma   = exc.tipoPlataforma;
        _puntosIndicacion = exc.puntosIndicacion;
        _cargaCtrl.text   = exc.carga ?? '';
        _notaCtrl.text    = exc.nota  ?? '';
        _rows = exc.posiciones.map((p) => [
          TextEditingController(text: p.posicion   ?? ''),
          TextEditingController(text: p.indicacion ?? ''),
          TextEditingController(text: p.retorno    ?? ''),
        ]).toList();
      });
    }
    if (_rows.isEmpty) _buildDefaultRows(4);
  }

  void _buildDefaultRows(int count) {
    for (final row in _rows) for (final c in row) c.dispose();
    _rows = List.generate(count, (_) => [
      TextEditingController(), TextEditingController(), TextEditingController(),
    ]);
  }

  void _onPuntosChanged(String? v) {
    final n = int.tryParse(v ?? '4') ?? 4;
    setState(() { _puntosIndicacion = v; _buildDefaultRows(n); });
    _saveToProvider();
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateExcentricidad(ExcentricidadData(
      tipoPlataforma:   _tipoPlataforma,
      puntosIndicacion: _puntosIndicacion,
      carga:            _cargaCtrl.text,
      nota:             _notaCtrl.text,
      posiciones: _rows.map((r) => PosicionData(
        posicion:   r[0].text,
        indicacion: r[1].text,
        retorno:    r[2].text,
      )).toList(),
    ));
  }

  @override
  void dispose() {
    for (final r in _rows) for (final c in r) c.dispose();
    _cargaCtrl.dispose(); _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text('PRUEBAS DE EXCENTRICIDAD',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[700]),
          ).animate().fadeIn(duration: 600.ms)),
          const SizedBox(height: 24),

          // Selector de plataforma
          DropdownButtonFormField<String>(
            value: _tipoPlataforma,
            decoration: _deco('Tipo de Plataforma'),
            hint: const Text('Seleccione'),
            items: _plataformas.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) { setState(() => _tipoPlataforma = v); _saveToProvider(); },
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _puntosIndicacion,
            decoration: _deco('N° de Puntos de Indicación'),
            hint: const Text('Seleccione'),
            items: _puntosOpciones.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: _onPuntosChanged,
          ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 16),

          TextField(
            controller: _cargaCtrl,
            onChanged: (_) => _saveToProvider(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: _deco('Carga (kg)'),
          ).animate(delay: 400.ms).fadeIn(),
          const SizedBox(height: 24),

          // Tabla de posiciones
          if (_rows.isNotEmpty) ...[
            Text('POSICIONES', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[700])),
            const SizedBox(height: 12),
            // Encabezado
            Row(children: [
              const SizedBox(width: 32),
              Expanded(child: Text('Posición', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              Expanded(child: Text('Indicación', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              Expanded(child: Text('Retorno', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
            ]),
            const SizedBox(height: 8),
            ...List.generate(_rows.length, (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 32, child: Text('${i + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _numField(_rows[i][0]))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _numField(_rows[i][1]))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _numField(_rows[i][2]))),
              ]),
            )).animate(delay: 500.ms).fadeIn(),
          ],

          const SizedBox(height: 20),
          TextField(
            controller: _notaCtrl,
            onChanged: (_) => _saveToProvider(),
            maxLines: 3,
            decoration: _deco('Nota / Comentario (opcional)'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController ctrl) => TextField(
    controller: ctrl,
    onChanged: (_) => _saveToProvider(),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
    decoration: const InputDecoration(
      isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      border: OutlineInputBorder(),
    ),
  );

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}
