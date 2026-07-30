// ignore_for_file: deprecated_member_use, use_build_context_synchronously, curly_braces_in_flow_control_structures
import 'dart:math' as math;
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
  String? _posicionCaseta;
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
    _posicionCaseta = null;
    _selectedPuntos = null;
    if (exc.puntosIndicacion != null && exc.puntosIndicacion!.isNotEmpty) {
      _parsePuntosIndicacion(exc.puntosIndicacion!);
    }
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

  void _parsePuntosIndicacion(String value) {
    final abrevRegex = RegExp(r'^(\d+)([FAID])$');
    final match = abrevRegex.firstMatch(value.trim());
    if (match != null) {
      _selectedPuntos = int.tryParse(match.group(1)!);
      final abrev = match.group(2)!;
      switch (abrev) {
        case 'F': _posicionCaseta = 'frente'; break;
        case 'A': _posicionCaseta = 'atras'; break;
        case 'I': _posicionCaseta = 'izquierda'; break;
        case 'D': _posicionCaseta = 'derecha'; break;
      }
    } else {
      _selectedPuntos = int.tryParse(value.trim());
    }
  }

  String _getPosicionAbrev() {
    switch (_posicionCaseta) {
      case 'frente': return 'F';
      case 'atras': return 'A';
      case 'izquierda': return 'I';
      case 'derecha': return 'D';
      default: return '';
    }
  }

  String? _composePuntosIndicacion() {
    if (_selectedPuntos == null) return null;
    final abrev = _getPosicionAbrev();
    return '$_selectedPuntos$abrev';
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
      puntosIndicacion: _composePuntosIndicacion(),
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
          _buildCasetaPositionSelector(isDark),
          const SizedBox(height: 16),
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
          child: const Icon(Icons.local_shipping,
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

  Widget _buildCasetaPositionSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Posición de Caseta', isDark),
        const SizedBox(height: 8),
        _buildDirectionButtons(isDark),
      ],
    );
  }

  Widget _buildDirectionButtons(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dirBtn('atras', Icons.arrow_upward, 'Atrás', isDark),
        const SizedBox(width: 6),
        _dirBtn('frente', Icons.arrow_downward, 'Frente', isDark),
        const SizedBox(width: 6),
        _dirBtn('izquierda', Icons.arrow_back, 'Izq', isDark),
        const SizedBox(width: 6),
        _dirBtn('derecha', Icons.arrow_forward, 'Der', isDark),
      ],
    );
  }

  Widget _dirBtn(String key, IconData icon, String label, bool isDark) {
    final selected = _posicionCaseta == key;
    return GestureDetector(
      onTap: () {
        setState(() => _posicionCaseta = key);
        _emit();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minWidth: 60),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.teal
              : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.tealAccent
                : (isDark ? Colors.white24 : Colors.black12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54))),
          ],
        ),
      ),
    );
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_forward_rounded, size: 14,
                  color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 4),
              Text('IDA',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(width: 16),
              Text('VUELTA',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_back_rounded, size: 14,
                  color: isDark ? Colors.white54 : Colors.black45),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _BasculaPlatformPainter(
                    half: half,
                    posicionCaseta: _posicionCaseta,
                    isDark: isDark,
                    idaDots: List.generate(half, (i) => i + 1),
                    vueltaDots: List.generate(half, (i) => half - i),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ).animate(delay: 150.ms).fadeIn();
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
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: isDark ? Colors.white70 : Colors.black54),
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

class _BasculaPlatformPainter extends CustomPainter {
  final int half;
  final String? posicionCaseta;
  final bool isDark;
  final List<int> idaDots;
  final List<int> vueltaDots;

  _BasculaPlatformPainter({
    required this.half,
    required this.posicionCaseta,
    required this.isDark,
    required this.idaDots,
    required this.vueltaDots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pL = w * 0.10;
    final pT = h * 0.10;
    final pW = w * 0.68;
    final pH = h * 0.70;
    final platform = Rect.fromLTWH(pL, pT, pW, pH);

    final bg = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE8ECF0);
    final fg = isDark ? Colors.white38 : Colors.black26;
    final textColor = isDark ? Colors.white70 : Colors.black45;
    final dotFill = isDark ? const Color(0xFF4A4A4A) : Colors.white;
    final dotBorder = isDark ? Colors.white38 : Colors.black26;

    final halfH = platform.height / 2;
    final topRowY = platform.top + halfH * 0.35;
    final botRowY = platform.top + halfH * 1.15;

    _drawPlatform(canvas, platform, bg, fg);
    _drawIdaArrow(canvas, platform, topRowY, textColor);
    _drawVueltaArrow(canvas, platform, botRowY, textColor);
    _drawDots(canvas, platform, idaDots, topRowY, dotFill, dotBorder, textColor);
    _drawDots(canvas, platform, vueltaDots, botRowY, dotFill, dotBorder, textColor);
    _drawTruck(canvas, platform, textColor);
    _drawCaseta(canvas, platform, w, h, textColor);
  }

  void _drawPlatform(Canvas canvas, Rect r, Color bg, Color border) {
    final paint = Paint()..color = bg;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), paint);
    paint
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), paint);
  }

  void _drawIdaArrow(Canvas canvas, Rect platform, double topRowY, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final midY = topRowY;
    final x1 = platform.left - 20;
    final x2 = platform.left - 4;
    canvas.drawLine(Offset(x1, midY), Offset(x2, midY), paint);
    _drawArrowHead(canvas, Offset(x2, midY), 0, paint);
  }

  void _drawVueltaArrow(Canvas canvas, Rect platform, double botRowY, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final midY = botRowY;
    final x1 = platform.right + 4;
    final x2 = platform.right + 20;
    canvas.drawLine(Offset(x1, midY), Offset(x2, midY), paint);
    _drawArrowHead(canvas, Offset(x2, midY), math.pi, paint);
  }

  void _drawArrowHead(Canvas canvas, Offset tip, double angle, Paint paint) {
    final headSize = 10.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx + headSize * math.cos(angle + math.pi * 0.83),
        tip.dy + headSize * math.sin(angle + math.pi * 0.83),
      )
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx + headSize * math.cos(angle - math.pi * 0.83),
        tip.dy + headSize * math.sin(angle - math.pi * 0.83),
      );
    canvas.drawPath(path, paint);
  }

  void _drawDots(
    Canvas canvas,
    Rect platform,
    List<int> dots,
    double rowY,
    Color fill,
    Color border,
    Color textColor,
  ) {
    if (dots.isEmpty) return;
    final spacing = platform.width / (dots.length + 1);
    for (int i = 0; i < dots.length; i++) {
      final cx = platform.left + spacing * (i + 1);
      final cy = rowY;
      final r = 11.0;

      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = fill);
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

      final tp = TextPainter(
        text: TextSpan(
          text: '${dots[i]}',
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  void _drawTruck(Canvas canvas, Rect platform, Color color) {
    final cx = platform.left + platform.width * 0.3;
    final cy = platform.top + platform.height * 0.52;
    final bodyW = 40.0;
    final bodyH = 18.0;
    final cabW = 14.0;
    final cabH = 16.0;

    final bodyPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: bodyW, height: bodyH),
      const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, strokePaint);

    final cabCenter = Offset(cx + bodyW / 2 + cabW / 2, cy);
    final cabRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: cabCenter, width: cabW, height: cabH),
      const Radius.circular(2),
    );
    canvas.drawRRect(cabRect, bodyPaint);
    canvas.drawRRect(cabRect, strokePaint);

    final wheelPaint = Paint()..color = color;
    for (final dx in [-bodyW / 2 + 4, bodyW / 2 - 4]) {
      canvas.drawCircle(Offset(cx + dx, cy - bodyH / 2 - 2), 2.5, wheelPaint);
      canvas.drawCircle(Offset(cx + dx, cy + bodyH / 2 + 2), 2.5, wheelPaint);
    }
  }

  void _drawCaseta(Canvas canvas, Rect platform, double w, double h, Color color) {
    if (posicionCaseta == null) return;

    final cw = 26.0;
    final ch = 22.0;
    Offset center;
    switch (posicionCaseta) {
      case 'frente':
        center = Offset(w / 2, platform.bottom + ch / 2 + 8);
        break;
      case 'atras':
        center = Offset(w / 2, platform.top - ch / 2 - 8);
        break;
      case 'izquierda':
        center = Offset(platform.left - cw / 2 - 10, platform.top + platform.height / 2);
        break;
      case 'derecha':
        center = Offset(platform.right + cw / 2 + 10, platform.top + platform.height / 2);
        break;
      default:
        return;
    }

    final fill = isDark ? const Color(0xFF4A4A4A) : const Color(0xFFDBE4EE);
    final stroke = color;

    final rect = Rect.fromCenter(center: center, width: cw, height: ch);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    final roofPath = Path()
      ..moveTo(center.dx - cw / 2, center.dy - ch / 2)
      ..lineTo(center.dx, center.dy - ch / 2 - 10)
      ..lineTo(center.dx + cw / 2, center.dy - ch / 2);
    canvas.drawPath(roofPath, Paint()..color = fill);
    canvas.drawPath(roofPath, Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _BasculaPlatformPainter old) {
    return old.half != half ||
        old.posicionCaseta != posicionCaseta ||
        old.isDark != isDark;
  }
}
