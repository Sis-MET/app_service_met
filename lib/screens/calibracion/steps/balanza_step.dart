// ignore_for_file: deprecated_member_use, use_build_context_synchronously
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
import 'package:service_met/screens/calibracion/widgets/qr_scanner_screen.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/utils/foto_helper.dart';
import 'package:service_met/utils/foto_storage_dialog.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/utils/new_scale_code.dart';
import 'package:service_met/utils/scale_brand_suggestions.dart';
import 'package:service_met/widgets/service_ui/editable_suggestion_field.dart';

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
  bool _didQrAutoFill = false;
  Map<String, dynamic>? _selectedBalanza;
  List<String> _fotosPaths = [];
  Set<String> _completedCodMetricas = {};

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
      _fotosPaths = List.from(b.fotosPaths);
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

    // Cargar balanzas completadas del SECA actual
    final seca = provider.session?.sessionInfo.seca;
    Set<String> completed = {};
    if (seca != null && seca.isNotEmpty) {
      final registros = await provider.getRegistrosCompletos(seca);
      completed = registros
          .where((r) =>
              r['estado_servicio_bal']?.toString() == 'Balanza Calibrada')
          .map((r) => r['cod_metrica']?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();
    }

    final savedCodMetrica = provider.session?.balanza?.codMetrica;

    setState(() {
      _completedCodMetricas = completed;
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

  void _fillFromBalanzaInfo(BalanzaInfo b) {
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
      infBal: _computeInfBal(),
      fotosPaths: _fotosPaths,
    ));
    provider.updateSessionInfo(provider.session!.sessionInfo.copyWith(
      nReca: _nRecaCtrl.text,
      sticker: _stickerCtrl.text,
      codMetrica: _codMetricaCtrl.text,
    ));
    provider.setBalanzaConfirmed(false);
  }

  // ponytail: diffs current controllers against original DB values or empty for new
  String _computeInfBal() {
    final fields = <String>[];
    // ignore: unused_local_variable
    void chk(String col, String cur, String? dbVal) {
      if (cur != (dbVal ?? '') && cur.isNotEmpty) fields.add(col);
    }

    final orig = _isNewBalanza ? <String, dynamic>{} : (_selectedBalanza ?? {});
    chk('cod_int', _codIntCtrl.text, orig['cod_int']?.toString());
    chk(
        'tipo_equipo',
        _tipoEquipoCtrl.text,
        orig['tipo_instrumento']?.toString() ??
            orig['tipo_equipo']?.toString());
    chk('marca', _marcaCtrl.text, orig['marca']?.toString());
    chk('modelo', _modeloCtrl.text, orig['modelo']?.toString());
    chk('serie', _serieCtrl.text,
        orig['serie']?.toString() ?? orig['inf_serie']?.toString());
    chk('unidades', _unidadesCtrl.text, orig['unidad']?.toString());
    chk('ubicacion', _ubicacionCtrl.text, orig['ubicacion']?.toString());
    chk('rango', _rangoCtrl.text, orig['rango']?.toString());
    chk('n_celdas', _nCeldasCtrl.text, orig['n_celdas']?.toString());
    chk('cap_max1', _capMax1Ctrl.text, orig['cap_max1']?.toString());
    chk('d1', _d1Ctrl.text, orig['d1']?.toString());
    chk('e1', _e1Ctrl.text, orig['e1']?.toString());
    chk('dec1', _dec1Ctrl.text, orig['dec1']?.toString());
    chk('cap_max2', _capMax2Ctrl.text, orig['cap_max2']?.toString());
    chk('d2', _d2Ctrl.text, orig['d2']?.toString());
    chk('e2', _e2Ctrl.text, orig['e2']?.toString());
    chk('dec2', _dec2Ctrl.text, orig['dec2']?.toString());
    chk('cap_max3', _capMax3Ctrl.text, orig['cap_max3']?.toString());
    chk('d3', _d3Ctrl.text, orig['d3']?.toString());
    chk('e3', _e3Ctrl.text, orig['e3']?.toString());
    chk('dec3', _dec3Ctrl.text, orig['dec3']?.toString());
    return fields.join(',');
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
        // QR auto-detect: cuando el provider tiene una balanza del QR
        // que aún no se ha reflejado en el formulario local
        if (!_didQrAutoFill &&
            provider.qrCodMetrica != null &&
            provider.session?.balanza?.codMetrica != null &&
            provider.session!.balanza!.codMetrica!.isNotEmpty &&
            _codMetricaCtrl.text != provider.session!.balanza!.codMetrica) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final balanzaFromProvider = provider.session!.balanza!;
            final match = _balanzas.cast<Map<String, dynamic>?>().firstWhere(
                  (b) =>
                      b?['cod_metrica']?.toString().trim() ==
                      balanzaFromProvider.codMetrica?.trim(),
                  orElse: () => null,
                );
            setState(() {
              _didQrAutoFill = true;
              if (match != null) {
                _selectedBalanza = match;
                _isNewBalanza = false;
              } else {
                _isNewBalanza = true;
                _selectedBalanza = null;
              }
            });
            if (match != null) {
              _fillFromMap(match);
            } else {
              _fillFromBalanzaInfo(balanzaFromProvider);
            }
            _saveToProvider(provider);
            provider
                .loadPreviousServiceData(balanzaFromProvider.codMetrica ?? '');
          });
        }

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
                _buildRangosSection(provider, isDark),
                const SizedBox(height: 24),
                _buildFotosSection(isDark),
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
          flex: 3,
          child: OutlinedButton.icon(
            onPressed:
                _isLoadingBalanzas ? null : () => _showSearchDialog(provider),
            icon: _isLoadingBalanzas
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search, size: 18),
            label: const Text('Buscar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            onPressed: () => _startNewBalanza(provider),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed:
                _isLoadingBalanzas ? null : () => _scanQrForBalanza(provider),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('QR'),
          ),
        ),
      ],
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2);
  }

  void _startNewBalanza(ServiceSessionProvider provider) {
    setState(() {
      _isNewBalanza = true;
      _selectedBalanza = null;
      _didQrAutoFill = false;
      _fotosPaths = [];
    });

    _codMetricaCtrl.text = _suggestNewCodMetrica();
    _categoriaCtrl.clear();
    _tecnologiaCtrl.clear();
    _claseCtrl.clear();
    _codIntCtrl.clear();
    _tipoEquipoCtrl.clear();
    _marcaCtrl.clear();
    _modeloCtrl.clear();
    _serieCtrl.clear();
    _unidadesCtrl.clear();
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

    _saveToProvider(provider);
    provider.clearPreviousServiceData();
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
              readOnly: true,
              onChanged: (_) => _saveToProvider(provider),
              isDark: isDark),
          const SizedBox(height: 12),
          _dropdownField('Categoría', Icons.category, _categorias,
              _categoriaCtrl, provider,
              isDark: isDark),
          const SizedBox(height: 12),
          _field(_tecnologiaCtrl, 'Tecnología', Icons.memory,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _field(_claseCtrl, 'Clase', Icons.class_,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          _field(_codIntCtrl, 'Código Interno', Icons.tag,
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          EditableSuggestionField(
            controller: _tipoEquipoCtrl,
            label: 'Tipo de Equipo',
            icon: Icons.scale,
            options: _tiposEquipo,
            onChanged: (_) => _saveToProvider(provider),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          EditableSuggestionField(
            controller: _marcaCtrl,
            label: 'Marca',
            icon: Icons.business,
            options: scaleBrandSuggestions,
            onChanged: (_) => _saveToProvider(provider),
            isDark: isDark,
          ),
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
              onChanged: (_) => _saveToProvider(provider), isDark: isDark),
          const SizedBox(height: 12),
          CalibrationNumberField(
            controller: _nCeldasCtrl,
            column: 'n_celdas',
            onChanged: (_) => _saveToProvider(provider),
            style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
            decoration:
                _fieldDecoration('N° Celdas', Icons.grid_view, isDark: isDark),
          ),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3);
  }

  Widget _buildRangosSection(ServiceSessionProvider provider, bool isDark) {
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
        _rangoCard(1, _capMax1Ctrl, _d1Ctrl, _e1Ctrl, _dec1Ctrl, isDark,
            () => _saveToProvider(provider)),
        const SizedBox(height: 12),
        _rangoCard(2, _capMax2Ctrl, _d2Ctrl, _e2Ctrl, _dec2Ctrl, isDark,
            () => _saveToProvider(provider)),
        const SizedBox(height: 12),
        _rangoCard(3, _capMax3Ctrl, _d3Ctrl, _e3Ctrl, _dec3Ctrl, isDark,
            () => _saveToProvider(provider)),
      ],
    ).animate(delay: 500.ms).fadeIn();
  }

  Widget _rangoCard(
      int rango,
      TextEditingController capCtrl,
      TextEditingController dCtrl,
      TextEditingController eCtrl,
      TextEditingController decCtrl,
      bool isDark,
      VoidCallback onChanged) {
    final title = 'Rango $rango';
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
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: _numField(capCtrl, 'Cap. Max', 'cap_max$rango',
                    onChanged: onChanged, isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(
                child: _numField(dCtrl, 'd', 'd$rango',
                    onChanged: onChanged, isDark: isDark)),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: _numField(eCtrl, 'e', 'e$rango',
                    onChanged: onChanged, isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(
                child: _numField(decCtrl, 'Dec.', 'dec$rango',
                    onChanged: onChanged, isDark: isDark)),
          ]),
        ],
      ),
    );
  }

  // ── Fotos del Instrumento ─────────────────────────────────────────────

  Widget _buildFotosSection(bool isDark) {
    final seca =
        context.read<ServiceSessionProvider>().session?.sessionInfo.seca;
    final codMetrica = _codMetricaCtrl.text;
    final canTakePhoto = _fotosPaths.length < 5 &&
        seca != null &&
        seca.isNotEmpty &&
        codMetrica.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.camera_alt_outlined,
                color: isDark ? Colors.white54 : Colors.black54, size: 20),
            const SizedBox(width: 8),
            Text('Fotos del Instrumento',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            const Spacer(),
            Text('${_fotosPaths.length}/5',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black45)),
          ],
        ),
        const SizedBox(height: 12),
        if (_fotosPaths.isEmpty)
          _emptyFotosHint(isDark, canTakePhoto)
        else
          _buildFotosGrid(isDark, canTakePhoto),
      ],
    ).animate(delay: 600.ms).fadeIn();
  }

  Widget _emptyFotosHint(bool isDark, bool canTakePhoto) {
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
          Icon(Icons.camera_alt_outlined,
              size: 40, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 10),
          Text(
            'Tome fotografías del instrumento',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canTakePhoto ? _takeInstrumentoFoto : null,
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Tomar Foto'),
          ),
        ],
      ),
    );
  }

  Widget _buildFotosGrid(bool isDark, bool canTakePhoto) {
    return Column(
      children: [
        if (canTakePhoto)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _takeInstrumentoFoto,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Agregar Fotografía'),
              ),
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_fotosPaths.length, (i) {
            final path = _fotosPaths[i];
            final exists = File(path).existsSync();
            return GestureDetector(
              onTap: exists ? () => _viewFoto(path, isDark) : null,
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
                        ? Icon(Icons.broken_image_outlined,
                            color: isDark ? Colors.white24 : Colors.black26)
                        : null,
                  ),
                  if (exists)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => _deleteFoto(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
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

  Future<void> _takeInstrumentoFoto() async {
    final provider = context.read<ServiceSessionProvider>();
    final seca = provider.session?.sessionInfo.seca;
    final codMetrica = _codMetricaCtrl.text;

    if (seca == null || seca.isEmpty || codMetrica.isEmpty) {
      TopAlert.show(context, 'Debe seleccionar un instrumento primero',
          isError: true);
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

      final savedPath = await FotoHelper.saveFoto(seca, codMetrica, photo.path);
      if (!mounted) return;

      setState(() {
        _fotosPaths.add(savedPath);
      });
      _saveToProvider(provider);
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'Error al tomar foto: $e', isError: true);
      }
    }
  }

  void _viewFoto(String path, bool isDark) {
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

  void _deleteFoto(int index) async {
    final path = _fotosPaths[index];
    await FotoHelper.deleteFoto(path);
    if (!mounted) return;
    setState(() {
      _fotosPaths.removeAt(index);
    });
    _saveToProvider(context.read<ServiceSessionProvider>());
  }

  // --- Helpers de widgets ---

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool readOnly = false,
      void Function(String)? onChanged,
      required bool isDark}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      onChanged: onChanged,
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration:
          _fieldDecoration(label, icon, readOnly: readOnly, isDark: isDark),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon,
      {bool readOnly = false, required bool isDark}) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
      prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      filled: readOnly,
      fillColor: readOnly
          ? (isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.05))
          : null,
    );
  }

  Widget _numField(TextEditingController ctrl, String label, String column,
      {required VoidCallback onChanged, required bool isDark}) {
    return CalibrationNumberField(
      controller: ctrl,
      column: column,
      onChanged: (_) => onChanged(),
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
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
        labelStyle:
            GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
        prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black54),
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
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A)))))
          .toList(),
      onChanged: (v) {
        ctrl.text = v ?? '';
        _saveToProvider(provider);
      },
    );
  }

  String _suggestNewCodMetrica() {
    final provider = context.read<ServiceSessionProvider>();
    return NewScaleCode.generate(
      clientCode: provider.session?.cliente?.codigoCliente,
      plantCode: provider.session?.planta?.codigo,
    );
  }

  Future<void> _scanQrForBalanza(ServiceSessionProvider provider) async {
    final rawValue = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (rawValue == null || !mounted) return;

    // Limpiar el raw value del QR: extraer solo el código métrica
    // Ej: "0032-11-020 Balanza X Marca Y" → "0032-11-020"
    final parts = rawValue.trim().split('-');
    String codMetrica;
    if (parts.length >= 3) {
      final suffix = RegExp(r'^\d+').stringMatch(parts[2]) ?? '';
      codMetrica = '${parts[0]}-${parts[1]}-$suffix';
    } else {
      codMetrica = rawValue.trim();
    }

    final match = _balanzas.cast<Map<String, dynamic>?>().firstWhere(
          (b) => b?['cod_metrica']?.toString().trim() == codMetrica.trim(),
          orElse: () => null,
        );

    if (match == null) {
      if (!mounted) return;
      TopAlert.show(context,
          'El código QR no pertenece al cliente y planta seleccionados',
          isError: true);
      return;
    }

    if (_completedCodMetricas.contains(codMetrica)) {
      TopAlert.show(
        context,
        'La balanza $codMetrica ya fue calibrada dentro de este SECA.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedBalanza = match;
      _isNewBalanza = false;
      _didQrAutoFill = true;
    });
    _fillFromMap(match);
    _saveToProvider(provider);
    try {
      await provider.loadPreviousServiceData(codMetrica);
    } catch (_) {
      // Error silencioso: datos del servicio anterior no críticos
    }
    if (!mounted) return;
    TopAlert.show(context, 'Instrumento identificado: $codMetrica');
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
                              if (_completedCodMetricas.contains(codMetrica)) {
                                TopAlert.show(
                                  ctx,
                                  'La balanza $codMetrica ya fue calibrada '
                                  'dentro de este SECA.',
                                  isError: true,
                                );
                                return;
                              }
                              setState(() {
                                _selectedBalanza = b;
                                _isNewBalanza = false;
                              });
                              _fillFromMap(b);
                              _saveToProvider(provider);
                              provider.loadPreviousServiceData(
                                  b['cod_metrica']?.toString() ?? '');
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
                                        Row(
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
                                            if (_completedCodMetricas
                                                .contains(codMetrica)) ...[
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
                                                  'Calibrada',
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
                                        _infoSearchRow(
                                            'Cód. Interno', codInterno, isDark),
                                        const SizedBox(height: 4),
                                        _infoSearchRow('Serie', serie, isDark),
                                        const SizedBox(height: 4),
                                        _infoSearchRow(
                                            'Tipo',
                                            b['tipo_instrumento']?.toString() ??
                                                b['instrumento']?.toString() ??
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
