import 'package:flutter/material.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/database/calibration_record_validator.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/home/screens/home_screen.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';
import 'package:service_met/screens/calibracion/widgets/save_blocked_dialog.dart';
import 'package:service_met/widgets/numeric_keypad.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/theme/app_colors.dart';
import '../../../theme/app_icons.dart';

class ExportacionStep extends StatefulWidget {
  const ExportacionStep({super.key});

  @override
  State<ExportacionStep> createState() => _ExportacionStepState();
}

class _ExportacionStepState extends State<ExportacionStep> {
  String? _emp;
  String? _regla;
  final _indicarCtrl = TextEditingController();
  final _factorCtrl = TextEditingController();
  int _balanzasCount = 0;
  List<Map<String, dynamic>> _balanzasRegistradas = [];

  List<Map<String, dynamic>> _equipamientos = [];
  List<EquipoInfo> _selectedInstrumentos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromSession();
      _loadBalanzasCount();
      _loadInstrumentos();
    });
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final session = provider.session;
    _selectedInstrumentos = session?.equipos
            .where((e) => !ServiceSessionProvider.isPatronType(e.tipo))
            .take(2)
            .toList() ??
        [];
    final exp = session?.exportacion;
    if (exp != null) {
      setState(() {
        _emp = const ['Sí', 'No'].contains(exp.emp23001) ? exp.emp23001 : null;
        _regla = const ['Ninguna', 'Simple', 'Conservadora']
                .contains(exp.reglaAceptacion)
            ? exp.reglaAceptacion
            : null;
        _indicarCtrl.text = exp.indicar ?? '';
        _factorCtrl.text = exp.factorSeguridad ?? '';
      });
    }
  }

  Future<void> _loadInstrumentos() async {
    if (!mounted) return;
    try {
      final result = await CalibrationRepository().getEquipos();
      if (!mounted) return;
      final instrumentos = result.where((eq) {
        final primary = eq['instrumento']?.toString() ?? '';
        final type = (primary.isNotEmpty
                ? primary
                : (eq['tipo_instrumento']?.toString() ?? ''))
            .toLowerCase();
        return !ServiceSessionProvider.isPatronType(type);
      }).toList();
      instrumentos.sort((a, b) {
        final codeA = a['cod_instrumento']?.toString() ?? '';
        final codeB = b['cod_instrumento']?.toString() ?? '';
        return codeA.compareTo(codeB);
      });
      if (!mounted) return;
      setState(() => _equipamientos = instrumentos);
    } catch (_) {
      // silently fail
    }
  }

  Future<void> _loadBalanzasCount() async {
    if (!mounted) return;
    final provider = context.read<ServiceSessionProvider>();
    final seca = provider.session?.sessionInfo.seca;
    if (seca == null || seca.isEmpty) return;
    final registros =
        await provider.getRegistrosCompletos(seca, soloHoy: false);
    if (!mounted) return;
    setState(() {
      _balanzasRegistradas = registros;
      _balanzasCount = registros.length;
    });
  }

  Future<void> _reviewOtherBalance(
      ServiceSessionProvider provider, String sessionId,
      {int step = 10}) async {
    if (!await provider.flushAutoSave()) {
      if (mounted) {
        TopAlert.show(context, provider.saveError ?? 'No se pudo guardar.',
            isError: true);
      }
      return;
    }
    final seca = provider.session?.sessionInfo.seca;
    if (seca == null || seca.isEmpty) return;
    try {
      await provider.loadExistingSession(seca, sessionId);
      if (provider.session == null) {
        throw StateError('No se encontró la balanza seleccionada.');
      }
      provider.goToStep(step);
    } catch (error) {
      if (mounted) {
        TopAlert.show(context, 'No se pudo abrir la balanza: $error',
            isError: true);
      }
    }
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateExportacion(ExportacionData(
      emp23001: _emp,
      indicar: _indicarCtrl.text,
      factorSeguridad: _factorCtrl.text,
      reglaAceptacion: _regla,
    ));
  }

  /// Antes de cerrar la balanza (o de pedir los datos del certificado): si
  /// le falta algo, se dice qué y se ofrece ir a corregirlo. Devuelve true
  /// si está completa.
  Future<bool> _balanzaCompleta(ServiceSessionProvider provider) async {
    final session = provider.session;
    if (session == null) return false;
    final issues = ServiceSessionProvider.calibrationIssues(session);
    if (issues.isEmpty) return true;
    final corregir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(AppIcons.verificacion, color: AppColors.warning),
        title: const Text('Faltan datos de esta balanza'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Para darla por calibrada complete:'),
              const SizedBox(height: 10),
              for (final issue in issues.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${ServiceSessionProvider.stepNames[issue.step]}: '
                    '${issue.message}',
                  ),
                ),
              if (issues.length > 6)
                Text('• y ${issues.length - 6} dato(s) más.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Ir a ${ServiceSessionProvider.stepNames[issues.first.step]}',
            ),
          ),
        ],
      ),
    );
    if (corregir == true) provider.goToStep(issues.first.step);
    return false;
  }

  Future<void> _seleccionarOtraBalanza(ServiceSessionProvider provider) async {
    if (!await _balanzaCompleta(provider)) return;
    final error = await provider.marcarBalanzaCompleta();
    if (error != null) {
      // La balanza queda abierta: los datos siguen en pantalla para corregir.
      if (mounted) await showSaveBlockedDialog(context, error);
      return;
    }
    await provider.resetearParaNuevaBalanza();
  }

  Future<void> _finalizar(ServiceSessionProvider provider) async {
    _saveToProvider();
    if (!await provider.flushAutoSave()) {
      if (mounted) {
        TopAlert.show(context, provider.saveError ?? 'No se pudo guardar.',
            isError: true);
      }
      return;
    }

    final seca = provider.session?.sessionInfo.seca;
    if (seca == null || seca.isEmpty) {
      if (mounted) TopAlert.show(context, 'SECA no disponible', isError: true);
      return;
    }
    if (!mounted) return;
    // Antes de pedir los datos del certificado: no tiene sentido llenarlos
    // para descubrir después que la balanza no puede cerrarse.
    if (!await _balanzaCompleta(provider) || !mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final datosCert = await _showCertificadoDialog(isDark);
    if (datosCert == null || !mounted) return;

    // Se aplican a todas las balanzas de la SECA: un valor fuera de esquema
    // haría fallar el guardado de todas.
    final certIssues = CalibrationRecordValidator.schemaIssues(datosCert);
    if (certIssues.isNotEmpty) {
      TopAlert.show(context, '${certIssues.first}', isError: true);
      return;
    }

    final instrumentos = await _showInstrumentosDialog(isDark);
    if (instrumentos == null || !mounted) return;

    _emp = datosCert['emp'];
    _indicarCtrl.text = datosCert['indicar'] ?? '';
    _factorCtrl.text = datosCert['factor'] ?? '';
    _regla = datosCert['regla_aceptacion'];
    _saveToProvider();

    // Persist instrument selection
    provider.updateMeasuringInstruments(instrumentos);

    try {
      await provider.persistSharedExportData(seca, {
        ...datosCert,
        ..._instrumentosToColumns(instrumentos),
      });

      final error = await provider.marcarBalanzaCompleta();
      if (error != null) {
        if (mounted) await showSaveBlockedDialog(context, error);
        return;
      }
      final registros = (await provider.getRegistrosCompletos(
        seca,
        soloHoy: false,
      ))
          .where((record) =>
              record['estado_servicio_bal']?.toString() ==
                  'Balanza Calibrada' &&
              (record['finalized_at']?.toString().isEmpty ?? true))
          .toList();
      if (registros.isEmpty) {
        throw StateError('No hay balanzas completas para finalizar.');
      }
      if (!mounted) return;
      if (!await _confirmarPruebasCompletas(registros, isDark)) return;

      final finalizedAt = DateTime.now();
      final nombreCsv =
          '${seca}_${DateFormat('yyyyMMdd_HHmmss').format(finalizedAt)}.csv';
      if (nombreCsv.length > 100) {
        throw StateError(
          'El nombre lógico del servicio supera los 100 caracteres.',
        );
      }
      await provider.finalizeCalibrationRecords(
        seca: seca,
        sessionIds:
            registros.map((record) => record['session_id']?.toString() ?? ''),
        nombreCsv: nombreCsv,
        finalizedAt: finalizedAt,
      );
      if (!mounted) return;
      TopAlert.show(
        context,
        'Servicio finalizado: ${registros.length} balanza(s) guardada(s)',
        isError: false,
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      TopAlert.show(
        context,
        'No se pudo finalizar el servicio: '
        '${error is StateError ? error.message : error}',
        isError: true,
      );
    }
  }

  /// Última revisión en sitio, sobre lo que realmente quedó en la base de
  /// cada balanza que se va a finalizar: con el técnico todavía frente a la
  /// balanza, una prueba que falta aún se puede repetir.
  Future<bool> _confirmarPruebasCompletas(
      List<Map<String, dynamic>> registros, bool isDark) async {
    final incompletas = <String>[];
    for (final record in registros) {
      final faltan = CalibrationRecordValidator.missingTests(record);
      if (faltan.isNotEmpty) {
        incompletas.add(
            '${record['cod_metrica'] ?? 'Sin código'}: ${faltan.join(', ')}');
      }
    }
    if (incompletas.isEmpty) return true;

    final continuar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(AppIcons.advertencia,
                color: isDark ? Colors.amber[300] : Colors.amber[800],
                size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Pruebas incompletas')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Estas balanzas no tienen guardadas todas sus pruebas:'),
              const SizedBox(height: 12),
              for (final linea in incompletas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $linea',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 8),
              const Text(
                  'Si finaliza, se exportarán y subirán sin esas pruebas.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalizar igual'),
          ),
        ],
      ),
    );
    return continuar == true;
  }

  Map<String, String> _instrumentosToColumns(List<EquipoInfo> instrumentos) {
    final map = <String, String>{};
    for (int i = 0; i < instrumentos.length && i < 2; i++) {
      final idx = i + 6;
      final inst = instrumentos[i];
      map['equipo$idx'] = inst.codInstrumento ?? '';
      if (inst.certFecha != null && inst.certFecha!.isNotEmpty) {
        map['certificado$idx'] = inst.certFecha!;
      }
      if (inst.enteCalibrador != null && inst.enteCalibrador!.isNotEmpty) {
        map['ente_calibrador$idx'] = inst.enteCalibrador!;
      }
      if (inst.estado != null && inst.estado!.isNotEmpty) {
        map['estado$idx'] = inst.estado!;
      }
      if (inst.cantidad != null && inst.cantidad!.isNotEmpty) {
        map['cantidad$idx'] = inst.cantidad!;
      }
    }
    return map;
  }

  /// Muestra un diálogo para seleccionar instrumentos de medición del servicio.
  /// Retorna la lista de instrumentos seleccionados o null si cancela.
  Future<List<EquipoInfo>?> _showInstrumentosDialog(bool isDark) async {
    List<EquipoInfo> selected = List<EquipoInfo>.from(_selectedInstrumentos);
    final searchCtrl = TextEditingController();
    final available = List<Map<String, dynamic>>.from(_equipamientos);
    for (final instrument in selected) {
      if (!available.any((item) =>
          item['cod_instrumento']?.toString() == instrument.codInstrumento)) {
        available.add({
          'cod_instrumento': instrument.codInstrumento,
          'instrumento': instrument.tipo,
          'cert_fecha': instrument.certFecha,
          'ente_calibrador': instrument.enteCalibrador,
        });
      }
    }

    final result = await showDialog<List<EquipoInfo>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = available.where((eq) {
            final q = searchCtrl.text.toLowerCase();
            if (q.isEmpty) return true;
            final code = eq['cod_instrumento']?.toString().toLowerCase() ?? '';
            final type = (eq['instrumento']?.toString() ?? '').toLowerCase();
            return code.contains(q) || type.contains(q);
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                Icon(AppIcons.temperatura,
                    color: isDark ? Colors.green[300] : Colors.green[700],
                    size: 22),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Instrumentos de Medición',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A)))),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccione los instrumentos usados en el servicio:',
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por código o tipo...',
                      prefixIcon: const Icon(AppIcons.buscar),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF0F2F5),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${selected.length}/2 seleccionados',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text('Sin resultados',
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final eq = filtered[i];
                              final code = eq['cod_instrumento']?.toString() ??
                                  'Sin código';
                              final type = eq['instrumento']?.toString() ?? '';
                              final cert =
                                  eq['cert_fecha']?.toString() ?? 'S/F';
                              final isSelected =
                                  selected.any((e) => e.codInstrumento == code);
                              final canSelect =
                                  isSelected || selected.length < 2;

                              return InkWell(
                                onTap: canSelect
                                    ? () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            selected.removeWhere((e) =>
                                                e.codInstrumento == code);
                                          } else {
                                            selected.add(EquipoInfo(
                                              codInstrumento: code,
                                              tipo: type,
                                              cantidad: '1',
                                              certFecha: eq['cert_fecha']
                                                      ?.toString() ??
                                                  '',
                                              enteCalibrador:
                                                  eq['ente_calibrador']
                                                          ?.toString() ??
                                                      '',
                                            ));
                                          }
                                        });
                                      }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? (isDark
                                              ? Colors.tealAccent
                                              : Colors.teal)
                                          : (isDark
                                              ? Colors.white12
                                              : const Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? AppIcons.completo
                                            : AppIcons.circulo,
                                        color: isSelected
                                            ? (isDark
                                                ? Colors.tealAccent
                                                : Colors.teal)
                                            : Colors.grey,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(code,
                                                style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1A1A1A))),
                                            const SizedBox(height: 2),
                                            Text(type,
                                                style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.white60
                                                        : Colors.black54)),
                                            const SizedBox(height: 4),
                                            Text('Cert: $cert',
                                                style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? Colors.white38
                                                        : Colors.black38)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar',
                    style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54)),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, List<EquipoInfo>.from(selected)),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      _selectedInstrumentos = result;
    }
    searchCtrl.dispose();
    return result;
  }

  /// Muestra un diálogo para ingresar los datos del certificado.
  /// Retorna un mapa con los valores si el usuario confirma, null si cancela.
  Future<Map<String, String>?> _showCertificadoDialog(bool isDark) async {
    final empCtrl = TextEditingController(text: _emp ?? '');
    final indicarCtrl = TextEditingController(text: _indicarCtrl.text);
    final factorCtrl = TextEditingController(text: _factorCtrl.text);
    String regla = _regla ?? '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return NumericKeypadHost(
            dockToScreen: true,
            child: AlertDialog(
              scrollable: true,
              title: Row(
                children: [
                  Icon(AppIcons.verificado,
                      color: isDark ? Colors.green[300] : Colors.green[700],
                      size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Datos del Certificado',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A)))),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingrese los datos para el certificado de calibración:',
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: const ['Sí', 'No'].contains(empCtrl.text)
                          ? empCtrl.text
                          : null,
                      decoration: _deco('EMP NB 23001', isDark),
                      dropdownColor:
                          isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      items: ['Sí', 'No']
                          .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() => empCtrl.text = v ?? '');
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: CalibrationNumberField(
                            style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A)),
                            controller: indicarCtrl,
                            column: 'indicar',
                            decoration: _deco('Indicar (%)', isDark),
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: CalibrationNumberField(
                            style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A)),
                            controller: factorCtrl,
                            column: 'factor',
                            decoration: _deco('Factor Seguridad', isDark),
                          )),
                        ]),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: const ['Ninguna', 'Simple', 'Conservadora']
                              .contains(regla)
                          ? regla
                          : null,
                      decoration: _deco('Regla de Aceptación', isDark),
                      dropdownColor:
                          isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      items: ['Ninguna', 'Simple', 'Conservadora']
                          .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() => regla = v ?? '');
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar',
                      style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54)),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'emp': empCtrl.text,
                    'indicar': indicarCtrl.text,
                    'factor': factorCtrl.text,
                    'regla_aceptacion': regla,
                  }),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          );
        },
      ),
    );

    return result;
  }

  @override
  void dispose() {
    _indicarCtrl.dispose();
    _factorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        final session = provider.session;
        final info = session?.sessionInfo;
        final seca = info?.seca ?? 'Sin SECA';
        final cod = info?.codMetrica ?? 'Sin Codigo';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SingleChildScrollView(
          padding: ServiceNavPill.pagePadding(context, top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 20),
              _buildResumenCard(seca, cod, isDark),
              const SizedBox(height: 16),
              _buildReview(provider),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _seleccionarOtraBalanza(provider),
                  icon: const Icon(AppIcons.agregarCirculo),
                  label: const Text('SELECCIONAR OTRA BALANZA',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ).animate(delay: 300.ms).fadeIn().scale(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _finalizar(provider),
                  icon: const Icon(AppIcons.completo),
                  label: const Text('FINALIZAR SERVICIO',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ).animate(delay: 400.ms).fadeIn().scale(),
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
          'Finalización',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Revisión y cierre del servicio de calibración',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildResumenCard(String seca, String cod, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.resumen,
                  color: isDark ? Colors.white54 : Colors.black54, size: 20),
              const SizedBox(width: 10),
              Text(
                'Resumen del Servicio',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row('SECA', seca, isDark),
          const SizedBox(height: 8),
          _row('Balanzas registradas', '$_balanzasCount', isDark),
          const SizedBox(height: 8),
          _row('Fecha', _serviceDate(context), isDark),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn();
  }

  String _serviceDate(BuildContext context) {
    final raw = context
        .read<ServiceSessionProvider>()
        .session
        ?.sessionInfo
        .fechaServicio;
    final date = DateTime.tryParse(raw ?? '');
    return date == null ? (raw ?? '-') : DateFormat('dd MMM yyyy').format(date);
  }

  Widget _buildReview(ServiceSessionProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final session = provider.session;
    const labels = ServiceSessionProvider.stepNames;
    final finalPhotos =
        session?.condicionesFinales?.fotosFinalesPaths?.length ?? 0;
    final loadPhotos = session?.linealidad?.fotosPaths.length ?? 0;
    final patterns = (session?.equipos ?? const <EquipoInfo>[])
        .where((e) => ServiceSessionProvider.isPatronType(e.tipo))
        .length;
    // Las mismas balanzas que la lista del paso Instrumento: sin los intentos
    // descartados, que quedan en la tabla con sus pruebas a medias.
    final otherBalances = _balanzasRegistradas
        .where((r) =>
            r['session_id']?.toString() != session?.sessionInfo.sessionId &&
            (r['finalized_at']?.toString().isEmpty ?? true) &&
            r['servicio_status']?.toString() != 'abandoned')
        .toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text('Revisión de esta balanza',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          for (final entry in labels.entries) ...[
            Builder(builder: (context) {
              final issue = entry.key == 3 &&
                      !(session?.metadata.balanzaConfirmed ?? false)
                  ? provider.validateStep(3) ??
                      'Confirma los datos del instrumento.'
                  : provider.validateStep(entry.key);
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(
                    issue == null ? AppIcons.completo : AppIcons.error,
                    color: issue == null ? AppColors.success : colors.error),
                title: Text(entry.value),
                subtitle: issue == null ? null : Text(issue),
                trailing: issue == null
                    ? null
                    : TextButton(
                        onPressed: () => provider.goToStep(entry.key),
                        child: const Text('Corregir'),
                      ),
              );
            }),
            if (entry.key != 9) const Divider(height: 1),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
                'Pesas patrón: $patterns  ·  Fotos de linealidad: '
                '$loadPhotos  ·  Fotos finales: $finalPhotos',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          ),
          if (otherBalances.isNotEmpty) ...[
            const Divider(height: 24),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Otras balanzas del servicio',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700))),
            for (final balance in otherBalances)
              Builder(builder: (context) {
                // Mismas reglas que la revisión de la balanza abierta y que el
                // cierre: si aquí dice "calibrada", al abrirla también.
                final other = ServiceSession.fromMap(balance);
                final issues = ServiceSessionProvider.calibrationIssues(other);
                final calibrada = balance['estado_servicio_bal']?.toString() ==
                    'Balanza Calibrada';
                final patterns = other.equipos
                    .where((e) => ServiceSessionProvider.isPatronType(e.tipo))
                    .length;
                final loadPhotos = other.linealidad?.fotosPaths.length ?? 0;
                final finalPhotos =
                    other.condicionesFinales?.fotosFinalesPaths?.length ?? 0;
                final pendientes = {
                  for (final issue in issues) labels[issue.step],
                }.join(', ');
                final estado = switch ((calibrada, issues.isEmpty)) {
                  (true, true) => 'Calibrada',
                  (true, false) =>
                    'Calibrada con datos pendientes: $pendientes',
                  (false, true) => 'En curso · lista para cerrar',
                  (false, false) => 'En curso · falta: $pendientes',
                };
                final ok = calibrada && issues.isEmpty;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title:
                      Text(balance['cod_metrica']?.toString() ?? 'Sin código'),
                  subtitle: Text(
                    '$estado\n'
                    'Pesas patrón: $patterns  ·  Fotos de linealidad: '
                    '$loadPhotos  ·  Fotos finales: $finalPhotos',
                  ),
                  leading: Icon(
                    ok ? AppIcons.completo : AppIcons.advertencia,
                    color: ok ? AppColors.success : AppColors.warning,
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      final sessionId = balance['session_id']?.toString();
                      if (sessionId != null && sessionId.isNotEmpty) {
                        _reviewOtherBalance(
                          provider,
                          sessionId,
                          step: issues.isEmpty ? 10 : issues.first.step,
                        );
                      }
                    },
                    child: Text(issues.isEmpty ? 'Revisar' : 'Corregir'),
                  ),
                );
              }),
          ],
        ]),
      ),
    );
  }

  Widget _row(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
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
}
