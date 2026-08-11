import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:service_met/home/screens/home_screen.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_screen.dart';
import 'package:service_met/utils/foto_helper.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/theme/app_design.dart';

class FinServicioConfig {
  final String tableNameDefault;
  final String csvSuffix;
  final String additionalWhere;
  final String tipoServicio;
  final Color primaryColor;

  const FinServicioConfig({
    this.tableNameDefault = 'soporte_servicio',
    this.csvSuffix = 'servicio',
    this.additionalWhere = '',
    this.tipoServicio = 'Servicio',
    this.primaryColor = AppColors.actionPositive,
  });
}

class FinServicioScreen extends StatefulWidget {
  final FinServicioConfig config;
  final BaseSoporteController controller;
  final String codMetrica;
  final String secaValue;
  final String clienteNombre;
  final String plantaNombre;
  final String selectedInstrumento;
  final String selectedMarca;
  final String selectedModelo;
  final String selectedCapMax;
  final String selectedDivMin;
  final String sessionId;
  final String nReca;
  final String userName;
  final String clienteId;
  final String plantaCodigo;
  final String tableName;

  const FinServicioScreen({
    super.key,
    required this.config,
    required this.controller,
    this.codMetrica = '',
    this.secaValue = '',
    this.clienteNombre = '',
    this.plantaNombre = '',
    this.selectedInstrumento = '',
    this.selectedMarca = '',
    this.selectedModelo = '',
    this.selectedCapMax = '',
    this.selectedDivMin = '',
    this.sessionId = '',
    this.nReca = '',
    this.userName = '',
    this.clienteId = '',
    this.plantaCodigo = '',
    this.tableName = '',
  });

  @override
  State<FinServicioScreen> createState() => _FinServicioScreenState();
}

class _FinServicioScreenState extends State<FinServicioScreen> {
  bool _isExporting = false;
  bool _isFinalizando = false;
  int _balanzasCount = 0;
  int _balanzasCountHoy = 0;
  bool _isLoadingSummary = true;

  @override
  void initState() {
    super.initState();
    // Asegurar contexto en el controller (fallback central para todos los módulos)
    if (widget.controller.secaValue.isEmpty) {
      widget.controller.secaValue = widget.secaValue;
    }
    if (widget.controller.clienteNombre.isEmpty) {
      widget.controller.clienteNombre = widget.clienteNombre;
    }
    if (widget.controller.plantaNombre.isEmpty) {
      widget.controller.plantaNombre = widget.plantaNombre;
    }
    _prepareServiceSummary();
  }

  Future<void> _prepareServiceSummary() async {
    try {
      // La pantalla se abre después de validar el último paso. Se completa
      // primero la balanza actual para que el resumen no quede una unidad atrás.
      await _finalizarServicioActual();
    } catch (error) {
      debugPrint('Error preparando resumen del servicio: $error');
    }
    await _loadBalanzasCount();
  }

  Future<void> _loadBalanzasCount() async {
    final seca = widget.secaValue;
    if (seca.isEmpty) {
      if (mounted) setState(() => _isLoadingSummary = false);
      return;
    }
    try {
      final registros = await widget.controller.getRegistrosPorSeca(
        widget.config.tableNameDefault,
        seca,
      );
      final registrosHoy = await widget.controller.getRegistrosPorSeca(
        widget.config.tableNameDefault,
        seca,
        soloHoy: true,
      );
      if (mounted) {
        setState(() {
          _balanzasCount = registros.length;
          _balanzasCountHoy = registrosHoy.length;
          _isLoadingSummary = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _finalizarServicioActual() async {
    await widget.controller.finalizarServicio(
      horaFin: widget.controller.horaFin,
      fechaProxServicio: widget.controller.fechaProxServicio,
    );
  }

  Future<void> _seleccionarOtraBalanza() async {
    final confirm = await _showConfirmDialog(
      title: 'CAMBIAR BALANZA',
      message: '¿Está seguro que desea seleccionar otra balanza?\n\n'
          'El servicio actual se guardará como completado.',
      confirmLabel: 'Sí, cambiar',
    );

    if (confirm != true || !mounted) return;

    try {
      await _finalizarServicioActual();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PrecargaScreenSop(
            tableName: widget.config.tableNameDefault,
            userName: widget.userName,
            clienteId: widget.clienteId,
            plantaCodigo: widget.plantaCodigo,
            servicio: widget.config.tipoServicio,
            seca: widget.secaValue,
            skipToBalanza: true,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Error al navegar: $e\n$st');
      if (mounted) {
        TopAlert.show(context, 'Error al navegar: $e', isError: true);
      }
    }
  }

  Future<void> _finalizarYExportar() async {
    final confirm = await _showConfirmDialog(
      title: 'Finalizar Servicio',
      message:
          '¿Está seguro que desea finalizar el servicio "${widget.config.tipoServicio}"?\n\n'
          'Se guardarán todos los datos y se procederá a la exportación.',
      confirmLabel: 'Sí, finalizar y exportar',
      isDestructive: false,
    );
    if (confirm != true || !mounted) return;

    setState(() => _isFinalizando = true);

    try {
      await _finalizarServicioActual();
      await _loadBalanzasCount();

      if (!mounted) return;

      final opcion = await _showExportDialog();
      if (opcion == null || !mounted) return;

      await _exportRegistros(soloHoy: opcion == 'hoy');
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'Error al finalizar servicio: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isFinalizando = false);
    }
  }

  Future<String?> _showExportDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
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
              '¿Qué registros desea exportar?',
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),
            _opcionExportacion(
              ctx,
              icon: Icons.today_rounded,
              titulo: 'Solo las de hoy',
              subtitulo: '$_balanzasCountHoy balanza(s)',
              isDark: isDark,
              onTap: () => Navigator.pop(ctx, 'hoy'),
            ),
            const SizedBox(height: 12),
            _opcionExportacion(
              ctx,
              icon: Icons.calendar_month_rounded,
              titulo: 'Todas las de la OTST',
              subtitulo: '$_balanzasCount balanza(s)',
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
  }

  Future<void> _exportRegistros({required bool soloHoy}) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final seca = widget.secaValue;
      if (seca.isEmpty) {
        TopAlert.show(context, 'OTST no disponible', isError: true);
        return;
      }

      final registros = await widget.controller.getRegistrosPorSeca(
        widget.config.tableNameDefault,
        seca,
        soloHoy: soloHoy,
      );

      if (!mounted) return;

      if (registros.isEmpty) {
        TopAlert.show(context, 'No hay registros para exportar', isError: true);
        return;
      }

      final rows = <List<String>>[];
      List<String>? headers;

      for (final r in registros) {
        Map<String, dynamic> data;
        try {
          data = Map<String, dynamic>.from(
              jsonDecode(r['data']?.toString() ?? '{}'));
        } catch (_) {
          continue;
        }

        final rowCod = r['cod_metrica']?.toString() ?? '';
        data['cod_metrica'] = rowCod.isNotEmpty
            ? rowCod
            : (data['cod_metrica']?.toString() ?? widget.codMetrica);
        data['seca_value'] = widget.secaValue;
        if ((data['cliente']?.toString() ?? '').isEmpty) {
          data['cliente'] = widget.clienteNombre;
        }
        if ((data['planta']?.toString() ?? '').isEmpty) {
          data['planta'] = widget.plantaNombre;
        }

        if (headers == null) {
          headers = data.keys.toList();
          rows.add(headers);
        }
        final values = headers.map((k) {
          final v = data[k];
          if (v is String) return v;
          if (v is List || v is Map) return jsonEncode(v);
          return v?.toString() ?? '';
        }).toList();
        rows.add(values);
      }

      if (!mounted) return;

      if (rows.isEmpty) {
        TopAlert.show(context, 'No se pudieron leer los registros',
            isError: true);
        return;
      }

      final csv = Csv(
        fieldDelimiter: ';',
        quoteCharacter: '"',
        autoDetect: false,
      ).encode(rows);

      final csvBytes = utf8.encode(csv);
      final timestamp =
          DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName =
          '${widget.secaValue}_${timestamp}_${widget.config.csvSuffix}.csv';

      final externalDir = await getExternalStorageDirectory();
      String? autoSavedPath;
      if (externalDir != null) {
        final exportDir =
            Directory('${externalDir.path}/RespaldoSM/CSV_Automaticos');
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        final internalFile = File('${exportDir.path}/$fileName');
        await internalFile.writeAsBytes(csvBytes);
        autoSavedPath = internalFile.path;
      }

      // Guardar también en el directorio de fotos (como calibración)
      try {
        final baseFotos =
            await FotoHelper.getBaseDir(subDirName: 'soporte_fotos');
        final csvDir = Directory(p.join(baseFotos.path, widget.secaValue));
        if (!await csvDir.exists()) {
          await csvDir.create(recursive: true);
        }
        final csvFile = File(p.join(csvDir.path, fileName));
        await csvFile.writeAsBytes(csvBytes);
      } catch (_) {
        // Si no hay directorio configurado, solo usamos el respaldo automático
      }

      final params = SaveFileDialogParams(
        data: Uint8List.fromList(csvBytes),
        fileName: fileName,
      );
      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (!mounted) return;

      if (savedPath != null) {
        TopAlert.show(
          context,
          'Exportación exitosa: ${registros.length} balanza(s) exportada(s)',
          isError: false,
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => false,
        );
      } else {
        TopAlert.show(
          context,
          autoSavedPath != null
              ? 'Exportación al destino cancelada. Respaldo guardado automáticamente.'
              : 'Exportación cancelada.',
          isError: autoSavedPath == null,
        );
      }
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'Error al exportar CSV: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: widget.config.primaryColor)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [const SizedBox(height: 4), Text(message)]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text(cancelLabel, style: const TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: isDestructive ? AppDesign.negativeButtonStyle() : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
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

  String _titleCase(String s) {
    const lower = {'de', 'del', 'la', 'el', 'y', 'en'};
    return s.toLowerCase().split(' ').map((w) {
      if (w.isEmpty) return w;
      if (lower.contains(w)) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final saveStatus = widget.controller.isSaving
            ? SaveStatus.saving
            : (widget.controller.lastSaveSuccessful
                ? SaveStatus.success
                : SaveStatus.error);

        return Scaffold(
          appBar: ServiceAppBar(
            title: _titleCase(widget.config.tipoServicio),
            actions: [SaveStatusIndicator(status: saveStatus)],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 20),
                _buildResumenCard(isDark),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isFinalizando ? null : _seleccionarOtraBalanza,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('SELECCIONAR OTRA BALANZA',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ).animate(delay: 300.ms).fadeIn().scale(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: (_isFinalizando || _isExporting)
                        ? null
                        : _finalizarYExportar,
                    icon: (_isFinalizando || _isExporting)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.actionPositiveInk)))
                        : const Icon(Icons.file_download),
                    label: const Text('FINALIZAR Y EXPORTAR',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ).animate(delay: 400.ms).fadeIn().scale(),
              ],
            ),
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

  Widget _buildResumenCard(bool isDark) {
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
          _row('OTST', widget.secaValue, isDark),
          const SizedBox(height: 8),
          _row('Balanzas atendidas',
              _isLoadingSummary ? 'Cargando...' : '$_balanzasCount', isDark),
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
          width: 140,
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
}
