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
  final _categoriaCtrl  = TextEditingController();
  final _tecnologiaCtrl = TextEditingController();
  final _claseCtrl      = TextEditingController();
  final _codIntCtrl     = TextEditingController();
  final _tipoEquipoCtrl = TextEditingController();
  final _marcaCtrl      = TextEditingController();
  final _modeloCtrl     = TextEditingController();
  final _serieCtrl      = TextEditingController();
  final _unidadesCtrl   = TextEditingController();
  final _ubicacionCtrl  = TextEditingController();
  final _rangoCtrl      = TextEditingController();
  final _nCeldasCtrl    = TextEditingController();
  final _capMax1Ctrl    = TextEditingController();
  final _d1Ctrl         = TextEditingController();
  final _e1Ctrl         = TextEditingController();
  final _dec1Ctrl       = TextEditingController();
  final _capMax2Ctrl    = TextEditingController(text: '0');
  final _d2Ctrl         = TextEditingController(text: '0');
  final _e2Ctrl         = TextEditingController(text: '0');
  final _dec2Ctrl       = TextEditingController(text: '0');
  final _capMax3Ctrl    = TextEditingController(text: '0');
  final _d3Ctrl         = TextEditingController(text: '0');
  final _e3Ctrl         = TextEditingController(text: '0');
  final _dec3Ctrl       = TextEditingController(text: '0');
  final _nRecaCtrl      = TextEditingController();
  final _stickerCtrl    = TextEditingController();

  List<Map<String, dynamic>> _balanzas = [];
  bool _isLoadingBalanzas = false;
  bool _isNewBalanza = false;
  Map<String, dynamic>? _selectedBalanza;

  static const List<String> _categorias   = ['STAC', 'STIL'];
  static const List<String> _unidades     = ['kg', 'g', 'mg', 't', 'lb', 'N'];
  static const List<String> _tiposEquipo  = ['Balanza Industrial', 'Balanza de Precisión', 'Báscula', 'Balanza de Piso', 'Balanza Colgante'];

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
    final session  = provider.session;
    if (session == null) return;

    final b = session.balanza;
    if (b != null) {
      _codMetricaCtrl.text  = b.codMetrica  ?? '';
      _categoriaCtrl.text   = b.categoria   ?? '';
      _tecnologiaCtrl.text  = b.tecnologia  ?? '';
      _claseCtrl.text       = b.clase       ?? '';
      _codIntCtrl.text      = b.codInterno  ?? '';
      _tipoEquipoCtrl.text  = b.tipo        ?? '';
      _marcaCtrl.text       = b.marca       ?? '';
      _modeloCtrl.text      = b.modelo      ?? '';
      _serieCtrl.text       = b.serie       ?? '';
      _unidadesCtrl.text    = b.unidad      ?? '';
      _ubicacionCtrl.text   = b.ubicacion   ?? '';
      _rangoCtrl.text       = b.rango       ?? '';
      _nCeldasCtrl.text     = b.nCeldas     ?? '';
      _capMax1Ctrl.text     = b.capMax1     ?? '';
      _d1Ctrl.text          = b.d1?.toString()   ?? '';
      _e1Ctrl.text          = b.e1?.toString()   ?? '';
      _dec1Ctrl.text        = b.dec1?.toString() ?? '';
      _capMax2Ctrl.text     = b.capMax2     ?? '0';
      _d2Ctrl.text          = b.d2?.toString()   ?? '0';
      _e2Ctrl.text          = b.e2?.toString()   ?? '0';
      _dec2Ctrl.text        = b.dec2?.toString() ?? '0';
      _capMax3Ctrl.text     = b.capMax3     ?? '0';
      _d3Ctrl.text          = b.d3?.toString()   ?? '0';
      _e3Ctrl.text          = b.e3?.toString()   ?? '0';
      _dec3Ctrl.text        = b.dec3?.toString() ?? '0';
    }
    final si = session.sessionInfo;
    _nRecaCtrl.text   = si.nReca   ?? '';
    _stickerCtrl.text = si.sticker ?? '';
  }

  Future<void> _loadBalanzas() async {
    setState(() => _isLoadingBalanzas = true);
    final provider = context.read<ServiceSessionProvider>();
    final clienteCod = provider.session?.cliente?.codigoCliente;
    final plantaCod = provider.session?.planta?.codigo;
    final result = await _repository.getBalanzas(clienteCod, plantaCod);
    if (!mounted) return;

    final savedCodMetrica = provider.session?.balanza?.codMetrica;

    setState(() {
      _balanzas = result;
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
    _codMetricaCtrl.text  = b['cod_metrica']?.toString()     ?? '';
    _categoriaCtrl.text   = b['categoria']?.toString()        ?? '';
    _tecnologiaCtrl.text  = b['tecnologia']?.toString()       ?? '';
    _claseCtrl.text       = b['clase']?.toString()            ?? '';
    _codIntCtrl.text      = b['cod_interno']?.toString()      ?? '';
    final tipoInst = b['tipo_instrumento']?.toString() ?? '';
    final inst = b['instrumento']?.toString() ?? '';
    final tipo = b['tipo']?.toString() ?? '';
    _tipoEquipoCtrl.text  = tipoInst.isNotEmpty ? tipoInst : (inst.isNotEmpty ? inst : tipo);
    _marcaCtrl.text       = b['marca']?.toString()            ?? '';
    _modeloCtrl.text      = b['modelo']?.toString()           ?? '';
    _serieCtrl.text       = b['inf_serie']?.toString()        ?? b['serie']?.toString() ?? '';
    _unidadesCtrl.text    = b['unidad']?.toString()           ?? '';
    _ubicacionCtrl.text   = b['ubicacion']?.toString()        ?? '';
    _rangoCtrl.text       = b['rango']?.toString()            ?? '';
    _nCeldasCtrl.text     = b['n_celdas']?.toString()         ?? '';
    _capMax1Ctrl.text     = b['cap_max1']?.toString()         ?? '';
    _d1Ctrl.text          = b['d1']?.toString()               ?? '';
    _e1Ctrl.text          = b['e1']?.toString()               ?? '';
    _dec1Ctrl.text        = b['dec1']?.toString()             ?? '';
    _capMax2Ctrl.text     = b['cap_max2']?.toString()         ?? '0';
    _d2Ctrl.text          = b['d2']?.toString()               ?? '0';
    _e2Ctrl.text          = b['e2']?.toString()               ?? '0';
    _dec2Ctrl.text        = b['dec2']?.toString()             ?? '0';
    _capMax3Ctrl.text     = b['cap_max3']?.toString()         ?? '0';
    _d3Ctrl.text          = b['d3']?.toString()               ?? '0';
    _e3Ctrl.text          = b['e3']?.toString()               ?? '0';
    _dec3Ctrl.text        = b['dec3']?.toString()             ?? '0';
  }

  void _saveToProvider(ServiceSessionProvider provider) {
    provider.updateBalanza(BalanzaInfo(
      codMetrica: _codMetricaCtrl.text,
      categoria:  _categoriaCtrl.text,
      // tecnologia: solo visual, no se persiste
      // clase: solo visual, no se persiste
      codInterno: _codIntCtrl.text,
      tipo:       _tipoEquipoCtrl.text,
      marca:      _marcaCtrl.text,
      modelo:     _modeloCtrl.text,
      serie:      _serieCtrl.text,
      unidad:     _unidadesCtrl.text,
      ubicacion:  _ubicacionCtrl.text,
      rango:      _rangoCtrl.text,
      nCeldas:    _nCeldasCtrl.text,
      capMax1:    _capMax1Ctrl.text,
      d1:         double.tryParse(_d1Ctrl.text),
      e1:         double.tryParse(_e1Ctrl.text),
      dec1:       double.tryParse(_dec1Ctrl.text),
      capMax2:    _capMax2Ctrl.text,
      d2:         double.tryParse(_d2Ctrl.text),
      e2:         double.tryParse(_e2Ctrl.text),
      dec2:       double.tryParse(_dec2Ctrl.text),
      capMax3:    _capMax3Ctrl.text,
      d3:         double.tryParse(_d3Ctrl.text),
      e3:         double.tryParse(_e3Ctrl.text),
      dec3:       double.tryParse(_dec3Ctrl.text),
    ));
    provider.updateSessionInfo(provider.session!.sessionInfo.copyWith(
      nReca:   _nRecaCtrl.text,
      sticker: _stickerCtrl.text,
    ));
    provider.setBalanzaConfirmed(false);
  }

  @override
  void dispose() {
    for (final c in [
      _codMetricaCtrl, _categoriaCtrl, _tecnologiaCtrl, _claseCtrl,
      _codIntCtrl, _tipoEquipoCtrl, _marcaCtrl, _modeloCtrl, _serieCtrl,
      _unidadesCtrl, _ubicacionCtrl, _rangoCtrl, _nCeldasCtrl,
      _capMax1Ctrl, _d1Ctrl, _e1Ctrl, _dec1Ctrl,
      _capMax2Ctrl, _d2Ctrl, _e2Ctrl, _dec2Ctrl,
      _capMax3Ctrl, _d3Ctrl, _e3Ctrl, _dec3Ctrl,
      _nRecaCtrl, _stickerCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'IDENTIFICACIÓN DEL INSTRUMENTO',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2C3E50)),
                ).animate().fadeIn(duration: 600.ms),
              ),
              const SizedBox(height: 24),

              // RECA + Sticker
              _buildRecaStickerRow(provider),
              const SizedBox(height: 24),

              // Botones de acción
              _buildActionButtons(provider),
              const SizedBox(height: 24),

              // Formulario si hay selección
              if (_selectedBalanza != null || _isNewBalanza) ...[
                _buildBalanzaForm(provider),
                const SizedBox(height: 24),
                _buildRangosSection(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecaStickerRow(ServiceSessionProvider provider) {
    return Row(
      children: [
        Expanded(child: _field(_nRecaCtrl,   'N° RECA *',    Icons.assignment, onChanged: (_) => _saveToProvider(provider))),
        const SizedBox(width: 12),
        Expanded(child: _field(_stickerCtrl, 'N° Sticker *', Icons.local_offer, onChanged: (_) => _saveToProvider(provider))),
      ],
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2);
  }

  Widget _buildActionButtons(ServiceSessionProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoadingBalanzas ? null : () => _showSearchDialog(provider),
            icon: _isLoadingBalanzas
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search, size: 18),
            label: const Text('Buscar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF326677), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() { _isNewBalanza = true; _selectedBalanza = null; });
              _codMetricaCtrl.clear(); _capMax2Ctrl.text = '0';
              _d2Ctrl.text = '0'; _e2Ctrl.text = '0'; _dec2Ctrl.text = '0';
              _capMax3Ctrl.text = '0'; _d3Ctrl.text = '0';
              _e3Ctrl.text = '0'; _dec3Ctrl.text = '0';
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF327734), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2);
  }

  Widget _buildBalanzaForm(ServiceSessionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isNewBalanza ? 'NUEVO INSTRUMENTO' : 'INSTRUMENTO SELECCIONADO',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold,
              color: _isNewBalanza ? Colors.green[700] : Colors.blue[700]),
          ),
          const SizedBox(height: 16),
          _field(_codMetricaCtrl, 'Código Métrica', Icons.qr_code, readOnly: !_isNewBalanza, onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _dropdownField('Categoría', Icons.category, _categorias, _categoriaCtrl, provider),
          const SizedBox(height: 12),
          _field(_tecnologiaCtrl, 'Tecnología', Icons.memory, readOnly: !_isNewBalanza, onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_claseCtrl, 'Clase', Icons.class_, readOnly: !_isNewBalanza, onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_codIntCtrl, 'Código Interno', Icons.tag, readOnly: !_isNewBalanza, onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _dropdownField('Tipo de Equipo', Icons.scale, _tiposEquipo, _tipoEquipoCtrl, provider),
          const SizedBox(height: 12),
          _field(_marcaCtrl, 'Marca', Icons.business, onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_modeloCtrl, 'Modelo', Icons.precision_manufacturing, onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_serieCtrl, 'Serie', Icons.confirmation_number, onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _dropdownField('Unidad', Icons.straighten, _unidades, _unidadesCtrl, provider),
          const SizedBox(height: 12),
          _field(_ubicacionCtrl, 'Ubicación', Icons.location_on, onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_rangoCtrl, 'Rango', Icons.linear_scale, readOnly: !_isNewBalanza, onChanged: (_) => _saveToProvider(provider)),
          const SizedBox(height: 12),
          _field(_nCeldasCtrl, 'N° Celdas', Icons.grid_view, readOnly: !_isNewBalanza, onChanged: (_) => _saveToProvider(provider)),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3);
  }

  Widget _buildRangosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RANGOS DE INTERVALO', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[700])),
        const SizedBox(height: 16),
        _rangoCard('RANGO 1', _capMax1Ctrl, _d1Ctrl, _e1Ctrl, _dec1Ctrl, Colors.blue),
        const SizedBox(height: 12),
        _rangoCard('RANGO 2', _capMax2Ctrl, _d2Ctrl, _e2Ctrl, _dec2Ctrl, Colors.orange),
        const SizedBox(height: 12),
        _rangoCard('RANGO 3', _capMax3Ctrl, _d3Ctrl, _e3Ctrl, _dec3Ctrl, Colors.green),
      ],
    ).animate(delay: 500.ms).fadeIn();
  }

  Widget _rangoCard(String title, TextEditingController capCtrl,
      TextEditingController dCtrl, TextEditingController eCtrl,
      TextEditingController decCtrl, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _numField(capCtrl, 'Cap. Max')),
            const SizedBox(width: 8),
            Expanded(child: _numField(dCtrl, 'D')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _numField(eCtrl, 'E')),
            const SizedBox(width: 8),
            Expanded(child: _numField(decCtrl, 'Decimales')),
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
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        labelText: label, prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: currentList.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text('BALANZAS DISPONIBLES', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite, height: 480,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Buscar…', hintText: 'Código, serie o marca',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () { searchCtrl.clear(); setDlg(() => filtered = List.from(_balanzas)); })
                      : null,
                ),
                onChanged: (q) => setDlg(() {
                  filtered = q.isEmpty ? List.from(_balanzas)
                      : _balanzas.where((b) {
                          final low = q.toLowerCase();
                          return (b['cod_metrica']?.toString().toLowerCase() ?? '').contains(low)
                              || (b['serie']?.toString().toLowerCase()       ?? '').contains(low)
                              || (b['marca']?.toString().toLowerCase()       ?? '').contains(low)
                              || (b['cod_interno']?.toString().toLowerCase() ?? '').contains(low);
                        }).toList();
                }),
              ),
              const SizedBox(height: 12),
              Expanded(child: filtered.isEmpty
                ? const Center(child: Text('Sin resultados'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final b = filtered[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Icon(Icons.scale, color: Colors.blue[700], size: 20),
                          ),
                          title: Text(b['cod_metrica']?.toString() ?? '',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${b['marca'] ?? ''} ${b['modelo'] ?? ''}  |  Serie: ${b['serie'] ?? 'N/A'}',
                              style: GoogleFonts.inter(fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            setState(() { _selectedBalanza = b; _isNewBalanza = false; });
                            _fillFromMap(b);
                            _saveToProvider(provider);
                            Navigator.pop(ctx);
                          },
                        ),
                      );
                    },
                  )),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
        );
      }),
    );
  }
}

