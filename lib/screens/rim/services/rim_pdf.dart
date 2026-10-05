import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../calidad/services/calidad_pdf.dart';
import '../data/rim_catalogo.dart';
import '../models/rim_documento.dart';

/// PDF de "Recepción de instrumentos de pesaje", con las mismas secciones que
/// el del formulario web.
///
/// Se genera en el teléfono y sin conexión: usa las fuentes integradas del
/// paquete `pdf` (solo Latin-1), así que todo texto pasa por
/// [CalidadPdf.texto].
class RimPdf {
  RimPdf._();

  static const _ink = PdfColor.fromInt(0xFF000000);
  static const _muted = PdfColor.fromInt(0xFF666666);
  static const _line = PdfColor.fromInt(0xFFDDDDDD);
  static const _section = PdfColor.fromInt(0xFFE0E0E0);
  static const _title = PdfColor.fromInt(0xFF1E3E70);
  static const _code = PdfColor.fromInt(0xFF16A34A);
  static const _void = PdfColor.fromInt(0xFFC62828);

  static final _fechaHora = DateFormat('dd/MM/yyyy HH:mm');

  /// Nombre del archivo: código del RIM, instrumento y fecha de emisión.
  static String nombreArchivo(RimDocumento documento) {
    final instrumento = documento.service.metricCode ?? 'sin_codigo';
    final fecha = DateFormat('yyyyMMdd_HHmm').format(documento.emitidoEn);
    return '${documento.codigo}_${instrumento}_$fecha.pdf'
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
  }

  static Future<Uint8List> generar(RimRegistro registro) async {
    final logo = pw.MemoryImage(
      (await rootBundle.load('images/logo_met.png')).buffer.asUint8List(),
    );
    final base = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final rim = registro.documento;
    final firmaCliente = pw.MemoryImage(registro.firmaCliente);
    final firmaRepresentante = registro.firmaRepresentante == null
        ? null
        : pw.MemoryImage(registro.firmaRepresentante!);

    final doc = pw.Document(
      title: CalidadPdf.texto('${rim.codigo} - Recepción de instrumento'),
      author: 'ServiceMET',
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.legal.copyWith(
          marginLeft: 25,
          marginRight: 25,
          marginTop: 25,
          marginBottom: 30,
        ),
        theme: pw.ThemeData.withFont(base: base, bold: bold).copyWith(
          defaultTextStyle: pw.TextStyle(
            font: base,
            fontSize: 8,
            color: _ink,
            lineSpacing: 1.3,
          ),
        ),
        footer: (context) => _pie(registro, context),
        build: (context) => [
          _encabezado(logo),
          _tituloDocumento(registro),
          _seccion('1. Datos generales del cliente'),
          _campos([
            ('Empresa', rim.service.clientName),
            ('Razón social', rim.service.clientLegalName),
            ('Código de planta', rim.service.plantCode),
            ('Planta', rim.service.plantName),
            ('Dirección', rim.service.plantAddress),
            ('Departamento', rim.service.plantDepartment),
            ('Nombre de contacto', rim.contactoNombre),
            ('Cargo', rim.contactoCargo),
            ('Teléfono', rim.contactoTelefono),
          ]),
          _seccion('2. Datos generales del instrumento'),
          _campos([
            ('Código Métrica', rim.service.metricCode),
            ('Instrumento', rim.service.equipmentType),
            ('Marca', rim.service.brand),
            ('Modelo', rim.service.model),
            ('Número de serie', rim.service.serial),
            ('Capacidad', rim.service.capacityWithUnit),
            ('Resolución', rim.service.divisionWithUnit),
            ('Área de trabajo', rim.service.location),
            (
              'Servicio de origen',
              [
                rim.service.serviceName,
                if (rim.service.seca != null)
                  '${rim.service.secaLabel} ${rim.service.seca}',
              ].join(' - '),
            ),
          ]),
          _parrafo('Motivo de la recepción', rim.motivo),
          _seccion('3. Estado físico e inventario'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _inventario(rim)),
              pw.SizedBox(width: 16),
              pw.Expanded(child: _estadoFisico(rim)),
            ],
          ),
          _seccion('4. Recepción, síntomas y pruebas'),
          _subtitulo('4.1 Síntomas y evidencias'),
          _parrafo(
            '¿Se realizaron pruebas de funcionamiento?',
            rim.pruebasFuncionamiento ? 'Sí' : 'No',
          ),
          if (rim.pruebasFuncionamiento && rim.descripcionPruebas.isNotEmpty)
            _parrafo('Descripción de pruebas', rim.descripcionPruebas),
          _subtitulo('4.2 Recepción'),
          _campos(columnas: 2, [
            ('Cliente / solicitante', rim.contactoNombre),
            ('Representante Métrica', rim.representanteMetrica),
            ('Lugar de recepción', rim.lugarRecepcion),
            ('Fecha y hora', _fechaHora.format(rim.emitidoEn)),
            if (rim.tecnicoAsignado.isNotEmpty)
              ('Técnico asignado', rim.tecnicoAsignado),
          ]),
          _firmas(rim, firmaCliente, firmaRepresentante),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _txt(
    String value, {
    bool bold = false,
    double size = 8,
    PdfColor color = _ink,
    pw.TextAlign? align,
  }) =>
      pw.Text(
        CalidadPdf.texto(value),
        textAlign: align,
        style: pw.TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );

  static pw.Widget _encabezado(pw.ImageProvider logo) {
    pw.Widget oficina(String ciudad, List<String> lineas, String correo,
            pw.CrossAxisAlignment align) =>
        pw.Column(
          crossAxisAlignment: align,
          children: [
            _txt(ciudad, bold: true, size: 7),
            for (final linea in lineas) _txt(linea, size: 6),
            _txt(correo, bold: true, size: 6),
          ],
        );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            children: [
              pw.Image(logo, width: 130, height: 50, fit: pw.BoxFit.contain),
              _txt('www.metrica.com.bo', bold: true),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              oficina(
                'LA PAZ',
                const [
                  'Pje. Gral. Donato Cardozo N° 715-B',
                  'Fernando Guachalla, Sopocachi',
                  '591 2 2422060 - 591 2 2910878',
                ],
                'comercial@metrica.com.bo',
                pw.CrossAxisAlignment.end,
              ),
              pw.SizedBox(width: 12),
              oficina(
                'SANTA CRUZ',
                const [
                  'Prolongación Mutualista N° 6170',
                  'Entre 6to y 7mo Anillo',
                  '+591 67010001',
                ],
                'info@metrica.com.bo',
                pw.CrossAxisAlignment.start,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _tituloDocumento(RimRegistro registro) {
    final rim = registro.documento;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _txt('RECEPCIÓN DE INSTRUMENTOS DE PESAJE',
              bold: true, size: 12, color: _title),
          pw.SizedBox(height: 3),
          _txt(rim.codigo, bold: true, size: 11, color: _code),
          if (registro.anulado) ...[
            pw.SizedBox(height: 5),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _void, width: 1.2),
              ),
              child: _txt(
                'ANULADO'
                '${registro.anuladoEn == null ? '' : ' el ${_fechaHora.format(registro.anuladoEn!)}'}'
                '${_vacio(registro.anuladoPor) ? '' : ' por ${registro.anuladoPor}'}'
                '${_vacio(registro.motivoAnulacion) ? '' : ': ${registro.motivoAnulacion}'}',
                bold: true,
                size: 9,
                color: _void,
                align: pw.TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static bool _vacio(String? value) => value == null || value.trim().isEmpty;

  static pw.Widget _seccion(String titulo) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 8, bottom: 6),
        padding: const pw.EdgeInsets.all(4),
        color: _section,
        child: _txt(titulo, bold: true, size: 9),
      );

  static pw.Widget _subtitulo(String titulo) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 4, bottom: 4),
        padding: const pw.EdgeInsets.only(bottom: 2),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _muted, width: 0.8)),
        ),
        child: _txt(titulo, bold: true, size: 9),
      );

  static pw.Widget _etiquetado(String etiqueta, String? valor) => pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 8, color: _ink),
          children: [
            pw.TextSpan(
              text: CalidadPdf.texto('$etiqueta: '),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: CalidadPdf.texto(_vacio(valor) ? '-' : valor!)),
          ],
        ),
      );

  /// Campos "Etiqueta: valor" en una grilla de [columnas].
  static pw.Widget _campos(
    List<(String, String?)> campos, {
    int columnas = 3,
  }) {
    final filas = <pw.Widget>[];
    for (var i = 0; i < campos.length; i += columnas) {
      filas.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var j = i; j < i + columnas; j++)
              pw.Expanded(
                child: j < campos.length
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 6),
                        child: _etiquetado(campos[j].$1, campos[j].$2),
                      )
                    : pw.SizedBox(),
              ),
          ],
        ),
      ));
    }
    return pw.Column(children: filas);
  }

  static pw.Widget _parrafo(String etiqueta, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: _etiquetado(etiqueta, valor),
      );

  static pw.Widget _inventario(RimDocumento rim) {
    final filas = <(String, String, String)>[
      for (final componente in RimCatalogo.componentes)
        if (rim.inventario[componente.key] != null)
          (
            componente.label,
            rim.inventario[componente.key]!.label,
            componente.conCantidad && !_vacio(rim.cantidades[componente.key])
                ? rim.cantidades[componente.key]!
                : '-',
          ),
      for (final otro in rim.otrosComponentes)
        (otro.nombre, otro.estado.label, '-'),
    ];

    pw.Widget celda(String value, {bool bold = false, bool center = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: _txt(value,
              bold: bold,
              size: 7.5,
              align: center ? pw.TextAlign.center : pw.TextAlign.left),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _subtitulo('3.1 Inventario de componentes'),
        if (filas.isEmpty)
          _txt('No se registraron componentes en el inventario.',
              size: 7, color: _muted)
        else
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(6),
              1: pw.FlexColumnWidth(2.4),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F0F0)),
                children: [
                  celda('Componente', bold: true),
                  celda('Estado', bold: true, center: true),
                  celda('Cantidad', bold: true, center: true),
                ],
              ),
              for (final (componente, estado, cantidad) in filas)
                pw.TableRow(children: [
                  celda(componente),
                  celda(estado, center: true),
                  celda(cantidad, center: true),
                ]),
            ],
          ),
        if (rim.observacionesInventario.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          _parrafo('Observaciones', rim.observacionesInventario),
        ],
      ],
    );
  }

  static pw.Widget _estadoFisico(RimDocumento rim) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _subtitulo('3.2 Daños físicos'),
          _parrafo(
            'Estado general',
            RimCatalogo.etiqueta(
                RimCatalogo.estadosGenerales, rim.estadoGeneral),
          ),
          if (rim.danos.isNotEmpty) ...[
            _txt('Tipos de daños encontrados:', bold: true),
            pw.SizedBox(height: 2),
            for (final dano in rim.danos.entries)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                child: _etiquetado(
                  '- ${RimCatalogo.etiqueta(RimCatalogo.tiposDano, dano.key)}',
                  dano.value.isEmpty
                      ? 'Ubicación no especificada'
                      : dano.value
                          .map((place) => RimCatalogo.etiqueta(
                              RimCatalogo.ubicacionesDano, place))
                          .join(', '),
                ),
              ),
            pw.SizedBox(height: 3),
          ],
          if (rim.descripcionDanos.isNotEmpty)
            _parrafo('Descripción adicional', rim.descripcionDanos),
          _subtitulo('3.3 Limpieza del instrumento'),
          _parrafo(
            'Nivel de suciedad',
            RimCatalogo.etiqueta(
                RimCatalogo.nivelesSuciedad, rim.nivelSuciedad),
          ),
        ],
      );

  static pw.Widget _firmas(
    RimDocumento rim,
    pw.ImageProvider firmaCliente,
    pw.ImageProvider? firmaRepresentante,
  ) {
    pw.Widget imagen(pw.ImageProvider firma) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Image(firma, fit: pw.BoxFit.contain),
        );

    pw.Widget caja(String titulo, String nombre, {pw.Widget? contenido}) =>
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Container(
                height: 62,
                width: 170,
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(
                  border:
                      pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.8)),
                ),
                child: contenido,
              ),
              pw.SizedBox(height: 3),
              _txt(titulo, bold: true, size: 7),
              _txt(nombre, size: 7),
            ],
          ),
        );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          caja(
            'Firma del cliente / solicitante',
            [
              rim.contactoNombre,
              if (rim.contactoCargo.isNotEmpty) rim.contactoCargo,
            ].join(' - '),
            contenido: imagen(firmaCliente),
          ),
          pw.SizedBox(width: 20),
          caja(
            'Representante de Métrica',
            rim.representanteMetrica,
            contenido:
                firmaRepresentante == null ? null : imagen(firmaRepresentante),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pie(RimRegistro registro, pw.Context context) {
    final rim = registro.documento;
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: 0.8)),
      ),
      child: _txt(
        'Métrica LTDA - RIM emitido el ${_fechaHora.format(rim.emitidoEn)} con '
        'ServiceMET${_vacio(rim.appVersion) ? '' : ' ${rim.appVersion}'} - '
        'ID ${rim.uuid} - Página ${context.pageNumber} de '
        '${context.pagesCount}',
        size: 6,
        color: _muted,
        align: pw.TextAlign.center,
      ),
    );
  }
}
