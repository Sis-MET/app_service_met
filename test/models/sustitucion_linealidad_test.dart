import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/database/calibration_data_normalizer.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/models/sustitucion_linealidad.dart';

FilaCarga _fila(double carga, double? indicacion) =>
    (carga: carga, indicacion: indicacion);

/// Arma la cadena paso a paso, como el asistente: cada carga que resulta
/// queda en su fila y el técnico registra su indicación.
List<FilaCarga> _cadena(
  MetodoSustitucion metodo,
  FilaCarga pesas,
  List<({double sustitutiva, double indicacionResultante})> pasos,
) {
  final filas = <FilaCarga>[pesas];
  for (final paso in pasos) {
    final usadas =
        filasDelMetodo(metodo, filaPesas: 0, filaAnterior: filas.length - 1);
    final calculo = calcularPaso(
      PasoSustitucion(
        fila: filas.length,
        metodo: metodo,
        indicacionSustitutiva: paso.sustitutiva,
        filaReferencia: usadas.referencia,
        filaBase: usadas.base,
      ),
      filas,
    )!;
    filas.add(_fila(calculo.cargaResultante, paso.indicacionResultante));
  }
  return filas;
}

void main() {
  group('filasDelMetodo', () {
    test('Método 1: corrige con la carga anterior y suma a la de pesas', () {
      final filas = filasDelMetodo(MetodoSustitucion.metodo1,
          filaPesas: 4, filaAnterior: 6);
      expect(filas.referencia, 6);
      expect(filas.base, 4);
    });

    test('Método 2: corrige con la carga de pesas y suma a la anterior', () {
      final filas = filasDelMetodo(MetodoSustitucion.metodo2,
          filaPesas: 4, filaAnterior: 6);
      expect(filas.referencia, 4);
      expect(filas.base, 6);
    });
  });

  group('ejemplos del laboratorio', () {
    test('Método 1, ejemplo 2: la segunda carga es 1500, no 1994,5', () {
      // E(500) = +0,5. La sustitutiva de 495 vale 494,5 → 994,5, que indica
      // 995,5 (E = +1). La de 1001 vale 1000 y va con los 500 kg de pesas.
      final filas = _cadena(MetodoSustitucion.metodo1, _fila(500, 500.5), [
        (sustitutiva: 495, indicacionResultante: 995.5),
        (sustitutiva: 1001, indicacionResultante: 1500.5),
      ]);
      expect(filas[1].carga, closeTo(994.5, 1e-9));
      expect(filas[2].carga, closeTo(1500, 1e-9));
    });

    test('Método 2: 995,5 → 1498 → 1988,5', () {
      // E(500) = −0,5; sustitutivas de 495, 502 y 490.
      final filas = _cadena(MetodoSustitucion.metodo2, _fila(500, 499.5), [
        (sustitutiva: 495, indicacionResultante: 995),
        (sustitutiva: 502, indicacionResultante: 1497.5),
        (sustitutiva: 490, indicacionResultante: 1988),
      ]);
      expect([for (final f in filas.skip(1)) f.carga],
          [closeTo(995.5, 1e-9), closeTo(1498, 1e-9), closeTo(1988.5, 1e-9)]);
    });
  });

  group('ResultadoPaso', () {
    test('avisa cuando la sustitutiva se aleja de su referencia', () {
      final cerca = calcularSustitucion(
        indicacionSustitutiva: 502,
        referencia: _fila(500, 499.5),
        base: _fila(500, 499.5),
      )!;
      final lejos = calcularSustitucion(
        indicacionSustitutiva: 300,
        referencia: _fila(500, 499.5),
        base: _fila(500, 499.5),
      )!;
      expect(cerca.fueraDeRango, isFalse);
      expect(lejos.desvio, closeTo(0.4, 1e-9));
      expect(lejos.fueraDeRango, isTrue);
    });

    test('sin la indicación de la referencia no hay cálculo', () {
      expect(
        calcularSustitucion(
          indicacionSustitutiva: 495,
          referencia: _fila(500, null),
          base: _fila(500, 500),
        ),
        isNull,
      );
    });
  });

  group('columna local', () {
    final registradoEn = DateTime.utc(2026, 11, 13, 14, 15);
    final sustitucion = SustitucionLinealidad(cargasPatron: 1, pasos: [
      PasoSustitucion(
        fila: 2,
        metodo: MetodoSustitucion.metodo1,
        indicacionSustitutiva: 1001,
        filaReferencia: 1,
        filaBase: 0,
        registradoEn: registradoEn,
      ),
      const PasoSustitucion(
        fila: 1,
        metodo: MetodoSustitucion.metodo1,
        indicacionSustitutiva: 495,
        filaReferencia: 0,
        filaBase: 0,
      ),
    ]);

    test('va y vuelve, con los pasos en orden de fila', () {
      final leida = SustitucionLinealidad.fromColumn(sustitucion.toColumn());
      expect(leida.cargasPatron, 1);
      expect([for (final p in leida.pasos) p.fila], [1, 2]);
      expect(leida.pasoDeFila(2)!.indicacionSustitutiva, 1001);
      expect(leida.pasoDeFila(2)!.registradoEn!.isAtSameMomentAs(registradoEn),
          isTrue);
    });

    test('sin validar ni pasos, la columna queda vacía', () {
      expect(SustitucionLinealidad.vacia.toColumn(), '');
      expect(SustitucionLinealidad.fromColumn('').estaVacia, isTrue);
      expect(SustitucionLinealidad.fromColumn(null).estaVacia, isTrue);
    });

    test('descarta un JSON roto y los pasos que usan filas posteriores', () {
      expect(SustitucionLinealidad.fromColumn('{no').estaVacia, isTrue);
      final leida = SustitucionLinealidad.fromColumn(
          '{"cargas_patron":1,"pasos":[{"fila":1,"metodo":"M1",'
          '"indicacion_sustitutiva":495,"fila_referencia":1,"fila_base":0}]}');
      expect(leida.cargasPatron, 1);
      expect(leida.pasos, isEmpty);
    });

    test('la sesión la guarda y la recupera', () {
      final map = ServiceSession(
        sessionInfo: SessionInfo(seca: '0032-11-C01-26', sessionId: '0001'),
        metadata: SessionMetadata(),
        linealidad: LinealidadData(
          metodoCarga: 'Método 1',
          filas: [
            FilaLinealidad(carga: '500', indicacion: '500.5', retorno: '0'),
          ],
          sustitucion: sustitucion,
        ),
      ).toMap();

      expect(map[SustitucionLinealidad.columna], sustitucion.toColumn());
      final recuperada = ServiceSession.fromMap(map).linealidad!.sustitucion;
      expect(recuperada.cargasPatron, 1);
      expect(recuperada.pasos, hasLength(2));
    });

    test('se guarda en el teléfono pero no viaja como columna', () {
      final registro = {
        'seca': '0032-11-C01-26',
        'session_id': '0001',
        SustitucionLinealidad.columna: sustitucion.toColumn(),
      };
      expect(
        CalibrationDataNormalizer.normalizeRecord(registro)
            .containsKey(SustitucionLinealidad.columna),
        isTrue,
      );
      expect(
        CalibrationDataNormalizer.normalizeForUpload(registro)
            .containsKey(SustitucionLinealidad.columna),
        isFalse,
      );
    });
  });

  group('pasosParaServidor', () {
    test('envía cada paso con los valores de sus filas, desde la fila 1', () {
      final registro = <String, dynamic>{
        'lin1': '500',
        'ind1': '500.5',
        'lin2': '994.5',
        'ind2': '995.5',
        'lin3': '1500',
        'ind3': '1500.5',
        SustitucionLinealidad.columna: const SustitucionLinealidad(
          cargasPatron: 1,
          pasos: [
            PasoSustitucion(
              fila: 1,
              metodo: MetodoSustitucion.metodo1,
              indicacionSustitutiva: 495,
              filaReferencia: 0,
              filaBase: 0,
            ),
            PasoSustitucion(
              fila: 2,
              metodo: MetodoSustitucion.metodo1,
              indicacionSustitutiva: 1001,
              filaReferencia: 1,
              filaBase: 0,
            ),
          ],
        ).toColumn(),
      };

      final pasos = SustitucionLinealidad.pasosParaServidor(registro);
      expect(pasos, hasLength(2));
      expect(pasos[1], {
        'paso': 2,
        'fila': 3,
        'metodo': 'M1',
        'indicacion_sustitutiva': 1001.0,
        'fila_referencia': 2,
        'carga_referencia': 994.5,
        'indicacion_referencia': 995.5,
        'error_referencia': 1.0,
        'carga_sustitutiva': 1000.0,
        'fila_base': 1,
        'carga_base': 500.0,
        'carga_resultante': 1500.0,
        'registrado_en': null,
      });
    });

    test('un registro sin cargas sustitutivas no envía pasos', () {
      expect(SustitucionLinealidad.pasosParaServidor({'lin1': '500'}), isEmpty);
    });
  });
}
