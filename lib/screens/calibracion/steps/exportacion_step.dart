import 'package:flutter/material.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/home/screens/home_screen.dart';

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
    final exp = provider.session?.exportacion;
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
        final type = (eq['instrumento']?.toString() ??
                eq['tipo_instrumento']?.toString() ??
                '')
            .toLowerCase();
        return !type.contains('pesa') &&
            !type.contains('masa') &&
            !type.contains('patron') &&
            !type.contains('patr');
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
    setState(() => _balanzasCount = registros.length);
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

  Future<void> _seleccionarOtraBalanza(ServiceSessionProvider provider) async {
    await provider.marcarBalanzaCompleta();
    await provider.resetearParaNuevaBalanza();
  }

  Future<void> _exportar(ServiceSessionProvider provider) async {
    _saveToProvider();
    await provider.flushAutoSave();

    final seca = provider.session?.sessionInfo.seca;
    if (seca == null || seca.isEmpty) {
      if (mounted) TopAlert.show(context, 'SECA no disponible', isError: true);
      return;
    }

    final registrosHoy =
        await provider.getRegistrosCompletos(seca, soloHoy: true);
    final registrosTodas =
        await provider.getRegistrosCompletos(seca, soloHoy: false);

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opcion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.file_download_rounded,
                color: isDark ? Colors.green[300] : Colors.green[700],
                size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Exportar datos',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : const Color(0xFF1A1A1A)))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Qué balanzas desea exportar?',
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),
            _opcionExportacion(
              ctx,
              icon: Icons.today_rounded,
              titulo: 'Solo las de hoy',
              subtitulo: '${registrosHoy.length} balanza(s)',
              isDark: isDark,
              onTap: () => Navigator.pop(ctx, 'hoy'),
            ),
            const SizedBox(height: 12),
            _opcionExportacion(
              ctx,
              icon: Icons.calendar_month_rounded,
              titulo: 'Todas las del SECA',
              subtitulo: '${registrosTodas.length} balanza(s)',
              isDark: isDark,
              onTap: () => Navigator.pop(ctx, 'todas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style:
                    TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          ),
        ],
      ),
    );

    if (opcion == null || !mounted) return;

    final registros = opcion == 'hoy' ? registrosHoy : registrosTodas;
    if (registros.isEmpty) {
      TopAlert.show(context, 'No hay registros para exportar', isError: true);
      return;
    }

    final datosCert = await _showCertificadoDialog(isDark);
    if (datosCert == null || !mounted) return;

    final instrumentos = await _showInstrumentosDialog(isDark);
    if (instrumentos == null || !mounted) return;

    // Aplicar datos del certificado a todas las filas exportadas
    final registrosConCert = registros
        .map((r) => ({
              ...r,
              ...datosCert,
            }))
        .toList();

    _emp = datosCert['emp'];
    _indicarCtrl.text = datosCert['indicar'] ?? '';
    _factorCtrl.text = datosCert['factor'] ?? '';
    _regla = datosCert['regla_aceptacion'];
    _saveToProvider();

    // Persist instrument selection
    if (instrumentos.isNotEmpty) {
      final existing = provider.session?.equipos ?? [];
      final pesas = existing.where((e) => _isPesaTipo(e.tipo)).toList();
      provider.updateEquipos([...pesas, ...instrumentos]);
    }

    final registrosConTodo = registrosConCert
        .map((r) => ({
              ...r,
              ..._instrumentosToColumns(instrumentos),
            }))
        .toList();

    await provider.persistSharedExportData(seca, {
      ...datosCert,
      ..._instrumentosToColumns(instrumentos),
    });

    final success = await provider.exportToCSV(registrosConTodo);
    if (!mounted) return;

    if (success) {
      TopAlert.show(context,
          'Exportación exitosa: ${registros.length} balanza(s) exportada(s)',
          isError: false);
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
    } else {
      TopAlert.show(context, 'Error al exportar CSV', isError: true);
    }
  }

  bool _isPesaTipo(String? value) {
    final v = value?.toLowerCase() ?? '';
    return v.contains('pesa') ||
        v.contains('masa') ||
        v.contains('patron') ||
        v.contains('patr');
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

    final result = await showDialog<List<EquipoInfo>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = _equipamientos.where((eq) {
            final q = searchCtrl.text.toLowerCase();
            if (q.isEmpty) return true;
            final code = eq['cod_instrumento']?.toString().toLowerCase() ?? '';
            final type = (eq['instrumento']?.toString() ?? '').toLowerCase();
            return code.contains(q) || type.contains(q);
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.thermostat,
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
                      prefixIcon: const Icon(Icons.search_rounded),
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
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
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
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, List<EquipoInfo>.from(selected)),
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
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.verified_outlined,
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
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => empCtrl.text = v ?? '');
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                      style: GoogleFonts.inter(
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A)),
                      controller: indicarCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _deco('Indicar (%)', isDark),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                      style: GoogleFonts.inter(
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A)),
                      controller: factorCtrl,
                      keyboardType: TextInputType.number,
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
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
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
          );
        },
      ),
    );

    return result;
  }

  Widget _opcionExportacion(
    BuildContext ctx, {
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isDark ? Colors.white54 : Colors.black54, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(subtitulo,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 20),
              _buildResumenCard(seca, cod, isDark),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _seleccionarOtraBalanza(provider),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('SELECCIONAR OTRA BALANZA',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF326677),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ).animate(delay: 300.ms).fadeIn().scale(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _exportar(provider),
                  icon: const Icon(Icons.file_download),
                  label: const Text('FINALIZAR Y EXPORTAR',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3e7732),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
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
          'Exportación',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Finalización del servicio y descarga de datos',
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
              Icon(Icons.summarize_rounded,
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
          _row('Balanzas calibradas', '$_balanzasCount', isDark),
          const SizedBox(height: 8),
          _row('Fecha', DateFormat('dd MMM yyyy').format(DateTime.now()),
              isDark),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn();
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
