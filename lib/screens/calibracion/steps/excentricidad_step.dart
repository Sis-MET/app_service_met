import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';
import 'package:service_met/utils/top_alert.dart';

class ExcentricidadStep extends StatefulWidget {
  const ExcentricidadStep({super.key});

  @override
  State<ExcentricidadStep> createState() => _ExcentricidadStepState();
}

class _ExcentricidadStepState extends State<ExcentricidadStep> {
  static const _plataformas = [
    'Cuadrada',
    'Rectangular',
    'Circular',
    'Triangular'
  ];

  String? _tipoPlataforma;
  String? _puntosIndicacion;
  int? _selectedPosition;
  String? _posicionIndicador;
  bool _hasCheckedPrevData = false;
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

  List<Offset> _getPositionCoords(int n) {
    switch (_tipoPlataforma) {
      case 'Cuadrada':
        return const [
          Offset(0.50, 0.50),
          Offset(0.73, 0.27),
          Offset(0.73, 0.73),
          Offset(0.27, 0.73),
          Offset(0.27, 0.27),
        ];
      case 'Rectangular':
        if (n == 3) {
          return const [
            Offset(0.50, 0.50),
            Offset(0.22, 0.50),
            Offset(0.78, 0.50),
          ];
        }
        return const [
          Offset(0.50, 0.50),
          Offset(0.78, 0.35),
          Offset(0.78, 0.65),
          Offset(0.22, 0.65),
          Offset(0.22, 0.35),
        ];
      case 'Circular':
        if (n == 4) {
          return const [
            Offset(0.50, 0.50),
            Offset(0.691, 0.309),
            Offset(0.50, 0.77),
            Offset(0.309, 0.309),
          ];
        }
        return const [
          Offset(0.50, 0.50),
          Offset(0.691, 0.309),
          Offset(0.691, 0.691),
          Offset(0.309, 0.691),
          Offset(0.309, 0.309),
        ];
      case 'Triangular':
        return const [
          Offset(0.50, 0.53),
          Offset(0.50, 0.30),
          Offset(0.66, 0.66),
          Offset(0.34, 0.66),
        ];
      default:
        return [];
    }
  }

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
    final exc = provider.session?.excentricidad;
    if (exc != null) {
      _parsePuntosIndicacion(exc.puntosIndicacion, exc.tipoPlataforma);
      // Solo las filas de la prueba: registros anteriores podían conservar
      // posiciones de una configuración con más puntos.
      final puntos = exc.puntosCount;
      final posiciones = puntos != null && puntos < exc.posiciones.length
          ? exc.posiciones.take(puntos)
          : exc.posiciones;
      setState(() {
        _cargaCtrl.text = exc.carga ?? '';
        _notaCtrl.text = exc.nota ?? '';
        _rows = posiciones
            .map((p) => [
                  TextEditingController(text: p.indicacion ?? ''),
                  TextEditingController(text: p.retorno ?? '0'),
                ])
            .toList();
      });
    }
    if (_rows.isEmpty) _buildDefaultRows(4);
    _hasCheckedPrevData = false;
  }

  // La posición del indicador (F, A, I, D) puede faltar si aún no se eligió.
  static final _puntosIndicacionRegex = RegExp(r'^(\w+)\s+(\d+)([FAID])?$');

  void _parsePuntosIndicacion(
      String? value, String? tipoPlataformaFromSession) {
    if (value == null || value.trim().isEmpty) return;

    final match = _puntosIndicacionRegex.firstMatch(value.trim());
    if (match != null) {
      setState(() {
        final tipo = match.group(1)!;
        final puntos = match.group(2)!;
        final abrev = match.group(3);
        if (_plataformas.contains(tipo)) {
          _tipoPlataforma = tipo;
        }
        final options = _getPuntosOptions();
        if (options.contains(puntos)) {
          _puntosIndicacion = puntos;
        }
        switch (abrev) {
          case 'F':
            _posicionIndicador = 'frente';
          case 'A':
            _posicionIndicador = 'atras';
          case 'I':
            _posicionIndicador = 'izquierda';
          case 'D':
            _posicionIndicador = 'derecha';
        }
      });
    } else {
      // Backward compatibility: solo el número (formato anterior)
      setState(() {
        _tipoPlataforma = _plataformas.contains(tipoPlataformaFromSession)
            ? tipoPlataformaFromSession
            : null;
        final options = _getPuntosOptions();
        _puntosIndicacion =
            options.contains(value.trim()) ? value.trim() : null;
      });
    }
  }

  /// Verifica si hay datos del servicio anterior para precargar la carga.
  Future<void> _checkPreviousServiceData() async {
    if (_hasCheckedPrevData) return;
    _hasCheckedPrevData = true;

    if (!mounted) return;
    final provider = context.read<ServiceSessionProvider>();

    // Cargar datos del servicio anterior para la balanza actual
    final codMetrica = provider.session?.balanza?.codMetrica;
    if (codMetrica != null && codMetrica.isNotEmpty) {
      await provider.loadPreviousServiceData(codMetrica);
    }

    final prev = provider.previousServiceData;
    if (prev == null) return;

    final exc = prev['exc']?.toString() ?? '';
    if (exc.isEmpty) {
      TopAlert.show(
          context, 'No hay datos del servicio anterior para Excentricidad');
      return;
    }

    // Solo preguntar si la carga está vacía (el step no tiene datos)
    if (_cargaCtrl.text.isNotEmpty) return;

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Excentricidad - Servicio anterior'),
        content:
            Text('Se encontró una carga registrada del servicio anterior:\n\n'
                'Carga: $exc\n\n'
                '¿Desea usar este valor?'),
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
        setState(() {
          _cargaCtrl.text = exc;
        });
        _reflectCargaToIndicaciones();
      }
    });
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
    if (_cargaCtrl.text.isNotEmpty) {
      _reflectCargaToIndicaciones();
    }
    _saveToProvider();
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

  void _reflectCargaToIndicaciones() {
    final value = _formatValueWithPrecision(_cargaCtrl.text);
    for (final row in _rows) {
      row[0].text = value;
    }
    _saveToProvider();
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateExcentricidad(ExcentricidadData(
      tipoPlataforma: _tipoPlataforma,
      puntosIndicacion: _composePuntosIndicacion(),
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

  String? _composePuntosIndicacion() {
    if (_tipoPlataforma == null || _puntosIndicacion == null) {
      return _puntosIndicacion;
    }
    final abrev = _getPosicionAbrev();
    return '$_tipoPlataforma $_puntosIndicacion$abrev';
  }

  String _getPosicionAbrev() {
    switch (_posicionIndicador) {
      case 'frente':
        return 'F';
      case 'atras':
        return 'A';
      case 'izquierda':
        return 'I';
      case 'derecha':
        return 'D';
      default:
        return '';
    }
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
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
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
                _sectionHeader('Posición del Indicador', isDark),
                const SizedBox(height: 8),
                _buildDirectionButtons(isDark),
                const SizedBox(height: 16),
              ],
              _buildPlatformDiagram(isDark),
              const SizedBox(height: 16),
              CalibrationNumberField(
                style: GoogleFonts.inter(
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                controller: _cargaCtrl,
                column: 'carga',
                onChanged: (_) {
                  _reflectCargaToIndicaciones();
                },
                decoration: _deco('Carga', isDark),
              ).animate(delay: 450.ms).fadeIn(),
              if (_cargaCtrl.text.isEmpty) _buildSuggestedLoadChips(isDark),
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
                const SizedBox(height: 8),
                ...List.generate(
                    _rows.length,
                    (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: SizedBox(
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
                                ),
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
                                        child: _numField(_rows[i][1],
                                            'retorno${i + 1}', isDark))),
                              ]),
                        )).animate(delay: 500.ms).fadeIn(),
              ],
              const SizedBox(height: 20),
              TextField(
                style: GoogleFonts.inter(
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
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

  String _getBalanceUnit() {
    try {
      return context.read<ServiceSessionProvider>().session?.balanza?.unidad ??
          'kg';
    } catch (_) {
      return 'kg';
    }
  }

  Widget _buildPlatformDiagram(bool isDark) {
    if (_tipoPlataforma == null || _puntosIndicacion == null) {
      return const SizedBox.shrink();
    }
    final n = int.tryParse(_puntosIndicacion!) ?? 0;
    if (n == 0) return const SizedBox.shrink();

    final coords = _getPositionCoords(n);
    if (coords.isEmpty) return const SizedBox.shrink();

    final unidad = _getBalanceUnit();
    final cargaValue = _cargaCtrl.text.isEmpty ? '0' : _cargaCtrl.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Diagrama de Posiciones', isDark),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _PlatformPainter(
                    tipo: _tipoPlataforma!,
                    posicionIndicador: _posicionIndicador,
                    isDark: isDark,
                    cargaValue: cargaValue,
                    unidad: unidad,
                  ),
                  child: Stack(
                    children: [
                      for (var i = 0; i < coords.length; i++)
                        Positioned(
                          left: coords[i].dx * 220 - 20,
                          top: coords[i].dy * 220 - 20,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedPosition = i + 1);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedPosition == i + 1
                                    ? Colors.teal
                                    : (isDark
                                        ? Colors.grey[700]
                                        : Colors.grey[300]),
                                border: Border.all(
                                  color: _selectedPosition == i + 1
                                      ? Colors.tealAccent
                                      : (isDark
                                          ? Colors.white38
                                          : Colors.black26),
                                  width: _selectedPosition == i + 1 ? 3 : 2,
                                ),
                                boxShadow: _selectedPosition == i + 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.teal.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: _selectedPosition == i + 1
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_selectedPosition != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Posición $_selectedPosition seleccionada',
                  style: TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
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
    final selected = _posicionIndicador == key;
    return GestureDetector(
      onTap: () {
        setState(() => _posicionIndicador = key);
        _saveToProvider();
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
            Icon(icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
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
    return CalibrationNumberField(
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _rows[i][0],
      column: 'indicacion${i + 1}',
      allowNegative: true,
      onChanged: (_) => _saveToProvider(),
      decoration: InputDecoration(
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
        suffixIcon: hasBase
            ? InkWell(
                onTap: () => _showIndicacionSuggestion(i),
                child: Icon(Icons.unfold_more_rounded,
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
    final balanza = context.read<ServiceSessionProvider>().session?.balanza;
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

  Widget _numField(TextEditingController ctrl, String column, bool isDark) =>
      CalibrationNumberField(
        style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
        controller: ctrl,
        column: column,
        allowNegative: true,
        onChanged: (_) => _saveToProvider(),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
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

  Widget _buildSuggestedLoadChips(bool isDark) {
    final balanza = context.read<ServiceSessionProvider>().session?.balanza;
    if (balanza == null) return const SizedBox.shrink();

    final rangos = SuggestionHelper.getValidCapacities(balanza);
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
          final unidad = _getBalanceUnit();
          final label = rangos.length > 1 ? 'Max${index + 1}' : 'Pmax';

          return GestureDetector(
            onTap: () {
              _cargaCtrl.text = formatted;
              _reflectCargaToIndicaciones();
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
}

class _PlatformPainter extends CustomPainter {
  final String tipo;
  final String? posicionIndicador;
  final bool isDark;
  final String cargaValue;
  final String unidad;

  _PlatformPainter({
    required this.tipo,
    required this.isDark,
    this.posicionIndicador,
    this.cargaValue = '0',
    this.unidad = 'kg',
  });

  Offset _getIndicatorPos(String posicion, double w, double h) {
    switch (tipo) {
      case 'Cuadrada':
        switch (posicion) {
          case 'frente':
            return Offset(w * 0.5, h * 0.85);
          case 'atras':
            return Offset(w * 0.5, h * 0.15);
          case 'izquierda':
            return Offset(w * 0.15, h * 0.5);
          case 'derecha':
            return Offset(w * 0.85, h * 0.5);
        }
      case 'Rectangular':
        switch (posicion) {
          case 'frente':
            return Offset(w * 0.5, h * 0.75);
          case 'atras':
            return Offset(w * 0.5, h * 0.25);
          case 'izquierda':
            return Offset(w * 0.12, h * 0.5);
          case 'derecha':
            return Offset(w * 0.88, h * 0.5);
        }
      case 'Circular':
        switch (posicion) {
          case 'frente':
            return Offset(w * 0.5, h * 0.90);
          case 'atras':
            return Offset(w * 0.5, h * 0.10);
          case 'izquierda':
            return Offset(w * 0.10, h * 0.5);
          case 'derecha':
            return Offset(w * 0.90, h * 0.5);
        }
      case 'Triangular':
        switch (posicion) {
          case 'frente':
            return Offset(w * 0.5, h * 0.90);
          case 'atras':
            return Offset(w * 0.5, h * 0.10);
          case 'izquierda':
            return Offset(w * 0.10, h * 0.90);
          case 'derecha':
            return Offset(w * 0.90, h * 0.90);
        }
    }
    return Offset.zero;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white38 : Colors.black38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final w = size.width;
    final h = size.height;

    switch (tipo) {
      case 'Cuadrada':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.15, h * 0.15, w * 0.70, h * 0.70),
            const Radius.circular(4),
          ),
          paint,
        );
      case 'Rectangular':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.25, w * 0.76, h * 0.50),
            const Radius.circular(4),
          ),
          paint,
        );
      case 'Circular':
        canvas.drawOval(
          Rect.fromLTWH(w * 0.10, h * 0.10, w * 0.80, h * 0.80),
          paint,
        );
      case 'Triangular':
        final path = Path()
          ..moveTo(w * 0.5, h * 0.10)
          ..lineTo(w * 0.90, h * 0.90)
          ..lineTo(w * 0.10, h * 0.90)
          ..close();
        canvas.drawPath(path, paint);
    }

    if (posicionIndicador != null) {
      final pos = _getIndicatorPos(posicionIndicador!, w, h);
      final label = '$cargaValue $unidad';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pw = (tp.width + 16).clamp(40.0, 100.0);
      final ph = (tp.height + 10).clamp(22.0, 36.0);
      final r = Rect.fromCenter(center: pos, width: pw, height: ph);

      final ip = Paint()
        ..color = Colors.teal
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(5)), ip);
      ip
        ..color = Colors.teal.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(
          RRect.fromRectAndRadius(r.inflate(6), const Radius.circular(8)), ip);

      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _PlatformPainter old) =>
      old.tipo != tipo ||
      old.isDark != isDark ||
      old.posicionIndicador != posicionIndicador ||
      old.cargaValue != cargaValue ||
      old.unidad != unidad;
}
