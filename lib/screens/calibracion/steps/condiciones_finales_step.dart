import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/utils/top_alert.dart';

class CondicionesFinalesStep extends StatefulWidget {
  const CondicionesFinalesStep({super.key});

  @override
  State<CondicionesFinalesStep> createState() => _CondicionesFinalesStepState();
}

class _CondicionesFinalesStepState extends State<CondicionesFinalesStep> {
  final _horaCtrl = TextEditingController();
  final _hriCtrl = TextEditingController();
  final _tiCtrl = TextEditingController();
  final _patmiCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  String? _mantenimiento;
  String? _ventaPesas;
  String? _reemplazo;

  List<EquipoInfo> _selectedPesas = [];
  List<EquipoInfo> _selectedMedicion = [];
  List<Map<String, dynamic>> _equipamientos = [];
  bool _isLoadingEquipamientos = false;

  String stickerCert = '';
  String stickerFecha = '';
  String stickerCod = '';
  String stickerNro = '';

  @override
  void initState() {
    super.initState();
    _loadEquipamientos();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  Future<void> _loadEquipamientos() async {
    setState(() => _isLoadingEquipamientos = true);
    final result = await CalibrationRepository().getEquipos();
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

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final session = provider.session;
    if (session == null) return;

    final cf = session.condicionesFinales;
    if (cf != null) {
      _horaCtrl.text = cf.horaFin ?? '';
      _hriCtrl.text = cf.hriFin ?? '';
      _tiCtrl.text = cf.tiFin ?? '';
      _patmiCtrl.text = cf.patmiFin ?? '';
      _mantenimiento = cf.mantenimiento;
      _ventaPesas = cf.ventaPesas;
      _reemplazo = cf.reemplazo;
      _obsCtrl.text = cf.observaciones ?? 'Sin Observaciones';
    } else {
      _obsCtrl.text = 'Sin Observaciones';
    }

    _initEquiposFromSession(session.equipos);

    final codParts = session.sessionInfo.codMetrica?.split('-') ?? [];
    final codCliente = codParts.isNotEmpty ? codParts[0] : 'XXXX';
    final secaParts = session.sessionInfo.seca?.split('-') ?? [];
    final cotizacion = secaParts.isNotEmpty ? secaParts.last : 'C0X';
    final gestion = DateTime.now().year.toString().substring(2);

    setState(() {
      stickerCert =
          '$codCliente-$cotizacion-${session.sessionInfo.nReca ?? "SN"}-$gestion';
      stickerFecha = session.sessionInfo.fechaServicio ?? '';
      stickerCod = session.sessionInfo.codMetrica ?? '';
      stickerNro = session.sessionInfo.sticker ?? 'SN';
    });
  }

  void _initEquiposFromSession(List<EquipoInfo> equipos) {
    _selectedPesas = [];
    _selectedMedicion = [];
    for (final equipo in equipos) {
      if (_isPesaTipo(equipo.tipo)) {
        if (_selectedPesas.length < 5) _selectedPesas.add(equipo);
      } else {
        if (_selectedMedicion.length < 2) _selectedMedicion.add(equipo);
      }
    }
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateCondicionesFinales(
        (provider.session?.condicionesFinales ?? CondicionesFinales()).copyWith(
      horaFin: _horaCtrl.text,
      hriFin: _hriCtrl.text,
      tiFin: _tiCtrl.text,
      patmiFin: _patmiCtrl.text,
      mantenimiento: _mantenimiento,
      ventaPesas: _ventaPesas,
      reemplazo: _reemplazo,
      observaciones: _obsCtrl.text,
    ));
    provider.updateEquipos([..._selectedPesas, ..._selectedMedicion]);
  }

  String _currentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _horaCtrl.dispose();
    _hriCtrl.dispose();
    _tiCtrl.dispose();
    _patmiCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<ServiceSessionProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 20),
          _sectionHeader('1. Condiciones Ambientales Finales', isDark),
          _buildHoraField(isDark),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextField(
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                    controller: _hriCtrl,
                    onChanged: (_) => _saveToProvider(),
                    keyboardType: TextInputType.number,
                    decoration: _deco('HRi Fin (%)', isDark))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                    controller: _tiCtrl,
                    onChanged: (_) => _saveToProvider(),
                    keyboardType: TextInputType.number,
                    decoration: _deco('Ti Fin (°C)', isDark))),
          ]),
          const SizedBox(height: 12),
          TextField(
              style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              controller: _patmiCtrl,
              onChanged: (_) => _saveToProvider(),
              keyboardType: TextInputType.number,
              decoration: _deco('Patmi Fin (hPa)', isDark)),
          const SizedBox(height: 24),
          _sectionHeader('2. Recomendaciones', isDark),
          DropdownButtonFormField<String>(
            value: _mantenimiento,
            decoration: _deco('Mantenimiento con ST', isDark),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            items: ['Sí', 'No']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              setState(() => _mantenimiento = v);
              _saveToProvider();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _ventaPesas,
            decoration: _deco('Venta de Pesas', isDark),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            items: ['Sí', 'No']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              setState(() => _ventaPesas = v);
              _saveToProvider();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _reemplazo,
            decoration: _deco('Reemplazo', isDark),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            items: ['Sí', 'No']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              setState(() => _reemplazo = v);
              _saveToProvider();
            },
          ),
          const SizedBox(height: 24),
          _sectionHeader('3. Observaciones / Comentarios', isDark),
          TextField(
              style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              controller: _obsCtrl,
              onChanged: (_) => _saveToProvider(),
              maxLines: 3,
              decoration: _deco('Observaciones', isDark)),
          const SizedBox(height: 24),
          _sectionHeader('4. Selección de Equipamiento', isDark),
          _buildEquipamientosSection(provider, isDark),
          const SizedBox(height: 24),
          _sectionHeader('5. Sticker de Calibrado (Referencial)', isDark),
          _buildSticker(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condiciones Finales',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Registro de condiciones al finalizar la calibración',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
    ).animate().fadeIn();
  }

  Widget _buildHoraField(bool isDark) {
    return TextField(
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _horaCtrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Hora Fin',
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
                  isDark ? const Color(0xFFf9e300) : const Color(0xFF5A4E00)),
          onPressed: () {
            _horaCtrl.text = _currentTime();
            _saveToProvider();
          },
        ),
      ),
    );
  }

  InputDecoration _deco(String label, bool isDark, {Widget? icon}) =>
      InputDecoration(
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
        suffixIcon: icon,
      );

  Widget _buildSticker(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey[300]!),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 160,
            decoration: const BoxDecoration(
                color: Color(0xFFFFD700),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12))),
            child: const RotatedBox(
                quarterTurns: 3,
                child: Center(
                    child: Text('METRICA LTDA',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)))),
          ),
          Expanded(
              child: Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Column(children: [
                  Text('CALIBRADO',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  Text('www.metrica.com.bo',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Certificado:',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                      Text(stickerCert,
                          style: GoogleFonts.caveat(
                              color: Colors.blue[800],
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Fecha de calibración:',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                      Text(stickerFecha,
                          style: GoogleFonts.caveat(
                              color: Colors.blue[800],
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(stickerCod,
                                    style: GoogleFonts.caveat(
                                        color: Colors.blue[800],
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold))),
                            Text('Nº: $stickerNro',
                                style: GoogleFonts.specialElite(
                                    color: Colors.red[800],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ]),
                    ]),
              ),
            ],
          )),
        ],
      ),
    );
  }

  // ── Equipamiento ────────────────────────────────────────────────────────────

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
    );
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
                _saveToProvider();
              },
            ),
          ],
        ),
      ),
    );
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
    _saveToProvider();
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
                '$title (${isPesas ? _selectedPesas.length : _selectedMedicion.length}/${isPesas ? 5 : 2})',
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
                    : _buildEquiposGroupedList(
                        filtered, isPesas, isDark, provider, setSheet),
              ),
            ],
          ),
        );
      }),
    );
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

  String _instrumentSection(String type) {
    final t = type.toLowerCase();
    if (_isPesaTipo(t)) {
      return 'Pesas Patrón';
    }
    if (t.contains('termo') ||
        t.contains('higro') ||
        t.contains('temp') ||
        t.contains('humedad')) {
      return 'Termohigrómetros';
    }
    if (t.contains('baro')) {
      return 'Barómetros';
    }
    return 'Otros Instrumentos';
  }

  Widget _buildEquiposGroupedList(
    List<Map<String, dynamic>> items,
    bool isPesas,
    bool isDark,
    ServiceSessionProvider provider,
    void Function(VoidCallback) setSheet,
  ) {
    final displayItems = <dynamic>[];
    if (isPesas) {
      displayItems.addAll(items);
    } else {
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final eq in items) {
        final section = _instrumentSection(_instrumentType(eq));
        groups.putIfAbsent(section, () => []).add(eq);
      }
      for (final entry in groups.entries) {
        displayItems.add({'_header': true, '_label': entry.key});
        displayItems.addAll(entry.value);
      }
    }

    return ListView.separated(
      itemCount: displayItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = displayItems[i];
        if (item is Map<String, dynamic> && item['_header'] == true) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              item['_label'] as String,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          );
        }
        final eq = item as Map<String, dynamic>;
        return _buildEquipoCard(eq, isPesas, isDark, provider, setSheet);
      },
    );
  }

  Widget _buildEquipoCard(
    Map<String, dynamic> eq,
    bool isPesas,
    bool isDark,
    ServiceSessionProvider provider,
    void Function(VoidCallback) setSheet,
  ) {
    final code = eq['cod_instrumento']?.toString() ?? 'Sin codigo';
    final type = _instrumentType(eq);
    final cert = _certStatus(eq['cert_fecha']?.toString());
    final target = isPesas ? _selectedPesas : _selectedMedicion;
    final selected = target.any((e) => e.codInstrumento == code);
    final canSelect = selected || target.length < (isPesas ? 5 : 2);

    return InkWell(
      onTap: canSelect
          ? () {
              _saveEquipoSelection(eq, isPesas, provider);
              setSheet(() {});
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? (isDark ? Colors.tealAccent : Colors.teal)
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected
                  ? (isDark ? Colors.tealAccent : Colors.teal)
                  : cert.color,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(type,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54)),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cert.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Cert: ${eq['cert_fecha'] ?? 'S/F'} | ${cert.label}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: cert.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    _saveToProvider();
    if (cert.remainingDays < 0 && mounted) {
      TopAlert.show(
        context,
        '${equipo.codInstrumento} tiene certificado vencido.',
        isError: true,
      );
    }
  }
}

class _CertStatus {
  final String label;
  final Color color;
  final int remainingDays;

  const _CertStatus(this.label, this.color, this.remainingDays);
}
