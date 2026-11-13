// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/servicio_model.dart';
import '../services/local_service_record_repository.dart';
import '../utils/pdf_generator.dart';
import '../../database/auditoria_registros.dart';
import '../../database/calibration_data_normalizer.dart';
import '../../utils/foto_storage_dialog.dart';
import '../../utils/saf_storage.dart';
import '../../utils/service_exporter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../widgets/foto_viewer.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../widgets/balanzas_nuevas_section.dart';
import 'calibration_upload_screen.dart';
import 'fotos_registro_screen.dart';
import 'support_upload_screen.dart';
import '../../theme/app_icons.dart';

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

  // Filtrar solo campos con datos válidos. Las fotos no: guardan rutas del
  // teléfono y se ven como fotos, no como texto.
  Map<String, dynamic> _obtenerCamposConDatos(Map<String, dynamic> item) {
    final Map<String, dynamic> camposValidos = {};

    item.forEach((key, value) {
      if (!CalibrationDataNormalizer.isLocalField(key) &&
          value != null &&
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

  String _tituloRegistro(int index, Map<String, dynamic> item) {
    final camposConDatos = _obtenerCamposConDatos(item);
    return camposConDatos['cod_metrica']?.toString() ??
        camposConDatos['modelo']?.toString() ??
        '${widget.servicio.nombreItem} ${index + 1}';
  }

  /// Prefijo de los archivos al compartir o guardar una foto.
  String _nombreBaseFotos(Map<String, dynamic> item) =>
      item['cod_metrica']?.toString().trim() ?? '';

  /// Todas las fotos del registro, por sección. Solo para ver: no pasa por
  /// el editor.
  Future<void> _verFotos(int index, Map<String, dynamic> item) =>
      FotosRegistroScreen.open(
        context,
        fotos: fotosDelRegistro(item),
        titulo: _tituloRegistro(index, item),
        servicio: '${widget.servicio.prefijo} ${widget.servicio.codigo}',
        nombreBase: _nombreBaseFotos(item),
      );

  Future<void> _confirmarEliminarRegistro(
      int index, Map<String, dynamic> item) async {
    final cs = Theme.of(context).colorScheme;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(AppIcons.eliminar, color: AppColors.actionNegative),
        title: const Text('Eliminar registro'),
        content: Text(
          'Esta acción borra el registro de forma permanente en este '
          'dispositivo y no se puede deshacer.',
          style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.actionNegative,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      final affected =
          await LocalServiceRecordRepository.delete(widget.servicio.tipo, item);
      if (!mounted) return;
      if (affected <= 0) {
        _mostrarError('No se encontró el registro para eliminar');
        return;
      }
      setState(() => itemsEditados.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro eliminado'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) _mostrarError('Error al eliminar: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(AppIcons.cancelar, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _mostrarAccionesRegistro(
      BuildContext context, int index, Map<String, dynamic> item) async {
    final cs = Theme.of(context).colorScheme;
    final fotos = fotosDelRegistro(item);
    final accion = await showModalBottomSheet<String>(
      context: context,
      // Con "Ver fotos" son cuatro opciones: la hoja crece lo necesario.
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 24 + MediaQuery.paddingOf(sheetContext).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registro',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Elige qué hacer con este registro individual.',
              style:
                  GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (fotos.isNotEmpty) ...[
              _buildActionTile(
                context: sheetContext,
                icon: AppIcons.fotos,
                iconColor: AppColors.shimmerGold,
                title: 'Ver fotos',
                subtitle: fotos.length == 1
                    ? '1 fotografía de este registro'
                    : '${fotos.length} fotografías de este registro',
                value: 'fotos',
              ),
              const SizedBox(height: 10),
            ],
            _buildActionTile(
              context: sheetContext,
              icon: AppIcons.exportarArchivo,
              iconColor: AppColors.calibracion,
              title: 'Exportar CSV',
              subtitle: 'Guardar una copia de este registro',
              value: 'csv',
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              context: sheetContext,
              icon: AppIcons.eliminar,
              iconColor: Colors.red,
              title: 'Eliminar',
              subtitle: 'Borrar este registro de forma permanente',
              value: 'eliminar',
            ),
          ],
        ),
      ),
    );

    if (!mounted || accion == null) return;
    switch (accion) {
      case 'fotos':
        await _verFotos(index, item);
      case 'csv':
        await _exportarRegistroCSV(item);
      case 'eliminar':
        await _confirmarEliminarRegistro(index, item);
    }
  }

  Future<void> _exportarRegistroCSV(Map<String, dynamic> item) async {
    try {
      final csvData = <List<dynamic>>[
        item.keys.toList(),
        item.values.toList(),
      ];
      final csv = Csv(fieldDelimiter: ';', autoDetect: false).encode(csvData);
      final csvBytes = Uint8List.fromList(utf8.encode(csv));

      final ref = item['cod_metrica']?.toString().trim();
      final sufijo = (ref == null || ref.isEmpty)
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : ref.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      final fileName =
          '${widget.servicio.prefijo}_${widget.servicio.codigo}_${sufijo}_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (!await _asegurarCarpeta()) return;

      final result = await ServiceExporter.exportServicio(
        codigoServicio: widget.servicio.codigo,
        fileName: fileName,
        mimeType: ServiceExporter.csvMime,
        bytes: csvBytes,
      );
      if (!result.saved) return;
      _mostrarExito(result);
    } catch (e) {
      if (mounted) _mostrarError('Error al exportar: $e');
    }
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

  /// Ofrece configurar la carpeta principal la primera vez. Si el técnico la
  /// omite, la exportación continúa con el selector estándar de Android.
  Future<bool> _asegurarCarpeta() async {
    if (!SafStorage.isSupported) return true;
    if (await SafStorage.isConfigured()) return true;
    if (!mounted) return false;
    await FotoStorageDialog.show(context);
    return mounted;
  }

  void _mostrarExito(ExportResult result) {
    if (!mounted) return;
    final fotos = result.photoCount > 0
        ? ' · ${result.photoCount} foto(s) incluidas'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(AppIcons.completo, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Guardado en: ${result.destination}$fotos')),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: result.canOpen
            ? SnackBarAction(
                label: 'Abrir',
                textColor: Colors.white,
                onPressed: () => SafStorage.openDocument(
                  result.uri!,
                  mimeType: result.mimeType ?? '*/*',
                ),
              )
            : null,
      ),
    );
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
      final csvBytes = Uint8List.fromList(utf8.encode(csv));

      final fileName =
          '${widget.servicio.prefijo}_${widget.servicio.codigo}_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (!await _asegurarCarpeta()) return;

      final result = await ServiceExporter.exportServicio(
        codigoServicio: widget.servicio.codigo,
        fileName: fileName,
        mimeType: ServiceExporter.csvMime,
        bytes: csvBytes,
      );
      if (!result.saved) return;
      _mostrarExito(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(AppIcons.cancelar, color: Colors.white, size: 20),
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

      if (!await _asegurarCarpeta()) return;

      final result = await ServiceExporter.exportServicio(
        codigoServicio: servicioFiltrado.codigo,
        fileName: fileName,
        mimeType: ServiceExporter.pdfMime,
        bytes: Uint8List.fromList(pdfBytes),
      );
      if (!result.saved) return;
      _mostrarExito(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(AppIcons.cancelar, color: Colors.white, size: 20),
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
            Icon(isPdf ? AppIcons.documento : AppIcons.exportar,
                color: primaryColor, size: 20),
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
    final icon = isCalibracion ? AppIcons.balanza : AppIcons.soporte;

    final camposConDatos = _obtenerCamposConDatos(item);
    final titulo = _tituloRegistro(index, item);
    final fotos = fotosDelRegistro(item);

    return GestureDetector(
      onTap: () => _mostrarDetalleItem(context, index, item),
      onLongPress: () => _mostrarAccionesRegistro(context, index, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: AppDesign.mediumRadius,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // ─ Ícono tipo servicio ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: primaryColor, size: 20),
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
                          if (esBalanzaNueva(item)) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Nueva',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              fotos.isEmpty
                                  ? '${camposConDatos.length} campos'
                                  : '${camposConDatos.length} campos · '
                                      '${fotos.length} '
                                      '${fotos.length == 1 ? 'foto' : 'fotos'}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(0.38),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ─ Flecha ────────────────────────────────────────────
                Icon(
                  AppIcons.siguiente,
                  color: cs.onSurface.withOpacity(isDark ? 0.30 : 0.26),
                  size: 22,
                ),
              ],
            ),
            // ─ Fotos: se ven desde aquí, sin pasar por el editor ────
            if (fotos.isNotEmpty) ...[
              const SizedBox(height: 14),
              FotoTiraMiniaturas(
                fotos: fotos,
                onFoto: (i) => abrirVisorFotos(
                  context,
                  fotos: fotos,
                  index: i,
                  nombreBase: _nombreBaseFotos(item),
                ),
                onVerTodas: () => _verFotos(index, item),
              ),
            ],
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
    final icon = isCalibracion ? AppIcons.balanza : AppIcons.soporte;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = cs.outlineVariant;

    final camposConDatos = _obtenerCamposConDatos(item);
    final titulo = _tituloRegistro(index, item);
    final fotos = fotosDelRegistro(item);
    final offset = fotos.isEmpty ? 0 : 1;

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
                      child: Icon(icon, color: primaryColor, size: 20),
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
                    Tooltip(
                      message: 'Los registros técnicos no se editan',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppIcons.bloqueado,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'Solo lectura',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ─ Fotos y campos scrolleables ────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: EdgeInsets.fromLTRB(
                      20, 20, 20, 40 + MediaQuery.paddingOf(ctx).bottom),
                  itemCount: offset + camposConDatos.length + 1,
                  itemBuilder: (_, fila) {
                    if (fila < offset) {
                      return FotoGallerySection(
                        fotos: fotos,
                        nombreBase: _nombreBaseFotos(item),
                      );
                    }
                    if (fila == offset + camposConDatos.length) {
                      return _HistorialCambios(
                        cargar: () => LocalServiceRecordRepository.historial(
                            widget.servicio.tipo, item),
                      );
                    }
                    final i = fila - offset;
                    final entry = camposConDatos.entries.elementAt(i);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : Border(top: BorderSide(color: borderColor)),
                      ),
                      child: _buildCampoRow(
                        _formatearNombreCampo(entry.key),
                        entry.value.toString(),
                        cs,
                        isDark,
                      ),
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
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 24 + MediaQuery.paddingOf(sheetContext).bottom),
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
              icon: AppIcons.documento,
              iconColor: Colors.red,
              title: 'Exportar PDF',
              subtitle: 'Generar un informe para compartir o imprimir',
              value: 'pdf',
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              context: sheetContext,
              icon: AppIcons.exportarArchivo,
              iconColor: AppColors.actionPositive,
              title: 'Respaldo CSV',
              subtitle: 'Guardar una copia editable de los datos',
              value: 'csv',
            ),
            const SizedBox(height: 10),
            _buildActionTile(
              context: sheetContext,
              icon: AppIcons.subir,
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
    required IconData icon,
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
                child: Icon(icon, color: iconColor, size: 20),
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
              Icon(AppIcons.siguiente, color: cs.onSurfaceVariant),
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
        icon: const Icon(AppIcons.filtros),
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
                  Icon(AppIcons.vacio, size: 64, color: Colors.grey[400]),
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
}

/// Cambios registrados sobre un registro técnico (NB/ISO/IEC 17025 7.5.2):
/// fecha, usuario, campo, valor anterior y nuevo, y motivo. Solo lectura.
class _HistorialCambios extends StatelessWidget {
  const _HistorialCambios({required this.cargar});

  final Future<List<EntradaAuditoria>> Function() cargar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<EntradaAuditoria>>(
      future: cargar(),
      builder: (context, snapshot) {
        final entradas = snapshot.data ?? const <EntradaAuditoria>[];
        if (entradas.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(AppIcons.historial, size: 18, color: cs.onSurface),
                  const SizedBox(width: 8),
                  Text(
                    'Historial de cambios',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final e in entradas)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.campo ?? 'Registro'}: ${e.valorAnterior ?? '—'} → '
                        '${e.valorNuevo ?? '—'}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.motivo,
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: cs.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${e.usuario} · ${e.fechaHora.replaceFirst('T', ' ')}'
                        ' · v${e.appVersion}',
                        style: GoogleFonts.inter(
                            fontSize: 11.5, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
