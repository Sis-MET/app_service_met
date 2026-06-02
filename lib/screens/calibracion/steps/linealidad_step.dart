import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';

class LinealidadStep extends StatefulWidget {
  const LinealidadStep({super.key});

  @override
  State<LinealidadStep> createState() => _LinealidadStepState();
}

class _LinealidadStepState extends State<LinealidadStep> {
  static const _metodos = ['Sustitución Directa', 'Método OIML'];
  static const _metCargas = ['Acumulación', 'Sustitución'];

  String? _metodo;
  String? _metodoCarga;
  final _notaCtrl = TextEditingController();

  // Filas de linealidad: [carga, indicacion, retorno]
  List<List<TextEditingController>> _rows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final lin = provider.session?.linealidad;
    if (lin != null) {
      setState(() {
        _metodo = lin.metodo;
        _metodoCarga = lin.metodoCarga;
        _notaCtrl.text = lin.nota ?? '';
        _rows = lin.filas
            .where((f) => f.carga != null || f.indicacion != null)
            .map((f) => [
                  TextEditingController(text: f.carga ?? ''),
                  TextEditingController(text: f.indicacion ?? ''),
                  TextEditingController(text: f.retorno ?? ''),
                ])
            .toList();
      });
    }
    if (_rows.isEmpty) _addRow();
  }

  void _addRow() {
    setState(() => _rows.add([
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ]));
  }

  void _removeRow() {
    if (_rows.length > 1) {
      setState(() {
        final r = _rows.removeLast();
        for (final c in r) {
          c.dispose();
        }
      });
      _saveToProvider();
    }
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateLinealidad(LinealidadData(
      metodo: _metodo,
      metodoCarga: _metodoCarga,
      nota: _notaCtrl.text,
      filas: _rows
          .map((r) => FilaLinealidad(
                carga: r[0].text,
                indicacion: r[1].text,
                retorno: r[2].text,
              ))
          .toList(),
    ));
  }

  @override
  void dispose() {
    for (final r in _rows)
      for (final c in r) {
        c.dispose();
      }
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Text(
            'PRUEBAS DE LINEALIDAD',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[700]),
          ).animate().fadeIn(duration: 600.ms)),
          const SizedBox(height: 24),

          DropdownButtonFormField<String>(
            value: _metodo,
            decoration: _deco('Método de Linealidad'),
            hint: const Text('Seleccione método'),
            items: _metodos
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              setState(() => _metodo = v);
              _saveToProvider();
            },
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _metodoCarga,
            decoration: _deco('Método de Aplicación de Carga'),
            hint: const Text('Seleccione'),
            items: _metCargas
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              setState(() => _metodoCarga = v);
              _saveToProvider();
            },
          ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 24),

          // Tabla
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('FILAS DE MEDICIÓN',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700])),
            Row(children: [
              IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.indigo),
                  onPressed: _addRow),
              IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.indigo),
                  onPressed: _removeRow),
            ]),
          ]),
          const SizedBox(height: 8),
          // Header
          Row(children: [
            const SizedBox(width: 30),
            _hdr('Carga'),
            _hdr('Indicación'),
            _hdr('Retorno'),
          ]),
          const SizedBox(height: 6),
          ...List.generate(
              _rows.length,
              (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                          width: 30,
                          child: Text('${i + 1}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[600]))),
                      Expanded(
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: _numField(_rows[i][0]))),
                      Expanded(
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: _indicationField(i))),
                      Expanded(
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: _numField(_rows[i][2]))),
                    ]),
                  )).animate(delay: 400.ms).fadeIn(),
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

  Widget _indicationField(int i) {
    final hasBase = _rows[i][0].text.isNotEmpty;
    return GestureDetector(
      onTap: hasBase ? () => _showIndicacionSuggestion(i) : null,
      child: AbsorbPointer(
        child: TextField(
          controller: _rows[i][1],
          onChanged: (_) => _saveToProvider(),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
          ],
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            border: const OutlineInputBorder(),
            suffixIcon: hasBase
                ? Icon(Icons.unfold_more_rounded,
                    color: Colors.indigo, size: 20)
                : null,
          ),
        ),
      ),
    );
  }

  void _showIndicacionSuggestion(int rowIdx) {
    final cargaText = _rows[rowIdx][0].text;
    final cargaValue = double.tryParse(cargaText);
    if (cargaValue == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balanza =
        context.read<ServiceSessionProvider>().session?.balanza;
    if (balanza == null) return;

    SuggestionHelper.showSuggestedValues(
      context: context,
      balanza: balanza,
      baseValue: cargaValue,
      title: 'Indicación - Fila ${rowIdx + 1}',
      isDark: isDark,
    ).then((selected) {
      if (selected != null) {
        _rows[rowIdx][1].text = selected;
        _saveToProvider();
      }
    });
  }

  Widget _hdr(String t) => Expanded(
      child: Text(t,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600]),
          textAlign: TextAlign.center));

  Widget _numField(TextEditingController ctrl) => TextField(
        controller: ctrl,
        onChanged: (_) => _saveToProvider(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
        ],
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          border: OutlineInputBorder(),
        ),
      );

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
