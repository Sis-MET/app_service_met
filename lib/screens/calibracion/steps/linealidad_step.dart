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
  static const _metodoCargaOptions = [
    'Sin metodo de carga',
    'Ascenso evaluando a ceros',
    'Ascenso Continuo por pasos',
  ];
  static const _maxPuntos = 60;

  String? _metodoCarga;
  bool _cargasValidadas = false;
  int _cargasPatronValidadas = 0;
  final _notaCtrl = TextEditingController();

  List<TextEditingController> _cargaCtrls = [];
  List<TextEditingController> _indCtrls = [];
  List<TextEditingController> _retCtrls = [];

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
    _metodoCarga = _metodoCargaOptions.contains(lin.metodo)
        ? lin.metodo
        : null;
    _parseValidationState(lin.metodoCarga);

    if (lin.filas.isNotEmpty) {
      _buildControllers(lin.filas.length.clamp(1, _maxPuntos));
      for (int i = 0; i < _cargaCtrls.length; i++) {
        _cargaCtrls[i].text = lin.filas[i].carga ?? '';
        _indCtrls[i].text = lin.filas[i].indicacion ?? '';
        _retCtrls[i].text = (lin.filas[i].retorno?.isNotEmpty ?? false)
            ? lin.filas[i].retorno!
            : '0';
      }
    } else {
      _buildControllers(12);
    }

    if (_cargasValidadas && _cargasPatronValidadas <= 0) {
      _cargasPatronValidadas = _filledPatronRowsCount();
    }

    if (mounted) setState(() {});
  }

  void _parseValidationState(String? raw) {
    _cargasValidadas = false;
    _cargasPatronValidadas = 0;
    if (raw == null) return;

    final match = RegExp(r'cargas_validadas:(\d+)').firstMatch(raw);
    if (match != null) {
      _cargasValidadas = true;
      _cargasPatronValidadas = int.tryParse(match.group(1) ?? '') ?? 0;
      return;
    }

    if (raw.contains('Metodo') || raw.contains('validada')) {
      _cargasValidadas = true;
    }
  }

  String get _validationStateForSave => _cargasValidadas
      ? 'cargas_validadas:$_cargasPatronValidadas'
      : 'validacion_pesas_pendiente';

  void _buildControllers(int count) {
    for (final c in _cargaCtrls) {
      c.dispose();
    }
    for (final c in _indCtrls) {
      c.dispose();
    }
    for (final c in _retCtrls) {
      c.dispose();
    }

    _cargaCtrls = List.generate(count, (_) => TextEditingController());
    _indCtrls = List.generate(count, (_) => TextEditingController());
    _retCtrls = List.generate(count, (_) => TextEditingController(text: '0'));
  }

  void _onMetodoCargaChanged(String? v) {
    setState(() => _metodoCarga = v);
    _saveToProvider();
  }

  void _addRow() {
    if (_cargaCtrls.length >= _maxPuntos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximo 60 puntos permitidos')),
      );
      return;
    }

    setState(() {
      _cargaCtrls.add(TextEditingController());
      _indCtrls.add(TextEditingController());
      _retCtrls.add(TextEditingController(text: '0'));
    });
  }

  void _removeRow() {
    if (_cargaCtrls.length <= 1) return;

    setState(() {
      _cargaCtrls.removeLast().dispose();
      _indCtrls.removeLast().dispose();
      _retCtrls.removeLast().dispose();
      if (_cargasPatronValidadas > _cargaCtrls.length) {
        _cargasPatronValidadas = _cargaCtrls.length;
      }
      if (_cargasPatronValidadas == 0) _cargasValidadas = false;
    });
    _saveToProvider();
  }

  void _onCargaChanged(int i, String val) {
    if (!_cargasValidadas || i < _cargasPatronValidadas) {
      _indCtrls[i].text = _formatValueWithPrecision(val);
    }
    _saveToProvider();
    setState(() {});
  }

  void _onIndicacionChanged(int i, String val) {
    _saveToProvider();
    setState(() {});
  }

  void _onRetornoChanged() {
    _saveToProvider();
    setState(() {});
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

  String _errorText(int i) {
    final cargaReal = double.tryParse(_cargaCtrls[i].text);
    final indicacion = double.tryParse(_indCtrls[i].text);
    if (cargaReal == null || indicacion == null) return '';
    return _fmt(indicacion - cargaReal);
  }

  int _filledPatronRowsCount() {
    int count = 0;
    for (int i = 0; i < _cargaCtrls.length; i++) {
      final hasCarga = _cargaCtrls[i].text.trim().isNotEmpty;
      final hasInd = _indCtrls[i].text.trim().isNotEmpty;
      if (hasCarga && hasInd) count = i + 1;
    }
    return count;
  }

  void _validatePatronLoads() {
    final count = _filledPatronRowsCount();
    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registre al menos una carga patron con indicacion.'),
        ),
      );
      return;
    }

    setState(() {
      _cargasValidadas = true;
      _cargasPatronValidadas = count;
    });
    _saveToProvider();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cargas patron validadas: $count')),
    );
  }

  void _resetValidation() {
    setState(() {
      _cargasValidadas = false;
      _cargasPatronValidadas = 0;
    });
    _saveToProvider();
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateLinealidad(LinealidadData(
      metodo: _metodoCarga,
      metodoCarga: _validationStateForSave,
      nota: _notaCtrl.text,
      filas: List.generate(_cargaCtrls.length, (i) {
        return FilaLinealidad(
          carga: _cargaCtrls[i].text,
          indicacion: _indCtrls[i].text,
          retorno: _retCtrls[i].text.isEmpty ? '0' : _retCtrls[i].text,
        );
      }),
    ));
  }

  @override
  void dispose() {
    for (final c in _cargaCtrls) {
      c.dispose();
    }
    for (final c in _indCtrls) {
      c.dispose();
    }
    for (final c in _retCtrls) {
      c.dispose();
    }
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
                decoration: _deco('Metodo de Carga', isDark),
                hint: Text('Seleccione',
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white54 : Colors.black45)),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: _metodoCargaOptions
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v,
                              style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A))),
                        ))
                    .toList(),
                onChanged: _onMetodoCargaChanged,
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 16),
              if (_metodoCarga != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _metodoCarga == 'Sin metodo de carga'
                        ? 'Registro sin metodo de carga definido.'
                        : _metodoCarga == 'Ascenso evaluando a ceros'
                            ? 'El ensayo retorna a cero despues de cada medicion.'
                            : 'El ensayo aplica carga de forma continua sin retornos intermedios.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ).animate(delay: 250.ms).fadeIn(),
                ),
              if (_metodoCarga != null) ...[
                _buildValidationHelp(isDark),
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
          'Registro de cargas patron y cargas sustitutivas',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildValidationHelp(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withOpacity(0.08)
            : Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.teal.withOpacity(0.3)
              : Colors.teal.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _cargasValidadas
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: Colors.teal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _cargasValidadas
                  ? 'Cargas patron validadas: $_cargasPatronValidadas. Ya puede agregar cargas sustitutivas usando el asistente.'
                  : 'Primero registre y revise las cargas de sus pesas patron. Cuando termine, pulse Validar cargas para habilitar el calculo de cargas sustitutivas.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn();
  }

  Widget _buildPuntosSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader('Puntos de Calibracion', isDark),
            Wrap(
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: Colors.teal, size: 22),
                  onPressed: _addRow,
                  tooltip: 'Agregar fila',
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: Colors.teal, size: 22),
                  onPressed: _removeRow,
                  tooltip: 'Eliminar ultima fila',
                ),
                if (_cargasValidadas)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.teal, size: 22),
                    onPressed: _resetValidation,
                    tooltip: 'Volver a validar cargas',
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _cargasValidadas ? null : _validatePatronLoads,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Validar cargas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cargasValidadas ? _showCargaSustitutivaSheet : null,
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Carga sustitutiva'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          children: List.generate(
            _cargaCtrls.length,
            (i) => _buildPuntoRows(i, isDark),
          ),
        ).animate(delay: 400.ms).fadeIn(),
      ],
    );
  }

  Widget _buildPuntoRows(int i, bool isDark) {
    final isSustitutiva = _cargasValidadas && i >= _cargasPatronValidadas;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Carga ${i + 1}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              if (isSustitutiva) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Sustitutiva',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Divider(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _cargaField(i, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _indicationField(i, isDark)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _retornoField(i, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _errorField(i, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    bool isDark, {
    String? labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: labelText,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
    );
  }

  Widget _cargaField(int i, bool isDark) {
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _cargaCtrls[i],
      onChanged: (val) => _onCargaChanged(i, val),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      decoration: _fieldDecoration(isDark, labelText: 'Carga real'),
    );
  }

  Widget _indicationField(int i, bool isDark) {
    final hasBase = _cargaCtrls[i].text.isNotEmpty;
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _indCtrls[i],
      onChanged: (val) => _onIndicacionChanged(i, val),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
      decoration: _fieldDecoration(
        isDark,
        labelText: 'Indicacion',
        suffixIcon: hasBase
            ? InkWell(
                onTap: () => _showIndicacionSuggestion(i),
                child: const Icon(Icons.unfold_more_rounded,
                    color: Colors.teal, size: 20),
              )
            : null,
      ),
    );
  }

  Widget _retornoField(int i, bool isDark) {
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _retCtrls[i],
      onChanged: (_) => _onRetornoChanged(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
      decoration: _fieldDecoration(isDark, labelText: 'Retorno a cero'),
    );
  }

  Widget _errorField(int i, bool isDark) {
    final error = _errorText(i);
    return InputDecorator(
      decoration: _fieldDecoration(isDark, labelText: 'Error'),
      child: Text(
        error.isEmpty ? '-' : error,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
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
      title: 'Indicacion - Punto ${rowIdx + 1}',
      isDark: isDark,
    ).then((selected) {
      if (selected != null) {
        _indCtrls[rowIdx].text = selected;
        _onIndicacionChanged(rowIdx, selected);
      }
    });
  }

  void _showCargaSustitutivaSheet() {
    if (!_cargasValidadas || _cargasPatronValidadas <= 0) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indicacionCtrl = TextEditingController();
    final validatedLoads = _referenceLoads();
    final baseLoads = _baseLoads();
    if (validatedLoads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cargas patron validas para usar.'),
        ),
      );
      indicacionCtrl.dispose();
      return;
    }
    if (baseLoads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cargas base validadas para sumar.'),
        ),
      );
      indicacionCtrl.dispose();
      return;
    }
    int selectedBaseIndex = baseLoads.last.index;
    int selectedLoadIndex = validatedLoads.last.index;
    bool referenceSelectedManually = false;

    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final indicacion = double.tryParse(indicacionCtrl.text) ?? 0.0;
            final selectedLoad = validatedLoads.firstWhere(
              (load) => load.index == selectedLoadIndex,
              orElse: () => validatedLoads.last,
            );
            final selectedBase = baseLoads.firstWhere(
              (load) => load.index == selectedBaseIndex,
              orElse: () => baseLoads.last,
            );
            final patronCarga = selectedLoad.carga;
            final patronError = selectedLoad.error;
            final cargaRealSustitutiva = indicacion - patronError;
            final acumulado = selectedBase.carga + cargaRealSustitutiva;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(isDark),
                  _sheetTitle('Carga sustitutiva', isDark),
                  const SizedBox(height: 8),
                  Text(
                    'Ingrese la indicacion obtenida con la carga sustitutiva. Elija la carga base que se sumara; el error se toma de la referencia mas cercana a la indicacion.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedBaseIndex,
                    decoration: _deco('Carga base para sumar', isDark),
                    dropdownColor:
                        isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    selectedItemBuilder: (context) => baseLoads
                        .map(
                          (load) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Carga ${load.index + 1}: ${_fmt(load.carga)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: baseLoads
                        .map(
                          (load) => DropdownMenuItem(
                            value: load.index,
                            child: Text(
                              'Carga ${load.index + 1}: ${_fmt(load.carga)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => selectedBaseIndex = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedLoadIndex,
                    decoration:
                        _deco('Carga de referencia para correccion', isDark),
                    dropdownColor:
                        isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    selectedItemBuilder: (context) => validatedLoads
                        .map(
                          (load) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Carga ${load.index + 1}: ${_fmt(load.carga)} | Err ${_fmt(load.error)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: validatedLoads
                        .map(
                          (load) => DropdownMenuItem(
                            value: load.index,
                            child: Text(
                              'Carga ${load.index + 1}: ${_fmt(load.carga)} | Ind ${_fmt(load.indicacion)} | Error ${_fmt(load.error)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selectedLoadIndex = value;
                        referenceSelectedManually = true;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _sheetNumberField(
                    controller: indicacionCtrl,
                    label: 'Indicacion carga sustitutiva',
                    isDark: isDark,
                    onChanged: (value) {
                      final reference = double.tryParse(value);
                      setSheetState(() {
                        if (!referenceSelectedManually && reference != null) {
                          selectedLoadIndex =
                              _nearestReferenceLoad(reference, validatedLoads)
                                  .index;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _sheetResult(
                    'Carga base a sumar: ${_fmt(selectedBase.carga)}\n'
                    'Referencia elegida: ${_fmt(patronCarga)}\n'
                    'Error referencia: ${_fmt(patronError)}\n'
                    'Carga real sustitutiva: ${_fmt(cargaRealSustitutiva)}\n'
                    'Carga acumulada a registrar: ${_fmt(acumulado)}',
                    isDark,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: indicacionCtrl.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(ctx, _fmt(acumulado)),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Guardar carga sustitutiva'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null) _appendSustitutiveRow(selected);
    });
  }

  void _appendSustitutiveRow(String carga) {
    final targetIndex = _firstEmptyRowFrom(_cargasPatronValidadas);
    if (targetIndex == null && _cargaCtrls.length >= _maxPuntos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximo 60 puntos permitidos')),
      );
      return;
    }

    final formattedCarga = _formatValueWithPrecision(carga);
    setState(() {
      if (targetIndex != null) {
        _cargaCtrls[targetIndex].text = formattedCarga;
        _indCtrls[targetIndex].clear();
        _retCtrls[targetIndex].text = '0';
      } else {
        _cargaCtrls.add(TextEditingController(text: formattedCarga));
        _indCtrls.add(TextEditingController());
        _retCtrls.add(TextEditingController(text: '0'));
      }
    });
    _saveToProvider();
  }

  int? _firstEmptyRowFrom(int startIndex) {
    for (int i = startIndex; i < _cargaCtrls.length; i++) {
      final hasCarga = _cargaCtrls[i].text.trim().isNotEmpty;
      final hasInd = _indCtrls[i].text.trim().isNotEmpty;
      if (!hasCarga && !hasInd) return i;
    }
    return null;
  }

  List<_ValidatedLoad> _referenceLoads() {
    final loads = <_ValidatedLoad>[];
    for (int i = 0; i < _cargaCtrls.length; i++) {
      final carga = double.tryParse(_cargaCtrls[i].text);
      final indicacion = double.tryParse(_indCtrls[i].text);
      if (carga == null || indicacion == null) continue;
      loads.add(_ValidatedLoad(
        index: i,
        carga: carga,
        indicacion: indicacion,
        error: indicacion - carga,
      ));
    }
    return loads;
  }

  List<_ValidatedLoad> _baseLoads() {
    final loads = <_ValidatedLoad>[];
    for (int i = 0; i < _cargaCtrls.length; i++) {
      final carga = double.tryParse(_cargaCtrls[i].text);
      final indicacion = double.tryParse(_indCtrls[i].text);
      if (carga == null) continue;
      loads.add(_ValidatedLoad(
        index: i,
        carga: carga,
        indicacion: indicacion ?? carga,
        error: indicacion == null ? 0 : indicacion - carga,
      ));
    }
    return loads;
  }

  _ValidatedLoad _nearestReferenceLoad(
    double reference,
    List<_ValidatedLoad> loads,
  ) {
    _ValidatedLoad nearest = loads.first;
    for (final load in loads.skip(1)) {
      if ((reference - load.indicacion).abs() <
          (reference - nearest.indicacion).abs()) {
        nearest = load;
      }
    }
    return nearest;
  }

  Widget _sheetHandle(bool isDark) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white24 : Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sheetTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _sheetNumberField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
      decoration: _deco(label, isDark),
    );
  }

  Widget _sheetResult(String text, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withOpacity(0.12)
            : Colors.teal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: GoogleFonts.robotoMono(
          fontSize: 13,
          height: 1.5,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
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

class _ValidatedLoad {
  final int index;
  final double carga;
  final double indicacion;
  final double error;

  const _ValidatedLoad({
    required this.index,
    required this.carga,
    required this.indicacion,
    required this.error,
  });
}
