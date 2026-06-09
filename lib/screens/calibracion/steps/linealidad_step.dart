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
  static const _metodoCargaOptions = ['Ascenso evaluando a ceros', 'Ascenso Continuo por pasos'];
  static const _metodoSustOptions = ['Método 1', 'Método 2'];
  static const _maxPatron = 500.0;

  String? _metodoCarga;
  String? _metodoSust;
  final _notaCtrl = TextEditingController();

  List<TextEditingController> _cargaCtrls = [];
  List<TextEditingController> _masaPatronCtrls = [];
  List<TextEditingController> _cargaSustCtrls = [];
  List<TextEditingController> _indCtrls = [];
  List<TextEditingController> _retCtrls = [];
  List<TextEditingController> _errorCtrls = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final lin = provider.session?.linealidad;
    if (lin == null) return;
    _notaCtrl.text = lin.nota ?? '';
    _metodoCarga = lin.metodo;
    _metodoSust = lin.metodoCarga;
    if (lin.filas.isNotEmpty) {
      _buildControllers(lin.filas.length);
      for (int i = 0; i < lin.filas.length; i++) {
        _cargaCtrls[i].text = lin.filas[i].carga ?? '';
        _masaPatronCtrls[i].text = lin.filas[i].masaPatron ?? '';
        _cargaSustCtrls[i].text = lin.filas[i].cargaSustitutiva ?? '';
        _indCtrls[i].text = lin.filas[i].indicacion ?? '';
        _retCtrls[i].text = lin.filas[i].retorno ?? '';
        _errorCtrls[i].text = lin.filas[i].error ?? '';
      }
    } else {
      _buildControllers(12);
    }
  }

  void _buildControllers(int count) {
    for (final c in _cargaCtrls) { c.dispose(); }
    for (final c in _masaPatronCtrls) { c.dispose(); }
    for (final c in _cargaSustCtrls) { c.dispose(); }
    for (final c in _indCtrls) { c.dispose(); }
    for (final c in _retCtrls) { c.dispose(); }
    for (final c in _errorCtrls) { c.dispose(); }

    _cargaCtrls = List.generate(count, (_) => TextEditingController());
    _masaPatronCtrls = List.generate(count, (_) => TextEditingController());
    _cargaSustCtrls = List.generate(count, (_) => TextEditingController());
    _indCtrls = List.generate(count, (_) => TextEditingController());
    _retCtrls = List.generate(count, (_) => TextEditingController(text: '0'));
    _errorCtrls = List.generate(count, (_) => TextEditingController());
  }

  void _onMetodoCargaChanged(String? v) {
    setState(() => _metodoCarga = v);
    _saveToProvider();
  }

  void _onMetodoSustChanged(String? v) {
    setState(() => _metodoSust = v);
    _saveToProvider();
  }

  void _addRow() {
    setState(() {
      _cargaCtrls.add(TextEditingController());
      _masaPatronCtrls.add(TextEditingController());
      _cargaSustCtrls.add(TextEditingController());
      _indCtrls.add(TextEditingController());
      _retCtrls.add(TextEditingController(text: '0'));
      _errorCtrls.add(TextEditingController());
    });
  }

  void _removeRow() {
    if (_cargaCtrls.length > 1) {
      setState(() {
        _cargaCtrls.removeLast().dispose();
        _masaPatronCtrls.removeLast().dispose();
        _cargaSustCtrls.removeLast().dispose();
        _indCtrls.removeLast().dispose();
        _retCtrls.removeLast().dispose();
        _errorCtrls.removeLast().dispose();
      });
      _saveToProvider();
    }
  }

  void _onCargaChanged(int i, String val) {
    final objetivo = double.tryParse(val) ?? 0.0;
    final masaPatron = objetivo < _maxPatron ? objetivo : _maxPatron;
    final cargaSust = objetivo > _maxPatron ? objetivo - _maxPatron : 0.0;

    _masaPatronCtrls[i].text = _fmt(masaPatron);
    _cargaSustCtrls[i].text = _fmt(cargaSust);
    _indCtrls[i].text = _formatValueWithPrecision(val);

    _recalcError(i);
    _saveToProvider();
  }

  void _onIndicacionChanged(int i, String val) {
    _recalcError(i);
    _saveToProvider();
  }

  void _recalcError(int i) {
    final indicacion = double.tryParse(_indCtrls[i].text) ?? 0.0;
    final masaPatron = double.tryParse(_masaPatronCtrls[i].text) ?? 0.0;
    final cargaSust = double.tryParse(_cargaSustCtrls[i].text) ?? 0.0;
    final error = indicacion - (masaPatron + cargaSust);
    _errorCtrls[i].text = error.toStringAsFixed(2);
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _formatValueWithPrecision(String value) {
    final v = double.tryParse(value);
    if (v == null) return value;
    try {
      final balanza = context.read<ServiceSessionProvider>().session?.balanza;
      if (balanza == null) return value;
      final d = SuggestionHelper.getDivisionForValue(balanza, v);
      if (d == 0) return value;
      final decimals = SuggestionHelper.getDecimalPlaces(d);
      return v.toStringAsFixed(decimals);
    } catch (_) {
      return value;
    }
  }

  void _saveToProvider() {
    final n = _cargaCtrls.length;
    final provider = context.read<ServiceSessionProvider>();
    provider.updateLinealidad(LinealidadData(
      metodo: _metodoCarga,
      metodoCarga: _metodoSust,
      nota: _notaCtrl.text,
      filas: List.generate(n, (i) => FilaLinealidad(
        carga: _cargaCtrls[i].text,
        masaPatron: _masaPatronCtrls[i].text,
        cargaSustitutiva: _cargaSustCtrls[i].text,
        metodSustitucion: _metodoSust,
        indicacion: _indCtrls[i].text,
        retorno: _retCtrls[i].text,
        error: _errorCtrls[i].text,
      )),
    ));
  }

  @override
  void dispose() {
    for (final c in _cargaCtrls) { c.dispose(); }
    for (final c in _masaPatronCtrls) { c.dispose(); }
    for (final c in _cargaSustCtrls) { c.dispose(); }
    for (final c in _indCtrls) { c.dispose(); }
    for (final c in _retCtrls) { c.dispose(); }
    for (final c in _errorCtrls) { c.dispose(); }
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: _metodoCarga,
                decoration: _deco('Método de Carga', isDark),
                hint: Text('Seleccione',
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white54 : Colors.black45)),
                dropdownColor:
                    isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: _metodoCargaOptions
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v,
                            style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A)))))
                    .toList(),
                onChanged: _onMetodoCargaChanged,
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 16),

              if (_metodoCarga != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _metodoCarga == 'Ascenso evaluando a ceros'
                        ? 'El ensayo retorna a cero después de cada medición.'
                        : 'El ensayo aplica carga de forma continua sin retornos intermedios.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ).animate(delay: 250.ms).fadeIn(),
                ),

              DropdownButtonFormField<String>(
                value: _metodoSust,
                decoration: _deco('Método de Cargas Sustitutivas', isDark),
                hint: Text('Seleccione',
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white54 : Colors.black45)),
                dropdownColor:
                    isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: _metodoSustOptions
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v,
                            style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A)))))
                    .toList(),
                onChanged: _onMetodoSustChanged,
              ).animate(delay: 300.ms).fadeIn(),
              const SizedBox(height: 16),

              if (_metodoSust != null) _buildSustitucionHelp(isDark),

              if (_metodoCarga != null && _metodoSust != null) ...[
                const SizedBox(height: 8),
                _buildPuntosSection(isDark),
                const SizedBox(height: 20),
              ],

              TextField(
                style: GoogleFonts.inter(
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                controller: _notaCtrl,
                onChanged: (_) => _saveToProvider(),
                maxLines: 3,
                decoration: _deco('Nota / Comentario (opcional)', isDark),
              ).animate(delay: 600.ms).fadeIn(),
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
          'Pruebas de Linealidad',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Registro de ensayos de linealidad con cargas sustitutivas',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildSustitucionHelp(bool isDark) {
    final isMetodo1 = _metodoSust == 'Método 1';
    final title = isMetodo1 ? 'Método 1 — Sustitución Única' : 'Método 2 — Sustituciones Sucesivas';
    final desc = isMetodo1
        ? 'Para cada punto que supere los $_maxPatron kg de masa patrón, la carga sustitutiva se calcula como:\n\n'
            '    Carga Sustitutiva = Carga Objetivo − $_maxPatron kg\n\n'
            'Ejemplo: Para 700 kg → Masa Patrón = 500 kg + Carga Sustitutiva = 200 kg\n'
            'Cada sustitución es independiente del punto anterior.'
        : 'Cada nuevo punto de calibración parte de la sustitución acumulada del punto anterior:\n\n'
            'Paso 1: Cargue $_maxPatron kg de masa patrón.\n'
            'Paso 2: Reemplace las masas patrón por material de sustitución hasta obtener la misma indicación.\n'
            'Paso 3: Agregue masa patrón sobre la sustitución para alcanzar el siguiente punto.\n'
            'Repita el proceso para cada punto sucesivo.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withOpacity(0.08)
            : Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.teal.withOpacity(0.3) : Colors.teal.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 18, color: Colors.teal),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
          ]),
          const SizedBox(height: 10),
          Text(desc,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    ).animate(delay: 350.ms).fadeIn();
  }

  Widget _buildPuntosSection(bool isDark) {
    final showRetorno = _metodoCarga == 'Ascenso evaluando a ceros';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader('Puntos de Calibración', isDark),
            Row(children: [
              IconButton(
                icon: Icon(Icons.add_circle_outline_rounded,
                    color: Colors.teal, size: 22),
                onPressed: _addRow,
                tooltip: 'Agregar fila',
              ),
              IconButton(
                icon: Icon(Icons.remove_circle_outline_rounded,
                    color: Colors.teal, size: 22),
                onPressed: _removeRow,
                tooltip: 'Eliminar última fila',
              ),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  const SizedBox(width: 30),
                  Expanded(flex: 2, child: _headerText('Carga\nObjetivo', isDark)),
                  Expanded(flex: 2, child: _headerText('Masa\nPatrón', isDark)),
                  Expanded(flex: 2, child: _headerText('Carga\nSust.', isDark)),
                  Expanded(flex: 2, child: _headerText('Indicación', isDark)),
                  if (showRetorno)
                    Expanded(flex: 2, child: _headerText('Retorno', isDark)),
                  Expanded(flex: 2, child: _headerText('Error', isDark)),
                ]),
              ),
              const SizedBox(height: 4),
              ...List.generate(
                  _cargaCtrls.length,
                  (i) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        child: Row(children: [
                          SizedBox(
                              width: 30,
                              child: Text('${i + 1}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87))),
                          Expanded(
                              flex: 2,
                              child: _cargaField(i, isDark)),
                          Expanded(
                              flex: 2,
                              child: _readonlyField(
                                  _masaPatronCtrls[i], isDark)),
                          Expanded(
                              flex: 2,
                              child: _readonlyField(
                                  _cargaSustCtrls[i], isDark)),
                          Expanded(
                              flex: 2,
                              child: _indicationField(i, isDark)),
                          if (showRetorno)
                            Expanded(
                                flex: 2,
                                child: _retornoField(i, isDark)),
                          Expanded(
                              flex: 2,
                              child: _readonlyField(
                                  _errorCtrls[i], isDark)),
                        ]),
                      )),
              const SizedBox(height: 12),
            ],
          ),
        ).animate(delay: 400.ms).fadeIn(),
      ],
    );
  }

  Widget _headerText(String text, bool isDark) {
    return Text(text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.3,
            color: isDark ? Colors.white70 : Colors.grey[600]));
  }

  InputDecoration _fieldDecoration(bool isDark, {Widget? suffixIcon}) {
    return InputDecoration(
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      suffixIcon: suffixIcon,
    );
  }

  Widget _cargaField(int i, bool isDark) {
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _cargaCtrls[i],
      onChanged: (val) => _onCargaChanged(i, val),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      decoration: _fieldDecoration(isDark),
    );
  }

  Widget _readonlyField(TextEditingController ctrl, bool isDark) {
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? Colors.white38 : Colors.black45),
      controller: ctrl,
      readOnly: true,
      decoration: _fieldDecoration(isDark),
    );
  }

  Widget _indicationField(int i, bool isDark) {
    final hasBase = _cargaCtrls[i].text.isNotEmpty;
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _indCtrls[i],
      onChanged: (val) => _onIndicacionChanged(i, val),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
      decoration: _fieldDecoration(isDark,
        suffixIcon: hasBase
            ? InkWell(
                onTap: () => _showIndicacionSuggestion(i),
                child: Icon(Icons.unfold_more_rounded,
                    color: Colors.teal, size: 18),
              )
            : null,
      ),
    );
  }

  Widget _retornoField(int i, bool isDark) {
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _retCtrls[i],
      onChanged: (_) => _saveToProvider(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
      decoration: _fieldDecoration(isDark),
    );
  }

  void _showIndicacionSuggestion(int rowIdx) {
    final cargaText = _cargaCtrls[rowIdx].text;
    final cargaValue = double.tryParse(cargaText);
    if (cargaValue == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balanza = context.read<ServiceSessionProvider>().session?.balanza;
    if (balanza == null) return;

    SuggestionHelper.showSuggestedValues(
      context: context,
      balanza: balanza,
      baseValue: cargaValue,
      title: 'Indicación - Punto ${rowIdx + 1}',
      isDark: isDark,
    ).then((selected) {
      if (selected != null) {
        _indCtrls[rowIdx].text = selected;
        _onIndicacionChanged(rowIdx, selected);
      }
    });
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
    );
  }

  InputDecoration _deco(String label, bool isDark) => InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      );
}
