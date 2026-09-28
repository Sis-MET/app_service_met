import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calidad/data/historial_versiones.dart';
import 'package:service_met/screens/calidad/data/manual_servicemet.dart';
import 'package:service_met/screens/calidad/data/requisitos_17025.dart';
import 'package:service_met/screens/calidad/models/cumplimiento.dart';

/// Versión declarada en pubspec.yaml ("6.3.3+15").
String _versionPubspec() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  return RegExp(r'^version:\s*(\S+)', multiLine: true)
      .firstMatch(pubspec)!
      .group(1)!;
}

/// Compara "6.3.3+15" con "6.3.1+13": versión y luego build.
int _compararVersiones(String a, String b) {
  List<int> partes(String v) =>
      v.split(RegExp(r'[.+]')).map((p) => int.tryParse(p) ?? 0).toList();
  final pa = partes(a);
  final pb = partes(b);
  for (var i = 0; i < 4; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

void main() {
  group('matriz de cumplimiento', () {
    final requisitos = evaluacionCumplimiento.requisitos;

    test('los IDs son únicos', () {
      final ids = requisitos.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('cada cláusula tiene requisitos', () {
      for (final clausula in Clausula.values) {
        expect(evaluacionCumplimiento.deClausula(clausula), isNotEmpty,
            reason: clausula.numero);
      }
    });

    test('lo que no cumple explica la brecha, la acción y el riesgo', () {
      for (final r in requisitos) {
        expect(r.evidencias, isNotEmpty, reason: r.id);
        if (r.estado == EstadoCumplimiento.cumple) {
          expect(r.brecha, isNull, reason: '${r.id} cumple y tiene brecha');
          continue;
        }
        expect(r.brecha, isNotNull, reason: r.id);
        expect(r.accion, isNotNull, reason: r.id);
        expect(r.cierre, isNotNull, reason: r.id);
        expect(r.riesgo, isNotNull, reason: r.id);
      }
    });

    test('se reevalúa en cada versión liberada', () {
      // Al subir la versión hay que revisar la matriz (7.11.2): estados,
      // evidencias, versión y fecha de evaluación.
      expect(evaluacionCumplimiento.version, _versionPubspec());
    });

    test('el avance pondera los parciales a la mitad', () {
      const cumple = Requisito(
        id: 'X-1',
        clausula: Clausula.registrosTecnicos,
        literal: '7.5.1',
        titulo: '',
        exige: '',
        estado: EstadoCumplimiento.cumple,
        evidencias: [''],
      );
      const parcial = Requisito(
        id: 'X-2',
        clausula: Clausula.registrosTecnicos,
        literal: '7.5.1',
        titulo: '',
        exige: '',
        estado: EstadoCumplimiento.parcial,
        evidencias: [''],
      );
      expect(ResumenCumplimiento([cumple, parcial]).avance, 0.75);
      expect(ResumenCumplimiento(const []).avance, 0);
    });
  });

  group('historial de versiones', () {
    test('la versión de pubspec.yaml está registrada como la más reciente', () {
      // Ninguna versión se distribuye sin su entrada en el historial.
      expect(historialVersiones.first.version, _versionPubspec(),
          reason: 'Agregue la versión a historialVersiones y mueva ahí los '
              'cambiosSinLiberar.');
    });

    test('va de la más reciente a la más antigua, sin repetir', () {
      for (var i = 1; i < historialVersiones.length; i++) {
        final previa = historialVersiones[i - 1];
        final actual = historialVersiones[i];
        expect(_compararVersiones(previa.version, actual.version), 1,
            reason: '${previa.version} debe ir antes de ${actual.version}');
        expect(previa.fecha.compareTo(actual.fecha), greaterThanOrEqualTo(0),
            reason: '${previa.version} tiene fecha anterior a '
                '${actual.version}');
      }
    });

    test('cada versión describe qué cambió', () {
      for (final v in historialVersiones) {
        expect(v.resumen, isNotEmpty, reason: v.version);
        expect(v.nuevo.isNotEmpty || v.corregido.isNotEmpty, isTrue,
            reason: v.version);
        expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v.fecha), isTrue,
            reason: v.version);
      }
    });
  });

  group('manual de uso', () {
    test('las secciones tienen ID único y contenido', () {
      final ids = manualServiceMet.secciones.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final s in manualServiceMet.secciones) {
        expect(s.bloques, isNotEmpty, reason: s.id);
      }
    });

    test('describe la versión menor instalada', () {
      // Una versión menor nueva (6.4) suele cambiar flujos: obliga a revisar
      // el manual y su "Aplica a" (7.11.5).
      final menor = _versionPubspec().split('.').take(2).join('.');
      expect(manualServiceMet.control.aplicaA, startsWith(menor));
    });

    test('la búsqueda encuentra texto dentro de los pasos', () {
      final seccion =
          manualServiceMet.secciones.firstWhere((s) => s.id == 'calibracion');
      expect(seccion.coincide('confirmar seca'), isTrue);
      expect(seccion.coincide('texto que no existe'), isFalse);
    });
  });
}
