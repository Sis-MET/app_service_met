import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';

class PrecargasAjusteStep extends StatefulWidget {
  const PrecargasAjusteStep({super.key});

  @override
  State<PrecargasAjusteStep> createState() => _PrecargasAjusteStepState();
}

class _PrecargasAjusteStepState extends State<PrecargasAjusteStep> {
  final _horaCtrl = TextEditingController();
  final _tiCtrl = TextEditingController();
  final _hriCtrl = TextEditingController();
  final _patmiCtrl = TextEditingController();
  final _cargasCtrl = TextEditingController();

  // Rows: list of [precarga, indicacion] controllers
  List<List<TextEditingController>> _rows = [];

  bool _ajusteRealizado = false;
  bool _ajusteExterno = false;
  String? _tipoAjuste;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final pa = provider.session?.precargasAjuste;
    if (pa != null) {
      _horaCtrl.text = pa.hora ?? _currentTime();
      _tiCtrl.text = pa.ti ?? '';
      _hriCtrl.text = pa.hri ?? '';
      _patmiCtrl.text = pa.patmi ?? '';
      _cargasCtrl.text = pa.cargasPesas ?? '';
      setState(() {
        _ajusteRealizado = pa.ajusteRealizado ?? false;
        _tipoAjuste = pa.tipoAjuste;
        _ajusteExterno = pa.tipoAjuste == 'Externo';
        // Build rows
        _rows = pa.precargas
            .map((r) => [
                  TextEditingController(text: r.precarga ?? ''),
                  TextEditingController(text: r.pIndicador ?? ''),
                ])
            .toList();
        if (_rows.isEmpty) _addRow();
      });
    } else {
      _horaCtrl.text = _currentTime();
      _addRow();
    }
  }

  void _addRow() {
    setState(
        () => _rows.add([TextEditingController(), TextEditingController()]));
  }

  void _removeRow() {
    if (_rows.length > 1) {
      setState(() {
        final removed = _rows.removeLast();
        for (final c in removed) {
          c.dispose();
        }
      });
      _saveToProvider();
    }
  }

  String _currentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    final precargas = _rows
        .map((r) => PrecargaRow(
              precarga: r[0].text,
              pIndicador: r[1].text,
            ))
        .toList();

    provider.updatePrecargasAjuste(PrecargasAjuste(
      precargas: precargas,
      ajusteRealizado: _ajusteRealizado,
      tipoAjuste: _tipoAjuste,
      cargasPesas: _cargasCtrl.text,
      hora: _horaCtrl.text,
      ti: _tiCtrl.text,
      hri: _hriCtrl.text,
      patmi: _patmiCtrl.text,
    ));
  }

  @override
  void dispose() {
    for (final row in _rows)
      for (final c in row) {
        c.dispose();
      }
    _horaCtrl.dispose();
    _tiCtrl.dispose();
    _hriCtrl.dispose();
    _patmiCtrl.dispose();
    _cargasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'PRECARGAS DE AJUSTE',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700]),
                ).animate().fadeIn(duration: 600.ms),
              ),
              const SizedBox(height: 24),

              // Tabla de precargas
              _sectionHeader('Precargas'),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.orange),
                      onPressed: _addRow),
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.orange),
                      onPressed: _removeRow),
                ],
              ),
              ...List.generate(_rows.length, (i) => _buildRow(i, provider)),
              const SizedBox(height: 20),

              // Ajuste
              _sectionHeader('Ajuste'),
              SwitchListTile(
                title: Text('¿Se realizó Ajuste?', style: GoogleFonts.inter()),
                value: _ajusteRealizado,
                onChanged: (v) {
                  setState(() {
                    _ajusteRealizado = v;
                    if (!v) {
                      _tipoAjuste = null;
                      _ajusteExterno = false;
                    }
                  });
                  _saveToProvider();
                },
                activeThumbColor: Colors.orange,
              ),
              if (_ajusteRealizado) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _tipoAjuste,
                  decoration: _deco('Tipo de Ajuste'),
                  hint: const Text('Seleccione'),
                  items: const [
                    DropdownMenuItem(value: 'Interno', child: Text('Interno')),
                    DropdownMenuItem(value: 'Externo', child: Text('Externo')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _tipoAjuste = v;
                      _ajusteExterno = v == 'Externo';
                    });
                    _saveToProvider();
                  },
                ),
                if (_ajusteExterno) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cargasCtrl,
                    onChanged: (_) => _saveToProvider(),
                    decoration: _deco('Cargas de Pesas Patrón Utilizadas'),
                  ),
                ],
              ],
              const SizedBox(height: 20),

              // Condiciones Ambientales
              _sectionHeader('Condiciones Ambientales'),
              Row(children: [
                Expanded(child: _buildHoraField()),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _tiCtrl,
                        onChanged: (_) => _saveToProvider(),
                        keyboardType: TextInputType.number,
                        decoration: _deco('Ti (°C)'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: _hriCtrl,
                        onChanged: (_) => _saveToProvider(),
                        keyboardType: TextInputType.number,
                        decoration: _deco('HRi (%)'))),
              ]),
              const SizedBox(height: 10),
              TextField(
                  controller: _patmiCtrl,
                  onChanged: (_) => _saveToProvider(),
                  keyboardType: TextInputType.number,
                  decoration: _deco('Patmi (hPa)')),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(int i, ServiceSessionProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('${i + 1}.',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
            controller: _rows[i][0],
            onChanged: (_) => _saveToProvider(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            decoration: _deco('Precarga'),
          )),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
            controller: _rows[i][1],
            onChanged: (_) => _saveToProvider(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            decoration: _deco('Indicación'),
          )),
        ],
      ),
    );
  }

  Widget _buildHoraField() {
    return TextField(
      controller: _horaCtrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Hora de Pruebas',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.access_time),
          onPressed: () {
            _horaCtrl.text = _currentTime();
            _saveToProvider();
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange[700])),
    ).animate().fadeIn();
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
