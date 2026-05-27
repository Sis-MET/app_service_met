import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';

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
  List<Map<String, dynamic>> _availableEquipos = [];

  String stickerCert = '';
  String stickerFecha = '';
  String stickerCod = '';
  String stickerNro = '';

  @override
  void initState() {
    super.initState();
    _loadEquipos();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  Future<void> _loadEquipos() async {
    final repo = context.read<ServiceSessionProvider>();
    // Need to use the raw repo or via provider. Since we don't expose it directly in Provider,
    // we instantiate it or use it if available.
    final items = await CalibrationRepository().getEquipos();
    if (mounted) {
      setState(() {
        _availableEquipos = items.where((e) {
          final inst = e['instrumento']?.toString().toLowerCase() ?? '';
          final tipo = e['tipo_instrumento']?.toString().toLowerCase() ?? '';
          final desc = e['descripcion']?.toString().toLowerCase() ?? '';
          return inst.contains('pesa') ||
              tipo.contains('pesa') ||
              desc.contains('pesa') ||
              inst.contains('masa') ||
              tipo.contains('masa') ||
              desc.contains('masa');
        }).toList();
      });
    }
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
      _selectedPesas = List.from(session.equipos);
    } else {
      _obsCtrl.text = 'Sin Observaciones';
    }

    // Calcular datos de sticker
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
    provider.updateEquipos(_selectedPesas);
  }

  void _setHora() {
    final now = DateTime.now();
    _horaCtrl.text =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _saveToProvider();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Text(
            'CONDICIONES FINALES',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800]),
          ).animate().fadeIn(duration: 600.ms)),
          const SizedBox(height: 24),
          _header('1. Condiciones Ambientales Finales'),
          Row(children: [
            Expanded(
                child: TextField(
              controller: _horaCtrl,
              readOnly: true,
              decoration: _deco('Hora Fin',
                  icon: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: _setHora)),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _hriCtrl,
                    onChanged: (_) => _saveToProvider(),
                    keyboardType: TextInputType.number,
                    decoration: _deco('HRi Fin (%)'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _tiCtrl,
                    onChanged: (_) => _saveToProvider(),
                    keyboardType: TextInputType.number,
                    decoration: _deco('Ti Fin (°C)'))),
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: _patmiCtrl,
              onChanged: (_) => _saveToProvider(),
              keyboardType: TextInputType.number,
              decoration: _deco('Patmi Fin (hPa)')),
          const SizedBox(height: 24),
          _header('2. Recomendaciones'),
          DropdownButtonFormField<String>(
            value: _mantenimiento,
            decoration: _deco('Mantenimiento con ST'),
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
            decoration: _deco('Venta de Pesas'),
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
            decoration: _deco('Reemplazo'),
            items: ['Sí', 'No']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              setState(() => _reemplazo = v);
              _saveToProvider();
            },
          ),
          const SizedBox(height: 24),
          _header('3. Observaciones / Comentarios'),
          TextField(
              controller: _obsCtrl,
              onChanged: (_) => _saveToProvider(),
              maxLines: 3,
              decoration: _deco('Observaciones')),
          const SizedBox(height: 24),
          _header('4. Selección de Pesas Patrón'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showPesasDialog,
              icon: const Icon(Icons.fitness_center),
              label: Text('Seleccionar Pesas (${_selectedPesas.length}/5)'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF365666),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 12),
          ..._selectedPesas.map((p) => Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.check_circle, color: Color(0xFF365666)),
                  title: Text(p.codInstrumento ?? 'Sin cod'),
                  subtitle: Text('Cant: ${p.cantidad}'),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() => _selectedPesas.remove(p));
                        _saveToProvider();
                      }),
                ),
              )),
          const SizedBox(height: 24),
          _header('5. Sticker de Calibrado (Referencial)'),
          _buildSticker(),
        ],
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800])),
      );

  InputDecoration _deco(String label, {Widget? icon}) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: icon,
      );

  Widget _buildSticker() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
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
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600])),
                      Text(stickerCert,
                          style: GoogleFonts.caveat(
                              color: Colors.blue[800],
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Fecha de calibración:',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600])),
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

  void _showPesasDialog() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 16),
                  Text('Seleccionar Pesas Patrón',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Expanded(
                      child: ListView.builder(
                    itemCount: _availableEquipos.length,
                    itemBuilder: (context, index) {
                      final eq = _availableEquipos[index];
                      final isSelected = _selectedPesas.any(
                          (p) => p.codInstrumento == eq['cod_instrumento']);
                      return CheckboxListTile(
                        title: Text(eq['cod_instrumento'] ?? ''),
                        subtitle: Text(eq['instrumento'] ?? ''),
                        value: isSelected,
                        onChanged: (v) {
                          if (v == true) {
                            if (_selectedPesas.length < 5) {
                              setModalState(() => _selectedPesas.add(EquipoInfo(
                                    codInstrumento: eq['cod_instrumento'],
                                    tipo: eq['instrumento'],
                                    cantidad: '1',
                                    certFecha: eq['cert_fecha'],
                                    enteCalibrador: eq['ente_calibrador'],
                                    estado: 'OK',
                                  )));
                            }
                          } else {
                            setModalState(() => _selectedPesas.removeWhere(
                                (p) =>
                                    p.codInstrumento == eq['cod_instrumento']));
                          }
                          setState(() {});
                          _saveToProvider();
                        },
                      );
                    },
                  )),
                ],
              ),
            );
          });
        });
  }
}
