import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/models/service_session.dart';

ServiceSession _sesion({
  ExcentricidadData? excentricidad,
  RepetibilidadData? repetibilidad,
  LinealidadData? linealidad,
}) =>
    ServiceSession(
      sessionInfo: SessionInfo(seca: '0032-11-C01-26', sessionId: '0001'),
      metadata: SessionMetadata(),
      excentricidad: excentricidad,
      repetibilidad: repetibilidad,
      linealidad: linealidad,
    );

void main() {
  group('toMap', () {
    test('vacía las casillas que la prueba ya no usa', () {
      // Una prueba de 5 puntos que pasó a 3: las posiciones 4 y 5 no deben
      // quedar en la base con los valores anteriores.
      final map = _sesion(
        excentricidad: ExcentricidadData(
          puntosIndicacion: 'Rectangular 3F',
          carga: '67',
          posiciones: [
            for (var i = 1; i <= 3; i++)
              PosicionData(posicion: '$i', indicacion: '67.0', retorno: '0'),
          ],
        ),
        repetibilidad: RepetibilidadData(cargas: [
          CargaRepetibilidad(
            carga: '100',
            indicaciones: ['100.0', '100.0', '100.1'],
            retornos: ['0', '0', '0'],
          ),
        ]),
        linealidad: LinealidadData(filas: [
          FilaLinealidad(carga: '50', indicacion: '50.0', retorno: '0'),
        ]),
      ).toMap();

      expect(map['indicacion3'], '67.0');
      expect(map.containsKey('indicacion4'), isTrue);
      expect(map['indicacion4'], isNull);
      expect(map['posicion6'], isNull);

      expect(map['indicacion1_3'], '100.1');
      expect(map.containsKey('indicacion1_4'), isTrue);
      expect(map['indicacion1_4'], isNull);
      expect(map['repetibilidad2'], isNull);
      expect(map['retorno3_10'], isNull);

      expect(map['lin1'], '50');
      expect(map.containsKey('lin60'), isTrue);
      expect(map['lin60'], isNull);
    });

    test('no toca las pruebas que la sesión todavía no tiene', () {
      final map = _sesion().toMap();

      expect(map.containsKey('posicion1'), isFalse);
      expect(map.containsKey('repetibilidad1'), isFalse);
      expect(map.containsKey('lin1'), isFalse);
    });
  });

  group('fromMap', () {
    test('recupera la prueba con los puntos, cargas y mediciones usados', () {
      final sesion = ServiceSession.fromMap({
        'seca': '0032-11-C01-26',
        'session_id': '0001',
        'puntos_ind': 'Rectangular 3F',
        for (var i = 1; i <= 3; i++) ...{
          'posicion$i': '$i',
          'indicacion$i': '67.0',
          'retorno$i': '0',
        },
        'posicion4': '',
        'repetibilidad1': '100',
        'repetibilidad2': '200',
        for (var i = 1; i <= 2; i++)
          for (var j = 1; j <= 5; j++) ...{
            'indicacion${i}_$j': '${i}00.0',
            'retorno${i}_$j': '0',
          },
        'indicacion3_1': '',
      });

      expect(sesion.excentricidad!.posiciones, hasLength(3));
      expect(sesion.excentricidad!.puntosCount, 3);
      final cargas = sesion.repetibilidad!.cargas;
      expect(cargas, hasLength(2));
      expect(cargas.every((c) => c.indicaciones.length == 5), isTrue);
      expect(cargas[1].indicaciones.first, '200.0');
    });

    test('sin datos, las pruebas vuelven vacías', () {
      final sesion = ServiceSession.fromMap({'seca': 'X', 'session_id': '1'});

      expect(sesion.excentricidad!.posiciones, isEmpty);
      expect(sesion.repetibilidad!.cargas, isEmpty);
    });

    test('lo recuperado se vuelve a guardar igual', () {
      final original = {
        'repetibilidad1': '100',
        'indicacion1_1': '100.0',
        'retorno1_1': '0',
        'indicacion1_2': '100.0',
        'retorno1_2': '0',
        'indicacion1_3': '100.1',
        'retorno1_3': '0',
      };
      final map = ServiceSession.fromMap(original).toMap();

      for (final entry in original.entries) {
        expect(map[entry.key], entry.value, reason: entry.key);
      }
      expect(map['indicacion1_4'], isNull);
    });

    test('recupera las fotos de cada paso', () {
      // Una carpeta con coma en el nombre: por eso las rutas van como JSON.
      const carpeta = '/fotos/0032-11-C01-26/calibracion_fotos/0032,11';
      final sesion = ServiceSession(
        sessionInfo: SessionInfo(seca: '0032-11-C01-26', sessionId: '0001'),
        metadata: SessionMetadata(),
        balanza: BalanzaInfo(fotosPaths: ['$carpeta/001.jpg']),
        linealidad: LinealidadData(
          fotosPaths: ['$carpeta/002.jpg', '$carpeta/003.jpg'],
        ),
        condicionesFinales: CondicionesFinales(
          fotosFinalesPaths: ['/fotos/fotos_finales/001.jpg'],
        ),
      );

      final recuperada = ServiceSession.fromMap(sesion.toMap());

      expect(recuperada.balanza!.fotosPaths, ['$carpeta/001.jpg']);
      expect(recuperada.linealidad!.fotosPaths,
          ['$carpeta/002.jpg', '$carpeta/003.jpg']);
      expect(recuperada.condicionesFinales!.fotosFinalesPaths,
          ['/fotos/fotos_finales/001.jpg']);
    });

    test('sin fotos, la columna queda vacía y vuelve vacía', () {
      final map = _sesion(linealidad: LinealidadData()).toMap();

      expect(map[ServiceSession.fotosLinealidadColumn], '');
      expect(ServiceSession.fromMap(map).linealidad!.fotosPaths, isEmpty);
    });

    test('lee también rutas sueltas o separadas por comas', () {
      final sesion = ServiceSession.fromMap({
        ServiceSession.fotosBalanzaColumn: '/a/001.jpg, /a/002.jpg',
      });

      expect(sesion.balanza!.fotosPaths, ['/a/001.jpg', '/a/002.jpg']);
    });

    test('recupera el código métrica de la balanza y el del cliente', () {
      // Sin el código de la balanza, linealidad no dejaba tomar fotos y el
      // paso Balanza quedaba sin instrumento.
      final sesion = ServiceSession.fromMap({
        'cod_metrica': '0032-11-020',
        'cod_planta': '0032-11',
      });

      expect(sesion.balanza!.codMetrica, '0032-11-020');
      expect(sesion.sessionInfo.codMetrica, '0032-11-020');
      expect(sesion.cliente!.codigoCliente, '0032');
    });

    test('un ajuste sin responder sigue sin responder', () {
      bool? ajuste(Map<String, dynamic> map) =>
          ServiceSession.fromMap(map).precargasAjuste!.ajusteRealizado;

      expect(ajuste({}), isNull);
      expect(ajuste({'ajuste': ''}), isNull);
      expect(ajuste({'ajuste': 'No'}), isFalse);
      expect(ajuste({'ajuste': 'Sí'}), isTrue);
    });
  });

  test('puntosCount lee el formato actual y el anterior', () {
    expect(
        ExcentricidadData(puntosIndicacion: 'Rectangular 5F').puntosCount, 5);
    expect(ExcentricidadData(puntosIndicacion: 'Circular 4').puntosCount, 4);
    expect(ExcentricidadData(puntosIndicacion: '3').puntosCount, 3);
    expect(ExcentricidadData().puntosCount, isNull);
  });
}
