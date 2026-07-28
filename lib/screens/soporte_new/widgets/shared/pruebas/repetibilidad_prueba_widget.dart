// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';

class RepetibilidadPruebaWidget extends StatefulWidget {
  final BalanzaInfo balanza;
  final RepetibilidadData data;
  final ValueChanged<RepetibilidadData> onChanged;
  final int copyTick;

  const RepetibilidadPruebaWidget({
    super.key,
    required this.balanza,
    required this.data,
    required this.onChanged,
    this.copyTick = 0,
  });

  @override
  State<RepetibilidadPruebaWidget> createState() =>
      _RepetibilidadPruebaWidgetState();
}

class _RepetibilidadPruebaWidgetState
    extends State<RepetibilidadPruebaWidget> {
  static const _medicionesOptions = ['3', '5', '10'];

  String? _medicionesCount;
  int _appliedCopyTick = 0;
  final _cargaCtrl = TextEditingController();
  List<TextEditingController> _indCtrls = [];
  List<TextEditingController> _retCtrls = [];

  @override
  void initState() {
    super.initState();
    _appliedCopyTick = widget.copyTick;
    _initFromData();
  }

  @override
  void didUpdateWidget(covariant RepetibilidadPruebaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.copyTick != _appliedCopyTick) {
      _appliedCopyTick = widget.copyTick;
      setState(_initFromData);
    }
  }

  void _initFromData() {
    final rep = widget.data;
    _medicionesCount = null;
    _cargaCtrl.text = rep.cargas.isNotEmpty ? (rep.cargas[0].carga ?? '') : '';
    if (rep.cargas.isNotEmpty) {
      final nMediciones = rep.cargas[0].indicaciones.length.clamp(3, 10);
      _medicionesCount = nMediciones.toString();
      _buildControllers(nMediciones);
      for (int j = 0; j < nMediciones; j++) {
        if (j < rep.cargas[0].indicaciones.length) {
          _indCtrls[j].text = rep.cargas[0].indicaciones[j] ?? '';
        }
        if (j < rep.cargas[0].retornos.length) {
          _retCtrls[j].text = rep.cargas[0].retornos[j] ?? '';
        }
      }
    } else {
      _buildControllers(3);
    }
  }

  void _buildControllers(int nMediciones) {
    for (final c in _indCtrls) { c.dispose(); }
    for (final c in _retCtrls) { c.dispose(); }
    _indCtrls = List.generate(nMediciones, (_) => TextEditingController());
    _retCtrls = List.generate(
        nMediciones, (_) => TextEditingController(text: '0'));
  }

  void _onMedicionesChanged(String? v) {
    final med = int.tryParse(v ?? '3') ?? 3;
    final oldInd = _indCtrls.map((c) => c.text).toList();
    final oldRet = _retCtrls.map((c) => c.text).toList();
    setState(() {
      _medicionesCount = v;
      _buildControllers(med);
    });
    for (int j = 0; j < med && j < oldInd.length; j++) {
      _indCtrls[j].text = oldInd[j];
      _retCtrls[j].text = oldRet[j];
    }
    _emit();
  }

  void _emit() {
    widget.onChanged(RepetibilidadData(
      cargas: [
        CargaRepetibilidad(
          carga: _cargaCtrl.text,
          indicaciones:
              _indCtrls.map((c) => c.text.isEmpty ? null : c.text).toList(),
          retornos:
              _retCtrls.map((c) => c.text.isEmpty ? null : c.text).toList(),
        ),
      ],
    ));
  }

  String _formatValueWithPrecision(String value) {
    final v = double.tryParse(value);
    if (v == null) return value;
    try {
      final d = SuggestionHelper.getDivisionForValue(widget.balanza, v);
      if (d == 0) return value;
      final decimals = SuggestionHelper.getDecimalPlaces(d);
      return v.toStringAsFixed(decimals);
    } catch (_) {
      return value;
    }
  }

  @override
  void dispose() {
    _cargaCtrl.dispose();
    for (final c in _indCtrls) { c.dispose(); }
    for (final c in _retCtrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _medicionesCount,
          decoration: _deco('N° de Mediciones por Carga', isDark),
          hint: Text('Seleccione',
              style: GoogleFonts.inter(
                  color: isDark ? Colors.white54 : Colors.black45)),
          dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          items: _medicionesOptions
              .map((v) => DropdownMenuItem(
                  value: v,
                  child: Text(v,
                      style: GoogleFonts.inter(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A1A)))))
              .toList(),
          onChanged: _onMedicionesChanged,
        ).animate(delay: 100.ms).fadeIn(),
        const SizedBox(height: 20),
        if (_medicionesCount != null) _buildCargaCard(isDark),
      ],
    );
  }

  Widget _buildCargaCard(bool isDark) {
    final nMediciones = int.tryParse(_medicionesCount ?? '3') ?? 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
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
          _sectionHeader('Carga', isDark),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              controller: _cargaCtrl,
              onChanged: (val) {
                final formatted = _formatValueWithPrecision(val);
                for (int j = 0; j < nMediciones; j++) {
                  _indCtrls[j].text = formatted;
                }
                _emit();
                setState(() {});
              },
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              decoration: _deco('Valor de carga', isDark),
            ),
          ),
          if (_cargaCtrl.text.isEmpty) _buildSuggestedLoadChips(isDark),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const SizedBox(width: 30),
              Expanded(
                  child: Text('Indicación',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color:
                              isDark ? Colors.white70 : Colors.grey[600]),
                      textAlign: TextAlign.center)),
              Expanded(
                  child: Text('Retorno',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color:
                              isDark ? Colors.white70 : Colors.grey[600]),
                      textAlign: TextAlign.center)),
            ]),
          ),
          const SizedBox(height: 8),
          ...List.generate(
              nMediciones,
              (j) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Row(children: [
                      SizedBox(
                          width: 30,
                          child: Text('${j + 1}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87))),
                      const SizedBox(width: 8),
                      Expanded(child: _indicationField(j, isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _numField(_retCtrls[j], isDark)),
                    ]),
                  )),
          const SizedBox(height: 12),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  InputDecoration _fieldDecoration(bool isDark, {Widget? suffixIcon}) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      suffixIcon: suffixIcon,
    );
  }

  Widget _indicationField(int medIdx, bool isDark) {
    final hasBase = _cargaCtrl.text.isNotEmpty;
    return TextField(
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _indCtrls[medIdx],
      onChanged: (_) => _emit(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
      decoration: _fieldDecoration(isDark,
        suffixIcon: hasBase
            ? InkWell(
                onTap: () => _showIndicacionSuggestion(medIdx),
                child: const Icon(Icons.unfold_more_rounded,
                    color: Colors.teal, size: 20),
              )
            : null,
      ),
    );
  }

  void _showIndicacionSuggestion(int medIdx) {
    final cargaText = _cargaCtrl.text;
    final cargaValue = double.tryParse(cargaText);
    if (cargaValue == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    SuggestionHelper.showSuggestedValues(
      context: context,
      balanza: widget.balanza,
      baseValue: cargaValue,
      title: 'Indicación - Medición ${medIdx + 1}',
      isDark: isDark,
    ).then((selected) {
      if (selected != null) {
        _indCtrls[medIdx].text = selected;
        _emit();
      }
    });
  }

  Widget _numField(TextEditingController ctrl, bool isDark) => TextField(
        style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
        controller: ctrl,
        onChanged: (_) => _emit(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
        ],
        decoration: _fieldDecoration(isDark),
      );

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
    );
  }

  InputDecoration _deco(String label, bool isDark) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            color: isDark ? Colors.white70 : Colors.black87),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      );

  Widget _buildSuggestedLoadChips(bool isDark) {
    final rangos = SuggestionHelper.getValidCapacities(widget.balanza);
    if (rangos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(rangos.length, (index) {
          final pmax = rangos[index]['capMax']!;
          final d = rangos[index]['d']!;

          final suggested =
              SuggestionHelper.roundToNearestMultiple(pmax * 0.5, d);
          final decimals = SuggestionHelper.getDecimalPlaces(d);
          final formatted = suggested.toStringAsFixed(decimals);
          final unidad = widget.balanza.unidad ?? 'kg';
          final label = rangos.length > 1 ? 'Max${index + 1}' : 'Pmax';

          return GestureDetector(
            onTap: () {
              _cargaCtrl.text = formatted;
              final nMediciones =
                  int.tryParse(_medicionesCount ?? '3') ?? 3;
              for (int j = 0; j < nMediciones; j++) {
                _indCtrls[j].text = formatted;
              }
              _emit();
              setState(() {});
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(isDark ? 0.15 : 0.1),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 14, color: Colors.teal),
                  const SizedBox(width: 4),
                  Text(
                    'Sugerido: $formatted $unidad (50% $label)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    ).animate().fadeIn();
  }
}
