import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';

class ExcentricidadStep extends StatefulWidget {
  const ExcentricidadStep({super.key});

  @override
  State<ExcentricidadStep> createState() => _ExcentricidadStepState();
}

class _ExcentricidadStepState extends State<ExcentricidadStep> {
  static const _plataformas = ['Cuadrada', 'Rectangular', 'Circular', 'Triangular'];

  String? _tipoPlataforma;
  String? _puntosIndicacion;
  final _cargaCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  List<List<TextEditingController>> _rows = []; // [indicacion, retorno]

  List<String> _getPuntosOptions() {
    switch (_tipoPlataforma) {
      case 'Cuadrada':
        return ['5'];
      case 'Rectangular':
        return ['3', '5'];
      case 'Circular':
        return ['4', '5'];
      case 'Triangular':
        return ['4'];
      default:
        return [];
    }
  }

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
        _tipoPlataforma = exc.tipoPlataforma;
        _puntosIndicacion = exc.puntosIndicacion;
        _cargaCtrl.text = exc.carga ?? '';
        _notaCtrl.text = exc.nota ?? '';
        _rows = exc.posiciones
            .map((p) => [
                  TextEditingController(text: p.indicacion ?? ''),
                  TextEditingController(text: p.retorno ?? '0'),
                ])
            .toList();
      });
    }
    if (_rows.isEmpty) _buildDefaultRows(4);
  }

  void _buildDefaultRows(int count) {
    for (final row in _rows)
      for (final c in row) {
        c.dispose();
      }
    _rows = List.generate(
        count,
        (_) => [
              TextEditingController(),
              TextEditingController(text: '0'),
            ]);
  }

  void _onPlataformaChanged(String? v) {
    setState(() {
      _tipoPlataforma = v;
      _puntosIndicacion = null;
    });
    final options = _getPuntosOptions();
    if (options.length == 1) {
      _onPuntosChanged(options[0]);
    } else {
      _rows = [];
      _saveToProvider();
    }
  }

  void _onPuntosChanged(String? v) {
    final n = int.tryParse(v ?? '4') ?? 4;
    setState(() {
      _puntosIndicacion = v;
      _buildDefaultRows(n);
    });
    _saveToProvider();
  }

  void _reflectCargaToIndicaciones() {
    final value = _cargaCtrl.text;
    for (final row in _rows) {
      row[0].text = value;
    }
    _saveToProvider();
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateExcentricidad(ExcentricidadData(
      tipoPlataforma: _tipoPlataforma,
      puntosIndicacion: _puntosIndicacion,
      carga: _cargaCtrl.text,
      nota: _notaCtrl.text.isEmpty ? 'Sin observaciones' : _notaCtrl.text,
      posiciones: _rows
          .asMap()
          .entries
          .map((e) => PosicionData(
                posicion: '${e.key + 1}',
                indicacion: e.value[0].text,
                retorno: e.value[1].text,
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
    _cargaCtrl.dispose();
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
                value: _tipoPlataforma,
                decoration: _deco('Tipo de Plataforma', isDark),
                hint: Text('Seleccione',
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white54 : Colors.black45)),
                dropdownColor:
                    isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: _plataformas
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v,
                            style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A)))))
                    .toList(),
                onChanged: _onPlataformaChanged,
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 16),

              if (_tipoPlataforma != null) ...[
                DropdownButtonFormField<String>(
                  value: _puntosIndicacion,
                  decoration: _deco('N° de Puntos de Indicación', isDark),
                  hint: Text('Seleccione',
                      style: GoogleFonts.inter(
                          color: isDark ? Colors.white54 : Colors.black45)),
                  dropdownColor:
                      isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  items: _getPuntosOptions()
                      .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v,
                              style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A)))))
                      .toList(),
                  onChanged: _onPuntosChanged,
                ).animate(delay: 300.ms).fadeIn(),
                const SizedBox(height: 16),
              ],

              TextField(
                style: GoogleFonts.inter(
                    color:
                        isDark ? Colors.white : const Color(0xFF1A1A1A)),
                controller: _cargaCtrl,
                onChanged: (_) {
                  _reflectCargaToIndicaciones();
                },
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                decoration: _deco('Carga (kg)', isDark),
              ).animate(delay: 450.ms).fadeIn(),
              const SizedBox(height: 24),

              if (_rows.isNotEmpty) ...[
                _sectionHeader('Posiciones', isDark),
                const SizedBox(height: 12),
                Row(children: [
                  const SizedBox(width: 66),
                  Expanded(
                      child: Text('Indicación',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey[600]),
                          textAlign: TextAlign.center)),
                  Expanded(
                      child: Text('Retorno',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey[600]),
                          textAlign: TextAlign.center)),
                ]),
                const SizedBox(height: 8),
                ...List.generate(
                    _rows.length,
                    (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            SizedBox(
                                width: 56,
                                child: Row(children: [
                                  Text('Pos ${i + 1}',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87)),
                                ])),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    child: _indicationField(i, isDark))),
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    child: _numField(_rows[i][1], isDark))),
                          ]),
                        )).animate(delay: 500.ms).fadeIn(),
              ],

              const SizedBox(height: 20),
              TextField(
                style: GoogleFonts.inter(
                    color:
                        isDark ? Colors.white : const Color(0xFF1A1A1A)),
                controller: _notaCtrl,
                onChanged: (_) => _saveToProvider(),
                maxLines: 3,
                decoration: _deco('Nota / Comentario (opcional)', isDark),
              ),
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
          'Pruebas de Excentricidad',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Registro de ensayos de excentricidad',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Text(title,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)))
        .animate()
        .fadeIn();
  }

  Widget _indicationField(int i, bool isDark) {
    final hasBase = _cargaCtrl.text.isNotEmpty;
    return GestureDetector(
      onTap: hasBase ? () => _showIndicacionSuggestion(i) : null,
      child: AbsorbPointer(
        child: TextField(
          style: GoogleFonts.inter(
              color:
                  isDark ? Colors.white : const Color(0xFF1A1A1A)),
          controller: _rows[i][0],
          onChanged: (_) => _saveToProvider(),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
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
            suffixIcon: hasBase
                ? Icon(Icons.unfold_more_rounded,
                    color: Colors.teal, size: 20)
                : null,
          ),
        ),
      ),
    );
  }

  void _showIndicacionSuggestion(int index) {
    final cargaText = _cargaCtrl.text;
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
      title: 'Indicación - Posición ${index + 1}',
      isDark: isDark,
    ).then((selected) {
      if (selected != null) {
        _rows[index][0].text = selected;
        _saveToProvider();
      }
    });
  }

  Widget _numField(TextEditingController ctrl, bool isDark) => TextField(
        style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
        controller: ctrl,
        onChanged: (_) => _saveToProvider(),
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
