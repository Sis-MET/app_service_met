// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/utils/top_alert.dart';

class BalanzaStep extends StatefulWidget {
  const BalanzaStep({super.key});

  @override
  State<BalanzaStep> createState() => _BalanzaStepState();
}

class _BalanzaStepState extends State<BalanzaStep> {
  final CalibrationRepository _repository = CalibrationRepository();

  // Form controllers
  final _codMetricaCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();
  final _tecnologiaCtrl = TextEditingController();
  final _claseCtrl = TextEditingController();
  final _codIntCtrl = TextEditingController();
  final _tipoEquipoCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _serieCtrl = TextEditingController();
  final _unidadesCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  final _rangoCtrl = TextEditingController();
  final _nCeldasCtrl = TextEditingController();
  final _capMax1Ctrl = TextEditingController();
  final _d1Ctrl = TextEditingController();
  final _e1Ctrl = TextEditingController();
  final _dec1Ctrl = TextEditingController();
  final _capMax2Ctrl = TextEditingController(text: '0');
  final _d2Ctrl = TextEditingController(text: '0');
  final _e2Ctrl = TextEditingController(text: '0');
  final _dec2Ctrl = TextEditingController(text: '0');
  final _capMax3Ctrl = TextEditingController(text: '0');
  final _d3Ctrl = TextEditingController(text: '0');
  final _e3Ctrl = TextEditingController(text: '0');
  final _dec3Ctrl = TextEditingController(text: '0');
  final _nRecaCtrl = TextEditingController();
  final _stickerCtrl = TextEditingController();

  List<Map<String, dynamic>> _balanzas = [];
  List<Map<String, dynamic>> _equipamientos = [];
  List<EquipoInfo> _selectedPesas = [];
  List<EquipoInfo> _selectedMedicion = [];
  bool _isLoadingBalanzas = false;
  bool _isLoadingEquipamientos = false;
  bool _isNewBalanza = false;
  Map<String, dynamic>? _selectedBalanza;

  static const List<String> _categorias = ['STAC', 'STIL'];
  static const List<String> _unidades = ['kg', 'g', 'mg', 't', 'lb', 'N'];
  static const List<String> _tiposEquipo = [
    'Balanza Industrial',
    'Balanza de Precisión',
    'Báscula',
    'Balanza de Piso',
    'Balanza Colgante'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBalanzas();
      _loadEquipamientos();
      _initFromSession();
    });
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final session = provider.session;
    if (session == null) return;

    final b = session.balanza;
    if (b != null) {
      _codMetricaCtrl.text = b.codMetrica ?? '';
      _categoriaCtrl.text = b.categoria ?? '';
      _tecnologiaCtrl.text = b.tecnologia ?? '';
      _claseCtrl.text = b.clase ?? '';
      _codIntCtrl.text = b.codInterno ?? '';
      _tipoEquipoCtrl.text = b.tipo ?? '';
      _marcaCtrl.text = b.marca ?? '';
      _modeloCtrl.text = b.modelo ?? '';
      _serieCtrl.text = b.serie ?? '';
      _unidadesCtrl.text = b.unidad ?? '';
      _ubicacionCtrl.text = b.ubicacion ?? '';
      _rangoCtrl.text = b.rango ?? '';
      _nCeldasCtrl.text = b.nCeldas ?? '';
      _capMax1Ctrl.text = b.capMax1 ?? '';
      _d1Ctrl.text = b.d1?.toString() ?? '';
      _e1Ctrl.text = b.e1?.toString() ?? '';
      _dec1Ctrl.text = b.dec1?.toString() ?? '';
      _capMax2Ctrl.text = b.capMax2 ?? '0';
      _d2Ctrl.text = b.d2?.toString() ?? '0';
      _e2Ctrl.text = b.e2?.toString() ?? '0';
      _dec2Ctrl.text = b.dec2?.toString() ?? '0';
      _capMax3Ctrl.text = b.capMax3 ?? '0';
      _d3Ctrl.text = b.d3?.toString() ?? '0';
      _e3Ctrl.text = b.e3?.toString() ?? '0';
      _dec3Ctrl.text = b.dec3?.toString() ?? '0';
    }
    final si = session.sessionInfo;
    _nRecaCtrl.text = si.nReca ?? '';
    _stickerCtrl.text = si.sticker ?? '';
    _initEquiposFromSession(session.equipos);
  }

  void _initEquiposFromSession(List<EquipoInfo> equipos) {
    _selectedPesas = [];
    _selectedMedicion = [];
    for (int i = 0; i < equipos.length; i++) {
      final equipo = equipos[i];
      if (_isPesaTipo(equipo.tipo) || i < 5) {
        if (_selectedPesas.length < 5) _selectedPesas.add(equipo);
      } else if (_selectedMedicion.length < 2) {
        _selectedMedicion.add(equipo);
      }
    }
  }

  Future<void> _loadBalanzas() async {
    setState(() => _isLoadingBalanzas = true);
    final provider = context.read<ServiceSessionProvider>();
    final clienteCod = provider.session?.cliente?.codigoCliente;
    final plantaCod = provider.session?.planta?.codigo;
    final result = await _repository.getBalanzas(clienteCod, plantaCod);

    // Convertir a una lista mutable ya que sqflite devuelve una lista de solo lectura
    final mutableResult = List<Map<String, dynamic>>.from(result);

    // Ordenamiento natural (numérico y alfabético) por cod_metrica
    mutableResult.sort((a, b) {
      final codeA = a['cod_metrica']?.toString() ?? '';
      final codeB = b['cod_metrica']?.toString() ?? '';

      final RegExp regExp = RegExp(r'(\d+)|(\D+)');
      final matchesA =
          regExp.allMatches(codeA).map((m) => m.group(0)!).toList();
      final matchesB =
          regExp.allMatches(codeB).map((m) => m.group(0)!).toList();

      for (var i = 0; i < matchesA.length && i < matchesB.length; i++) {
        final partA = matchesA[i];
        final partB = matchesB[i];
        if (partA != partB) {
          final numA = int.tryParse(partA);
          final numB = int.tryParse(partB);
          if (numA != null && numB != null) {
            return numA.compareTo(numB);
          }
          return partA.compareTo(partB);
        }
      }
      return matchesA.length.compareTo(matchesB.length);
    });

    if (!mounted) return;

    final savedCodMetrica = provider.session?.balanza?.codMetrica;

    setState(() {
      _balanzas = mutableResult;
      _isLoadingBalanzas = false;

      // Restore selected balanza state after navigating back to this step
      if (savedCodMetrica != null && savedCodMetrica.isNotEmpty) {
        final match = result.firstWhere(
          (b) => b['cod_metrica']?.toString() == savedCodMetrica,
          orElse: () => <String, dynamic>{},
        );

        if (match.isNotEmpty) {
          // Found it in the DB list → restore as "selected"
          _selectedBalanza = match;
          _isNewBalanza = false;
        } else {
          // Not in the list → was entered as a new balanza
          _isNewBalanza = true;
          _selectedBalanza = null;
        }
      }
    });
  }

  Future<void> _loadEquipamientos() async {
    setState(() => _isLoadingEquipamientos = true);
    final result = await _repository.getEquipos();
    final mutableResult = List<Map<String, dynamic>>.from(result);
    mutableResult.sort((a, b) {
      final typeA = a['instrumento']?.toString() ?? '';
      final typeB = b['instrumento']?.toString() ?? '';
      final codeA = a['cod_instrumento']?.toString() ?? '';
      final codeB = b['cod_instrumento']?.toString() ?? '';
      final typeCompare = typeA.compareTo(typeB);
      return typeCompare != 0 ? typeCompare : codeA.compareTo(codeB);
    });
    if (!mounted) return;
    setState(() {
      _equipamientos = mutableResult;
      _isLoadingEquipamientos = false;
    });
  }

  void _fillFromMap(Map<String, dynamic> b) {
    _codMetricaCtrl.text = b['cod_metrica']?.toString() ?? '';
    _categoriaCtrl.text = b['categoria']?.toString() ?? '';
    _tecnologiaCtrl.text = b['tecnologia']?.toString() ?? '';
    _claseCtrl.text = b['clase']?.toString() ?? '';
    _codIntCtrl.text = b['cod_interno']?.toString() ?? '';
    final tipoInst = b['tipo_instrumento']?.toString() ?? '';
    final inst = b['instrumento']?.toString() ?? '';
    final tipo = b['tipo']?.toString() ?? '';
    _tipoEquipoCtrl.text =
        tipoInst.isNotEmpty ? tipoInst : (inst.isNotEmpty ? inst : tipo);
    _marcaCtrl.text = b['marca']?.toString() ?? '';
    _modeloCtrl.text = b['modelo']?.toString() ?? '';
    _serieCtrl.text =
        b['inf_serie']?.toString() ?? b['serie']?.toString() ?? '';
    _unidadesCtrl.text = b['unidad']?.toString() ?? '';
    _ubicacionCtrl.text = b['ubicacion']?.toString() ?? '';
    _rangoCtrl.text = b['rango']?.toString() ?? '';
    _nCeldasCtrl.text = b['n_celdas']?.toString() ?? '';
    _capMax1Ctrl.text = b['cap_max1']?.toString() ?? '';
    _d1Ctrl.text = b['d1']?.toString() ?? '';
    _e1Ctrl.text = b['e1']?.toString() ?? '';
    _dec1Ctrl.text = b['dec1']?.toString() ?? '';
    _capMax2Ctrl.text = b['cap_max2']?.toString() ?? '0';
    _d2Ctrl.text = b['d2']?.toString() ?? '0';
    _e2Ctrl.text = b['e2']?.toString() ?? '0';
    _dec2Ctrl.text = b['dec2']?.toString() ?? '0';
    _capMax3Ctrl.text = b['cap_max3']?.toString() ?? '0';
    _d3Ctrl.text = b['d3']?.toString() ?? '0';
    _e3Ctrl.text = b['e3']?.toString() ?? '0';
    _dec3Ctrl.text = b['dec3']?.toString() ?? '0';
  }

  void _saveToProvider(ServiceSessionProvider provider) {
    provider.updateBalanza(BalanzaInfo(
      codMetrica: _codMetricaCtrl.text,
      categoria: _categoriaCtrl.text,
      // tecnologia: solo visual, no se persiste
      // clase: solo visual, no se persiste
      codInterno: _codIntCtrl.text,
      tipo: _tipoEquipoCtrl.text,
      marca: _marcaCtrl.text,
      modelo: _modeloCtrl.text,
      serie: _serieCtrl.text,
      unidad: _unidadesCtrl.text,
      ubicacion: _ubicacionCtrl.text,
      rango: _rangoCtrl.text,
      nCeldas: _nCeldasCtrl.text,
      capMax1: _capMax1Ctrl.text,
      d1: double.tryParse(_d1Ctrl.text),
      e1: double.tryParse(_e1Ctrl.text),
      dec1: double.tryParse(_dec1Ctrl.text),
      capMax2: _capMax2Ctrl.text,
      d2: double.tryParse(_d2Ctrl.text),
      e2: double.tryParse(_e2Ctrl.text),
      dec2: double.tryParse(_dec2Ctrl.text),
      capMax3: _capMax3Ctrl.text,
      d3: double.tryParse(_d3Ctrl.text),
      e3: double.tryParse(_e3Ctrl.text),
      dec3: double.tryParse(_dec3Ctrl.text),
    ));
    provider.updateSessionInfo(provider.session!.sessionInfo.copyWith(
      nReca: _nRecaCtrl.text,
      sticker: _stickerCtrl.text,
      codMetrica: _codMetricaCtrl.text,
    ));
    provider.updateEquipos([..._selectedPesas, ..._selectedMedicion]);
    provider.setBalanzaConfirmed(false);
  }

  @override
  void dispose() {
    for (final c in [
      _codMetricaCtrl,
      _categoriaCtrl,
      _tecnologiaCtrl,
      _claseCtrl,
      _codIntCtrl,
      _tipoEquipoCtrl,
      _marcaCtrl,
      _modeloCtrl,
      _serieCtrl,
      _unidadesCtrl,
      _ubicacionCtrl,
      _rangoCtrl,
      _nCeldasCtrl,
      _capMax1Ctrl,
      _d1Ctrl,
      _e1Ctrl,
      _dec1Ctrl,
      _capMax2Ctrl,
      _d2Ctrl,
      _e2Ctrl,
      _dec2Ctrl,
      _capMax3Ctrl,
      _d3Ctrl,
      _e3Ctrl,
      _dec3Ctrl,
      _nRecaCtrl,
      _stickerCtrl,
    ]) {
      c.dispose();
    }
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

              // RECA + Sticker
              _buildRecaStickerRow(provider, isDark),
              const SizedBox(height: 24),

              // Botones de acción
              _buildActionButtons(provider),
              const SizedBox(height: 24),

              // Formulario si hay selección
              if (_selectedBalanza != null || _isNewBalanza) ...[
                _buildBalanzaForm(provider, isDark),
                const SizedBox(height: 24),
                _buildRangosSection(isDark),
                const SizedBox(height: 24),
                _buildEquipamientosSection(provider, isDark),
              ],
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
          'Instrumento',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Selecciona o registra el instrumento a calibrar',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildRecaStickerRow(ServiceSessionProvider provider, bool isDark) {
    return Row(
      children: [
        Expanded(
            child: _field(_nRecaCtrl, 'N° RECA *', Icons.assignment,
                onChanged: (_) => _saveToProvider(provider), isDark: isDark)),
        const SizedBox(width: 12),
        Expanded(
            child: _field(_stickerCtrl, 'N° Sticker *', Icons.local_offer,
                onChanged: (_) => _saveToProvider(provider), isDark: isDark)),
      ],
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2);
  }

  Widget _buildActionButtons(ServiceSessionProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _isLoadingBalanzas ? null : () => _showSearchDialog(provider),
            icon: _isLoadingBalanzas
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search, size: 18),
            label: const Text('Buscar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF326677),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isNewBalanza = true;
                _selectedBalanza = null;
              });
              _codMetricaCtrl.text = _suggestNewCodMetrica();
              _capMax2Ctrl.text = '0';
              _d2Ctrl.text = '0';
              _e2Ctrl.text = '0';
              _dec2Ctrl.text = '0';
              _capMax3Ctrl.text = '0';
              _d3Ctrl.text = '0';
              _e3Ctrl.text = '0';
              _dec3Ctrl.text = '0';
              _saveToProvider(provider);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF327734),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2);
  }

  Widget _buildBalanzaForm(ServiceSessionProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isNewBalanza
                    ? Icons.add_circle_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: _isNewBalanza
                    ? (isDark
                        ? const Color(0xFF81C784)
                        : const Color(0xFF2E7D32))
                    : (isDark
                        ? const Color(0xFF64B5F6)
                        : const Color(0xFF1565C0)),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                _isNewBalanza
                    ? 'Nuevo Instrumento'
                    : 'Instrumento Seleccionado',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isNewBalanza
                        ? (isDark
                            ? const Color(0xFF81C784)
                            : const Color(0xFF2E7D32))
                        : (isDark
                            ? const Color(0xFF64B5F6)
                            : const Color(0xFF1565C0))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _field(_codMetricaCtrl, 'Código Métrica', Icons.qr_code,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _dropdownField('Categoría', Icons.category, _categorias,
              _categoriaCtrl, provider, isDark: isDark),
          const SizedBox(height: 12),
          _field(_tecnologiaCtrl, 'Tecnología', Icons.memory,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _field(_claseCtrl, 'Clase', Icons.class_,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _field(_codIntCtrl, 'Código Interno', Icons.tag,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _dropdownField('Tipo de Equipo', Icons.scale, _tiposEquipo,
              _tipoEquipoCtrl, provider, isDark: isDark),
          const SizedBox(height: 12),
          _field(_marcaCtrl, 'Marca', Icons.business,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _field(_modeloCtrl, 'Modelo', Icons.precision_manufacturing,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _field(_serieCtrl, 'Serie', Icons.confirmation_number,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _dropdownField(
              'Unidad', Icons.straighten, _unidades, _unidadesCtrl, provider,
              isDark: isDark),
          const SizedBox(height: 12),
          _field(_ubicacionCtrl, 'Ubicación', Icons.location_on,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _field(_rangoCtrl, 'Rango', Icons.linear_scale,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _field(_nCeldasCtrl, 'N° Celdas', Icons.grid_view,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3);
  }

  Widget _buildRangosSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded,
                color: isDark ? Colors.white54 : Colors.black54, size: 20),
            const SizedBox(width: 8),
            Text('Rangos de Intervalo',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          ],
        ),
        const SizedBox(height: 16),
        _rangoCard(
            'Rango 1', _capMax1Ctrl, _d1Ctrl, _e1Ctrl, _dec1Ctrl, isDark),
        const SizedBox(height: 12),
        _rangoCard(
            'Rango 2', _capMax2Ctrl, _d2Ctrl, _e2Ctrl, _dec2Ctrl, isDark),
        const SizedBox(height: 12),
        _rangoCard(
            'Rango 3', _capMax3Ctrl, _d3Ctrl, _e3Ctrl, _dec3Ctrl, isDark),
      ],
    ).animate(delay: 500.ms).fadeIn();
  }

  Widget _buildEquipamientosSection(
      ServiceSessionProvider provider, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2_outlined,
                color: isDark ? Colors.white54 : Colors.black54, size: 20),
            const SizedBox(width: 8),
            Text('Equipamiento del Servicio',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoadingEquipamientos
                    ? null
                    : () => _showEquipamientosDialog(
                          provider: provider,
                          isPesas: true,
                        ),
                icon: const Icon(Icons.fitness_center, size: 18),
                label: Text('Pesas (${_selectedPesas.length}/5)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF365666),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF365666).withOpacity(0.45),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoadingEquipamientos
                    ? null
                    : () => _showEquipamientosDialog(
                          provider: provider,
                          isPesas: false,
                        ),
                icon: const Icon(Icons.thermostat, size: 18),
                label: Text('Ambiente (${_selectedMedicion.length}/2)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF326677),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF326677).withOpacity(0.45),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedPesas.isEmpty && _selectedMedicion.isEmpty)
          _emptyEquiposHint(isDark)
        else ...[
          ..._selectedPesas
              .map((e) => _selectedEquipoTile(e, true, provider, isDark)),
          ..._selectedMedicion
              .map((e) => _selectedEquipoTile(e, false, provider, isDark)),
        ],
      ],
    ).animate(delay: 550.ms).fadeIn();
  }

  Widget _emptyEquiposHint(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        'Seleccione al menos una pesa patron y un termohigometro, barometro o instrumento de medicion.',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }

  Widget _selectedEquipoTile(
    EquipoInfo equipo,
    bool isPesa,
    ServiceSessionProvider provider,
    bool isDark,
  ) {
    final cert = _certStatus(equipo.certFecha);
    return Card(
      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isPesa ? Icons.fitness_center : Icons.thermostat,
          color: cert.color,
        ),
        title: Text(equipo.codInstrumento ?? 'Sin codigo'),
        subtitle: Text(
          '${equipo.tipo ?? 'Instrumento'} | Cert: ${equipo.certFecha ?? 'S/F'} | ${cert.label}',
        ),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Cant. ${equipo.cantidad ?? '1'}'),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _editCantidad(equipo, isPesa, provider),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() {
                  final target = isPesa ? _selectedPesas : _selectedMedicion;
                  target.removeWhere(
                      (e) => e.codInstrumento == equipo.codInstrumento);
                });
                _saveToProvider(provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangoCard(
      String title,
      TextEditingController capCtrl,
      TextEditingController dCtrl,
      TextEditingController eCtrl,
      TextEditingController decCtrl,
      bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(title,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _numField(capCtrl, 'Cap. Max', isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(child: _numField(dCtrl, 'd', isDark: isDark)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _numField(eCtrl, 'e', isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(child: _numField(decCtrl, 'Dec.', isDark: isDark)),
          ]),
        ],
      ),
    );
  }

  // --- Helpers de widgets ---

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool readOnly = false, void Function(String)? onChanged,
      required bool isDark}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      onChanged: onChanged,
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            color: isDark ? Colors.white70 : Colors.black87),
        prefixIcon: Icon(icon,
            color: isDark ? Colors.white54 : Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        filled: readOnly,
        fillColor: readOnly
            ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05))
            : null,
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label,
      {required bool isDark}) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            color: isDark ? Colors.white70 : Colors.black87),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _dropdownField(String label, IconData icon, List<String> items,
      TextEditingController ctrl, ServiceSessionProvider provider,
      {required bool isDark}) {
    final currentList = List<String>.from(items);
    if (ctrl.text.isNotEmpty && !currentList.contains(ctrl.text)) {
      currentList.add(ctrl.text);
    }
    final current = currentList.contains(ctrl.text) ? ctrl.text : null;
    return DropdownButtonFormField<String>(
      value: current,
      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            color: isDark ? Colors.white70 : Colors.black87),
        prefixIcon: Icon(icon,
            color: isDark ? Colors.white54 : Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      items: currentList
          .map((v) => DropdownMenuItem(
              value: v,
              child: Text(v,
                  style: GoogleFonts.inter(
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A1A)))))
          .toList(),
      onChanged: (v) {
        ctrl.text = v ?? '';
        _saveToProvider(provider);
      },
    );
  }

  String _suggestNewCodMetrica() {
    final provider = context.read<ServiceSessionProvider>();
    final cliente = provider.session?.cliente?.codigoCliente?.trim() ?? '';
    final plantaRaw = provider.session?.planta?.codigo?.trim() ?? '';
    final planta =
        plantaRaw.contains('-') ? plantaRaw.split('-').last : plantaRaw;
    final now = DateTime.now();
    final stamp = '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${(now.year % 100).toString().padLeft(2, '0')}';
    if (cliente.isEmpty && planta.isEmpty) return 'NUEVO-$stamp';
    if (plantaRaw.contains('-')) return '$plantaRaw-($stamp)';
    return '$cliente-$planta-($stamp)';
  }

  bool _isPesaTipo(String? value) {
    final v = value?.toLowerCase() ?? '';
    return v.contains('pesa') ||
        v.contains('masa') ||
        v.contains('patron') ||
        v.contains('patr');
  }

  String _instrumentType(Map<String, dynamic> eq) {
    final instrumento = eq['instrumento']?.toString() ?? '';
    final tipo = eq['tipo_instrumento']?.toString() ?? '';
    return instrumento.isNotEmpty ? instrumento : tipo;
  }

  _CertStatus _certStatus(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return _CertStatus('Sin fecha', Colors.grey, 999999);
    }
    final date = DateTime.tryParse(raw.trim());
    if (date == null) return _CertStatus('Fecha invalida', Colors.grey, 999999);
    final elapsed = DateTime.now().difference(date).inDays;
    final remaining = 365 - elapsed;
    if (elapsed > 365) return _CertStatus('Vencido', Colors.red, remaining);
    if (remaining <= 90) {
      return _CertStatus(
          'Por vencer ($remaining dias)', Colors.amber[800]!, remaining);
    }
    return _CertStatus('Vigente ($remaining dias)', Colors.green, remaining);
  }

  EquipoInfo _equipoFromMap(Map<String, dynamic> eq) {
    final cert = _certStatus(eq['cert_fecha']?.toString());
    return EquipoInfo(
      codInstrumento: eq['cod_instrumento']?.toString() ?? '',
      tipo: _instrumentType(eq),
      cantidad: '1',
      certFecha: eq['cert_fecha']?.toString() ?? '',
      enteCalibrador: eq['ente_calibrador']?.toString() ?? '',
      estado: cert.label,
    );
  }

  void _saveEquipoSelection(
    Map<String, dynamic> eq,
    bool isPesas,
    ServiceSessionProvider provider,
  ) {
    final equipo = _equipoFromMap(eq);
    final cert = _certStatus(equipo.certFecha);
    setState(() {
      final target = isPesas ? _selectedPesas : _selectedMedicion;
      final max = isPesas ? 5 : 2;
      if (target.any((e) => e.codInstrumento == equipo.codInstrumento)) {
        target.removeWhere((e) => e.codInstrumento == equipo.codInstrumento);
      } else if (target.length < max) {
        target.add(equipo);
      }
    });
    _saveToProvider(provider);
    if (cert.remainingDays < 0 && mounted) {
      TopAlert.show(
        context,
        '${equipo.codInstrumento} tiene certificado vencido.',
        isError: true,
      );
    }
  }

  Future<void> _editCantidad(
    EquipoInfo equipo,
    bool isPesas,
    ServiceSessionProvider provider,
  ) async {
    final ctrl = TextEditingController(text: equipo.cantidad ?? '1');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad',
            style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
        content: TextField(
          controller: ctrl,
          style: GoogleFonts.inter(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Cantidad a llevar',
            labelStyle: GoogleFonts.inter(
                color: isDark ? Colors.white70 : Colors.black87),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: isDark ? Colors.white24 : Colors.black26),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.inter(
                    color: isDark ? Colors.white70 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF326677),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    setState(() {
      final target = isPesas ? _selectedPesas : _selectedMedicion;
      final idx =
          target.indexWhere((e) => e.codInstrumento == equipo.codInstrumento);
      if (idx >= 0) target[idx] = target[idx].copyWith(cantidad: value);
    });
    _saveToProvider(provider);
  }

  void _showEquipamientosDialog({
    required ServiceSessionProvider provider,
    required bool isPesas,
  }) {
    final searchCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isPesas ? 'Seleccionar Pesas Patron' : 'Seleccionar Ambiente';
    final filteredBase = _equipamientos.where((eq) {
      final type = _instrumentType(eq);
      return isPesas ? _isPesaTipo(type) : !_isPesaTipo(type);
    }).toList();
    List<Map<String, dynamic>> filtered = List.from(filteredBase);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por codigo o tipo...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF0F2F5),
                ),
                onChanged: (q) => setSheet(() {
                  final low = q.toLowerCase();
                  filtered = filteredBase.where((eq) {
                    final code =
                        eq['cod_instrumento']?.toString().toLowerCase() ?? '';
                    final type = _instrumentType(eq).toLowerCase();
                    return code.contains(low) || type.contains(low);
                  }).toList();
                }),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados',
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final eq = filtered[i];
                          final code =
                              eq['cod_instrumento']?.toString() ?? 'Sin codigo';
                          final type = _instrumentType(eq);
                          final cert =
                              _certStatus(eq['cert_fecha']?.toString());
                          final target =
                              isPesas ? _selectedPesas : _selectedMedicion;
                          final selected =
                              target.any((e) => e.codInstrumento == code);
                          final canSelect =
                              selected || target.length < (isPesas ? 5 : 2);
                          return InkWell(
                            onTap: canSelect
                                ? () {
                                    _saveEquipoSelection(eq, isPesas, provider);
                                    setSheet(() {});
                                  }
                                : null,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? Colors.teal
                                      : (isDark
                                          ? Colors.white12
                                          : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: selected ? Colors.teal : cert.color,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          code,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(type,
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white60
                                                    : Colors.black54)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Cert: ${eq['cert_fecha'] ?? 'S/F'} | ${cert.label}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: cert.color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // --- Diálogo de búsqueda ---

  void _showSearchDialog(ServiceSessionProvider provider) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(_balanzas);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de arrastre
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Buscar Instrumento',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchCtrl,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'Buscar por código, serie o marca...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: isDark ? Colors.white54 : Colors.black38,
                      size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: isDark ? Colors.white54 : Colors.black38,
                              size: 18),
                          onPressed: () {
                            searchCtrl.clear();
                            setSheet(() => filtered = List.from(_balanzas));
                          })
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (q) => setSheet(() {
                  filtered = q.isEmpty
                      ? List.from(_balanzas)
                      : _balanzas.where((b) {
                          final low = q.toLowerCase();
                          return (b['cod_metrica']?.toString().toLowerCase() ??
                                      '')
                                  .contains(low) ||
                              (b['serie']?.toString().toLowerCase() ?? '')
                                  .contains(low) ||
                              (b['marca']?.toString().toLowerCase() ?? '')
                                  .contains(low) ||
                              (b['cod_interno']?.toString().toLowerCase() ?? '')
                                  .contains(low);
                        }).toList();
                }),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48,
                                color:
                                    isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 12),
                            Text(
                              'Sin resultados',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final b = filtered[i];
                          final codMetrica =
                              b['cod_metrica']?.toString() ?? 'Sin código';
                          final marca =
                              b['marca']?.toString() ?? 'No especificada';
                          final codInterno =
                              b['cod_interno']?.toString() ?? 'No especificado';
                          final serie =
                              b['serie']?.toString() ?? 'No especificada';

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedBalanza = b;
                                _isNewBalanza = false;
                              });
                              _fillFromMap(b);
                              _saveToProvider(provider);
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: isDark
                                        ? Colors.white12
                                        : const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          codMetrica,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFFf9e300)
                                                : const Color(0xFF5A4E00),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _infoSearchRow('Marca', marca, isDark),
                                        const SizedBox(height: 4),
                                        _infoSearchRow(
                                            'Cód. Interno', codInterno, isDark),
                                        const SizedBox(height: 4),
                                        _infoSearchRow('Serie', serie, isDark),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Icon(Icons.chevron_right_rounded,
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.black26),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  Widget _infoSearchRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CertStatus {
  final String label;
  final Color color;
  final int remainingDays;

  const _CertStatus(this.label, this.color, this.remainingDays);
}
