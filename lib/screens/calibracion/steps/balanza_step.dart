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
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/utils/foto_helper.dart';
import 'package:service_met/utils/foto_storage_dialog.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/utils/new_scale_code.dart';
import 'package:service_met/utils/scale_brand_suggestions.dart';
import 'package:service_met/utils/scale_range_validator.dart';
import 'package:service_met/widgets/dialogo_permiso.dart';
import 'package:service_met/widgets/service_ui/editable_suggestion_field.dart';
import 'package:service_met/widgets/service_ui/ficha_instrumento.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import '../../../theme/app_icons.dart';

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

  /// Orden en que se muestran los rangos guardados (0 = cap_max1): de menor a
  /// mayor capacidad. Solo visual. Se recalcula al cargar una balanza y al
  /// salir de la sección de rangos, no mientras se escribe, para que la
  /// tarjeta que se está editando no cambie de lugar.
  List<int> _rangeOrder = const [0, 1, 2];

  /// Rangos que el técnico abrió con "Agregar rango" aunque sigan vacíos.
  final Set<int> _rangosAgregados = {};

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
    _refreshRangeOrder();
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
          // Tecnología y clase solo se muestran, no se guardan: al continuar
          // una calibración pendiente se toman otra vez del catálogo.
          if (_tecnologiaCtrl.text.isEmpty) {
            _tecnologiaCtrl.text = match['tecnologia']?.toString() ?? '';
          }
          if (_claseCtrl.text.isEmpty) {
            _claseCtrl.text = match['clase']?.toString() ?? '';
          }
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
    _rangosAgregados.clear();
    _refreshRangeOrder();
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
    _rangosAgregados.clear();
    _refreshRangeOrder();
  }

  // ── Rangos: orden visual ──────────────────────────────────────────────

  /// Controladores de cada rango guardado: capacidad, d, e y decimales.
  List<List<TextEditingController>> get _rangeCtrls => [
        [_capMax1Ctrl, _d1Ctrl, _e1Ctrl, _dec1Ctrl],
        [_capMax2Ctrl, _d2Ctrl, _e2Ctrl, _dec2Ctrl],
        [_capMax3Ctrl, _d3Ctrl, _e3Ctrl, _dec3Ctrl],
      ];

  bool _rangoActivo(int slot) {
    final c = _rangeCtrls[slot];
    return ScaleRangeValues(
      capacity: c[0].text,
      division: c[1].text,
      verificationDivision: c[2].text,
      decimals: c[3].text,
    ).hasAnyValue;
  }

  void _refreshRangeOrder() {
    _rangeOrder =
        ScaleRangeOrder.displayOrder([for (final c in _rangeCtrls) c[0].text]);
  }

  /// Rangos a mostrar, en orden visual: los que tienen datos (y los
  /// anteriores a ellos, que deben completarse primero) más los agregados.
  List<int> get _visibleSlots {
    var last = 0;
    for (var slot = 0; slot < 3; slot++) {
      if (_rangoActivo(slot)) last = slot;
    }
    final visibles = {
      for (var slot = 0; slot <= last; slot++) slot,
      ..._rangosAgregados,
    };
    return _rangeOrder.where(visibles.contains).toList();
  }

  List<RangoInstrumento> get _rangosOrdenados => RangoInstrumento.ordenados(
        capacidades: [for (final c in _rangeCtrls) c[0].text],
        d: [for (final c in _rangeCtrls) c[1].text],
        e: [for (final c in _rangeCtrls) c[2].text],
        decimales: [for (final c in _rangeCtrls) c[3].text],
      );

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
          padding: ServiceNavPill.pagePadding(context, top: 20),
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
            child: _field(_nRecaCtrl, 'N° RECA *', AppIcons.formulario,
                onChanged: (_) => _saveToProvider(provider), isDark: isDark)),
        const SizedBox(width: 12),
        Expanded(
            child: _field(_stickerCtrl, 'N° Sticker *', AppIcons.etiqueta,
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
                : const Icon(AppIcons.buscar, size: 18),
            label: const Text('Buscar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            onPressed: () => _startNewBalanza(provider),
            icon: const Icon(AppIcons.agregar, size: 18),
            label: const Text('Nuevo'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed:
                _isLoadingBalanzas ? null : () => _scanQrForBalanza(provider),
            icon: const Icon(AppIcons.escanearQr, size: 18),
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
    _rangosAgregados.clear();
    _refreshRangeOrder();

    _saveToProvider(provider);
    provider.clearPreviousServiceData();
  }

  Widget _buildBalanzaForm(ServiceSessionProvider provider, bool isDark) {
    void guardar(String _) => _saveToProvider(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Resumen de lo que se está calibrando; se actualiza al escribir.
        FichaInstrumentoEncabezado(
          codMetrica: _codMetricaCtrl.text,
          esNueva: _isNewBalanza,
          marca: _marcaCtrl.text,
          modelo: _modeloCtrl.text,
          serie: _serieCtrl.text,
          tipo: _tipoEquipoCtrl.text,
          categoria: _categoriaCtrl.text,
          clase: _claseCtrl.text,
          unidad: _unidadesCtrl.text,
          nCeldas: _nCeldasCtrl.text,
          rangos: _rangosOrdenados,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: _panelDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _groupTitle('Identificación', AppIcons.etiqueta, isDark),
              _field(_codMetricaCtrl, 'Código Métrica', AppIcons.qr,
                  readOnly: true, onChanged: guardar, isDark: isDark),
              const SizedBox(height: 12),
              _field(_codIntCtrl, 'Código Interno', AppIcons.numero,
                  onChanged: guardar, isDark: isDark),
              const SizedBox(height: 12),
              EditableSuggestionField(
                controller: _tipoEquipoCtrl,
                label: 'Tipo de Equipo',
                icon: AppIcons.balanza,
                options: _tiposEquipo,
                onChanged: guardar,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dropdownField('Categoría', null, _categorias,
                        _categoriaCtrl, provider,
                        isDark: isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dropdownField(
                        'Unidad', null, _unidades, _unidadesCtrl, provider,
                        isDark: isDark),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _groupTitle('Fabricante', AppIcons.empresa, isDark),
              EditableSuggestionField(
                controller: _marcaCtrl,
                label: 'Marca',
                icon: AppIcons.empresa,
                options: scaleBrandSuggestions,
                onChanged: guardar,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(_modeloCtrl, 'Modelo', null,
                        onChanged: guardar, isDark: isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_serieCtrl, 'Serie', null,
                        onChanged: guardar, isDark: isDark),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _groupTitle('Características', AppIcons.chip, isDark),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(_tecnologiaCtrl, 'Tecnología', null,
                        onChanged: guardar, isDark: isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_claseCtrl, 'Clase', null,
                        onChanged: guardar, isDark: isDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: _field(_rangoCtrl, 'Rango', null,
                          onChanged: guardar, isDark: isDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CalibrationNumberField(
                      controller: _nCeldasCtrl,
                      column: 'n_celdas',
                      onChanged: guardar,
                      style: GoogleFonts.inter(
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A)),
                      decoration:
                          _fieldDecoration('N° Celdas', null, isDark: isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(_ubicacionCtrl, 'Ubicación', AppIcons.ubicacion,
                  onChanged: guardar, isDark: isDark),
            ],
          ),
        ),
      ],
    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3);
  }

  BoxDecoration _panelDecoration(bool isDark) => BoxDecoration(
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
      );

  Widget _groupTitle(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangosSection(ServiceSessionProvider provider, bool isDark) {
    final slots = _visibleSlots;
    final siguiente = [0, 1, 2].where((slot) => !slots.contains(slot));
    final unidad = _unidadesCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(AppIcons.medida,
                color: isDark ? Colors.white54 : Colors.black54, size: 20),
            const SizedBox(width: 8),
            Text('Rangos de pesaje',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Se muestran de menor a mayor capacidad: el Rango 1 es siempre el '
          'menor.',
          style: GoogleFonts.inter(
              fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
        ),
        const SizedBox(height: 14),
        // Al salir de los campos de rangos se vuelven a ordenar.
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (hasFocus) {
            if (!hasFocus && mounted) setState(_refreshRangeOrder);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < slots.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _rangoCard(slots[i], i + 1, slots.length, unidad, isDark,
                    () => _saveToProvider(provider)),
              ],
            ],
          ),
        ),
        if (siguiente.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _agregarRango(siguiente.first),
            icon: const Icon(AppIcons.agregar, size: 18),
            label: Text('Agregar rango ${slots.length + 1}'),
          ),
        ],
      ],
    ).animate(delay: 500.ms).fadeIn();
  }

  /// Abre un rango vacío para escribirlo: los ceros con que se inicializan
  /// los rangos sin usar se borran para no tener que borrarlos a mano.
  void _agregarRango(int slot) {
    setState(() {
      _rangosAgregados.add(slot);
      for (final c in _rangeCtrls[slot]) {
        if ((double.tryParse(c.text.trim()) ?? 0) == 0) c.clear();
      }
    });
  }

  /// Cierra un rango agregado que quedó vacío; vuelve a quedar en 0.
  void _quitarRango(int slot) {
    setState(() {
      _rangosAgregados.remove(slot);
      for (final c in _rangeCtrls[slot]) {
        c.text = '0';
      }
    });
  }

  /// Tarjeta editable de un rango guardado en [slot] (0 = cap_max1) que se
  /// muestra como Rango [numero]. La insignia lleva el tono del rango en la
  /// escala (amarillo, dorado, tinta), el mismo de la ficha de arriba.
  Widget _rangoCard(int slot, int numero, int total, String unidad, bool isDark,
      VoidCallback onChanged) {
    final c = _rangeCtrls[slot];
    final columna = slot + 1;
    final capacidad = formatoMedida(c[0].text);
    final quitable = _rangosAgregados.contains(slot) && !_rangoActivo(slot);
    final sufijo = unidad.isEmpty ? null : unidad;
    final texto = isDark ? Colors.white : AppColors.textPrimaryLight;
    return Container(
      decoration: decoracionFicha(context, radio: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            // Neutro, como el encabezado de la tabla de la ficha: el color
            // del rango va solo en la insignia.
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(isDark ? 0.05 : 0.035),
            padding: EdgeInsets.fromLTRB(14, 10, quitable ? 4 : 14, 10),
            child: Row(
              children: [
                NumeroRango(numero: numero, total: total),
                const SizedBox(width: 10),
                Text('Rango $numero',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: texto)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    capacidad.isEmpty
                        ? 'Sin capacidad'
                        : 'hasta $capacidad${sufijo == null ? '' : ' $sufijo'}',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: capacidad.isEmpty ? texto.withOpacity(0.5) : texto,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (quitable)
                  IconButton(
                    tooltip: 'Quitar rango',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _quitarRango(slot),
                    icon: const Icon(AppIcons.cerrar, size: 18),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: _numField(c[0], 'Cap. Max', 'cap_max$columna',
                          suffix: sufijo,
                          onChanged: onChanged,
                          isDark: isDark)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _numField(c[1], 'd', 'd$columna',
                          suffix: sufijo,
                          onChanged: onChanged,
                          isDark: isDark)),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: _numField(c[2], 'e', 'e$columna',
                          suffix: sufijo,
                          onChanged: onChanged,
                          isDark: isDark)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _numField(c[3], 'Decimales', 'dec$columna',
                          onChanged: onChanged, isDark: isDark)),
                ]),
              ],
            ),
          ),
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
            Icon(AppIcons.camara,
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
          Icon(AppIcons.camara,
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
            icon: const Icon(AppIcons.camara, size: 18),
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
                icon: const Icon(AppIcons.camara, size: 18),
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
                        ? Icon(AppIcons.imagenNoDisponible,
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
    if (!await asegurarCamara(context) || !mounted) return;

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

  Widget _field(TextEditingController ctrl, String label, IconData? icon,
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

  InputDecoration _fieldDecoration(String label, IconData? icon,
      {bool readOnly = false, required bool isDark}) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: isDark ? Colors.white54 : Colors.black54),
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
      {required VoidCallback onChanged, required bool isDark, String? suffix}) {
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
        suffixText: suffix,
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

  Widget _dropdownField(String label, IconData? icon, List<String> items,
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
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: isDark ? Colors.white54 : Colors.black54),
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
    final rawValue = await QrScannerScreen.escanear(context);
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
                  prefixIcon: Icon(AppIcons.buscar,
                      color: isDark ? Colors.white54 : Colors.black38,
                      size: 20),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(AppIcons.cerrar,
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
                            Icon(AppIcons.sinResultados,
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
                                        _infoSearchRow('Capacidad',
                                            _capacidadResumen(b), isDark),
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
                                    child: Icon(AppIcons.siguiente,
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

  /// "300 / 600 kg": las capacidades de una balanza del catálogo, de menor
  /// a mayor.
  String _capacidadResumen(Map<String, dynamic> b) {
    final rangos = RangoInstrumento.ordenados(
        capacidades: [b['cap_max1'], b['cap_max2'], b['cap_max3']]);
    if (rangos.isEmpty) return 'No especificada';
    final unidad = b['unidad']?.toString().trim() ?? '';
    final valores = rangos.map((r) => formatoMedida(r.capacidad)).join(' / ');
    return unidad.isEmpty ? valores : '$valores $unidad';
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
