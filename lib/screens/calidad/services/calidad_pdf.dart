import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cumplimiento.dart';
import '../models/manual.dart';
import '../models/version_app.dart';

/// Documentos de calidad en PDF: matriz de cumplimiento, manual de uso e
/// historial de versiones.
///
/// Usa las fuentes integradas del paquete `pdf` para generar sin conexión
/// (en planta no siempre hay red para descargar fuentes). Esas fuentes solo
/// cubren Latin-1, así que todo texto pasa por [texto] antes de dibujarse.
class CalidadPdf {
  CalidadPdf._();

  static const _ink = PdfColor.fromInt(0xFF171714);
  static const _muted = PdfColor.fromInt(0xFF6C6B64);
  static const _line = PdfColor.fromInt(0xFFE2DED2);
  static const _soft = PdfColor.fromInt(0xFFF5F3EC);
  static const _accent = PdfColor.fromInt(0xFFF9E300);

  static final _fecha = DateFormat('yyyy-MM-dd');
  static final _fechaHora = DateFormat('yyyy-MM-dd HH:mm');

  /// Reemplaza lo que no existe en Latin-1 por su equivalente legible.
  static String texto(String value) {
    const reemplazos = {
      '—': '-',
      '–': '-',
      '‒': '-',
      '−': '-',
      '“': '"',
      '”': '"',
      '„': '"',
      '‘': "'",
      '’': "'",
      '…': '...',
      '•': '-',
      '›': '>',
      '‹': '<',
      '→': '->',
      '←': '<-',
      '≥': '>=',
      '≤': '<=',
      '≠': '!=',
      '✓': 'OK',
      '×': 'x',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      if (rune <= 0xFF) {
        buffer.write(char);
      } else {
        buffer.write(reemplazos[char] ?? '?');
      }
    }
    return buffer.toString();
  }

  // ── Documentos ─────────────────────────────────────────────────────────

  static Future<Uint8List> matrizCumplimiento(
    EvaluacionCumplimiento evaluacion, {
    required String appVersion,
    DateTime? generado,
  }) async {
    final doc = await _documento(
      titulo: 'Matriz de cumplimiento NB/ISO/IEC 17025',
      appVersion: appVersion,
      generado: generado ?? DateTime.now(),
      contenido: () {
        final resumen = evaluacion.resumen;
        return [
          _titulo('Matriz de cumplimiento NB/ISO/IEC 17025'),
          _parrafo('Evaluación interna de ServiceMET frente a las cláusulas '
              '7.5 (registros técnicos), 7.11 (control de los datos y gestión '
              'de la información) y 8.4 (control de registros). No sustituye '
              'la evaluación del organismo de acreditación.'),
          pw.SizedBox(height: 8),
          _tablaDatos([
            ('Versión evaluada', evaluacion.version),
            ('Fecha de evaluación', _fecha.format(evaluacion.fecha)),
            ('Requisitos evaluados', '${resumen.total}'),
            (
              'Resultado',
              EstadoCumplimiento.values
                  .map((e) => '${e.etiqueta}: ${resumen[e]}')
                  .join('   ·   '),
            ),
            ('Avance ponderado', '${(resumen.avance * 100).round()} %'),
          ]),
          for (final clausula in Clausula.values) ...[
            pw.SizedBox(height: 16),
            _subtitulo('${clausula.numero}  ${clausula.nombre}'),
            _parrafo(clausula.resumen, color: _muted),
            pw.SizedBox(height: 6),
            _tablaRequisitos(evaluacion.deClausula(clausula)),
          ],
          pw.SizedBox(height: 22),
          _firmas(['Evaluó', 'Revisó (Calidad)']),
        ];
      },
    );
    return doc.save();
  }

  static Future<Uint8List> manualDeUso(
    ManualUso manual, {
    required String appVersion,
    DateTime? generado,
  }) async {
    final control = manual.control;
    final doc = await _documento(
      titulo: control.titulo,
      appVersion: appVersion,
      generado: generado ?? DateTime.now(),
      contenido: () => [
        _titulo(control.titulo),
        _parrafo('Documento controlado. La copia vigente es la aprobada por '
            'Calidad; las copias impresas no se actualizan solas.'),
        pw.SizedBox(height: 8),
        _tablaDatos([
          ('Código', control.codigo),
          ('Revisión', control.revision),
          ('Fecha de emisión', control.fechaEmision),
          ('Aplica a la versión de la app', control.aplicaA),
          ('Elaboró', control.elaboro),
          ('Revisó', control.reviso),
          ('Aprobó', control.aprobo),
        ]),
        pw.SizedBox(height: 12),
        _subtitulo('Historial de revisiones'),
        _tabla(
          encabezados: ['Rev.', 'Fecha', 'Descripción del cambio'],
          anchos: const [1, 2, 7],
          filas: [
            for (final r in control.historial)
              [r.revision, r.fecha, r.descripcion],
          ],
        ),
        pw.SizedBox(height: 14),
        _subtitulo('Contenido'),
        for (final (i, s) in manual.secciones.indexed)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(texto('${i + 1}. ${s.titulo}'),
                style: const pw.TextStyle(fontSize: 10, color: _ink)),
          ),
        for (final (i, seccion) in manual.secciones.indexed) ...[
          pw.SizedBox(height: 18),
          _subtitulo('${i + 1}. ${seccion.titulo}'),
          _parrafo(seccion.resumen, color: _muted),
          pw.SizedBox(height: 4),
          for (final bloque in seccion.bloques) ..._bloque(bloque),
        ],
      ],
    );
    return doc.save();
  }

  static Future<Uint8List> historialVersiones(
    List<VersionApp> versiones, {
    required String appVersion,
    List<String> sinLiberar = const [],
    String? notaFinal,
    DateTime? generado,
  }) async {
    final doc = await _documento(
      titulo: 'Historial de versiones',
      appVersion: appVersion,
      generado: generado ?? DateTime.now(),
      contenido: () => [
        _titulo('Historial de versiones de ServiceMET'),
        _parrafo('Control de cambios del software (NB/ISO/IEC 17025 7.11.2). '
            'Clase A: afecta captura, cálculos, esquema, subida o seguridad. '
            'Clase B: cambia flujos o pantallas sin alterar datos. '
            'Clase C: textos, estilos o compilación.'),
        pw.SizedBox(height: 8),
        _tablaDatos([
          ('Versión instalada al exportar', appVersion),
          ('Versiones registradas', '${versiones.length}'),
        ]),
        if (sinLiberar.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _subtitulo('Cambios sin liberar'),
          ..._vinetas(sinLiberar),
        ],
        for (final v in versiones) ...[
          pw.SizedBox(height: 16),
          _subtitulo('${v.version}   ·   ${v.fecha}   ·   Clase '
              '${v.clase.codigo} (${v.clase.nombre})'),
          _parrafo(v.resumen),
          if (v.commit != null)
            _parrafo('Commit: ${v.commit}', color: _muted, size: 8.5),
          if (v.nuevo.isNotEmpty) ...[
            _etiqueta('Nuevo'),
            ..._vinetas(v.nuevo),
          ],
          if (v.corregido.isNotEmpty) ...[
            _etiqueta('Corregido'),
            ..._vinetas(v.corregido),
          ],
          _etiqueta('Impacto en registros'),
          _parrafo(v.impactoRegistros ?? 'Ninguno en los datos capturados.'),
          _etiqueta('Validación'),
          _parrafo(v.validacion ?? 'Registro de validación pendiente.',
              color: v.validacion == null ? _muted : _ink),
        ],
        if (notaFinal != null) ...[
          pw.SizedBox(height: 16),
          _parrafo(notaFinal, color: _muted),
        ],
      ],
    );
    return doc.save();
  }

  // ── Estructura común ───────────────────────────────────────────────────

  static Future<pw.Document> _documento({
    required String titulo,
    required String appVersion,
    required DateTime generado,
    required List<pw.Widget> Function() contenido,
  }) async {
    final logo = await _logo();
    final doc = pw.Document(
      title: texto(titulo),
      author: 'ServiceMET',
      creator: 'ServiceMET $appVersion',
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 34, 40, 34),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
        ),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 2)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.SizedBox(height: 22, child: pw.Image(logo))
              else
                pw.Text('ServiceMET',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(texto(titulo),
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink)),
                  pw.Text('ServiceMET · NB/ISO/IEC 17025',
                      style: const pw.TextStyle(fontSize: 8, color: _muted)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            children: [
              pw.Text(
                texto('Generado el ${_fechaHora.format(generado)} con '
                    'ServiceMET $appVersion'),
                style: const pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
              pw.Spacer(),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
            ],
          ),
        ),
        build: (_) => contenido(),
      ),
    );
    return doc;
  }

  static Future<pw.MemoryImage?> _logo() async {
    try {
      final data = await rootBundle.load('images/logo_met.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Sin logo el documento sigue siendo válido: se muestra el nombre.
      return null;
    }
  }

  // ── Piezas de contenido ────────────────────────────────────────────────

  static pw.Widget _titulo(String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(texto(value),
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink)),
      );

  static pw.Widget _subtitulo(String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(texto(value),
            style: pw.TextStyle(
                fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _ink)),
      );

  static pw.Widget _etiqueta(String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
        child: pw.Text(texto(value.toUpperCase()),
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.6,
                color: _muted)),
      );

  static pw.Widget _parrafo(String value,
          {PdfColor color = _ink, double size = 10}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(texto(value),
            style: pw.TextStyle(fontSize: size, color: color, lineSpacing: 2)),
      );

  static List<pw.Widget> _vinetas(List<String> items) => [
        for (final item in items)
          pw.Bullet(
            text: texto(item),
            style: const pw.TextStyle(fontSize: 10, color: _ink),
            bulletSize: 3,
            bulletMargin: const pw.EdgeInsets.only(top: 4.5, right: 6),
            margin: const pw.EdgeInsets.only(bottom: 2),
          ),
      ];

  static pw.Widget _tablaDatos(List<(String, String)> filas) => pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.6),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(7),
        },
        children: [
          for (final (clave, valor) in filas)
            pw.TableRow(children: [
              pw.Container(
                color: _soft,
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(texto(clave),
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(texto(valor),
                    style: const pw.TextStyle(fontSize: 9)),
              ),
            ]),
        ],
      );

  static pw.Widget _tabla({
    required List<String> encabezados,
    required List<int> anchos,
    required List<List<String>> filas,
  }) =>
      pw.Table(
        border: pw.TableBorder.all(color: _line, width: 0.6),
        columnWidths: {
          for (final (i, a) in anchos.indexed) i: pw.FlexColumnWidth(a * 1.0),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _soft),
            children: [
              for (final h in encabezados)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(texto(h),
                      style: pw.TextStyle(
                          fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ),
            ],
          ),
          for (final fila in filas)
            pw.TableRow(children: [
              for (final celda in fila)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(texto(celda),
                      style: const pw.TextStyle(fontSize: 8.5)),
                ),
            ]),
        ],
      );

  static pw.Widget _tablaRequisitos(List<Requisito> requisitos) {
    pw.Widget celda(String value, {bool bold = false, PdfColor? color}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(4.5),
          child: pw.Text(texto(value),
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? _ink,
              )),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(4.6),
        4: pw.FlexColumnWidth(3.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _soft),
          children: [
            celda('ID', bold: true),
            celda('Requisito', bold: true),
            celda('Estado', bold: true),
            celda('Evidencia y brecha', bold: true),
            celda('Acción · cierre · riesgo', bold: true),
          ],
        ),
        for (final r in requisitos)
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.top,
            children: [
              celda(r.id, bold: true),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4.5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(texto(r.titulo),
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text(texto(r.literal),
                        style:
                            const pw.TextStyle(fontSize: 7.5, color: _muted)),
                  ],
                ),
              ),
              celda(r.estado.etiqueta,
                  bold: true,
                  color: PdfColor.fromInt(r.estado.color.toARGB32())),
              celda([
                ...r.evidencias.map((e) => '- $e'),
                if (r.brecha != null) 'Brecha: ${r.brecha}',
              ].join('\n')),
              celda([
                r.accion ?? '-',
                if (r.cierre != null) 'Cierre: ${r.cierre!.etiqueta}',
                if (r.riesgo != null) 'Riesgo: ${r.riesgo!.etiqueta}',
              ].join('\n')),
            ],
          ),
      ],
    );
  }

  static List<pw.Widget> _bloque(BloqueManual bloque) => switch (bloque) {
        Parrafo(:final contenido) => [_parrafo(contenido)],
        Lista(:final titulo, :final items) => [
            if (titulo != null) _etiqueta(titulo),
            ..._vinetas(items),
          ],
        Pasos(:final titulo, :final pasos) => [
            if (titulo != null) _etiqueta(titulo),
            for (final (i, paso) in pasos.indexed)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 18,
                      child: pw.Text('${i + 1}.',
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(texto(paso.accion),
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold)),
                          if (paso.detalle != null)
                            pw.Text(texto(paso.detalle!),
                                style: const pw.TextStyle(
                                    fontSize: 9.5, color: _muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        Nota(:final tipo, :final contenido, :final referencia) => [
            // Inseparable: el rótulo y el texto de la nota van en la misma
            // página. La fila con Expanded le da todo el ancho.
            pw.Inseparable(
              child: pw.Row(children: [
                pw.Expanded(child: _nota(tipo, contenido, referencia)),
              ]),
            ),
          ],
      };

  static pw.Widget _nota(TipoNota tipo, String contenido, String? referencia) =>
      pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 5),
        padding: const pw.EdgeInsets.fromLTRB(9, 6, 8, 6),
        decoration: pw.BoxDecoration(
          color: _soft,
          border: pw.Border(
            left: pw.BorderSide(
                color: PdfColor.fromInt(tipo.color.toARGB32()), width: 3),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              texto(referencia == null
                  ? tipo.etiqueta
                  : '${tipo.etiqueta} · $referencia'),
              style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, color: _muted),
            ),
            pw.SizedBox(height: 2),
            pw.Text(texto(contenido), style: const pw.TextStyle(fontSize: 9.5)),
          ],
        ),
      );

  static pw.Widget _firmas(List<String> roles) => pw.Row(
        children: [
          for (final rol in roles)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(right: 24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 26),
                    pw.Container(height: 0.8, color: _ink),
                    pw.SizedBox(height: 3),
                    pw.Text(texto('$rol: nombre, firma y fecha'),
                        style: const pw.TextStyle(fontSize: 8, color: _muted)),
                  ],
                ),
              ),
            ),
        ],
      );
}
