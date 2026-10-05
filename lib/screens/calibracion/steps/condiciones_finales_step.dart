import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';
import 'package:service_met/screens/calibracion/widgets/step_scroll_view.dart';
import 'package:service_met/screens/calibracion/widgets/patron_weights_selector.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/utils/foto_helper.dart';
import 'package:service_met/utils/foto_storage_dialog.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/numeric_keypad.dart';
import '../../../theme/app_icons.dart';

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
  List<Map<String, dynamic>> _equipamientos = [];
  bool _isLoadingEquipamientos = false;
  bool _equipamientosLoadFailed = false;

  List<String> _fotosFinalesPaths = [];

  @override
  void initState() {
    super.initState();
    _loadEquipamientos();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  Future<void> _loadEquipamientos() async {
    setState(() {
      _isLoadingEquipamientos = true;
      _equipamientosLoadFailed = false;
    });
    try {
      final result = await CalibrationRepository().getEquipos();
      if (!mounted) return;
      setState(() => _equipamientos = List.of(result));
    } catch (_) {
      if (mounted) setState(() => _equipamientosLoadFailed = true);
    } finally {
      if (mounted) setState(() => _isLoadingEquipamientos = false);
    }
  }

  void _initFromSession() {
    if (!mounted) return;
    final provider = context.read<ServiceSessionProvider>();
    final session = provider.session;
    if (session == null) return;

    final cf = session.condicionesFinales;
    if (cf != null) {
      _horaCtrl.text = cf.horaFin ?? '';
      _hriCtrl.text = cf.hriFin ?? '';
      _tiCtrl.text = cf.tiFin ?? '';
      _patmiCtrl.text = cf.patmiFin ?? '';
      _mantenimiento = const ['Sí', 'No'].contains(cf.mantenimiento)
          ? cf.mantenimiento
          : null;
      _ventaPesas =
          const ['Sí', 'No'].contains(cf.ventaPesas) ? cf.ventaPesas : null;
      _reemplazo =
          const ['Sí', 'No'].contains(cf.reemplazo) ? cf.reemplazo : null;
      _obsCtrl.text = cf.observaciones ?? 'Sin Observaciones';
    } else {
      _obsCtrl.text = 'Sin Observaciones';
    }

    _initEquiposFromSession(session.equipos);
    _fotosFinalesPaths = List.from(cf?.fotosFinalesPaths ?? []);

    setState(() {});
  }

  void _initEquiposFromSession(List<EquipoInfo> equipos) {
    _selectedPesas = [];
    for (final equipo in equipos) {
      if (ServiceSessionProvider.isPatronType(equipo.tipo) &&
          _selectedPesas.length < 5) {
        _selectedPesas.add(equipo);
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
      fotosFinalesPaths: _fotosFinalesPaths,
    ));
    provider.updatePatronWeights(_selectedPesas);
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
    return StepScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 20),
          _sectionHeader('1. Condiciones Ambientales Finales', isDark),
          _buildHoraField(isDark),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: CalibrationNumberField(
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                    controller: _hriCtrl,
                    column: 'hri_fin',
                    onChanged: (_) => _saveToProvider(),
                    decoration: _deco('HRi Fin (%)', isDark))),
            const SizedBox(width: 10),
            Expanded(
                child: CalibrationNumberField(
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                    controller: _tiCtrl,
                    column: 'ti_fin',
                    // Hay cámaras frías bajo cero.
                    allowNegative: true,
                    onChanged: (_) => _saveToProvider(),
                    decoration: _deco('Ti Fin (°C)', isDark))),
          ]),
          const SizedBox(height: 12),
          CalibrationNumberField(
              style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              controller: _patmiCtrl,
              column: 'patmi_fin',
              onChanged: (_) => _saveToProvider(),
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
          _sectionHeader('4. Selección de Pesas Patrón', isDark),
          _buildPesasSection(),
          const SizedBox(height: 24),
          _sectionHeader('5. Sticker de Calibrado (Referencial)', isDark),
          _buildSticker(isDark),
          const SizedBox(height: 24),
          _sectionHeader('6. Fotos Finales', isDark),
          _buildFotosFinalesSection(isDark),
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
          icon: Icon(AppIcons.hora,
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
    // Lo que va escrito en el sticker sale del servicio guardado y no de lo
    // que se tecleó al armar el SECA: al continuar un servicio eso ya no está
    // en memoria, y la cotización es parte del número de certificado.
    return Consumer<ServiceSessionProvider>(builder: (context, provider, _) {
      final info = provider.session?.sessionInfo;
      final codMetrica = info?.codMetrica ?? '';
      final codCliente =
          codMetrica.isEmpty ? 'XXXX' : codMetrica.split('-').first;
      final secaParts = info?.seca?.split('-') ?? const <String>[];
      final gestion =
          secaParts.length >= 3 && RegExp(r'^\d{2}$').hasMatch(secaParts.last)
              ? secaParts.last
              : DateTime.now().year.toString().substring(2);
      final cert = '$codCliente-${provider.cotizacion}-'
          '${info?.nReca ?? "SN"}-$gestion';
      final fecha = info?.fechaServicio ?? '';
      final nro = info?.sticker ?? 'SN';

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 40,
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
                          Text(cert,
                              style: GoogleFonts.caveat(
                                  color: Colors.blue[800],
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Fecha de calibración:',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                          Text(fecha,
                              style: GoogleFonts.caveat(
                                  color: Colors.blue[800],
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                    child: Text(codMetrica,
                                        style: GoogleFonts.caveat(
                                            color: Colors.blue[800],
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold))),
                                Text('Nº: $nro',
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
        ),
      );
    });
  }

  Widget _buildPesasSection() {
    return PatronWeightsSelector(
      catalog: _equipamientos
          .where(
              (eq) => ServiceSessionProvider.isPatronType(_instrumentType(eq)))
          .map(_equipoFromMap)
          .toList(),
      selected: _selectedPesas,
      loading: _isLoadingEquipamientos,
      loadFailed: _equipamientosLoadFailed,
      onRetry: _loadEquipamientos,
      onEditQuantity: _editCantidad,
      onChanged: (weights) {
        final previousCodes =
            _selectedPesas.map((e) => e.codInstrumento).toSet();
        setState(() => _selectedPesas = weights);
        _saveToProvider();
        final expired = weights.where((e) =>
            !previousCodes.contains(e.codInstrumento) &&
            WeightCertificateStatus(e.certFecha).expired);
        if (expired.isNotEmpty) {
          TopAlert.show(context,
              '${expired.map((e) => e.codInstrumento).join(', ')}: certificado vencido.',
              isError: true);
        }
      },
    );
  }

  Future<void> _editCantidad(EquipoInfo equipo) async {
    final ctrl = TextEditingController(text: equipo.cantidad ?? '1');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad · ${equipo.codInstrumento}',
            style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
        // El diálogo queda fuera del teclado de la pantalla: lleva el suyo.
        content: SizedBox(
          width: double.maxFinite,
          child: NumericKeypadHost(
            child: CalibrationNumberField(
              controller: ctrl,
              column: 'cantidad1',
              autofocus: true,
              style: GoogleFonts.inter(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                labelText: 'Cantidad utilizada',
                labelStyle: GoogleFonts.inter(
                    color: isDark ? Colors.white70 : Colors.black87),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black26),
                ),
              ),
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted || value == null || value.trim().isEmpty) return;
    setState(() {
      final idx = _selectedPesas
          .indexWhere((e) => e.codInstrumento == equipo.codInstrumento);
      if (idx >= 0) {
        _selectedPesas[idx] = _selectedPesas[idx].copyWith(cantidad: value);
      }
    });
    _saveToProvider();
  }

  String _instrumentType(Map<String, dynamic> eq) {
    final instrumento = eq['instrumento']?.toString() ?? '';
    final tipo = eq['tipo_instrumento']?.toString() ?? '';
    return instrumento.isNotEmpty ? instrumento : tipo;
  }

  EquipoInfo _equipoFromMap(Map<String, dynamic> eq) {
    final cert = WeightCertificateStatus(eq['cert_fecha']?.toString());
    return EquipoInfo(
      codInstrumento: eq['cod_instrumento']?.toString() ?? '',
      tipo: _instrumentType(eq),
      cantidad: '1',
      certFecha: eq['cert_fecha']?.toString() ?? '',
      enteCalibrador: eq['ente_calibrador']?.toString() ?? '',
      estado: cert.label,
    );
  }

  // ── Fotos Finales ───────────────────────────────────────────────────────────

  Widget _buildFotosFinalesSection(bool isDark) {
    final provider = context.read<ServiceSessionProvider>();
    final seca = provider.session?.sessionInfo.seca;
    final canTakePhoto =
        _fotosFinalesPaths.length < 5 && seca != null && seca.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AppIcons.camara,
                color: isDark ? Colors.white54 : Colors.black54, size: 20),
            const SizedBox(width: 8),
            Text('Fotografías Finales',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            const Spacer(),
            Text('${_fotosFinalesPaths.length}/5',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black45)),
          ],
        ),
        const SizedBox(height: 12),
        if (_fotosFinalesPaths.isEmpty)
          _emptyFotosFinalesHint(isDark, canTakePhoto)
        else
          _buildFotosFinalesGrid(isDark, canTakePhoto),
      ],
    ).animate(delay: 700.ms).fadeIn();
  }

  Widget _emptyFotosFinalesHint(bool isDark, bool canTakePhoto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(AppIcons.camara,
              size: 40, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 10),
          Text(
            'Tome fotografías finales del servicio',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: canTakePhoto ? _takeFinalFoto : null,
            icon: const Icon(AppIcons.camara, size: 18),
            label: const Text('Tomar Foto'),
          ),
        ],
      ),
    );
  }

  Widget _buildFotosFinalesGrid(bool isDark, bool canTakePhoto) {
    return Column(
      children: [
        if (canTakePhoto)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _takeFinalFoto,
                icon: const Icon(AppIcons.camara, size: 18),
                label: const Text('Agregar Fotografía'),
              ),
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_fotosFinalesPaths.length, (i) {
            final path = _fotosFinalesPaths[i];
            final exists = File(path).existsSync();
            return GestureDetector(
              onTap: exists ? () => _viewFinalFoto(path, isDark) : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      image: exists
                          ? DecorationImage(
                              image: FileImage(File(path)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: !exists
                        ? Icon(AppIcons.imagenNoDisponible,
                            color: isDark ? Colors.white24 : Colors.black26)
                        : null,
                  ),
                  if (exists)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => _deleteFinalFoto(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(AppIcons.cerrar,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _takeFinalFoto() async {
    final provider = context.read<ServiceSessionProvider>();
    final seca = provider.session?.sessionInfo.seca;

    if (seca == null || seca.isEmpty) {
      TopAlert.show(context, 'SECA no disponible', isError: true);
      return;
    }

    if (!await FotoHelper.isConfigured()) {
      if (!mounted) return;
      final configured = await FotoStorageDialog.show(context);
      if (!configured || !mounted) return;
    }

    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null || !mounted) return;

      final savedPath =
          await FotoHelper.saveFoto(seca, 'fotos_finales', photo.path);
      if (!mounted) return;

      setState(() {
        _fotosFinalesPaths.add(savedPath);
      });
      _saveToProvider();
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'Error al tomar foto: $e', isError: true);
      }
    }
  }

  void _viewFinalFoto(String path, bool isDark) {
    if (!File(path).existsSync()) {
      TopAlert.show(context, 'La foto ya no existe en el dispositivo',
          isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: const Center(
              child: AppBackButton(foregroundColor: Colors.white),
            ),
          ),
          body: Container(
            color: Colors.black,
            child: PhotoView(imageProvider: FileImage(File(path))),
          ),
        ),
      ),
    );
  }

  void _deleteFinalFoto(int index) async {
    final path = _fotosFinalesPaths[index];
    await FotoHelper.deleteFoto(path);
    if (!mounted) return;
    setState(() {
      _fotosFinalesPaths.removeAt(index);
    });
    _saveToProvider();
  }
}
