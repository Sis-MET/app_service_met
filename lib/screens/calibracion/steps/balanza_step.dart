// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';

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
  bool _isLoadingBalanzas = false;
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
      final matchesA = regExp.allMatches(codeA).map((m) => m.group(0)!).toList();
      final matchesB = regExp.allMatches(codeB).map((m) => m.group(0)!).toList();
      
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
    ));
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
              _buildRecaStickerRow(provider),
              const SizedBox(height: 24),

              // Botones de acción
              _buildActionButtons(provider),
              const SizedBox(height: 24),

              // Formulario si hay selección
              if (_selectedBalanza != null || _isNewBalanza) ...[
                _buildBalanzaForm(provider, isDark),
                const SizedBox(height: 24),
                _buildRangosSection(isDark),
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

  Widget _buildRecaStickerRow(ServiceSessionProvider provider) {
    return Row(
      children: [
        Expanded(
            child: _field(_nRecaCtrl, 'N° RECA *', Icons.assignment,
                onChanged: (_) => _saveToProvider(provider))),
        const SizedBox(width: 12),
        Expanded(
            child: _field(_stickerCtrl, 'N° Sticker *', Icons.local_offer,
                onChanged: (_) => _saveToProvider(provider))),
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
              _codMetricaCtrl.clear();
              _capMax2Ctrl.text = '0';
              _d2Ctrl.text = '0';
              _e2Ctrl.text = '0';
              _dec2Ctrl.text = '0';
              _capMax3Ctrl.text = '0';
              _d3Ctrl.text = '0';
              _e3Ctrl.text = '0';
              _dec3Ctrl.text = '0';
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
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
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
                _isNewBalanza ? Icons.add_circle_outline_rounded : Icons.check_circle_outline_rounded,
                color: _isNewBalanza ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)) : (isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0)),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                _isNewBalanza ? 'Nuevo Instrumento' : 'Instrumento Seleccionado',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isNewBalanza ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)) : (isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _field(_codMetricaCtrl, 'Código Métrica', Icons.qr_code,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _dropdownField('Categoría', Icons.category, _categorias,
              _categoriaCtrl, provider),
          const SizedBox(height: 12),
          _field(_tecnologiaCtrl, 'Tecnología', Icons.memory,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_claseCtrl, 'Clase', Icons.class_,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_codIntCtrl, 'Código Interno', Icons.tag,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _dropdownField('Tipo de Equipo', Icons.scale, _tiposEquipo,
              _tipoEquipoCtrl, provider),
          const SizedBox(height: 12),
          _field(_marcaCtrl, 'Marca', Icons.business,
              onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_modeloCtrl, 'Modelo', Icons.precision_manufacturing,
              onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_serieCtrl, 'Serie', Icons.confirmation_number,
              onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _dropdownField(
              'Unidad', Icons.straighten, _unidades, _unidadesCtrl, provider),
          const SizedBox(height: 12),
          _field(_ubicacionCtrl, 'Ubicación', Icons.location_on,
              onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_rangoCtrl, 'Rango', Icons.linear_scale,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_nCeldasCtrl, 'N° Celdas', Icons.grid_view,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToProvider(provider)),
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
            Icon(Icons.tune_rounded, color: isDark ? Colors.white54 : Colors.black54, size: 20),
            const SizedBox(width: 8),
            Text('Rangos de Intervalo',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          ],
        ),
        const SizedBox(height: 16),
        _rangoCard('Rango 1', _capMax1Ctrl, _d1Ctrl, _e1Ctrl, _dec1Ctrl, isDark),
        const SizedBox(height: 12),
        _rangoCard('Rango 2', _capMax2Ctrl, _d2Ctrl, _e2Ctrl, _dec2Ctrl, isDark),
        const SizedBox(height: 12),
        _rangoCard('Rango 3', _capMax3Ctrl, _d3Ctrl, _e3Ctrl, _dec3Ctrl, isDark),
      ],
    ).animate(delay: 500.ms).fadeIn();
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
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
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
                    fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _numField(capCtrl, 'Cap. Max')),
            const SizedBox(width: 12),
            Expanded(child: _numField(dCtrl, 'd')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _numField(eCtrl, 'e')),
            const SizedBox(width: 12),
            Expanded(child: _numField(decCtrl, 'Dec.')),
          ]),
        ],
      ),
    );
  }

  // --- Helpers de widgets ---

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool readOnly = false, void Function(String)? onChanged}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.withOpacity(0.05) : null,
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _dropdownField(String label, IconData icon, List<String> items,
      TextEditingController ctrl, ServiceSessionProvider provider) {
    final currentList = List<String>.from(items);
    if (ctrl.text.isNotEmpty && !currentList.contains(ctrl.text)) {
      currentList.add(ctrl.text);
    }
    final current = currentList.contains(ctrl.text) ? ctrl.text : null;
    return DropdownButtonFormField<String>(
      value: current,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: currentList
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) {
        ctrl.text = v ?? '';
        _saveToProvider(provider);
      },
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
                style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'Buscar por código, serie o marca...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38),
                  prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : Colors.black38, size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.black38, size: 18),
                          onPressed: () {
                            searchCtrl.clear();
                            setSheet(() => filtered = List.from(_balanzas));
                          })
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
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
                          return (b['cod_metrica']?.toString().toLowerCase() ?? '').contains(low) ||
                              (b['serie']?.toString().toLowerCase() ?? '').contains(low) ||
                              (b['marca']?.toString().toLowerCase() ?? '').contains(low) ||
                              (b['cod_interno']?.toString().toLowerCase() ?? '').contains(low);
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
                            Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
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
                          final codMetrica = b['cod_metrica']?.toString() ?? 'Sin código';
                          final marca = b['marca']?.toString() ?? 'No especificada';
                          final codInterno = b['cod_interno']?.toString() ?? 'No especificado';
                          final serie = b['serie']?.toString() ?? 'No especificada';
                          
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
                                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          codMetrica,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFFf9e300) : const Color(0xFF5A4E00),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _infoSearchRow('Marca', marca, isDark),
                                        const SizedBox(height: 4),
                                        _infoSearchRow('Cód. Interno', codInterno, isDark),
                                        const SizedBox(height: 4),
                                        _infoSearchRow('Serie', serie, isDark),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26),
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
