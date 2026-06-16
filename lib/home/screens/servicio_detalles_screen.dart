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

  Future<void> _exportarCSV() async {
    try {
      final List<List<dynamic>> csvData = [];

      if (itemsEditados.isNotEmpty) {
        csvData.add(itemsEditados.first.keys.toList());
      }

      for (var item in itemsEditados) {
        csvData.add(item.values.toList());
      }

      // Generar CSV
      final csv =
          const ListToCsvConverter(fieldDelimiter: ';').convert(csvData);

      // Codificar a bytes UTF-8 para evitar problemas de caracteres
      final List<int> csvBytes = utf8.encode(csv);

      final fileName =
          '${widget.servicio.prefijo}_${widget.servicio.codigo}_${DateTime.now().millisecondsSinceEpoch}.csv';

      // Seleccionar directorio de destino
      final String? directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleccione carpeta para guardar el respaldo',
      );

      if (directoryPath == null) {
        // Usuario canceló
        return;
      }

      final File file = File('$directoryPath/$fileName');
      await file.writeAsBytes(csvBytes);

      // Abrir el archivo generado
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

  Future<void> _exportarPDF() async {
    try {
      final isCalibracion = widget.servicio.tipo == TipoServicio.calibracion;
      final pdfBytes = isCalibracion 
          ? await PdfGenerator.generateCalibracionPdf(widget.servicio)
          : await PdfGenerator.generateSoportePdf(widget.servicio);

      final fileName =
          'Resumen_${widget.servicio.nombreTipo.replaceAll(" ", "_")}_${widget.servicio.prefijo}_${widget.servicio.codigo}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Seleccionar directorio de destino
      final String? directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleccione carpeta para guardar el PDF',
      );

      if (directoryPath == null) {
        // Usuario canceló
        return;
      }

      final File file = File('$directoryPath/$fileName');
      await file.writeAsBytes(pdfBytes);

      // Abrir el archivo generado
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

  Widget _buildItemCard(
      BuildContext context, int index, Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE);
    
    final isCalibracion = widget.servicio.tipo == TipoServicio.calibracion;
    final Color primaryColor = isCalibracion ? const Color(0xFF667EEA) : const Color(0xFF4CAF50);
    final icon = isCalibracion ? FontAwesomeIcons.scaleBalanced : FontAwesomeIcons.screwdriverWrench;
    
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
          borderRadius: BorderRadius.circular(16),
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
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
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
                          color: isDark ? Colors.white38 : Colors.black38,
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
              color: isDark ? Colors.white30 : Colors.black26,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isCalibracion = widget.servicio.tipo == TipoServicio.calibracion;
    final Color primaryColor = isCalibracion ? const Color(0xFF667EEA) : const Color(0xFF4CAF50);
    final icon = isCalibracion ? FontAwesomeIcons.scaleBalanced : FontAwesomeIcons.screwdriverWrench;
    
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE);
        
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ─ Handle + header ──────────────────────────────────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                      bottom: BorderSide(color: borderColor, width: 1)),
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
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
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
                      isDark,
                      cardColor,
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
      String label, String value, bool isDark, Color cardColor) {
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
                color: isDark ? Colors.white60 : Colors.black54,
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
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final isCalibracion = widget.servicio.tipo == TipoServicio.calibracion;
    final Color primaryColor = isCalibracion ? const Color(0xFF667EEA) : const Color(0xFF4CAF50);
    
    final bgColor =
        isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA);
    final cardColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDarkMode, primaryColor),
      // ── Barra de acciones fija en el fondo ───────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportarPDF,
                  icon: const FaIcon(FontAwesomeIcons.filePdf,
                      size: 16, color: Colors.red),
                  label: Text(
                    'Exportar PDF',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.red.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportarCSV,
                  icon: const FaIcon(FontAwesomeIcons.fileArrowDown,
                      size: 16, color: Colors.white),
                  label: Text(
                    'Respaldo CSV',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              itemCount: itemsEditados.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildResumenBanner(isDarkMode, primaryColor, borderColor);
                }
                final i = index - 1;
                return _buildItemCard(context, i, itemsEditados[i]);
              },
            ),
    );
  }

  Widget _buildResumenBanner(bool isDark, Color accent, Color borderColor) {
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final isCalibracion = widget.servicio.tipo == TipoServicio.calibracion;
    final icon = isCalibracion ? FontAwesomeIcons.scaleBalanced : FontAwesomeIcons.screwdriverWrench;
    
    final primerDato =
        itemsEditados.isNotEmpty ? itemsEditados.first : {};
    final cliente = primerDato['cliente']?.toString() ??
        primerDato['razon_social']?.toString() ?? '';
    final fecha = primerDato['fecha']?.toString() ??
        primerDato['fecha_servicio']?.toString() ?? '';
    final tecnico = primerDato['tecnico']?.toString() ??
        primerDato['nombre_tecnico']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.servicio.prefijo} ${widget.servicio.codigo}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      'Servicio de ${widget.servicio.nombreTipo}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.2)),
                ),
                child: Text(
                  '${widget.servicio.cantidad} ${widget.servicio.nombreItem}${widget.servicio.cantidad != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          if (cliente.isNotEmpty || fecha.isNotEmpty || tecnico.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(
                height: 1,
                color: isDark
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFEEEEEE)),
            const SizedBox(height: 12),
            if (cliente.isNotEmpty)
              _buildBannerRow(
                  Icons.business_outlined, 'Cliente', cliente, isDark),
            if (fecha.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildBannerRow(
                  Icons.calendar_today_outlined, 'Fecha', fecha, isDark),
            ],
            if (tecnico.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildBannerRow(
                  Icons.person_outline_rounded, 'Técnico', tecnico, isDark),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBannerRow(
      IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode, Color primaryColor) {
    final cardColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE);
    final titleColor =
        isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    final iconColor =
        isDarkMode ? Colors.white70 : const Color(0xFF555555);

    return PreferredSize(
      preferredSize: const Size.fromHeight(65),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border:
              Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 65,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 4,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: iconColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.servicio.prefijo} ${widget.servicio.codigo}',
                      style: GoogleFonts.poppins(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.0,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      '${widget.servicio.cantidad} ${widget.servicio.nombreItem}${widget.servicio.cantidad != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        color: isDarkMode ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w500,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 4,
                  child: Row(
                    children: [
                      _buildAction(
                          icon: FontAwesomeIcons.filePdf,
                          color: Colors.red,
                          onPressed: _exportarPDF,
                          tooltip: 'Exportar PDF'),
                      const SizedBox(width: 4),
                      _buildAction(
                          icon: FontAwesomeIcons.fileExport,
                          color: primaryColor,
                          onPressed: _exportarCSV,
                          tooltip: 'Exportar CSV'),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction(
      {required dynamic icon,
      required Color color,
      required VoidCallback onPressed,
      required String tooltip}) {
    return IconButton(
      tooltip: tooltip,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: icon is IconData ? Icon(icon, color: color, size: 17) : FaIcon(icon, color: color, size: 17),
      ),
      onPressed: onPressed,
    );
  }

  void _mostrarDialogoEdicion(
      BuildContext context, int index, Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isCalibracion = widget.servicio.tipo == TipoServicio.calibracion;
    final Color primaryColor = isCalibracion ? const Color(0xFF4A90E2) : const Color(0xFF04376E); // Or use custom colors, keeping the same as before
    
    final camposConDatos = _obtenerCamposConDatos(item);
    final Map<String, TextEditingController> controllers = {};

    camposConDatos.forEach((key, value) {
      controllers[key] = TextEditingController(text: value?.toString() ?? '');
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
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
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
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
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: _formatearNombreCampo(entry.key),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
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
                color: Colors.grey[600],
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
