// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:open_filex/open_filex.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/servicio_model.dart';
import '../utils/pdf_generator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import 'calibration_upload_screen.dart';
import 'support_upload_screen.dart';

class ServicioDetallesScreen extends StatefulWidget {
  final ServicioResumen servicio;

  const ServicioDetallesScreen({super.key, required this.servicio});

  @override
  State<ServicioDetallesScreen> createState() => _ServicioDetallesScreenState();
}

class _ServicioDetallesScreenState extends State<ServicioDetallesScreen> {
  List<Map<String, dynamic>> itemsEditados = [];

  @override
  void initState() {
    super.initState();
    itemsEditados = List.from(widget.servicio.items);
  }

  // Filtrar solo campos con datos válidos
  Map<String, dynamic> _obtenerCamposConDatos(Map<String, dynamic> item) {
    final Map<String, dynamic> camposValidos = {};

    item.forEach((key, value) {
      if (value != null &&
          value.toString().isNotEmpty &&
          value.toString() != '0' &&
          value.toString() != 'null' &&
          value.toString().trim().isNotEmpty) {
        camposValidos[key] = value;
      }
    });

    return camposValidos;
  }

  // Formatear nombres de campos
  String _formatearNombreCampo(String campo) {
    return campo
        .replaceAll('_', ' ')
        .split(' ')
        .map((palabra) => palabra.isEmpty
            ? ''
            : palabra[0].toUpperCase() + palabra.substring(1).toLowerCase())
        .join(' ');
  }

  void _editarItem(int index, Map<String, dynamic> nuevosDatos) {
    setState(() {
      itemsEditados[index] = {...itemsEditados[index], ...nuevosDatos};
    });
  }

  List<Map<String, dynamic>> _getFilteredItems({bool soloCompletos = false}) {
    if (!soloCompletos) return itemsEditados;
    final isCalibracion = widget.servicio.tipo == TipoServicio.calibracion;
    final estadoField =
        isCalibracion ? 'estado_servicio_bal' : 'estado_servicio';
    final estadoValor = isCalibracion ? 'Balanza Calibrada' : 'Completo';
    return itemsEditados.where((item) {
      final estado = item[estadoField]?.toString() ?? '';
      return estado == estadoValor;
    }).toList();
  }

  Future<void> _exportarCSV({bool soloCompletos = false}) async {
    try {
      final items = _getFilteredItems(soloCompletos: soloCompletos);
      final List<List<dynamic>> csvData = [];

      if (items.isNotEmpty) {
        csvData.add(items.first.keys.toList());
      }

      for (var item in items) {
        csvData.add(item.values.toList());
      }

      final csv = Csv(fieldDelimiter: ';', autoDetect: false).encode(csvData);
      final List<int> csvBytes = utf8.encode(csv);

      final fileName =
          '${widget.servicio.prefijo}_${widget.servicio.codigo}_${DateTime.now().millisecondsSinceEpoch}.csv';

      final String? directoryPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Seleccione carpeta para guardar el respaldo',
      );
      if (directoryPath == null) return;

      final File file = File('$directoryPath/$fileName');
      await file.writeAsBytes(csvBytes);
      OpenFilex.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const FaIcon(FontAwesomeIcons.circleCheck,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Archivo guardado en: ${file.path}')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const FaIcon(FontAwesomeIcons.circleXmark,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error al exportar: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _exportarPDF({bool soloCompletos = false}) async {
    try {
      final items = _getFilteredItems(soloCompletos: soloCompletos);
      final servicioFiltrado = ServicioResumen(
        tipo: widget.servicio.tipo,
        codigo: widget.servicio.codigo,
        cantidad: items.length,
        items: items,
      );

      final isCalibracion = servicioFiltrado.tipo == TipoServicio.calibracion;
      final pdfBytes = isCalibracion
          ? await PdfGenerator.generateCalibracionPdf(servicioFiltrado)
          : await PdfGenerator.generateSoportePdf(servicioFiltrado);

      final fileName =
          'Resumen_${servicioFiltrado.nombreTipo.replaceAll(" ", "_")}_${servicioFiltrado.prefijo}_${servicioFiltrado.codigo}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String? directoryPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Seleccione carpeta para guardar el PDF',
      );
      if (directoryPath == null) return;

      final File file = File('$directoryPath/$fileName');
      await file.writeAsBytes(pdfBytes);
      OpenFilex.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const FaIcon(FontAwesomeIcons.circleCheck,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('PDF guardado en: ${file.path}')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const FaIcon(FontAwesomeIcons.circleXmark,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error al exportar PDF: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _mostrarDialogoExportacion(
      BuildContext context, bool isPdf) async {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    const Color primaryColor = AppColors.actionPositive;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            FaIcon(
                isPdf ? FontAwesomeIcons.filePdf : FontAwesomeIcons.fileExport,
                color: primaryColor,
                size: 20),
            const SizedBox(width: 12),
            Text(
              'Exportar ${isPdf ? "PDF" : "CSV"}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Desea exportar todos los registros o solo los completos?',
          style: GoogleFonts.inter(
              fontSize: 14, color: cs.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'todos'),
            child: Text('Todos los datos',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'completos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Solo completos',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result == null) return;
    final soloCompletos = result == 'completos';

    if (isPdf) {
      await _exportarPDF(soloCompletos: soloCompletos);
    } else {
      await _exportarCSV(soloCompletos: soloCompletos);
    }
  }

  Widget _buildItemCard(
      BuildContext context, int index, Map<String, dynamic> item) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    final isCalibracion = widget.servicio.tipo == TipoServicio.calibracion;
    const Color primaryColor = AppColors.actionPositive;
    final icon = isCalibracion
        ? FontAwesomeIcons.scaleBalanced
        : FontAwesomeIcons.screwdriverWrench;

    final camposConDatos = _obtenerCamposConDatos(item);
    final titulo = camposConDatos['cod_metrica']?.toString() ??
        camposConDatos['modelo']?.toString() ??
        '${widget.servicio.nombreItem} ${index + 1}';

    return GestureDetector(
      onTap: () => _mostrarDetalleItem(context, index, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: AppDesign.mediumRadius,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // ─ Ícono tipo servicio ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FaIcon(icon, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 14),
            // ─ Info principal ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.servicio.nombreTipo,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${camposConDatos.length} campos',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.38),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ─ Flecha ────────────────────────────────────────────
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withOpacity(isDark ? 0.30 : 0.26),
              size: 22,
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.05, end: 0);
  }

  void _mostrarDetalleItem(
      BuildContext context, int index, Map<String, dynamic> item) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final isCalibracion = widget.servicio.tipo == TipoServicio.calibracion;
    const Color primaryColor = AppColors.actionPositive;
    final icon = isCalibracion
        ? FontAwesomeIcons.scaleBalanced
        : FontAwesomeIcons.screwdriverWrench;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = cs.outlineVariant;

    final camposConDatos = _obtenerCamposConDatos(item);
    final titulo = camposConDatos['cod_metrica']?.toString() ??
        camposConDatos['modelo']?.toString() ??
        '${widget.servicio.nombreItem} ${index + 1}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ─ Handle + header ──────────────────────────────────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(isDark ? 0.24 : 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: bgColor,
                  border:
                      Border(bottom: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FaIcon(icon, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Servicio de ${widget.servicio.nombreTipo}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _mostrarDialogoEdicion(context, index, item);
                      },
                      icon: Icon(Icons.edit_outlined,
                          size: 16, color: primaryColor),
                      label: Text(
                        'Editar',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ─ Campos scrolleables ─────────────────────────────────
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: camposConDatos.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: borderColor,
                  ),
                  itemBuilder: (_, i) {
                    final entry = camposConDatos.entries.elementAt(i);
                    return _buildCampoRow(
                      _formatearNombreCampo(entry.key),
                      entry.value.toString(),
                      cs,
                      isDark,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampoRow(
      String label, String value, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withOpacity(isDark ? 0.60 : 0.54),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(isDark ? 1.0 : 0.87),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarMenuAcciones() async {
    final cs = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones del servicio',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Elige qué deseas hacer con estos registros.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _buildActionTile(
              context: sheetContext,
              icon: FontAwesomeIcons.filePdf,
              iconColor: Colors.red,
              title: 'Exportar PDF',
              subtitle: 'Generar un informe para compartir o imprimir',
              value: 'pdf',
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              context: sheetContext,
              icon: FontAwesomeIcons.fileArrowDown,
              iconColor: AppColors.actionPositive,
              title: 'Respaldo CSV',
              subtitle: 'Guardar una copia editable de los datos',
              value: 'csv',
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              context: sheetContext,
              icon: FontAwesomeIcons.cloudArrowUp,
              iconColor: widget.servicio.tipo == TipoServicio.calibracion
                  ? AppColors.calibracion
                  : AppColors.soporte,
              title: 'Subir datos',
              subtitle: 'Validar y enviar los registros al servidor',
              value: 'upload',
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'pdf':
        await _mostrarDialogoExportacion(context, true);
      case 'csv':
        await _mostrarDialogoExportacion(context, false);
      case 'upload':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => widget.servicio.tipo == TipoServicio.calibracion
                ? CalibrationUploadScreen(seca: widget.servicio.codigo)
                : SupportUploadScreen(servicio: widget.servicio),
          ),
        );
    }
  }

  Widget _buildActionTile({
    required BuildContext context,
    required FaIconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withOpacity(0.45),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => Navigator.pop(context, value),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: FaIcon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDarkMode = cs.brightness == Brightness.dark;

    const Color primaryColor = AppColors.actionPositive;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const ServiceAppBar(title: 'Registros'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'acciones_registros',
        onPressed: _mostrarMenuAcciones,
        backgroundColor: primaryColor,
        foregroundColor: AppColors.actionPositiveInk,
        icon: const Icon(Icons.tune_rounded),
        label: Text(
          'Acciones',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: itemsEditados.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.boxOpen,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay ${widget.servicio.nombreItem}s registrados',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              itemCount: itemsEditados.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeader(isDarkMode);
                }
                final i = index - 1;
                return _buildItemCard(context, i, itemsEditados[i]);
              },
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.servicio.prefijo} ${widget.servicio.codigo}',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              height: 1.1,
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
          const SizedBox(height: 4),
          Text(
            'Servicio de ${widget.servicio.nombreTipo}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w400,
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  void _mostrarDialogoEdicion(
      BuildContext context, int index, Map<String, dynamic> item) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    const Color primaryColor = AppColors.actionPositive;

    final camposConDatos = _obtenerCamposConDatos(item);
    final Map<String, TextEditingController> controllers = {};

    camposConDatos.forEach((key, value) {
      controllers[key] = TextEditingController(text: value?.toString() ?? '');
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FaIcon(
                FontAwesomeIcons.penToSquare,
                color: primaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Editar ${widget.servicio.nombreItem}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: entry.value,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: _formatearNombreCampo(entry.key),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? cs.onSurface.withOpacity(0.05)
                          : const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? cs.onSurface.withOpacity(0.1)
                              : cs.onSurface.withOpacity(0.05),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                color: cs.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final Map<String, dynamic> nuevosDatos = {};
              controllers.forEach((key, controller) {
                nuevosDatos[key] = controller.text;
              });

              _editarItem(index, nuevosDatos);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.circleCheck,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      const Text('Cambios guardados correctamente'),
                    ],
                  ),
                  backgroundColor: primaryColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Guardar',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
