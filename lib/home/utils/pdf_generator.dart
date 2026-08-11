import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/servicio_model.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfGenerator {
  static Future<Uint8List> generateCalibracionPdf(
      ServicioResumen servicio) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoExtraLight();
    final fontBold = await PdfGoogleFonts.nunitoExtraBold();

    // Cargar logo
    final logoBytes = await rootBundle.load('images/logo_met.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Obtener datos del encabezado (del primer registro)
    final firstRecord = servicio.items.isNotEmpty ? servicio.items.first : {};
    final String cliente = firstRecord['cliente']?.toString() ?? '';
    final String razonSocial = firstRecord['razon_social']?.toString() ?? '';
    final String planta = firstRecord['planta']?.toString() ?? '';
    final String dirPlanta = firstRecord['dir_planta']?.toString() ?? '';
    final String tecResponsable = firstRecord['personal']?.toString() ??
        firstRecord['tec_responsable']?.toString() ??
        '';

    // Filtrar y deduplicar: solo balanzas calibradas o con datos reales
    final records = _filterCalibracion(servicio.items);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginLeft: 10,
          marginRight: 10,
          marginTop: 14,
          marginBottom: 14,
        ),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            _buildHeader(
                cliente,
                razonSocial,
                planta,
                dirPlanta,
                tecResponsable,
                'RESUMEN DE CALIBRACIÓN - SECA ${servicio.codigo}',
                logo),
            pw.SizedBox(height: 10),
            _buildCalibracionTable(records, font),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateSoportePdf(ServicioResumen servicio) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoExtraLight();
    final fontBold = await PdfGoogleFonts.nunitoExtraBold();

    // Cargar logo
    final logoBytes = await rootBundle.load('images/logo_met.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Obtener datos del encabezado
    final firstRecord = servicio.items.isNotEmpty ? servicio.items.first : {};
    final String cliente = firstRecord['cliente']?.toString() ?? '';
    final String razonSocial = firstRecord['razon_social']?.toString() ?? '';
    final String planta = firstRecord['planta']?.toString() ?? '';
    final String dirPlanta = firstRecord['dir_planta']?.toString() ?? '';
    final String tecResponsable = firstRecord['personal']?.toString() ??
        firstRecord['tec_responsable']?.toString() ??
        '';

    // Filtrar y deduplicar registros completos
    final records = _filterSoporte(servicio.items);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginLeft: 10,
          marginRight: 10,
          marginTop: 14,
          marginBottom: 14,
        ),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            _buildHeader(
                cliente,
                razonSocial,
                planta,
                dirPlanta,
                tecResponsable,
                'RESUMEN DE SOPORTE TÉCNICO - OTST ${servicio.codigo}',
                logo),
            pw.SizedBox(height: 10),
            _buildSoporteTable(records, font),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ──────────────────────────────────────────────────────────────
  // FILTROS
  // ──────────────────────────────────────────────────────────────

  /// Filtro para calibración: elimina duplicados y filas vacías/pendientes sin datos clave
  static List<Map<String, dynamic>> _filterCalibracion(
      List<Map<String, dynamic>> originalList) {
    final Map<String, Map<String, dynamic>> uniqueMap = {};

    for (var record in originalList) {
      final String key = _getUniqueKey(record);
      final String estado = record['estado_servicio_bal']?.toString() ?? '';
      final bool isCalibrada = estado == 'Balanza Calibrada';

      // Detectar si la fila tiene al menos datos mínimos útiles
      final bool hasData = _hasMinimumData(record);

      // Si no tiene datos mínimos y no está calibrada, descartarla
      if (!hasData && !isCalibrada) continue;

      if (uniqueMap.containsKey(key)) {
        final existingStatus =
            uniqueMap[key]!['estado_servicio_bal']?.toString() ?? '';
        // Si el actual está calibrado y el existente no, reemplazar
        if (isCalibrada && existingStatus != 'Balanza Calibrada') {
          uniqueMap[key] = record;
        }
      } else {
        uniqueMap[key] = record;
      }
    }

    return uniqueMap.values.toList();
  }

  /// Filtro para soporte: elimina duplicados y filas vacías/incompletas
  static List<Map<String, dynamic>> _filterSoporte(
      List<Map<String, dynamic>> originalList) {
    final Map<String, Map<String, dynamic>> uniqueMap = {};

    for (var record in originalList) {
      final String key = _getUniqueKey(record);
      final String estado = record['estado_servicio']?.toString() ?? '';
      final bool isCompleto = estado == 'Completo';
      final bool hasData = _hasMinimumData(record);

      if (!hasData && !isCompleto) continue;

      if (uniqueMap.containsKey(key)) {
        final existingStatus =
            uniqueMap[key]!['estado_servicio']?.toString() ?? '';
        if (isCompleto && existingStatus != 'Completo') {
          uniqueMap[key] = record;
        }
      } else {
        uniqueMap[key] = record;
      }
    }

    return uniqueMap.values.toList();
  }

  static String _getUniqueKey(Map<String, dynamic> record) {
    String key = record['cod_metrica']?.toString().trim() ?? '';
    if (key.isEmpty || key == 'null') {
      key = record['serie']?.toString().trim() ?? '';
    }
    if (key.isEmpty || key == 'null') {
      key = record.hashCode.toString();
    }
    return key;
  }

  /// Un registro tiene datos mínimos si tiene al menos marca, modelo o cod_metrica no vacío
  static bool _hasMinimumData(Map<String, dynamic> record) {
    final fields = ['marca', 'modelo', 'cod_metrica', 'serie', 'cod_int'];
    for (final f in fields) {
      final v = record[f]?.toString().trim() ?? '';
      if (v.isNotEmpty && v != 'null' && v != '0') return true;
    }
    return false;
  }

  // ──────────────────────────────────────────────────────────────
  // ENCABEZADO
  // ──────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(
      String cliente,
      String razonSocial,
      String planta,
      String dirPlanta,
      String tecResponsable,
      String title,
      pw.ImageProvider logo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(title,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Container(
              height: 32,
              child: pw.Image(logo),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow('Cliente:', cliente),
                  _buildHeaderRow('Razón Social:', razonSocial),
                  _buildHeaderRow('Planta:', planta),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow('Dirección Planta:', dirPlanta),
                  _buildHeaderRow('Personal:', tecResponsable),
                ],
              ),
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildHeaderRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Text('$label ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          pw.Expanded(
              child: pw.Text(value,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: const pw.TextStyle(fontSize: 8))),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // TABLA CALIBRACIÓN
  // ──────────────────────────────────────────────────────────────

  static pw.Widget _buildCalibracionTable(
      List<Map<String, dynamic>> records, pw.Font font) {
    final headers = [
      '#',
      'Cód. Métrica',
      'Marca',
      'Modelo',
      'Serie',
      'Cod. Int.',
      'Cap Max',
      'd',
      'Und',
      'Ubicación',
      'Fecha',
      'Observaciones',
      'Estado',
    ];

    int rowNum = 0;
    final data = records.map((r) {
      rowNum++;
      final estado = r['estado_servicio_bal']?.toString() ?? '';
      final isCalibrada = estado == 'Balanza Calibrada';
      final color = isCalibrada
          ? PdfColor.fromInt(0xFFC8E6C9) // Verde suave
          : PdfColor.fromInt(0xFFFFCDD2); // Rojo suave

      return [
        '$rowNum',
        r['cod_metrica']?.toString() ?? '',
        r['marca']?.toString() ?? '',
        r['modelo']?.toString() ?? '',
        r['serie']?.toString() ?? '',
        r['cod_int']?.toString() ?? '',
        r['cap_max1']?.toString() ?? '',
        r['d1']?.toString() ?? '',
        r['unidades']?.toString() ?? '',
        r['ubicacion']?.toString() ?? '',
        r['fecha_servicio']?.toString() ?? '',
        r['observaciones']?.toString() ?? '',
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            estado.isEmpty ? 'Pendiente' : estado,
            style: const pw.TextStyle(fontSize: 6),
          ),
        ),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFF365666)),
      cellStyle: const pw.TextStyle(fontSize: 6),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      columnWidths: {
        0: const pw.FixedColumnWidth(16), // #
        1: const pw.FixedColumnWidth(55), // Cód. Métrica
        2: const pw.FixedColumnWidth(40), // Marca
        3: const pw.FixedColumnWidth(40), // Modelo
        4: const pw.FixedColumnWidth(42), // Serie
        5: const pw.FixedColumnWidth(38), // Cod Int
        6: const pw.FixedColumnWidth(34), // Cap
        7: const pw.FixedColumnWidth(24), // d
        8: const pw.FixedColumnWidth(24), // Und
        9: const pw.FlexColumnWidth(2), // Ubicacion (largo)
        10: const pw.FixedColumnWidth(42), // Fecha
        11: const pw.FlexColumnWidth(3), // Observaciones
        12: const pw.FixedColumnWidth(52), // Estado
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // TABLA SOPORTE TÉCNICO
  // ──────────────────────────────────────────────────────────────

  static pw.Widget _buildSoporteTable(
      List<Map<String, dynamic>> records, pw.Font font) {
    final headers = [
      '#',
      'Cód. Métrica',
      'Marca',
      'Modelo',
      'Serie',
      'Cod. Int.',
      'Cap Max',
      'd',
      'Und',
      'Ubicación',
      'Fecha',
      'Observaciones',
      'Estado',
    ];

    int rowNum = 0;
    final data = records.map((r) {
      rowNum++;
      final estado = r['estado_servicio']?.toString() ?? '';
      final isCompleto = estado == 'Completo';
      final color = isCompleto
          ? PdfColor.fromInt(0xFFC8E6C9) // Verde suave
          : PdfColor.fromInt(0xFFFFCDD2); // Rojo suave

      // Observaciones: usar comentario_general primero, luego observaciones
      final obs =
          (r['comentario_general']?.toString().trim().isNotEmpty == true)
              ? r['comentario_general']!.toString()
              : r['observaciones']?.toString() ?? '';

      return [
        '$rowNum',
        r['cod_metrica']?.toString() ?? '',
        r['marca']?.toString() ?? '',
        r['modelo']?.toString() ?? '',
        r['serie']?.toString() ?? '',
        r['cod_int']?.toString() ?? '',
        r['cap_max1']?.toString() ?? '',
        r['d1']?.toString() ?? '',
        r['unidades']?.toString() ?? '',
        r['ubicacion']?.toString() ?? '',
        r['fecha_servicio']?.toString() ?? '',
        obs,
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            estado.isEmpty ? 'Pendiente' : estado,
            style: const pw.TextStyle(fontSize: 6),
          ),
        ),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFF365666)),
      cellStyle: const pw.TextStyle(fontSize: 6),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      columnWidths: {
        0: const pw.FixedColumnWidth(16), // #
        1: const pw.FixedColumnWidth(55), // Cód. Métrica
        2: const pw.FixedColumnWidth(40), // Marca
        3: const pw.FixedColumnWidth(40), // Modelo
        4: const pw.FixedColumnWidth(42), // Serie
        5: const pw.FixedColumnWidth(38), // Cod Int
        6: const pw.FixedColumnWidth(34), // Cap
        7: const pw.FixedColumnWidth(24), // d
        8: const pw.FixedColumnWidth(24), // Und
        9: const pw.FlexColumnWidth(2), // Ubicacion
        10: const pw.FixedColumnWidth(42), // Fecha
        11: const pw.FlexColumnWidth(3), // Observaciones
        12: const pw.FixedColumnWidth(52), // Estado
      },
    );
  }
}
