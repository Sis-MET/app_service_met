// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/calibracion/widgets/qr_scanner_screen.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_controller.dart';
import 'package:service_met/utils/top_alert.dart';

class BalanzaStep extends StatefulWidget {
  final PrecargaController controller;

  const BalanzaStep({
    super.key,
    required this.controller,
  });

  @override
  State<BalanzaStep> createState() => _BalanzaStepState();
}

class _BalanzaStepState extends State<BalanzaStep> {
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

  bool _isNewBalanza = false;
  Map<String, dynamic>? _selectedBalanza;
  Set<String> _completedCodMetricas = {};

  static const List<String> _categorias = ['STAC', 'STIL'];
  static const List<String> _unidades = ['kg', 'g', 'mg', 't', 'lb', 'N'];
  static const List<String> _tiposEquipo = [
    'BALANZA',
    'BALANZA ANALIZADORA DE HUMEDAD',
    'BALANZA ANALÍTICA',
    'BALANZA MECÁNICA',
    'BALANZA ELECTROMECÁNICA',
    'BALANZA ELECTRÓNICA DE DOBLE RANGO',
    'BALANZA ELECTRÓNICA DE TRIPLE RANGO',
    'BALANZA ELECTRÓNICA DE DOBLE INTERVALO',
    'BALANZA ELECTRÓNICA DE TRIPLE INTERVALO',
    'BALANZA SEMIMICROANALÍTICA',
    'BALANZA MICROANALÍTICA',
    'BALANZA ELECTRONICA',
  ];

  @override
  void initState() {
    super.initState();
    _initFromController();
    _loadCompletedCodMetricas();
  }

  Future<void> _loadCompletedCodMetricas() async {
    final c = widget.controller;
    final completed = await c.getCompletedCodMetricas();
    if (mounted) {
      setState(() {
        _completedCodMetricas = completed;
      });
    }
  }

  void _initFromController() {
    final c = widget.controller;
    final inst = c.selectedInstrumentoData;
    if (inst != null) {
      _selectedBalanza = inst;
      _fillFromMap(inst);
    }
  }

  void _fillFromMap(Map<String, dynamic> b) {
    _codMetricaCtrl.text = b['cod_metrica']?.toString() ?? b['codigo']?.toString() ?? '';
    _categoriaCtrl.text = b['categoria']?.toString() ?? 'STAC';
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
    _unidadesCtrl.text = b['unidad']?.toString() ?? 'kg';
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

  void _saveToController() {
    final mapData = {
      'cod_metrica': _codMetricaCtrl.text,
      'codigo': _codMetricaCtrl.text,
      'categoria': _categoriaCtrl.text,
      'tecnologia': _tecnologiaCtrl.text,
      'clase': _claseCtrl.text,
      'cod_interno': _codIntCtrl.text,
      'tipo': _tipoEquipoCtrl.text,
      'tipo_instrumento': _tipoEquipoCtrl.text,
      'instrumento': _tipoEquipoCtrl.text,
      'marca': _marcaCtrl.text,
      'modelo': _modeloCtrl.text,
      'serie': _serieCtrl.text,
      'unidad': _unidadesCtrl.text,
      'ubicacion': _ubicacionCtrl.text,
      'rango': _rangoCtrl.text,
      'n_celdas': _nCeldasCtrl.text,
      'cap_max1': _capMax1Ctrl.text,
      'd1': _d1Ctrl.text,
      'e1': _e1Ctrl.text,
      'dec1': _dec1Ctrl.text,
      'cap_max2': _capMax2Ctrl.text,
      'd2': _d2Ctrl.text,
      'e2': _e2Ctrl.text,
      'dec2': _dec2Ctrl.text,
      'cap_max3': _capMax3Ctrl.text,
      'd3': _d3Ctrl.text,
      'e3': _e3Ctrl.text,
      'dec3': _dec3Ctrl.text,
      'isNew': _isNewBalanza,
    };
    widget.controller.selectInstrumento(mapData);
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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.controller;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),

          // Botones de acción principales: Buscar, Nuevo, QR
          _buildActionButtons(c, isDark),
          const SizedBox(height: 24),

          // Formulario si hay selección o si se eligió Nueva Balanza
          if (_selectedBalanza != null || _isNewBalanza) ...[
            _buildBalanzaForm(c, isDark),
            const SizedBox(height: 24),
            _buildRangosSection(isDark),
          ] else ...[
            _buildEmptyState(isDark),
          ]
        ],
      ),
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
          'Selecciona o registra el instrumento sobre el cual se ejecutará el servicio',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildActionButtons(PrecargaController provider, bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: () => _showSearchDialog(provider),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Buscar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF326677),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isNewBalanza = true;
                _selectedBalanza = null;
              });
              _codMetricaCtrl.text = _suggestNewCodMetrica(provider);
              _categoriaCtrl.text = 'STAC';
              _tecnologiaCtrl.clear();
              _claseCtrl.clear();
              _codIntCtrl.clear();
              _tipoEquipoCtrl.text = 'BALANZA';
              _marcaCtrl.clear();
              _modeloCtrl.clear();
              _serieCtrl.clear();
              _unidadesCtrl.text = 'kg';
              _ubicacionCtrl.clear();
              _rangoCtrl.clear();
              _nCeldasCtrl.clear();
              _capMax1Ctrl.clear();
              _d1Ctrl.clear();
              _e1Ctrl.clear();
              _dec1Ctrl.clear();
              _capMax2Ctrl.text = '0';
              _d2Ctrl.text = '0';
              _e2Ctrl.text = '0';
              _dec2Ctrl.text = '0';
              _capMax3Ctrl.text = '0';
              _d3Ctrl.text = '0';
              _e3Ctrl.text = '0';
              _dec3Ctrl.text = '0';
              _saveToController();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nuevo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF327734),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => _scanQrForBalanza(provider),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF04376E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2);
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.scale_outlined,
            size: 56,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'Ningún instrumento seleccionado',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Utiliza "Buscar", "Nuevo" o "QR" para seleccionar o registrar el equipo.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn();
  }

  Widget _buildBalanzaForm(PrecargaController provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                    ? 'Nuevo Instrumento Registrado'
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
          _field(_codMetricaCtrl, 'Código Métrica', Icons.qr_code_rounded,
              readOnly: !_isNewBalanza,
              onChanged: (_) => _saveToController(),
              isDark: isDark),
          const SizedBox(height: 12),
          _dropdownField('Categoría', Icons.category_rounded, _categorias,
              _categoriaCtrl, isDark: isDark),
          const SizedBox(height: 12),
          _field(_tecnologiaCtrl, 'Tecnología', Icons.memory_rounded,
              onChanged: (_) => _saveToController(), isDark: isDark),
          const SizedBox(height: 12),
          _field(_claseCtrl, 'Clase', Icons.class_rounded,
              onChanged: (_) => _saveToController(), isDark: isDark),
          const SizedBox(height: 12),
          _field(_codIntCtrl, 'Código Interno', Icons.tag_rounded,
              onChanged: (_) => _saveToController(), isDark: isDark),
          const SizedBox(height: 12),
          _dropdownField('Tipo de Equipo', Icons.scale_rounded, _tiposEquipo,
              _tipoEquipoCtrl, isDark: isDark),
          const SizedBox(height: 12),
          _field(_marcaCtrl, 'Marca', Icons.business_rounded,
              onChanged: (_) => _saveToController(), isDark: isDark),
          const SizedBox(height: 12),
          _field(_modeloCtrl, 'Modelo', Icons.precision_manufacturing_rounded,
              onChanged: (_) => _saveToController(), isDark: isDark),
          const SizedBox(height: 12),
          _field(_serieCtrl, 'Serie', Icons.confirmation_number_rounded,
              onChanged: (_) => _saveToController(), isDark: isDark),
          const SizedBox(height: 12),
          _dropdownField(
              'Unidad', Icons.straighten_rounded, _unidades, _unidadesCtrl,
              isDark: isDark),
          const SizedBox(height: 12),
          _field(_ubicacionCtrl, 'Ubicación', Icons.location_on_rounded,
              onChanged: (_) => _saveToController(), isDark: isDark),
          const SizedBox(height: 12),
          _field(_rangoCtrl, 'Rango', Icons.linear_scale_rounded,
              onChanged: (_) => _saveToController(), isDark: isDark),
          const SizedBox(height: 12),
          _field(_nCeldasCtrl, 'N° Celdas', Icons.grid_view_rounded,
              onChanged: (_) => _saveToController(), isDark: isDark),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2);
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
    ).animate(delay: 400.ms).fadeIn();
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
        borderRadius: BorderRadius.circular(14),
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

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool readOnly = false,
      void Function(String)? onChanged,
      required bool isDark}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      onChanged: (v) {
        if (onChanged != null) onChanged(v);
        _saveToController();
      },
      style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.black54),
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
            ? (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.05))
            : null,
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label,
      {required bool isDark}) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => _saveToController(),
      style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
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
      TextEditingController ctrl,
      {required bool isDark}) {
    final currentList = List<String>.from(items);
    if (ctrl.text.isNotEmpty && !currentList.contains(ctrl.text)) {
      currentList.add(ctrl.text);
    }
    final current = currentList.contains(ctrl.text) ? ctrl.text : null;
    return DropdownButtonFormField<String>(
      value: current,
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.black54),
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
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A)))))
          .toList(),
      onChanged: (v) {
        ctrl.text = v ?? '';
        _saveToController();
      },
    );
  }

  String _suggestNewCodMetrica(PrecargaController provider) {
    final codPlanta = provider.plantaCodigo ?? 'PLANTA';
    final now = DateTime.now();
    final stamp = '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}';
    return '$codPlanta-$stamp';
  }

  List<Map<String, dynamic>> _sortInstrumentos(List<Map<String, dynamic>> list) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      final aCod = a['cod_metrica']?.toString() ?? '';
      final bCod = b['cod_metrica']?.toString() ?? '';
      return _naturalCompare(aCod, bCod);
    });
    return sorted;
  }

  int _naturalCompare(String a, String b) {
    final aParts =
        RegExp(r'(\d+|\D+)').allMatches(a).map((m) => m.group(1)!).toList();
    final bParts =
        RegExp(r'(\d+|\D+)').allMatches(b).map((m) => m.group(1)!).toList();
    final len = aParts.length < bParts.length ? aParts.length : bParts.length;
    for (int i = 0; i < len; i++) {
      final aNum = int.tryParse(aParts[i]);
      final bNum = int.tryParse(bParts[i]);
      if (aNum != null && bNum != null) {
        if (aNum != bNum) return aNum.compareTo(bNum);
      } else {
        final cmp = aParts[i].compareTo(bParts[i]);
        if (cmp != 0) return cmp;
      }
    }
    return aParts.length.compareTo(bParts.length);
  }

  Future<void> _scanQrForBalanza(PrecargaController provider) async {
    final rawValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (rawValue == null || !mounted) return;

    final codMetrica = rawValue.trim();
    final list = provider.instrumentos;

    final match = list.cast<Map<String, dynamic>?>().firstWhere(
          (b) => b?['cod_metrica']?.toString().trim() == codMetrica ||
                 b?['codigo']?.toString().trim() == codMetrica,
          orElse: () => null,
        );

    if (match != null) {
      setState(() {
        _selectedBalanza = match;
        _isNewBalanza = false;
      });
      _fillFromMap(match);
      _saveToController();
      TopAlert.show(context, 'Instrumento identificado: $codMetrica');
    } else {
      // Si no está en la lista pero vino del QR, lo creamos con el código del QR
      setState(() {
        _isNewBalanza = true;
        _selectedBalanza = null;
      });
      _codMetricaCtrl.text = codMetrica;
      _saveToController();
      TopAlert.show(context, 'Nuevo instrumento registrado por QR: $codMetrica');
    }
  }

  // --- Modal de Búsqueda de Instrumento ---
  void _showSearchDialog(PrecargaController provider) {
    final searchCtrl = TextEditingController();
    final balanzas = provider.instrumentos;
    List<Map<String, dynamic>> filtered = _sortInstrumentos(balanzas);
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
                  hintText: 'Buscar por código, serie, marca o modelo...',
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
                            setSheet(() => filtered = _sortInstrumentos(balanzas));
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
                      ? _sortInstrumentos(balanzas)
                      : _sortInstrumentos(balanzas.where((b) {
                          final low = q.toLowerCase();
                          final cod = b['cod_metrica']?.toString().toLowerCase() ?? '';
                          final serie = b['serie']?.toString().toLowerCase() ?? '';
                          final marca = b['marca']?.toString().toLowerCase() ?? '';
                          final modelo = b['modelo']?.toString().toLowerCase() ?? '';
                          final desc = b['descripcion']?.toString().toLowerCase() ?? '';
                          return cod.contains(low) ||
                              serie.contains(low) ||
                              marca.contains(low) ||
                              modelo.contains(low) ||
                              desc.contains(low);
                        }).toList());
                }),
              ),
              const SizedBox(height: 12),
              Text(
                '${filtered.length} instrumentos disponibles',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black45),
              ),
              const SizedBox(height: 12),
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
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          final cod = item['cod_metrica']?.toString() ??
                              item['codigo']?.toString() ??
                              'Sin código';
                          final marca =
                              item['marca']?.toString() ?? 'No especificada';
                          final codInterno =
                              item['cod_interno']?.toString() ??
                                  'No especificado';
                          final serie =
                              item['serie']?.toString() ?? 'No especificada';

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedBalanza = item;
                                _isNewBalanza = false;
                              });
                              _fillFromMap(item);
                              _saveToController();
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
                                        Row(
                                          children: [
                                            Text(
                                              cod,
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? const Color(0xFFf9e300)
                                                    : const Color(0xFF5A4E00),
                                              ),
                                            ),
                                            if (_completedCodMetricas
                                                .contains(cod)) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color: Colors.green
                                                          .withOpacity(0.4)),
                                                ),
                                                child: Text(
                                                  'Mantenimiento',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green[700],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _infoSearchRow('Marca', marca, isDark),
                                        const SizedBox(height: 4),
                                        _infoSearchRow('Cód. Interno',
                                            codInterno, isDark),
                                        const SizedBox(height: 4),
                                        _infoSearchRow('Serie', serie, isDark),
                                        const SizedBox(height: 4),
                                        _infoSearchRow(
                                            'Tipo',
                                            item['tipo_instrumento']
                                                    ?.toString() ??
                                                item['instrumento']
                                                    ?.toString() ??
                                                'No especificado',
                                            isDark),
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
