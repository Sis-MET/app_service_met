import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/models/sustitucion_linealidad.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';
import 'package:service_met/screens/calibracion/widgets/indicator_reader_screen.dart';
import 'package:service_met/screens/calibracion/widgets/step_scroll_view.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/utils/foto_helper.dart';
import 'package:service_met/utils/foto_storage_dialog.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/dialogo_permiso.dart';
import 'package:service_met/widgets/numeric_keypad.dart';
import '../../../theme/app_icons.dart';

class LinealidadStep extends StatefulWidget {
  const LinealidadStep({super.key});

  @override
  State<LinealidadStep> createState() => _LinealidadStepState();
}

class _LinealidadStepState extends State<LinealidadStep> {
  static const _metodoCargaOptions = [
    'Sin metodo de carga',
    'Ascenso evaluando a ceros',
    'Ascenso Continuo por pasos',
  ];
  static const _metodoCargasSustitutivasOptions = [
    'Sin método',
    'Método 1',
    'Método 2',
  ];
  static const _maxPuntos = 60;

  String? _metodoCarga;
  String? _metodoCargasSustitutivas;
  bool _cargasValidadas = false;
  int _cargasPatronValidadas = 0;
  bool _hasCheckedPrevData = false;
  final _notaCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<String> _fotosPaths = [];
  bool _isTakingFoto = false;

  List<TextEditingController> _cargaCtrls = [];
  List<TextEditingController> _indCtrls = [];
  List<TextEditingController> _retCtrls = [];

  /// Pasos de sustitución, por fila resultante en orden creciente.
  List<PasoSustitucion> _pasos = [];

  MetodoSustitucion? get _metodoSustitucion =>
      MetodoSustitucion.deEtiqueta(_metodoCargasSustitutivas);

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
    final lin = provider.session?.linealidad;
    if (lin == null) return;

    _notaCtrl.text = lin.nota ?? '';
    _metodoCarga = _metodoCargaOptions.contains(lin.metodo) ? lin.metodo : null;
    _metodoCargasSustitutivas =
        _metodoCargasSustitutivasOptions.contains(lin.metodoCarga)
            ? lin.metodoCarga
            : null;

    _fotosPaths = List.from(lin.fotosPaths);

    // Migrate from old CondicionesFinales.fotosPaths (FotoCargaStep)
    if (_fotosPaths.isEmpty) {
      final cf = provider.session?.condicionesFinales;
      if (cf != null && cf.fotosPaths != null && cf.fotosPaths!.isNotEmpty) {
        _fotosPaths = List.from(cf.fotosPaths!);
      }
    }

    if (lin.filas.isNotEmpty) {
      _buildControllers(lin.filas.length.clamp(1, _maxPuntos));
      for (int i = 0; i < _cargaCtrls.length; i++) {
        _cargaCtrls[i].text = lin.filas[i].carga ?? '';
        _indCtrls[i].text = lin.filas[i].indicacion ?? '';
        _retCtrls[i].text = (lin.filas[i].retorno?.isNotEmpty ?? false)
            ? lin.filas[i].retorno!
            : '0';
      }
    } else {
      _buildControllers(12);
    }

    // La validación y los pasos de sustitución: sin ellos, al volver al paso
    // las cargas sustitutivas parecían cargas de pesas.
    final sustitucion = lin.sustitucion;
    if (sustitucion.cargasPatron > 0) {
      _cargasValidadas = true;
      _cargasPatronValidadas =
          sustitucion.cargasPatron.clamp(1, _cargaCtrls.length);
      _pasos = [
        for (final paso in sustitucion.pasos)
          if (paso.fila >= _cargasPatronValidadas &&
              paso.fila < _cargaCtrls.length)
            paso,
      ];
    }

    if (mounted) setState(() {});
  }

  void _onMetodoCargasSustitutivasChanged(String? v) {
    setState(() => _metodoCargasSustitutivas = v);
    _saveToProvider();
  }

  /// Verifica si hay datos del servicio anterior para precargar cargas.
  Future<void> _checkPreviousServiceData() async {
    if (_hasCheckedPrevData) return;
    _hasCheckedPrevData = true;

    if (!mounted) return;
    final provider = context.read<ServiceSessionProvider>();

    final codMetrica = provider.session?.balanza?.codMetrica;
    if (codMetrica != null && codMetrica.isNotEmpty) {
      await provider.loadPreviousServiceData(codMetrica);
    }

    final prev = provider.previousServiceData;
    if (prev == null) return;

    final linValues = <String>[];
    for (int i = 1; i <= 13; i++) {
      final val = prev['lin$i']?.toString() ?? '';
      if (val.isNotEmpty) linValues.add(val);
    }

    if (linValues.isEmpty) {
      TopAlert.show(
          context, 'No hay datos del servicio anterior para Linealidad');
      return;
    }

    if (_cargaCtrls.isNotEmpty &&
        _cargaCtrls.any((c) => c.text.trim().isNotEmpty)) {
      return;
    }

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Linealidad - Servicio anterior'),
        content:
            Text('Se encontraron cargas registradas del servicio anterior:\n\n'
                '${linValues.join(', ')}\n\n'
                '¿Desea usar estos valores?'),
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
        final count = linValues.length;
        setState(() {
          _buildControllers(count);
          _pasos = [];
          for (int i = 0; i < count; i++) {
            _cargaCtrls[i].text = linValues[i];
            _indCtrls[i].text = linValues[i];
          }
        });
        _saveToProvider();
      }
    });
  }

  void _buildControllers(int count) {
    for (final c in _cargaCtrls) {
      c.dispose();
    }
    for (final c in _indCtrls) {
      c.dispose();
    }
    for (final c in _retCtrls) {
      c.dispose();
    }

    _cargaCtrls = List.generate(count, (_) => TextEditingController());
    _indCtrls = List.generate(count, (_) => TextEditingController());
    _retCtrls = List.generate(count, (_) => TextEditingController(text: '0'));
  }

  void _onMetodoCargaChanged(String? v) {
    setState(() => _metodoCarga = v);
    _saveToProvider();
  }

  void _addRow() {
    if (_cargaCtrls.length >= _maxPuntos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximo 60 puntos permitidos')),
      );
      return;
    }

    setState(() {
      _cargaCtrls.add(TextEditingController());
      _indCtrls.add(TextEditingController());
      _retCtrls.add(TextEditingController(text: '0'));
    });
  }

  void _removeRow() {
    if (_cargaCtrls.length <= 1) return;

    setState(() {
      _cargaCtrls.removeLast().dispose();
      _indCtrls.removeLast().dispose();
      _retCtrls.removeLast().dispose();
      _pasos.removeWhere((paso) => paso.fila >= _cargaCtrls.length);
      if (_cargasPatronValidadas > _cargaCtrls.length) {
        _cargasPatronValidadas = _cargaCtrls.length;
      }
      if (_cargasPatronValidadas == 0) _cargasValidadas = false;
    });
    _saveToProvider();
  }

  void _onCargaChanged(int i, String val) {
    // La indicación arranca igual a la carga; el técnico corrige solo si la
    // balanza marca otra cosa.
    if (!_cargasValidadas || i < _cargasPatronValidadas) {
      _indCtrls[i].text = _formatValueWithPrecision(val);
    }
    _recalcularSustitutivas();
    _saveToProvider();
    setState(() {});
  }

  void _onIndicacionChanged(int i, String val) {
    _recalcularSustitutivas();
    _saveToProvider();
    setState(() {});
  }

  void _onRetornoChanged() {
    _saveToProvider();
    setState(() {});
  }

  /// Para mostrar. Sin redondear a 2 decimales (con d = 0,001 se perdía la
  /// resolución): hasta 6 y sin ceros de más.
  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    final text = v.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
    return text == '-0' ? '0' : text;
  }

  /// Carga calculada, con los decimales de d en ese valor.
  String _formatCarga(double v) {
    try {
      final balanza = context.read<ServiceSessionProvider>().session?.balanza;
      final d = balanza == null
          ? 0.0
          : SuggestionHelper.getDivisionForValue(balanza, v);
      if (d == 0) return _fmt(v);
      return v.toStringAsFixed(SuggestionHelper.getDecimalPlaces(d));
    } catch (_) {
      return _fmt(v);
    }
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

  String _errorText(int i) {
    final cargaReal = double.tryParse(_cargaCtrls[i].text);
    final indicacion = double.tryParse(_indCtrls[i].text);
    if (cargaReal == null || indicacion == null) return '';
    return _fmt(indicacion - cargaReal);
  }

  int _filledPatronRowsCount() {
    int count = 0;
    for (int i = 0; i < _cargaCtrls.length; i++) {
      final hasCarga = _cargaCtrls[i].text.trim().isNotEmpty;
      final hasInd = _indCtrls[i].text.trim().isNotEmpty;
      if (hasCarga && hasInd) count = i + 1;
    }
    return count;
  }

  void _validatePatronLoads() {
    final count = _filledPatronRowsCount();
    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registre al menos una carga patron con indicacion.'),
        ),
      );
      return;
    }

    setState(() {
      _cargasValidadas = true;
      _cargasPatronValidadas = count;
      _pasos = [];
    });
    _saveToProvider();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cargas patron validadas: $count')),
    );
  }

  /// Las cargas sustitutivas dependen de las cargas de pesas validadas: al
  /// volver a validar se borran, después de confirmarlo.
  Future<void> _resetValidation() async {
    if (_pasos.isNotEmpty) {
      final filas = [for (final paso in _pasos) paso.fila + 1];
      final cuales = filas.length == 1
          ? 'la carga ${filas.first}'
          : 'las cargas ${filas.first} a ${filas.last}';
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Volver a validar cargas'),
          content:
              Text('Las cargas sustitutivas dependen de las cargas de pesas '
                  'validadas. Se borrarán $cuales y tendrá que registrarlas de '
                  'nuevo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar y validar de nuevo'),
            ),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;
    }
    setState(() {
      for (final paso in _pasos) {
        _cargaCtrls[paso.fila].clear();
        _indCtrls[paso.fila].clear();
        _retCtrls[paso.fila].text = '0';
      }
      _pasos = [];
      _cargasValidadas = false;
      _cargasPatronValidadas = 0;
    });
    _saveToProvider();
  }

  Future<void> _takeFoto() async {
    if (_isTakingFoto) return;

    final provider = context.read<ServiceSessionProvider>();
    final seca = provider.session?.sessionInfo.seca;
    final codMetrica = provider.session?.balanza?.codMetrica;

    if (seca == null ||
        seca.isEmpty ||
        codMetrica == null ||
        codMetrica.isEmpty) {
      TopAlert.show(context, 'Debe seleccionar un instrumento primero',
          isError: true);
      return;
    }

    setState(() => _isTakingFoto = true);
    try {
      if (!await FotoHelper.isConfigured()) {
        if (!mounted) return;
        final configured = await FotoStorageDialog.show(context);
        if (!configured || !mounted) return;
      }
      if (!mounted) return;
      if (!await asegurarCamara(context) || !mounted) return;

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null || !mounted) return;

      final savedPath = await FotoHelper.saveFoto(seca, codMetrica, photo.path);
      if (!mounted) return;

      setState(() => _fotosPaths.add(savedPath));
      _saveToProvider();
    } on PlatformException catch (e) {
      if (mounted) {
        TopAlert.show(
          context,
          e.code == 'camera_access_denied'
              ? 'No se concedió permiso para usar la cámara'
              : 'No se pudo abrir la cámara. Intente nuevamente.',
          isError: true,
        );
      }
    } on FileSystemException {
      await FotoHelper.reset();
      if (mounted) {
        TopAlert.show(
          context,
          'No se pudo guardar la foto. Seleccione nuevamente la carpeta de almacenamiento.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'No se pudo registrar la fotografía',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isTakingFoto = false);
    }
  }

  void _viewFoto(String path) {
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
    setState(() => _fotosPaths.removeAt(index));
    _saveToProvider();
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateLinealidad(LinealidadData(
      metodo: _metodoCarga,
      metodoCarga: _metodoCargasSustitutivas ?? '',
      nota: _notaCtrl.text,
      fotosPaths: _fotosPaths,
      filas: List.generate(_cargaCtrls.length, (i) {
        return FilaLinealidad(
          carga: _cargaCtrls[i].text,
          indicacion: _indCtrls[i].text,
          retorno: _retCtrls[i].text.isEmpty ? '0' : _retCtrls[i].text,
        );
      }),
      sustitucion: SustitucionLinealidad(
        cargasPatron: _cargasValidadas ? _cargasPatronValidadas : 0,
        pasos: _pasos,
      ),
    ));
  }

  @override
  void dispose() {
    for (final c in _cargaCtrls) {
      c.dispose();
    }
    for (final c in _indCtrls) {
      c.dispose();
    }
    for (final c in _retCtrls) {
      c.dispose();
    }
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        return StepScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _metodoCarga,
                decoration: _deco('Metodo de Carga', isDark),
                hint: Text('Seleccione',
                    style: GoogleFonts.inter(
                        color: isDark ? Colors.white54 : Colors.black45)),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: _metodoCargaOptions
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v,
                              style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A))),
                        ))
                    .toList(),
                onChanged: _onMetodoCargaChanged,
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 16),
              if (_metodoCarga != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _metodoCarga == 'Sin metodo de carga'
                        ? 'Registro sin metodo de carga definido.'
                        : _metodoCarga == 'Ascenso evaluando a ceros'
                            ? 'El ensayo retorna a cero despues de cada medicion.'
                            : 'El ensayo aplica carga de forma continua sin retornos intermedios.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ).animate(delay: 250.ms).fadeIn(),
                ),
              if (_metodoCarga != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _metodoCargasSustitutivas,
                  decoration: _deco('Método de Cargas Sustitutivas', isDark),
                  hint: Text('Seleccione',
                      style: GoogleFonts.inter(
                          color: isDark ? Colors.white54 : Colors.black45)),
                  dropdownColor:
                      isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  items: _metodoCargasSustitutivasOptions
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v,
                                style: GoogleFonts.inter(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A))),
                          ))
                      .toList(),
                  // Con cargas sustitutivas registradas el método no cambia:
                  // fija cómo se calcularon.
                  onChanged: _pasos.isEmpty
                      ? _onMetodoCargasSustitutivasChanged
                      : null,
                ).animate(delay: 280.ms).fadeIn(),
                if (_pasos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Para cambiar el método, pulse «Volver a validar cargas»: '
                      'se borran las cargas sustitutivas.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildValidationHelp(isDark),
                const SizedBox(height: 8),
                _buildPuntosSection(isDark),
                const SizedBox(height: 20),
              ],
              TextField(
                style: GoogleFonts.inter(
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                controller: _notaCtrl,
                onChanged: (_) => _saveToProvider(),
                maxLines: 3,
                decoration: _deco('Nota / Comentario (opcional)', isDark),
              ).animate(delay: 600.ms).fadeIn(),
              _buildFotosSection(isDark),
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
          'Pruebas de Linealidad',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Registro de cargas patron y cargas sustitutivas',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildValidationHelp(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withOpacity(0.08)
            : Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.teal.withOpacity(0.3)
              : Colors.teal.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _cargasValidadas ? AppIcons.completo : AppIcons.info,
            size: 18,
            color: Colors.teal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              !_cargasValidadas
                  ? 'Primero registre y revise las cargas de sus pesas patron. Cuando termine, pulse Validar cargas para habilitar el calculo de cargas sustitutivas.'
                  : switch (_metodoSustitucion) {
                      null =>
                        'Cargas patron validadas: $_cargasPatronValidadas. Para usar el asistente, elija el método de cargas sustitutivas: Método 1 o Método 2.',
                      MetodoSustitucion.metodo1 =>
                        'Cargas patron validadas: $_cargasPatronValidadas. Método 1: cada carga sustitutiva se parece a la carga anterior, se pesa sola y se suma a la carga de pesas.',
                      MetodoSustitucion.metodo2 =>
                        'Cargas patron validadas: $_cargasPatronValidadas. Método 2: cada carga sustitutiva se parece a la carga de pesas, se pesa sola y se suma a la carga anterior.',
                    },
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn();
  }

  Widget _buildPuntosSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader('Puntos de Calibracion', isDark),
            Wrap(
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(AppIcons.agregarCirculo,
                      color: Colors.teal, size: 22),
                  onPressed: _addRow,
                  tooltip: 'Agregar fila',
                ),
                IconButton(
                  icon: const Icon(AppIcons.quitarCirculo,
                      color: Colors.teal, size: 22),
                  onPressed: _removeRow,
                  tooltip: 'Eliminar ultima fila',
                ),
                if (_cargasValidadas)
                  IconButton(
                    icon: const Icon(AppIcons.actualizar,
                        color: Colors.teal, size: 22),
                    onPressed: _resetValidation,
                    tooltip: 'Volver a validar cargas',
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _cargasValidadas ? null : _validatePatronLoads,
                icon: const Icon(AppIcons.verificado, size: 18),
                label: const Text('Validar cargas'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cargasValidadas && _metodoSustitucion != null
                    ? _showCargaSustitutivaSheet
                    : null,
                icon: const Icon(AppIcons.calcular, size: 18),
                label: const Text('Carga sustitutiva'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          children: List.generate(
            _cargaCtrls.length,
            (i) => _buildPuntoRows(i, isDark),
          ),
        ).animate(delay: 400.ms).fadeIn(),
      ],
    );
  }

  Widget _buildPuntoRows(int i, bool isDark) {
    final paso = _pasoDeFila(i);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Carga ${i + 1}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              if (paso != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Sustitutiva · ${paso.metodo.codigo}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Divider(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _cargaField(i, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _indicationField(i, isDark)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _retornoField(i, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _errorField(i, isDark)),
            ],
          ),
          if (paso != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Carga sustitutiva sola: ${_fmt(paso.indicacionSustitutiva)} · '
                'corrige con la Carga ${paso.filaReferencia + 1} · '
                'se suma a la Carga ${paso.filaBase + 1}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    bool isDark, {
    String? labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: labelText,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
    );
  }

  Widget _cargaField(int i, bool isDark) {
    return CalibrationNumberField(
      style: GoogleFonts.inter(
          fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _cargaCtrls[i],
      column: 'lin${i + 1}',
      // Después de validar, las cargas siguientes las calcula el asistente.
      enabled: !_cargasValidadas || i < _cargasPatronValidadas,
      onChanged: (val) => _onCargaChanged(i, val),
      decoration: _fieldDecoration(isDark, labelText: 'Carga real'),
    );
  }

  Widget _indicationField(int i, bool isDark) {
    final hasBase = _cargaCtrls[i].text.isNotEmpty;
    return CalibrationNumberField(
      style: GoogleFonts.inter(
          fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _indCtrls[i],
      column: 'ind${i + 1}',
      allowNegative: true,
      readable: true,
      onChanged: (val) => _onIndicacionChanged(i, val),
      decoration: _fieldDecoration(
        isDark,
        labelText: 'Indicacion',
        suffixIcon: hasBase
            ? InkWell(
                onTap: () => _showIndicacionSuggestion(i),
                child:
                    const Icon(AppIcons.expandir, color: Colors.teal, size: 20),
              )
            : null,
      ),
    );
  }

  Widget _retornoField(int i, bool isDark) {
    return CalibrationNumberField(
      style: GoogleFonts.inter(
          fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _retCtrls[i],
      column: 'retorno_lin${i + 1}',
      allowNegative: true,
      readable: true,
      onChanged: (_) => _onRetornoChanged(),
      decoration: _fieldDecoration(isDark, labelText: 'Retorno a cero'),
    );
  }

  Widget _errorField(int i, bool isDark) {
    final error = _errorText(i);
    return InputDecorator(
      decoration: _fieldDecoration(isDark, labelText: 'Error'),
      child: Text(
        error.isEmpty ? '-' : error,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
    );
  }

  void _showIndicacionSuggestion(int rowIdx) {
    final cargaText = _cargaCtrls[rowIdx].text;
    final cargaValue = double.tryParse(cargaText);
    if (cargaValue == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balanza = context.read<ServiceSessionProvider>().session?.balanza;
    if (balanza == null) return;

    SuggestionHelper.showSuggestedValues(
      context: context,
      balanza: balanza,
      baseValue: cargaValue,
      title: 'Indicacion - Punto ${rowIdx + 1}',
      isDark: isDark,
    ).then((selected) {
      if (selected != null) {
        _indCtrls[rowIdx].text = selected;
        _onIndicacionChanged(rowIdx, selected);
      }
    });
  }

  PasoSustitucion? _pasoDeFila(int fila) {
    for (final paso in _pasos) {
      if (paso.fila == fila) return paso;
    }
    return null;
  }

  double? _numero(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  List<FilaCarga> _filasVigentes() => [
        for (int i = 0; i < _cargaCtrls.length; i++)
          (
            carga: _numero(_cargaCtrls[i].text),
            indicacion: _numero(_indCtrls[i].text),
          ),
      ];

  /// Rehace, en orden, la carga de cada fila sustitutiva con las cargas e
  /// indicaciones vigentes: si se corrige una lectura, las cargas que
  /// dependen de ella cambian con ella.
  void _recalcularSustitutivas() {
    for (final paso in _pasos) {
      final calculo = calcularPaso(paso, _filasVigentes());
      if (calculo == null) continue;
      final texto = _formatCarga(calculo.cargaResultante);
      if (_cargaCtrls[paso.fila].text != texto) {
        _cargaCtrls[paso.fila].text = texto;
      }
    }
  }

  /// Última fila con carga: la carga anterior de la próxima sustitución.
  int _ultimaFilaConCarga() {
    for (int i = _cargaCtrls.length - 1; i >= 0; i--) {
      if (_numero(_cargaCtrls[i].text) != null) return i;
    }
    return -1;
  }

  /// Cargas de pesas validadas que tienen carga e indicación.
  List<int> _filasPesas() => [
        for (int i = 0;
            i < _cargasPatronValidadas && i < _cargaCtrls.length;
            i++)
          if (_numero(_cargaCtrls[i].text) != null &&
              _numero(_indCtrls[i].text) != null)
            i,
      ];

  /// El aviso nuevo reemplaza al anterior: es el que dice qué hacer ahora.
  void _aviso(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  /// Asistente de una carga sustitutiva. El método elegido fija qué filas se
  /// usan (ver [filasDelMetodo]); el técnico solo elige, si hay varias, cuál
  /// es la carga de pesas, y escribe la indicación de la carga sustitutiva.
  void _showCargaSustitutivaSheet() {
    final metodo = _metodoSustitucion;
    if (!_cargasValidadas || _cargasPatronValidadas <= 0) return;
    if (metodo == null) {
      _aviso('Elija el método de cargas sustitutivas: Método 1 o Método 2.');
      return;
    }
    final filasPesas = _filasPesas();
    if (filasPesas.isEmpty) {
      _aviso('No hay cargas de pesas validadas con su indicación.');
      return;
    }
    final filaAnterior = _ultimaFilaConCarga();
    if (filaAnterior < 0) return;
    if (_numero(_indCtrls[filaAnterior].text) == null) {
      _aviso('Registre primero la indicación de la Carga ${filaAnterior + 1}.');
      return;
    }
    final filaNueva = filaAnterior + 1;
    if (filaNueva >= _maxPuntos) {
      _aviso('Maximo 60 puntos permitidos');
      return;
    }

    final filas = _filasVigentes();
    // La carga de pesas de la sustitución anterior o, si es la primera, la
    // mayor de las validadas.
    final ultimo = _pasos.isEmpty ? null : _pasos.last;
    final pesasAnteriores = ultimo == null
        ? null
        : ultimo.metodo == MetodoSustitucion.metodo1
            ? ultimo.filaBase
            : ultimo.filaReferencia;
    int filaPesas =
        pesasAnteriores != null && filasPesas.contains(pesasAnteriores)
            ? pesasAnteriores
            : filasPesas
                .reduce((a, b) => filas[b].carga! > filas[a].carga! ? b : a);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balanza = context.read<ServiceSessionProvider>().session?.balanza;
    final indicacionCtrl = TextEditingController();
    final esMetodo1 = metodo == MetodoSustitucion.metodo1;

    showModalBottomSheet<PasoSustitucion>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filasPaso = filasDelMetodo(
              metodo,
              filaPesas: filaPesas,
              filaAnterior: filaAnterior,
            );
            final referencia = filas[filasPaso.referencia];
            final base = filas[filasPaso.base];
            final errorReferencia = referencia.indicacion! - referencia.carga!;
            final indicacion = _numero(indicacionCtrl.text);
            final calculo = indicacion == null
                ? null
                : calcularSustitucion(
                    indicacionSustitutiva: indicacion,
                    referencia: referencia,
                    base: base,
                  );

            return Padding(
              // Abajo, el teclado del sistema o la barra de navegación: la
              // hoja dibuja detrás de ella y el teclado propio quedaba tapado.
              padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.viewInsetsOf(ctx).bottom +
                      MediaQuery.paddingOf(ctx).bottom +
                      20),
              // La hoja queda fuera del teclado de la pantalla: lleva el suyo,
              // también con el lector del display.
              child: NumericKeypadHost(
                  onReadIndicator: (context) =>
                      IndicatorReaderScreen.read(context, balanza: balanza),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sheetHandle(isDark),
                      _sheetTitle(
                          'Carga sustitutiva · ${metodo.etiqueta}', isDark),
                      const SizedBox(height: 8),
                      Text(
                        esMetodo1
                            ? 'Pese la carga sustitutiva sola: debe parecerse a la carga anterior. Su indicación se corrige con el error de la carga anterior y el resultado se suma a la carga de pesas.'
                            : 'Pese la carga sustitutiva sola: debe parecerse a la carga de pesas. Su indicación se corrige con el error de la carga de pesas y el resultado se suma a la carga anterior.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (filasPesas.length > 1) ...[
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: filaPesas,
                          decoration: _deco('Carga de pesas', isDark),
                          dropdownColor:
                              isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          items: filasPesas
                              .map(
                                (fila) => DropdownMenuItem(
                                  value: fila,
                                  child: Text(
                                    'Carga ${fila + 1}: ${_fmt(filas[fila].carga!)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => filaPesas = value);
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      _sheetResult(
                        'Corrige: Carga ${filasPaso.referencia + 1} = ${_fmt(referencia.carga!)}\n'
                        '  indicación ${_fmt(referencia.indicacion!)} · error ${_fmt(errorReferencia)}\n'
                        'Se suma a: Carga ${filasPaso.base + 1} = ${_fmt(base.carga!)}',
                        isDark,
                      ),
                      const SizedBox(height: 10),
                      _sheetNumberField(
                        controller: indicacionCtrl,
                        label: 'Indicación de la carga sustitutiva sola',
                        isDark: isDark,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      if (calculo != null) ...[
                        const SizedBox(height: 14),
                        _sheetResult(
                          'Carga real sustitutiva: ${_fmt(indicacion!)} − (${_fmt(errorReferencia)}) = ${_fmt(calculo.cargaSustitutiva)}\n'
                          'Carga ${filaNueva + 1}: ${_fmt(base.carga!)} + ${_fmt(calculo.cargaSustitutiva)} = ${_formatCarga(calculo.cargaResultante)}',
                          isDark,
                        ),
                      ],
                      if (calculo != null && calculo.fueraDeRango) ...[
                        const SizedBox(height: 10),
                        _sheetWarning(
                          'La carga sustitutiva se aparta un '
                          '${((calculo.desvio ?? 0) * 100).round()} % de la '
                          'Carga ${filasPaso.referencia + 1}: su error ya no '
                          'representa bien el de la carga sustitutiva. '
                          '${esMetodo1 ? 'Acérquela a la carga anterior.' : 'Acérquela a la carga de pesas.'}',
                          isDark,
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: calculo == null
                              ? null
                              : () => Navigator.pop(
                                    ctx,
                                    PasoSustitucion(
                                      fila: filaNueva,
                                      metodo: metodo,
                                      indicacionSustitutiva: indicacion!,
                                      filaReferencia: filasPaso.referencia,
                                      filaBase: filasPaso.base,
                                      registradoEn: DateTime.now(),
                                    ),
                                  ),
                          icon: const Icon(AppIcons.listo),
                          label: const Text('Guardar carga sustitutiva'),
                        ),
                      ),
                    ],
                  )),
            );
          },
        );
      },
    ).then((paso) {
      if (paso != null && mounted) _agregarPaso(paso);
    });
  }

  /// Deja la carga que resulta en su fila, con la indicación vacía: el
  /// técnico la lee con la carga completa sobre la balanza.
  void _agregarPaso(PasoSustitucion paso) {
    setState(() {
      while (_cargaCtrls.length <= paso.fila) {
        _cargaCtrls.add(TextEditingController());
        _indCtrls.add(TextEditingController());
        _retCtrls.add(TextEditingController(text: '0'));
      }
      _indCtrls[paso.fila].clear();
      _retCtrls[paso.fila].text = '0';
      _pasos = [
        for (final otro in _pasos)
          if (otro.fila != paso.fila) otro,
        paso,
      ]..sort((a, b) => a.fila.compareTo(b.fila));
      _recalcularSustitutivas();
    });
    _saveToProvider();
    _aviso(paso.metodo == MetodoSustitucion.metodo1
        ? 'Ahora ponga juntas la Carga ${paso.filaBase + 1} de pesas y la carga sustitutiva, y registre la indicación de la Carga ${paso.fila + 1}.'
        : 'Ahora agregue la carga sustitutiva a la carga anterior y registre la indicación de la Carga ${paso.fila + 1}.');
  }

  Widget _sheetWarning(String text, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.info, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetHandle(bool isDark) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white24 : Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sheetTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _sheetNumberField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    // Valor intermedio: la carga acumulada que resulta se valida en la fila.
    return CalibrationNumberField(
      controller: controller,
      readable: true,
      onChanged: onChanged,
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: _deco(label, isDark),
    );
  }

  Widget _sheetResult(String text, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withOpacity(0.12)
            : Colors.teal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: GoogleFonts.robotoMono(
          fontSize: 13,
          height: 1.5,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
    );
  }

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

  // ── Fotos de Carga ────────────────────────────────────────────────────

  Widget _buildFotosSection(bool isDark) {
    final seca =
        context.read<ServiceSessionProvider>().session?.sessionInfo.seca;
    final codMetrica =
        context.read<ServiceSessionProvider>().session?.balanza?.codMetrica;
    final canTakePhoto = !_isTakingFoto &&
        _fotosPaths.length < 5 &&
        seca != null &&
        seca.isNotEmpty &&
        codMetrica != null &&
        codMetrica.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(AppIcons.camara,
                color: isDark ? Colors.white54 : Colors.black54, size: 20),
            const SizedBox(width: 8),
            Text('Fotos de Carga',
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
    ).animate(delay: 700.ms).fadeIn();
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
            'Tome fotografías de la última carga',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: canTakePhoto ? _takeFoto : null,
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
                onPressed: _takeFoto,
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
              onTap: exists ? () => _viewFoto(path) : null,
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
}
