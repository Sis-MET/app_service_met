import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calidad/data/historial_versiones.dart';
import 'package:service_met/screens/calidad/data/manual_servicemet.dart';
import 'package:service_met/screens/calidad/data/requisitos_17025.dart';
import 'package:service_met/screens/calidad/services/calidad_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final generado = DateTime(2026, 9, 28, 10, 30);

  void esPdf(List<int> bytes) {
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
  }

  test('la matriz de cumplimiento se genera sin conexión', () async {
    esPdf(await CalidadPdf.matrizCumplimiento(
      evaluacionCumplimiento,
      appVersion: '6.3.3+15',
      generado: generado,
    ));
  });

  test('el manual de uso se genera con todas sus secciones', () async {
    esPdf(await CalidadPdf.manualDeUso(
      manualServiceMet,
      appVersion: '6.3.3+15',
      generado: generado,
    ));
  });

  test('el historial de versiones se genera con los cambios sin liberar',
      () async {
    esPdf(await CalidadPdf.historialVersiones(
      historialVersiones,
      appVersion: '6.3.3+15',
      sinLiberar: const ['Cambio de prueba → con flecha'],
      notaFinal: notaVersionesAnteriores,
      generado: generado,
    ));
  });

  group('texto para las fuentes integradas', () {
    test('conserva tildes, eñes y signos del español', () {
      const texto = 'Calibración ñandú ¿Qué? ¡Sí! 25 °C ± 0,5 · Nº';
      expect(CalidadPdf.texto(texto), texto);
    });

    test('reemplaza lo que no existe en Latin-1', () {
      expect(CalidadPdf.texto('A → B — “ok” … ≥ 1'), 'A -> B - "ok" ... >= 1');
      expect(CalidadPdf.texto('listo ✅'), 'listo ?');
    });
  });
}
