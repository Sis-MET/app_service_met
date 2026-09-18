import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';
import 'package:service_met/utils/top_alert.dart';

class RepetibilidadStep extends StatefulWidget {
  const RepetibilidadStep({super.key});

  @override
  State<RepetibilidadStep> createState() => _RepetibilidadStepState();
}

class _RepetibilidadStepState extends State<RepetibilidadStep> {
  static const _cargasOptions = ['1', '2', '3'];
  static const _medicionesOptions = ['3', '5', '10'];

  String? _cargasCount;
  String? _medicionesCount;

  bool _hasCheckedPrevData = false;
  List<TextEditingController> _cargasCtrls = [];
  List<List<TextEditingController>> _indCtrls = [];
  List<List<TextEditingController>> _retCtrls = [];
  final _notaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initFromSession();
      await _checkPreviousServiceData();
    });
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final rep = provider.session?.repetibilidad;
    if (rep == null) return;
    _notaCtrl.text = rep.nota ?? '';
    if (rep.cargas.isNotEmpty) {
      final nCargas = rep.cargas.length.clamp(1, 3);
      final registradas = rep.cargas
          .map((c) => c.indicaciones.length)
          .fold(0, (a, b) => a > b ? a : b);
      // La lista solo ofrece 3, 5 o 10: se toma la menor que alcanza para lo
      // registrado.
      _medicionesCount = _medicionesOptions.firstWhere(
        (option) => int.parse(option) >= registradas,
        orElse: () => _medicionesOptions.last,
      );
      final nMediciones = int.parse(_medicionesCount!);
      _cargasCount = nCargas.toString();
      _buildControllers(nCargas, nMediciones);
      for (int i = 0; i < nCargas; i++) {
        _cargasCtrls[i].text = rep.cargas[i].carga ?? '';
        for (int j = 0; j < nMediciones; j++) {
          if (j < rep.cargas[i].indicaciones.length) {
            _indCtrls[i][j].text = rep.cargas[i].indicaciones[j] ?? '';
          }
          if (j < rep.cargas[i].retornos.length) {
            _retCtrls[i][j].text = rep.cargas[i].retornos[j] ?? '';
          }
        }
      }
    }
    if (mounted) setState(() {});
  }

  /// Verifica si hay datos del servicio anterior para precargar cargas.
  Future<void> _checkPreviousServiceData() async {
    if (_hasCheckedPrevData) return;
    _hasCheckedPrevData = true;

    if (!mounted) return;
    final provider = context.read<ServiceSessionProvider>();

    final codMetrica = provider.session?.balanza?.codMetrica;
    if (codMetrica != null && codMetrica.isNotEmpty) {
      await provider.loadPreviousServiceData(codMetrica);
    }

    final prev = provider.previousServiceData;
    if (prev == null) return;

    final repValues = <String>[];
    for (int i = 1; i <= 3; i++) {
      final val = prev['rep$i']?.toString() ?? '';
      if (val.isNotEmpty) repValues.add(val);
    }

    if (repValues.isEmpty) {
      TopAlert.show(
          context, 'No hay datos del servicio anterior para Repetibilidad');
      return;
    }

    if (_cargasCount != null) return;

    final valoresStr = repValues.join(', ');
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Repetibilidad - Servicio anterior'),
        content:
            Text('Se encontraron cargas registradas del servicio anterior:\n\n'
                'Cargas: $valoresStr\n\n'
                '¿Desea usar estos valores?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No usar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usar datos'),
          ),
        ],
      ),
    ).then((accepted) {
      if (!mounted) return;
      if (accepted == true) {
        final nCargas = repValues.length;
        const nMediciones = 3;
        setState(() {
          _cargasCount = nCargas.toString();
          _medicionesCount = nMediciones.toString();
          _buildControllers(nCargas, nMediciones);
          for (int i = 0; i < nCargas; i++) {
            _cargasCtrls[i].text = repValues[i];
            for (int j = 0; j < nMediciones; j++) {
              _indCtrls[i][j].text = repValues[i];
            }
          }
        });
        _saveToProvider();
      }
    });
  }

  void _buildControllers(int nCargas, int nMediciones) {
    for (final c in _cargasCtrls) {
      c.dispose();
    }
    for (final row in _indCtrls) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _retCtrls) {
      for (final c in row) {
        c.dispose();
      }
    }

    _cargasCtrls = List.generate(nCargas, (_) => TextEditingController());
    _indCtrls = List.generate(nCargas,
        (_) => List.generate(nMediciones, (_) => TextEditingController()));
    _retCtrls = List.generate(
        nCargas,
        (_) => List.generate(
            nMediciones, (_) => TextEditingController(text: '0')));
  }

  void _onCargasChanged(String? v) {
    final n = int.tryParse(v ?? '1') ?? 1;
    final med = int.tryParse(_medicionesCount ?? '3') ?? 3;

    final oldCargas = _cargasCtrls.map((c) => c.text).toList();
    final oldInd = _indCtrls.map((r) => r.map((c) => c.text).toList()).toList();
    final oldRet = _retCtrls.map((r) => r.map((c) => c.text).toList()).toList();

    setState(() {
      _cargasCount = v;
      _buildControllers(n, med);
    });

    for (int i = 0; i < n && i < oldCargas.length; i++) {
      _cargasCtrls[i].text = oldCargas[i];
    }
    for (int i = 0; i < n && i < oldInd.length; i++) {
      for (int j = 0; j < med && j < oldInd[i].length; j++) {
        _indCtrls[i][j].text = oldInd[i][j];
        _retCtrls[i][j].text = oldRet[i][j];
      }
    }
    _saveToProvider();
  }

  void _onMedicionesChanged(String? v) {
    final med = int.tryParse(v ?? '3') ?? 3;
    final n = int.tryParse(_cargasCount ?? '1') ?? 1;

    final oldCargas = _cargasCtrls.map((c) => c.text).toList();
    final oldInd = _indCtrls.map((r) => r.map((c) => c.text).toList()).toList();
    final oldRet = _retCtrls.map((r) => r.map((c) => c.text).toList()).toList();

    setState(() {
      _medicionesCount = v;
      _buildControllers(n, med);
    });

    for (int i = 0; i < n && i < oldCargas.length; i++) {
      _cargasCtrls[i].text = oldCargas[i];
    }
    for (int i = 0; i < n && i < oldInd.length; i++) {
      for (int j = 0; j < med && j < oldInd[i].length; j++) {
        _indCtrls[i][j].text = oldInd[i][j];
        _retCtrls[i][j].text = oldRet[i][j];
      }
    }
    _saveToProvider();
  }

  void _saveToProvider() {
    // Sin N° de cargas elegido todavía no hay filas (solo la nota), y sin N°
    // de mediciones las cargas aún no muestran lecturas.
    final n = _cargasCount == null ? 0 : _cargasCtrls.length;
    final conMediciones = _medicionesCount != null;
    final provider = context.read<ServiceSessionProvider>();
    provider.updateRepetibilidad(RepetibilidadData(
      nota: _notaCtrl.text,
      cargas: List.generate(
          n,
          (i) => CargaRepetibilidad(
                carga: _cargasCtrls[i].text,
                indicaciones: conMediciones
                    ? _indCtrls[i]
                        .map((c) => c.text.isEmpty ? null : c.text)
                        .toList()
                    : const [],
                retornos: conMediciones
                    ? _retCtrls[i]
                        .map((c) => c.text.isEmpty ? null : c.text)
                        .toList()
                    : const [],
              )),
    ));
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

  @override
  void dispose() {
    for (final c in _cargasCtrls) {
      c.dispose();
    }
    for (final row in _indCtrls) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _retCtrls) {
      for (final c in row) {
        c.dispose();
      }
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
                value: _cargasCount,
                decoration: _deco('N° de Cargas', isDark),
                hint: Text('Seleccione',
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white54 : Colors.black45)),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: _cargasOptions
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v,
                            style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A)))))
                    .toList(),
                onChanged: _onCargasChanged,
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 16),
              if (_cargasCount != null) ...[
                DropdownButtonFormField<String>(
                  value: _medicionesCount,
                  decoration: _deco('N° de Mediciones por Carga', isDark),
                  hint: Text('Seleccione',
                      style: GoogleFonts.inter(
                          color: isDark ? Colors.white54 : Colors.black45)),
                  dropdownColor:
                      isDark ? const Color(0xFF2A2A2A) : Colors.white,
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
                ).animate(delay: 300.ms).fadeIn(),
                const SizedBox(height: 24),
              ],
              if (_cargasCount != null && _medicionesCount != null) ...[
                ...List.generate(int.tryParse(_cargasCount!) ?? 1,
                    (i) => _buildCargaCard(i, isDark)),
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
          'Pruebas de Repetibilidad',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Registro de ensayos de repetibilidad',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildCargaCard(int i, bool isDark) {
    final nMediciones = int.tryParse(_medicionesCount ?? '3') ?? 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          _sectionHeader('Carga ${i + 1}', isDark),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CalibrationNumberField(
              style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              controller: _cargasCtrls[i],
              column: 'repetibilidad${i + 1}',
              onChanged: (val) {
                final formatted = _formatValueWithPrecision(val);
                for (int j = 0; j < nMediciones; j++) {
                  _indCtrls[i][j].text = formatted;
                }
                _saveToProvider();
              },
              decoration: _deco('Valor de carga', isDark),
            ),
          ),
          if (_cargasCtrls[i].text.isEmpty) _buildSuggestedLoadChips(i, isDark),
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
                          color: isDark ? Colors.white70 : Colors.grey[600]),
                      textAlign: TextAlign.center)),
              Expanded(
                  child: Text('Retorno',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey[600]),
                      textAlign: TextAlign.center)),
            ]),
          ),
          const SizedBox(height: 8),
          ...List.generate(
              nMediciones,
              (j) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                                width: 30,
                                child: Text('${j + 1}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _indicationField(i, j, isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _numField(_retCtrls[i][j],
                                  'retorno${i + 1}_${j + 1}', isDark)),
                        ]),
                  )),
          const SizedBox(height: 12),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 400 + i * 100)).fadeIn();
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

  Widget _indicationField(int cargaIdx, int medIdx, bool isDark) {
    final hasBase = _cargasCtrls[cargaIdx].text.isNotEmpty;
    return CalibrationNumberField(
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _indCtrls[cargaIdx][medIdx],
      column: 'indicacion${cargaIdx + 1}_${medIdx + 1}',
      allowNegative: true,
      onChanged: (_) => _saveToProvider(),
      decoration: _fieldDecoration(
        isDark,
        suffixIcon: hasBase
            ? InkWell(
                onTap: () => _showIndicacionSuggestion(cargaIdx, medIdx),
                child: Icon(Icons.unfold_more_rounded,
                    color: Colors.teal, size: 20),
              )
            : null,
      ),
    );
  }

  void _showIndicacionSuggestion(int cargaIdx, int medIdx) {
    final cargaText = _cargasCtrls[cargaIdx].text;
    final cargaValue = double.tryParse(cargaText);
    if (cargaValue == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balanza = context.read<ServiceSessionProvider>().session?.balanza;
    if (balanza == null) return;

    SuggestionHelper.showSuggestedValues(
      context: context,
      balanza: balanza,
      baseValue: cargaValue,
      title: 'Indicación - Carga ${cargaIdx + 1}, Medición ${medIdx + 1}',
      isDark: isDark,
    ).then((selected) {
      if (selected != null) {
        _indCtrls[cargaIdx][medIdx].text = selected;
        _saveToProvider();
      }
    });
  }

  Widget _numField(TextEditingController ctrl, String column, bool isDark) =>
      CalibrationNumberField(
        style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
        controller: ctrl,
        column: column,
        allowNegative: true,
        onChanged: (_) => _saveToProvider(),
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

  Widget _buildSuggestedLoadChips(int cargaIdx, bool isDark) {
    final balanza = context.read<ServiceSessionProvider>().session?.balanza;
    if (balanza == null) return const SizedBox.shrink();

    final rangos = SuggestionHelper.getValidCapacities(balanza);
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
          final unidad = balanza.unidad ?? 'kg';
          final label = rangos.length > 1 ? 'Max${index + 1}' : 'Pmax';

          return GestureDetector(
            onTap: () {
              _cargasCtrls[cargaIdx].text = formatted;
              final nMediciones = int.tryParse(_medicionesCount ?? '3') ?? 3;
              for (int j = 0; j < nMediciones; j++) {
                _indCtrls[cargaIdx][j].text = formatted;
              }
              _saveToProvider();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
