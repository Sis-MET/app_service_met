import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';

class RepetibilidadStep extends StatefulWidget {
  const RepetibilidadStep({super.key});

  @override
  State<RepetibilidadStep> createState() => _RepetibilidadStepState();
}

class _RepetibilidadStepState extends State<RepetibilidadStep> {
  // 3 cargas, cada una con hasta 10 indicaciones/retornos
  final int _numCargas = 3;
  final int _numMediciones = 10;

  late List<TextEditingController> _cargasCtrls;
  late List<List<TextEditingController>> _indCtrls;
  late List<List<TextEditingController>> _retCtrls;
  final _notaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargasCtrls = List.generate(_numCargas, (_) => TextEditingController());
    _indCtrls = List.generate(_numCargas, (_) =>
        List.generate(_numMediciones, (_) => TextEditingController()));
    _retCtrls = List.generate(_numCargas, (_) =>
        List.generate(_numMediciones, (_) => TextEditingController()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final rep = provider.session?.repetibilidad;
    if (rep == null) return;
    _notaCtrl.text = rep.nota ?? '';
    for (int i = 0; i < rep.cargas.length && i < _numCargas; i++) {
      _cargasCtrls[i].text = rep.cargas[i].carga ?? '';
      for (int j = 0; j < rep.cargas[i].indicaciones.length && j < _numMediciones; j++) {
        _indCtrls[i][j].text = rep.cargas[i].indicaciones[j] ?? '';
        _retCtrls[i][j].text = rep.cargas[i].retornos[j]    ?? '';
      }
    }
    setState(() {});
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateRepetibilidad(RepetibilidadData(
      nota: _notaCtrl.text,
      cargas: List.generate(_numCargas, (i) => CargaRepetibilidad(
        carga: _cargasCtrls[i].text,
        indicaciones: _indCtrls[i].map((c) => c.text.isEmpty ? null : c.text).toList(),
        retornos:     _retCtrls[i].map((c) => c.text.isEmpty ? null : c.text).toList(),
      )),
    ));
  }

  @override
  void dispose() {
    for (final c in _cargasCtrls) c.dispose();
    for (final row in _indCtrls) for (final c in row) c.dispose();
    for (final row in _retCtrls) for (final c in row) c.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text('PRUEBAS DE REPETIBILIDAD',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple[700]),
          ).animate().fadeIn(duration: 600.ms)),
          const SizedBox(height: 24),
          ...List.generate(_numCargas, (i) => _buildCargaCard(i)),
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

  Widget _buildCargaCard(int i) {
    final colors = [Colors.blue, Colors.orange, Colors.green];
    final color  = colors[i % colors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
        color: color.withOpacity(0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Icon(Icons.scale, color: color, size: 18),
              const SizedBox(width: 8),
              Text('CARGA ${i + 1}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 16),
              Expanded(child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _cargasCtrls[i],
                  onChanged: (_) => _saveToProvider(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: InputDecoration(
                    hintText: 'Valor carga (kg)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              // Encabezado
              Row(children: [
                const SizedBox(width: 28),
                _headerCell('N°'),
                _headerCell('Indicación'),
                _headerCell('Retorno'),
              ]),
              const SizedBox(height: 6),
              ...List.generate(_numMediciones, (j) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 28, child: Text('${j + 1}', textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]))),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _numField(_indCtrls[i][j]))),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _numField(_retCtrls[i][j]))),
                ]),
              )),
            ]),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 200 + i * 100)).fadeIn().slideY(begin: 0.2);
  }

  Widget _headerCell(String text) => Expanded(child: Text(text,
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]),
      textAlign: TextAlign.center));

  Widget _numField(TextEditingController ctrl) => TextField(
    controller: ctrl,
    onChanged: (_) => _saveToProvider(),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
    decoration: const InputDecoration(
      isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      border: OutlineInputBorder(),
    ),
  );

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}
