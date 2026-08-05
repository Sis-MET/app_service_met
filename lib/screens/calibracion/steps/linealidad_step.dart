import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/screens/calibracion/utils/suggestion_helper.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/utils/foto_helper.dart';
import 'package:service_met/utils/foto_storage_dialog.dart';
import 'package:service_met/utils/top_alert.dart';

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

    if (_cargasValidadas && _cargasPatronValidadas <= 0) {
      _cargasPatronValidadas = _filledPatronRowsCount();
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
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
      if (_cargasPatronValidadas > _cargaCtrls.length) {
        _cargasPatronValidadas = _cargaCtrls.length;
      }
      if (_cargasPatronValidadas == 0) _cargasValidadas = false;
    });
    _saveToProvider();
  }

  void _onCargaChanged(int i, String val) {
    if (!_cargasValidadas || i < _cargasPatronValidadas) {
      _indCtrls[i].text = _formatValueWithPrecision(val);
    }
    _saveToProvider();
    setState(() {});
  }

  void _onIndicacionChanged(int i, String val) {
    _saveToProvider();
    setState(() {});
  }

  void _onRetornoChanged() {
    _saveToProvider();
    setState(() {});
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
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
    });
    _saveToProvider();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cargas patron validadas: $count')),
    );
  }

  void _resetValidation() {
    setState(() {
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
              iconTheme: const IconThemeData(color: Colors.white)),
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
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
                  onChanged: _onMetodoCargasSustitutivasChanged,
                ).animate(delay: 280.ms).fadeIn(),
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
            _cargasValidadas
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: Colors.teal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _cargasValidadas
                  ? 'Cargas patron validadas: $_cargasPatronValidadas. Ya puede agregar cargas sustitutivas usando el asistente.'
                  : 'Primero registre y revise las cargas de sus pesas patron. Cuando termine, pulse Validar cargas para habilitar el calculo de cargas sustitutivas.',
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
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: Colors.teal, size: 22),
                  onPressed: _addRow,
                  tooltip: 'Agregar fila',
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: Colors.teal, size: 22),
                  onPressed: _removeRow,
                  tooltip: 'Eliminar ultima fila',
                ),
                if (_cargasValidadas)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
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
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Validar cargas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cargasValidadas ? _showCargaSustitutivaSheet : null,
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Carga sustitutiva'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
    final isSustitutiva = _cargasValidadas && i >= _cargasPatronValidadas;
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
              if (isSustitutiva) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Sustitutiva',
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
            children: [
              Expanded(child: _cargaField(i, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _indicationField(i, isDark)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _retornoField(i, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _errorField(i, isDark)),
            ],
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
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _cargaCtrls[i],
      onChanged: (val) => _onCargaChanged(i, val),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      decoration: _fieldDecoration(isDark, labelText: 'Carga real'),
    );
  }

  Widget _indicationField(int i, bool isDark) {
    final hasBase = _cargaCtrls[i].text.isNotEmpty;
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _indCtrls[i],
      onChanged: (val) => _onIndicacionChanged(i, val),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
      decoration: _fieldDecoration(
        isDark,
        labelText: 'Indicacion',
        suffixIcon: hasBase
            ? InkWell(
                onTap: () => _showIndicacionSuggestion(i),
                child: const Icon(Icons.unfold_more_rounded,
                    color: Colors.teal, size: 20),
              )
            : null,
      ),
    );
  }

  Widget _retornoField(int i, bool isDark) {
    return TextField(
      style: GoogleFonts.inter(
          fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      controller: _retCtrls[i],
      onChanged: (_) => _onRetornoChanged(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
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

  void _showCargaSustitutivaSheet() {
    if (!_cargasValidadas || _cargasPatronValidadas <= 0) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indicacionCtrl = TextEditingController();
    final validatedLoads = _referenceLoads();
    final baseLoads = _baseLoads();
    if (validatedLoads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cargas patron validas para usar.'),
        ),
      );
      indicacionCtrl.dispose();
      return;
    }
    if (baseLoads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cargas base validadas para sumar.'),
        ),
      );
      indicacionCtrl.dispose();
      return;
    }
    int selectedBaseIndex = baseLoads.last.index;
    int selectedLoadIndex = validatedLoads.last.index;
    bool referenceSelectedManually = false;

    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final indicacion = double.tryParse(indicacionCtrl.text) ?? 0.0;
            final selectedLoad = validatedLoads.firstWhere(
              (load) => load.index == selectedLoadIndex,
              orElse: () => validatedLoads.last,
            );
            final selectedBase = baseLoads.firstWhere(
              (load) => load.index == selectedBaseIndex,
              orElse: () => baseLoads.last,
            );
            final patronCarga = selectedLoad.carga;
            final patronError = selectedLoad.error;
            final cargaRealSustitutiva = indicacion - patronError;
            final acumulado = selectedBase.carga + cargaRealSustitutiva;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(isDark),
                  _sheetTitle('Carga sustitutiva', isDark),
                  const SizedBox(height: 8),
                  Text(
                    'Ingrese la indicacion obtenida con la carga sustitutiva. Elija la carga base que se sumara; el error se toma de la referencia mas cercana a la indicacion.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedBaseIndex,
                    decoration: _deco('Carga base para sumar', isDark),
                    dropdownColor:
                        isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    selectedItemBuilder: (context) => baseLoads
                        .map(
                          (load) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Carga ${load.index + 1}: ${_fmt(load.carga)}',
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
                    items: baseLoads
                        .map(
                          (load) => DropdownMenuItem(
                            value: load.index,
                            child: Text(
                              'Carga ${load.index + 1}: ${_fmt(load.carga)}',
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
                      setSheetState(() => selectedBaseIndex = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: selectedLoadIndex,
                    decoration:
                        _deco('Carga de referencia para correccion', isDark),
                    dropdownColor:
                        isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    selectedItemBuilder: (context) => validatedLoads
                        .map(
                          (load) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Carga ${load.index + 1}: ${_fmt(load.carga)} | Err ${_fmt(load.error)}',
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
                    items: validatedLoads
                        .map(
                          (load) => DropdownMenuItem(
                            value: load.index,
                            child: Text(
                              'Carga ${load.index + 1}: ${_fmt(load.carga)} | Ind ${_fmt(load.indicacion)} | Error ${_fmt(load.error)}',
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
                      setSheetState(() {
                        selectedLoadIndex = value;
                        referenceSelectedManually = true;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _sheetNumberField(
                    controller: indicacionCtrl,
                    label: 'Indicacion carga sustitutiva',
                    isDark: isDark,
                    onChanged: (value) {
                      final reference = double.tryParse(value);
                      setSheetState(() {
                        if (!referenceSelectedManually && reference != null) {
                          selectedLoadIndex =
                              _nearestReferenceLoad(reference, validatedLoads)
                                  .index;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _sheetResult(
                    'Carga base a sumar: ${_fmt(selectedBase.carga)}\n'
                    'Referencia elegida: ${_fmt(patronCarga)}\n'
                    'Error referencia: ${_fmt(patronError)}\n'
                    'Carga real sustitutiva: ${_fmt(cargaRealSustitutiva)}\n'
                    'Carga acumulada a registrar: ${_fmt(acumulado)}',
                    isDark,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: indicacionCtrl.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(ctx, _fmt(acumulado)),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Guardar carga sustitutiva'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null) _appendSustitutiveRow(selected);
    });
  }

  void _appendSustitutiveRow(String carga) {
    final targetIndex = _firstEmptyRowFrom(_cargasPatronValidadas);
    if (targetIndex == null && _cargaCtrls.length >= _maxPuntos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximo 60 puntos permitidos')),
      );
      return;
    }

    final formattedCarga = _formatValueWithPrecision(carga);
    setState(() {
      if (targetIndex != null) {
        _cargaCtrls[targetIndex].text = formattedCarga;
        _indCtrls[targetIndex].clear();
        _retCtrls[targetIndex].text = '0';
      } else {
        _cargaCtrls.add(TextEditingController(text: formattedCarga));
        _indCtrls.add(TextEditingController());
        _retCtrls.add(TextEditingController(text: '0'));
      }
    });
    _saveToProvider();
  }

  int? _firstEmptyRowFrom(int startIndex) {
    for (int i = startIndex; i < _cargaCtrls.length; i++) {
      final hasCarga = _cargaCtrls[i].text.trim().isNotEmpty;
      final hasInd = _indCtrls[i].text.trim().isNotEmpty;
      if (!hasCarga && !hasInd) return i;
    }
    return null;
  }

  List<_ValidatedLoad> _referenceLoads() {
    final loads = <_ValidatedLoad>[];
    for (int i = 0; i < _cargaCtrls.length; i++) {
      final carga = double.tryParse(_cargaCtrls[i].text);
      final indicacion = double.tryParse(_indCtrls[i].text);
      if (carga == null || indicacion == null) continue;
      loads.add(_ValidatedLoad(
        index: i,
        carga: carga,
        indicacion: indicacion,
        error: indicacion - carga,
      ));
    }
    return loads;
  }

  List<_ValidatedLoad> _baseLoads() {
    final loads = <_ValidatedLoad>[];
    for (int i = 0; i < _cargaCtrls.length; i++) {
      final carga = double.tryParse(_cargaCtrls[i].text);
      final indicacion = double.tryParse(_indCtrls[i].text);
      if (carga == null) continue;
      loads.add(_ValidatedLoad(
        index: i,
        carga: carga,
        indicacion: indicacion ?? carga,
        error: indicacion == null ? 0 : indicacion - carga,
      ));
    }
    return loads;
  }

  _ValidatedLoad _nearestReferenceLoad(
    double reference,
    List<_ValidatedLoad> loads,
  ) {
    _ValidatedLoad nearest = loads.first;
    for (final load in loads.skip(1)) {
      if ((reference - load.indicacion).abs() <
          (reference - nearest.indicacion).abs()) {
        nearest = load;
      }
    }
    return nearest;
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
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.inter(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
      ],
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
            Icon(Icons.camera_alt_outlined,
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
          Icon(Icons.camera_alt_outlined,
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
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Tomar Foto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.calibracion,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.calibracion.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
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
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Agregar Fotografía'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.calibracion,
                  side: const BorderSide(color: AppColors.calibracion),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
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
}

class _ValidatedLoad {
  final int index;
  final double carga;
  final double indicacion;
  final double error;

  const _ValidatedLoad({
    required this.index,
    required this.carga,
    required this.indicacion,
    required this.error,
  });
}
