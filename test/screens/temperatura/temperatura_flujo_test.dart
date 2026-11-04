import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/calibracion/tipo_calibracion_screen.dart';
import 'package:service_met/screens/calibracion_temperatura/controllers/temperatura_controller.dart';
import 'package:service_met/screens/calibracion_temperatura/data/catalogo_temperatura.dart';
import 'package:service_met/screens/calibracion_temperatura/data/temperatura_store.dart';
import 'package:service_met/screens/calibracion_temperatura/models/temperatura_models.dart';
import 'package:service_met/services/ubicacion_servicio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Catalogo implements CatalogoTemperatura {
  static const cliente = {
    'cliente_id': '7',
    'codigo_cliente': '0032',
    'cliente': 'Lab Andino',
    'razonsocial': 'Laboratorio Andino S.A.',
  };
  static const planta = {
    'planta_id': '70',
    'codigo_planta': '0032-11',
    'planta': 'El Alto',
    'dep': 'La Paz',
  };
  static const mufla = {
    'cod_metrica': '0032-11-090',
    'instrumento': 'Mufla eléctrica',
    'marca': 'Thermolyne',
    'modelo': 'F48000',
    'serie': 'X1',
  };

  @override
  Future<List<Map<String, dynamic>>> buscarClientes(String texto) async =>
      [cliente];

  @override
  Future<Map<String, dynamic>?> clientePorCodigo(String codigo) async =>
      codigo == '0032' ? cliente : null;

  @override
  Future<List<Map<String, dynamic>>> plantasDe(String clienteId) async =>
      [planta];

  @override
  Future<List<Map<String, dynamic>>> equiposDe(String codPlanta) async =>
      [mufla];

  @override
  Future<Map<String, dynamic>?> equipoPorCodigo(String codMetrica) async =>
      codMetrica == '0032-11-090' ? mufla : null;

  @override
  Future<List<Map<String, dynamic>>> patrones() async => [
        {
          'cod_instrumento': 'TM-001',
          'instrumento': 'Termómetro digital patrón'
        },
        {'cod_instrumento': 'TH-002', 'instrumento': 'Termohigrómetro'},
        {'cod_instrumento': 'PE-010', 'instrumento': 'Pesa patrón 1 kg'},
      ];
}

void main() {
  late Database db;
  late TemperaturaStore store;
  var ahora = DateTime(2026, 10, 29, 9, 0);

  setUpAll(() {
    sqfliteFfiInit();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = TemperaturaStore(open: () async => db);
    RegistroUbicacion.lectorOverride = () async =>
        const UbicacionServicio(latitud: -16.5, longitud: -68.15, precision: 8);
    ahora = DateTime(2026, 10, 29, 9, 0);
  });

  tearDown(() async {
    RegistroUbicacion.lectorOverride = null;
    await db.close();
  });

  TemperaturaController controlador() => TemperaturaController(
        userName: 'jperez',
        store: store,
        catalogo: _Catalogo(),
        appVersion: () async => '6.5.0+20',
        autoguardado: Duration.zero,
        reloj: () => ahora,
      );

  test('el recorrido completo deja un registro finalizado y bloqueado',
      () async {
    final c = controlador();
    await c.abrir();
    expect(c.listo, isTrue);
    expect(c.servicio.appVersion, '6.5.0+20');
    expect(c.puedeAbrir(PasoTemp.planta), isFalse);

    c.elegirCliente(_Catalogo.cliente);
    c.elegirPlanta(_Catalogo.planta);
    expect(c.secaPropuesta('c13'), '0032-11-C13-26');
    expect(await c.confirmarSeca('0032-11-x'), isNotNull, reason: 'formato');
    expect(await c.confirmarSeca(c.secaPropuesta('C13')), isNull);
    expect(c.clienteFijo, isTrue);
    expect(c.servicio.horaInicio, startsWith('2026-10-29T09:00:00'));

    c.equipoNuevo();
    expect(c.servicio.equipo?.nuevo, isTrue);
    expect(await c.confirmarEquipo(), 'Indique el tipo de equipo.');
    c.editarEquipo(
        (e) => e.copyWith(tipo: 'Mufla', resolucion: 1).conRango(100, 1100));
    expect(await c.confirmarEquipo(), isNull);

    final patrones = await c.catalogo.patrones();
    expect(patrones.where(FiltrosTemperatura.esPatronTemperatura).length, 1);
    expect(patrones.where(FiltrosTemperatura.esAmbiente).length, 1);
    await c.guardarPatrones([
      FiltrosTemperatura.patronDe(patrones[0], uso: TempPatron.usoTemperatura),
      FiltrosTemperatura.patronDe(patrones[1], uso: TempPatron.usoAmbiente),
    ]);
    // El indicador se crea solo; es digital: lo lee la cámara.
    expect(c.servicio.equipo?.indicador, 'Digital');
    await c.asegurarIndicador();
    expect(c.canales.map((k) => (k.rol, k.metodo, k.decimales)),
        [(RolCanal.equipo, MetodoCanal.camara, 0)]);
    expect(c.faltantes(PasoTemp.patrones), [
      'Agregue los sensores del patrón que van dentro del equipo.',
      'Registre la temperatura y la humedad ambiente iniciales.',
    ]);
    // Los sensores graban en su software: no se leen en la app.
    expect(await c.guardarSensor(c.sensorNuevo()), isNull);
    expect(await c.guardarSensor(c.sensorNuevo()), isNull);
    expect(c.canales.map((k) => (k.n, k.nombre, k.metodo)), [
      (1, 'Indicador del equipo', MetodoCanal.camara),
      (2, 'T1', MetodoCanal.externo),
      (3, 'T2', MetodoCanal.externo),
    ]);
    expect(c.canales[1].posicion, 'Centro');
    expect(c.canales[1].codPatron, 'TM-001');
    // Todos los indicadores se leen con la cámara (uno analógico, por su
    // aguja); el técnico puede elegir "A mano" si la cámara no alcanza.
    expect(esIndicadorAnalogico('Analógico'), isTrue);
    expect(esIndicadorAnalogico('Digital'), isFalse);
    expect(await c.metodoIndicador(MetodoCanal.manual), isNull);
    expect(c.canales.first.metodo, MetodoCanal.manual);
    expect(await c.metodoIndicador(MetodoCanal.camara), isNull);
    expect(c.canales.first.metodo, MetodoCanal.camara);
    // El tipo ya no cambia con el equipo confirmado.
    await c.elegirIndicador('Analógico');
    expect(c.servicio.equipo?.indicador, 'Digital');
    c.actualizar((s) => s.copyWith(
        ambiente:
            const TempAmbiente(temperaturaInicio: 21.4, humedadInicio: 38)));
    await c.guardarYa();
    expect(c.puedeAbrir(PasoTemp.puntos), isTrue);

    expect(
        await c.guardarPuntos(const [
          TempPunto(
              n: 1, temperaturaNominal: 300, duracionMin: 1, intervaloS: 30),
        ]),
        isNull);
    expect(await c.iniciarPunto(1), isNull);
    await store.registrarLectura(
      c.servicio.uuid,
      const TempLectura(
        nPunto: 1,
        nLectura: 0,
        nCanal: 1,
        tiempoProgramadoS: 0,
        capturadaEn: '2026-10-29T09:00:00.000-04:00',
        valor: 299.6,
        valorOriginal: 299.6,
        origen: OrigenLectura.ocrSegmentos,
      ),
    );
    await c.recargar();
    expect(c.canalesFijos, isTrue);
    expect(await c.guardarSensor(c.sensorNuevo()), isNotNull,
        reason: 'con lecturas, los sensores no cambian');
    expect(c.paquete.canalesLeidos.single.rol, RolCanal.equipo);
    expect(c.paquete.sensores.length, 2);

    ahora = ahora.add(const Duration(minutes: 2));
    expect(await c.completarPunto(1), isNull);
    expect(await c.finalizar(),
        'Registre la temperatura y la humedad ambiente finales.');
    c.actualizar((s) => s.copyWith(
        ambiente: TempAmbiente(
            temperaturaInicio: s.ambiente.temperaturaInicio,
            humedadInicio: s.ambiente.humedadInicio,
            temperaturaFin: 22,
            humedadFin: 40)));
    expect(await c.finalizar(), isNull);
    expect(c.servicio.finalizado, isTrue);
    expect(c.servicio.horaFin, startsWith('2026-10-29T09:02:00'));
    expect(c.puedeAbrir(PasoTemp.cliente), isFalse);
    expect(c.puedeAbrir(PasoTemp.resumen), isTrue);
    // La ubicación quedó en el registro.
    final paquete = await store.paquete(c.servicio.uuid);
    expect(paquete?.ubicacion?['latitud'], -16.5);

    // Otro equipo de la misma SECA.
    expect(await c.otroEquipo(), isNull);
    expect(c.servicio.seca, '0032-11-C13-26');
    expect(c.servicio.equipo, isNull);
    expect(c.paso, PasoTemp.equipo);
    c.dispose();
  });

  test('el QR del equipo completa cliente, planta y equipo', () async {
    final c = controlador();
    await c.abrir();
    expect(await c.aplicarQr('0032-11-090 Mufla Thermolyne'), isNull);
    expect(c.servicio.cliente?.nombre, 'Lab Andino');
    expect(c.servicio.planta?.codigo, '0032-11');
    expect(c.servicio.equipo?.codMetrica, '0032-11-090');
    expect(c.servicio.equipo?.tipo, 'Mufla');
    expect(await c.aplicarQr('hola'), isNotNull);
    c.dispose();
  });

  testWidgets('el tipo de calibración se elige como en soporte',
      (tester) async {
    TipoCalibracion? elegido;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => elegido = await TipoCalibracionScreen.elegir(
                context,
                pendientesTemperatura: 2,
                onRegistrosTemperatura: () {}),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('CALIBRACIÓN DE BALANZAS'), findsOneWidget);
    expect(find.text('CALIBRACIÓN DE TEMPERATURA'), findsOneWidget);
    expect(find.text('Registros de temperatura'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('CALIBRACIÓN DE TEMPERATURA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(elegido, TipoCalibracion.temperatura);
  });
}
