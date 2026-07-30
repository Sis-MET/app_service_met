// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';

class ExcentricidadBasculaWidget extends StatefulWidget {
  final BalanzaInfo balanza;
  final ExcentricidadData data;
  final ValueChanged<ExcentricidadData> onChanged;
  final int copyTick;

  const ExcentricidadBasculaWidget({
    super.key,
    required this.balanza,
    required this.data,
    required this.onChanged,
    this.copyTick = 0,
  });

  @override
  State<ExcentricidadBasculaWidget> createState() =>
      _ExcentricidadBasculaWidgetState();
}

class _ExcentricidadBasculaWidgetState
    extends State<ExcentricidadBasculaWidget> {
  static const _puntosOptions = [2, 4, 6, 8, 10];

  int? _selectedPuntos;
  final _cargaCtrl = TextEditingController();

  // Cada fila: [indicación, retorno]
  final List<List<TextEditingController>> _rows = [];
  int _appliedCopyTick = 0;

  @override
  void initState() {
    super.initState();
    _appliedCopyTick = widget.copyTick;
    _initFromData();
  }

  @override
  void didUpdateWidget(covariant ExcentricidadBasculaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.copyTick != _appliedCopyTick) {
      _appliedCopyTick = widget.copyTick;
      setState(_initFromData);
    }
  }

  void _initFromData() {
    final exc = widget.data;
    _selectedPuntos = int.tryParse(exc.puntosIndicacion ?? '');
    _cargaCtrl.text = exc.carga ?? '';
    _rows.clear();
    for (final p in exc.posiciones) {
      _rows.add([
        TextEditingController(text: p.indicacion ?? ''),
        TextEditingController(text: p.retorno ?? '0'),
      ]);
    }
    if (_rows.isEmpty && _selectedPuntos != null && _selectedPuntos! > 0) {
      _buildPositions(_selectedPuntos!);
    }
  }

  void _onPuntosChanged(int? v) {
    if (v == null) return;
    setState(() {
      _selectedPuntos = v;
      _buildPositions(v);
    });
    if (_cargaCtrl.text.isNotEmpty) _reflectCarga();
    _emit();
  }

  void _buildPositions(int total) {
    for (final row in _rows) {
      for (final c in row) c.dispose();
    }
    _rows.clear();
    final half = total ~/ 2;
    for (int i = 1; i <= half; i++) {
      _rows.add([
        TextEditingController(text: _cargaCtrl.text),
        TextEditingController(text: '0'),
      ]);
    }
    for (int i = half; i >= 1; i--) {
      _rows.add([
        TextEditingController(text: _cargaCtrl.text),
        TextEditingController(text: '0'),
      ]);
    }
  }

  void _reflectCarga() {
    final v = _formatWithPrecision(_cargaCtrl.text);
    for (final row in _rows) row[0].text = v;
  }

  String _formatWithPrecision(String value) {
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

  void _emit() {
    final half = _selectedPuntos != null ? _selectedPuntos! ~/ 2 : 0;
    final posiciones = <PosicionData>[];
    for (int i = 0; i < _rows.length; i++) {
      final label = i < half ? 'Ida ${i + 1}' : 'Vuelta ${_rows.length - i}';
      posiciones.add(PosicionData(
        posicion: label,
        indicacion: _rows[i][0].text,
        retorno: _rows[i][1].text,
      ));
    }
    widget.onChanged(ExcentricidadData(
      tipoPlataforma: 'Báscula de camión',
      puntosIndicacion: _selectedPuntos?.toString(),
      carga: _cargaCtrl.text,
      posiciones: posiciones,
    ));
  }

  @override
  void dispose() {
    _cargaCtrl.dispose();
    for (final row in _rows) {
      for (final c in row) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final half = _selectedPuntos != null ? _selectedPuntos! ~/ 2 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(isDark),
        const SizedBox(height: 16),
        _puntosDropdown(isDark),
        const SizedBox(height: 16),
        _cargaField(isDark),
        if (_cargaCtrl.text.isEmpty) _buildSuggestedLoadChips(isDark),
        const SizedBox(height: 24),
        if (_selectedPuntos != null && _selectedPuntos! > 0) ...[
          _buildDiagram(half, isDark),
          const SizedBox(height: 24),
          _sectionHeader('Posiciones', isDark),
          const SizedBox(height: 8),
          _buildColumnHeaders(isDark),
          const SizedBox(height: 4),
          ...List.generate(_rows.length, (i) => _buildRow(i, half, isDark))
              .animate(delay: 300.ms)
              .fadeIn(),
        ],
      ],
    );
  }

  Widget _buildTitle(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.local_shipping,
              size: 20, color: Colors.blue),
        ),
        const SizedBox(width: 12),
        Text(
          'Excentricidad — Báscula de camión',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _puntosDropdown(bool isDark) {
    return DropdownButtonFormField<int>(
      value: _selectedPuntos,
      decoration: _deco('Cantidad de Puntos', isDark),
      hint: Text('Seleccione',
          style: GoogleFonts.inter(
              color: isDark ? Colors.white54 : Colors.black45)),
      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      items: _puntosOptions
          .map((v) => DropdownMenuItem(
              value: v,
              child: Text(
                  '$v puntos (${v ~/ 2} Ida / ${v ~/ 2} Vuelta)',
                  style: GoogleFonts.inter(
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A1A)))))
          .toList(),
      onChanged: _onPuntosChanged,
    ).animate(delay: 100.ms).fadeIn();
  }

  Widget _cargaField(bool isDark) {
    return TextField(
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _cargaCtrl,
      onChanged: (_) {
        _reflectCarga();
        _emit();
        setState(() {});
      },
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      decoration: _deco('Carga aplicada', isDark),
    ).animate(delay: 200.ms).fadeIn();
  }

  Widget _buildSuggestedLoadChips(bool isDark) {
    final rangos = SuggestionHelper.getValidCapacities(widget.balanza);
    if (rangos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(rangos.length, (index) {
          final pmax = rangos[index]['capMax']!;
          final d = rangos[index]['d']!;
          final suggested =
              SuggestionHelper.roundToNearestMultiple(pmax / 3, d);
          final decimals = SuggestionHelper.getDecimalPlaces(d);
          final formatted = suggested.toStringAsFixed(decimals);
          final unidad = widget.balanza.unidad ?? 'kg';
          final label = rangos.length > 1 ? 'Max${index + 1}' : 'Pmax';

          return GestureDetector(
            onTap: () {
              _cargaCtrl.text = formatted;
              _reflectCarga();
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
                    'Sugerido: $formatted $unidad (⅓ $label)',
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

  Widget _buildDiagram(int half, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Text('ESQUEMA DE PLATAFORMA',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.black45,
              )),
          const SizedBox(height: 16),
          // Ida row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('IDA',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.indigo)),
              const SizedBox(width: 12),
              ...List.generate(half, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildDot(i + 1, Colors.indigo),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: isDark ? Colors.white12 : Colors.grey[300]),
          const SizedBox(height: 10),
          // Vuelta row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('VUELTA',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.green)),
              const SizedBox(width: 12),
              ...List.generate(half, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildDot(half - i, Colors.green),
                );
              }),
            ],
          ),
        ],
      ),
    ).animate(delay: 150.ms).fadeIn();
  }

  Widget _buildDot(int number, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildColumnHeaders(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Row(
        children: [
          Expanded(
              child: Text('Indicación',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[600]),
                  textAlign: TextAlign.center)),
          Expanded(
              child: Text('Retorno',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[600]),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildRow(int i, int half, bool isDark) {
    final label = i < half ? 'Ida ${i + 1}' : 'Vuelta ${_rows.length - i}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(
                color: i < half
                    ? Colors.indigo.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: i < half ? Colors.indigo : Colors.green),
                  textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: _indicationField(i, isDark)),
          const SizedBox(width: 4),
          Expanded(child: _numField(_rows[i][1], isDark)),
        ],
      ),
    );
  }

  Widget _indicationField(int i, bool isDark) {
    final hasCarga = _cargaCtrl.text.isNotEmpty;
    return TextField(
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _rows[i][0],
      onChanged: (_) => _emit(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.black26)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12)),
        suffixIcon: hasCarga
            ? InkWell(
                onTap: () => _showIndicacionSuggestion(i),
                child: const Icon(Icons.unfold_more_rounded,
                    color: Colors.teal, size: 20),
              )
            : null,
      ),
    );
  }

  void _showIndicacionSuggestion(int index) {
    final cargaText = _cargaCtrl.text;
    final cargaValue = double.tryParse(cargaText);
    if (cargaValue == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    SuggestionHelper.showSuggestedValues(
      context: context,
      balanza: widget.balanza,
      baseValue: cargaValue,
      title: 'Indicación',
      isDark: isDark,
    ).then((selected) {
      if (selected != null) {
        _rows[index][0].text = selected;
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
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.black26)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12)),
        ),
      );

  Widget _sectionHeader(String title, bool isDark) {
    return Text(title,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)))
        .animate()
        .fadeIn();
  }

  InputDecoration _deco(String label, bool isDark) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            color: isDark ? Colors.white70 : Colors.black87),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.black26)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12)),
      );
}
