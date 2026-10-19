import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/rim/models/rim_documento.dart';
import 'package:service_met/screens/rim/services/rim_pdf.dart';

import 'rim_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RimRegistro registro({bool anulado = false}) => RimRegistro(
        id: 1,
        documento: rimDePrueba(),
        firmaCliente: firmaDePrueba,
        firmaRepresentante: firmaRepresentanteDePrueba,
        estado: RimEstadoSubida.pending,
        anulado: anulado,
        anuladoPor: anulado ? 'lmamani' : null,
        anuladoEn: anulado ? DateTime(2026, 10, 1, 15) : null,
        motivoAnulacion: anulado ? 'Se eligió la balanza equivocada.' : null,
      );

  void esPdf(List<int> bytes) {
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
  }

  /// Con RIM_PDF_DIR definido deja el PDF en esa carpeta, para revisarlo.
  void guardar(String nombre, List<int> bytes) {
    final carpeta = Platform.environment['RIM_PDF_DIR'];
    if (carpeta == null || carpeta.isEmpty) return;
    File('$carpeta${Platform.pathSeparator}$nombre').writeAsBytesSync(bytes);
  }

  test('el PDF del RIM se genera sin conexión, con las firmas', () async {
    final bytes = await RimPdf.generar(registro());
    esPdf(bytes);
    guardar('rim.pdf', bytes);
  });

  test('un RIM anulado genera su PDF marcado', () async {
    final bytes = await RimPdf.generar(registro(anulado: true));
    esPdf(bytes);
    guardar('rim_anulado.pdf', bytes);
  });

  test('el archivo lleva el código, el instrumento y la fecha de emisión', () {
    expect(
      RimPdf.nombreArchivo(rimDePrueba()),
      'RIM-26-0041_0090-11-014_20261001_1445.pdf',
    );
  });
}
