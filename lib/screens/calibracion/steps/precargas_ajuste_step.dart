import 'package:flutter/material.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';

class PrecargasAjusteStep extends StatefulWidget {
  const PrecargasAjusteStep({super.key});

  @override
  State<PrecargasAjusteStep> createState() => _PrecargasAjusteStepState();
}

class _PrecargasAjusteStepState extends State<PrecargasAjusteStep> {
  static const int _maxRows = 6;
  static const int _defaultRows = 5;

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
    if (pa != null && pa.precargas.isNotEmpty) {
      _horaCtrl.text = pa.hora ?? _currentTime();
      _tiCtrl.text = pa.ti ?? '';
      _hriCtrl.text = pa.hri ?? '';
      _patmiCtrl.text = pa.patmi ?? '';
      _cargasCtrl.text = pa.cargasPesas ?? '';
      setState(() {
        _ajusteRealizado = pa.ajusteRealizado ?? false;
        _tipoAjuste = pa.tipoAjuste?.isNotEmpty == true ? pa.tipoAjuste : null;
        _ajusteExterno = pa.tipoAjuste == 'Externo';
        // Build rows
        _rows = pa.precargas
            .map((r) => [
                  TextEditingController(text: r.precarga ?? ''),
                  TextEditingController(text: r.pIndicador ?? ''),
                ])
            .toList();
        // Ensure we have at least _defaultRows
        while (_rows.length < _defaultRows) {
          _rows.add([TextEditingController(), TextEditingController()]);
        }
      });
    } else {
      _horaCtrl.text = _currentTime();
      // Create default rows
      for (int i = 0; i < _defaultRows; i++) {
        _rows.add([TextEditingController(), TextEditingController()]);
      }
      setState(() {});
    }
  }

  void _addRow() {
    if (_rows.length >= _maxRows) return;
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

  void _onPrecargaChanged(int index) {
    final precargaText = _rows[index][0].text;
    // Reflejar el valor de precarga en la indicación
    _rows[index][1].text = precargaText;
    _saveToProvider();
  }

  void _showSuggestedValues(int index, bool isDark) {
    final precargaText = _rows[index][0].text;
    final precargaValue = double.tryParse(precargaText);
    if (precargaValue == null) return;

    final balanza = context.read<ServiceSessionProvider>().session?.balanza;
    if (balanza == null) return;

    SuggestionHelper.showSuggestedValues(
      context: context,
      balanza: balanza,
      baseValue: precargaValue,
      title: 'Indicación para Precarga ${index + 1}',
      isDark: isDark,
    ).then((selected) {
      if (selected != null) {
        _rows[index][1].text = selected;
        _saveToProvider();
      }
    });
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
    for (final row in _rows) {
      for (final c in row) {
        c.dispose();
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 20),

              // Tabla de precargas
              _sectionHeader('Precargas', isDark),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_rows.length < _maxRows)
                    IconButton(
                        icon: Icon(Icons.add_circle_rounded,
                            color: isDark
                                ? const Color(0xFF81C784)
                                : const Color(0xFF2E7D32)),
                        onPressed: _addRow),
                  IconButton(
                      icon: Icon(Icons.remove_circle_rounded,
                          color: isDark
                              ? const Color(0xFFE57373)
                              : const Color(0xFFD32F2F)),
                      onPressed: _removeRow),
                ],
              ),
              ...List.generate(
                  _rows.length, (i) => _buildRow(i, provider, isDark)),
              const SizedBox(height: 20),

              // Ajuste
              _sectionHeader('Ajuste', isDark),
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
                activeThumbColor: Colors.green,
              ),
              if (_ajusteRealizado) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _tipoAjuste?.isNotEmpty == true ? _tipoAjuste : null,
                  decoration: _deco('Tipo de Ajuste', isDark),
                  hint: const Text('Seleccione'),
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor:
                      isDark ? AppColors.cardDark : Colors.white,
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
                    style: GoogleFonts.inter(
                        color: cs.onSurface),
                    controller: _cargasCtrl,
                    onChanged: (_) => _saveToProvider(),
                    decoration:
                        _deco('Cargas de Pesas Patrón Utilizadas', isDark),
                  ),
                ],
              ],
              const SizedBox(height: 20),

              // Condiciones Ambientales
              _sectionHeader('Condiciones Ambientales', isDark),
              Row(children: [
                Expanded(child: _buildHoraField(isDark)),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: CalibrationNumberField(
                        style: GoogleFonts.inter(color: cs.onSurface),
                        controller: _tiCtrl,
                        column: 'ti',
                        // Hay cámaras frías bajo cero.
                        allowNegative: true,
                        onChanged: (_) => _saveToProvider(),
                        decoration: _deco('Ti (°C)', isDark))),
                const SizedBox(width: 10),
                Expanded(
                    child: CalibrationNumberField(
                        style: GoogleFonts.inter(color: cs.onSurface),
                        controller: _hriCtrl,
                        column: 'hri',
                        onChanged: (_) => _saveToProvider(),
                        decoration: _deco('HRi (%)', isDark))),
              ]),
              const SizedBox(height: 10),
              CalibrationNumberField(
                  style: GoogleFonts.inter(color: cs.onSurface),
                  controller: _patmiCtrl,
                  column: 'patmi',
                  onChanged: (_) => _saveToProvider(),
                  decoration: _deco('Patmi (hPa)', isDark)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(int i, ServiceSessionProvider provider, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: 28,
              child: Text('${i + 1}.',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
              child: CalibrationNumberField(
            style: GoogleFonts.inter(color: cs.onSurface),
            controller: _rows[i][0],
            column: 'precarga${i + 1}',
            onChanged: (_) => _onPrecargaChanged(i),
            decoration: _deco('Precarga', isDark),
          )),
          const SizedBox(width: 8),
          Expanded(
            // La indicación se escribe con el teclado o se elige entre los
            // valores cercanos a la precarga, con el ícono.
            child: CalibrationNumberField(
              style: GoogleFonts.inter(color: cs.onSurface),
              controller: _rows[i][1],
              column: 'p_indicador${i + 1}',
              readable: true,
              onChanged: (_) => _saveToProvider(),
              decoration: _deco('Indicación', isDark).copyWith(
                suffixIcon: _rows[i][0].text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Valores sugeridos',
                        onPressed: () => _showSuggestedValues(i, isDark),
                        icon: Icon(Icons.unfold_more_rounded,
                            color: isDark
                                ? AppColors.accentYellow
                                : const Color(0xFF5A4E00),
                            size: 20),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoraField(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      style: GoogleFonts.inter(
          color: cs.onSurface),
      controller: _horaCtrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Hora de Pruebas',
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
        suffixIcon: IconButton(
          icon: Icon(Icons.access_time_filled_rounded,
              color:
                   isDark ? AppColors.accentYellow : const Color(0xFF5A4E00)),
          onPressed: () {
            _horaCtrl.text = _currentTime();
            _saveToProvider();
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Precargas y Ajuste',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Registro de ensayos previos a la calibración',
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface)),
    ).animate().fadeIn();
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
