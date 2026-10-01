import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:service_met/database/app_database.dart';
import 'package:service_met/database/calibration_data_normalizer.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> borrarBase() async {
    await AppDatabase().close();
    await deleteDatabase(p.join(await getDatabasesPath(), 'calibracion.db'));
  }

  setUp(borrarBase);
  tearDown(borrarBase);

  Future<ServiceSessionProvider> nuevaSesion({bool conSeca = true}) async {
    final provider = ServiceSessionProvider(CalibrationRepository());
    addTearDown(provider.dispose);
    await provider.createNewSession('tecnico');
    if (conSeca) {
      provider.updateCliente(ClienteInfo(id: '1', nombreComercial: 'Cliente'));
      provider.updatePlanta(PlantaInfo(codigo: '0032-11', nombre: 'Planta'));
      expect(await provider.confirmSeca(), isTrue);
    }
    return provider;
  }

  ExcentricidadData excentricidad(
    String carga, {
    String puntos = 'Rectangular 3F',
    int filasVacias = 0,
    String? nota,
  }) =>
      ExcentricidadData(
        tipoPlataforma: 'Rectangular',
        puntosIndicacion: puntos,
        carga: carga,
        nota: nota,
        posiciones: [
          for (var i = 1; i <= 3; i++)
            PosicionData(posicion: '$i', indicacion: '67.0', retorno: '0'),
          for (var i = 0; i < filasVacias; i++) PosicionData(),
        ],
      );

  /// Completa los pasos de una balanza salvo excentricidad y repetibilidad,
  /// que cada prueba arma a su medida.
  void completarBalanza(ServiceSessionProvider provider) {
    provider.updateSessionInfo(provider.session!.sessionInfo.copyWith(
      nReca: '123',
      sticker: '456',
      codMetrica: '0032-11-001',
    ));
    provider.updateBalanza(BalanzaInfo(
      codMetrica: '0032-11-001',
      tipo: 'Balanza',
      marca: 'Marca',
      modelo: 'Modelo',
      serie: 'S1',
      capMax1: '100',
      d1: 0.1,
      e1: 0.1,
      dec1: 1,
    ));
    provider.setBalanzaConfirmed(true);
    provider.updateInspeccionVisual(InspeccionVisual(
      tiempoEstab: '15 min',
      tiempoOperacion: '30 min',
      campos: {
        for (final key in const [
          'vibracion',
          'polvo',
          'temp',
          'humedad',
          'mesada',
          'iluminacion',
          'limp_foza',
          'estado_drenaje',
          'limp_general',
          'golpes_terminal',
          'nivelacion',
          'limp_recepto',
          'golpes_receptor',
          'encendido',
        ])
          key: 'Bueno',
      },
    ));
    provider.updatePrecargasAjuste(PrecargasAjuste(
      precargas: [PrecargaRow(precarga: '50', pIndicador: '50.0')],
      ti: '20',
      hri: '50',
      patmi: '1010',
    ));
    provider.updateLinealidad(LinealidadData(
      metodo: 'Sin metodo de carga',
      metodoCarga: 'Sin método',
      filas: [FilaLinealidad(carga: '50', indicacion: '50.0', retorno: '0')],
      fotosPaths: const ['carga.jpg'],
    ));
    provider.updatePatronWeights(
        [EquipoInfo(codInstrumento: 'MP-01', tipo: 'Pesa patrón')]);
    provider.updateCondicionesFinales(CondicionesFinales(
      horaFin: '12:00',
      hriFin: '50',
      tiFin: '20',
      patmiFin: '1010',
    ));
  }

  RepetibilidadData repetibilidad() => RepetibilidadData(cargas: [
        CargaRepetibilidad(
          carga: '100',
          indicaciones: ['100.0'],
          retornos: ['0'],
        ),
      ]);

  test('pesas e instrumentos se conservan al editar ambos pasos y continuar',
      () async {
    final provider = await nuevaSesion();
    final pattern =
        EquipoInfo(codInstrumento: 'MP-01', tipo: 'Pesa patrón', cantidad: '3');
    final thermometer = EquipoInfo(codInstrumento: 'TA-01', tipo: 'Termómetro');
    final hygrometer = EquipoInfo(codInstrumento: 'HA-02', tipo: 'Higrómetro');
    provider.updatePatronWeights([pattern]);
    provider.updateMeasuringInstruments([thermometer, hygrometer]);
    provider.updatePatronWeights([pattern.copyWith(cantidad: '4')]);
    expect(provider.session!.equipos.map((e) => e.codInstrumento),
        ['MP-01', 'TA-01', 'HA-02']);
    expect(provider.session!.equipos.first.cantidad, '4');
    expect(await provider.flushAutoSave(), isTrue);
    final info = provider.session!.sessionInfo;
    final reopened = ServiceSessionProvider(CalibrationRepository());
    addTearDown(reopened.dispose);
    await reopened.loadExistingSession(info.seca!, info.sessionId!);
    expect(reopened.session!.equipos.map((e) => e.codInstrumento),
        ['MP-01', 'TA-01', 'HA-02']);
    reopened.updateMeasuringInstruments([hygrometer]);
    expect(reopened.session!.equipos.map((e) => e.codInstrumento),
        ['MP-01', 'HA-02']);
    reopened.updateMeasuringInstruments([]);
    expect(reopened.session!.equipos.single.codInstrumento, 'MP-01');
  });

  test('los pendientes obligatorios se muestran juntos y señalan el campo',
      () async {
    final provider = await nuevaSesion();
    provider.updateRepetibilidad(RepetibilidadData(cargas: [
      CargaRepetibilidad(
          carga: '10', indicaciones: [null, '10'], retornos: [null, null]),
    ]));
    final readings = provider.stepIssues(7);
    expect(readings.map((issue) => issue.column), [
      'indicacion1_1',
      'retorno1_1',
      'retorno1_2',
    ]);
    expect(provider.validateRepetibilidad(), readings.first.message);

    provider.updateCondicionesFinales(
        CondicionesFinales(horaFin: '13:00', tiFin: '25'));
    final finalIssues = provider.stepIssues(9);
    expect(finalIssues.map((issue) => issue.column),
        ['hri_fin', 'patmi_fin', null]);
    expect(provider.validateCondicionesFinales(), finalIssues.first.message);
  });

  group('cierre de la balanza', () {
    test(
        'un dato fuera de esquema ya no deja la balanza "calibrada" sin sus '
        'pruebas', () async {
      // El caso reportado fue una carga con decimales cuando la columna era
      // int. Cualquier valor fuera de esquema tenía el mismo efecto: el
      // guardado rechazaba el registro completo, el error se tragaba y la
      // balanza se marcaba calibrada con lo último que sí se había guardado.
      final provider = await nuevaSesion();
      final seca = provider.session!.sessionInfo.seca!;
      final sessionId = provider.session!.sessionInfo.sessionId!;
      const notaLarga = 'Observación larga. ';

      // Más de 500 caracteres: el campo Nota no tiene límite en pantalla.
      provider
          .updateExcentricidad(excentricidad('66.65', nota: notaLarga * 27));
      provider.updateRepetibilidad(RepetibilidadData(cargas: [
        CargaRepetibilidad(
          carga: '100',
          indicaciones: ['100.0'],
          retornos: ['0'],
        ),
      ]));

      expect(await provider.flushAutoSave(), isFalse);
      expect(
        provider.saveError,
        contains('Excentricidad › Nota: admite hasta 500 caracteres'),
      );
      expect(
        provider.validateStep(6),
        'Excentricidad › Nota: admite hasta 500 caracteres (tiene 512)',
      );

      expect(await provider.marcarBalanzaCompleta(), isNotNull);
      final abierta = await AppDatabase().getRegistroBySeca(seca, sessionId);
      expect(abierta!['estado_servicio_bal'], isEmpty);
      expect(abierta['indicacion1_1'], isEmpty);

      provider.updateExcentricidad(
          excentricidad('66.65', nota: 'Sin observaciones'));
      completarBalanza(provider);
      expect(await provider.marcarBalanzaCompleta(), isNull);
      expect(provider.saveError, isNull);

      final cerrada = await AppDatabase().getRegistroBySeca(seca, sessionId);
      expect(cerrada!['estado_servicio_bal'], 'Balanza Calibrada');
      // La carga ya admite decimales (migración 011).
      expect(cerrada['carga'], '66.65');
      expect(cerrada['indicacion3'], '67');
      expect(cerrada['indicacion1_1'], '100');
    });

    test('no se marca calibrada una balanza con pruebas vacías', () async {
      // Desde la barra de pasos se puede saltar al último paso; cerrar desde
      // ahí dejaba "Balanza Calibrada" una balanza a la que le faltaban
      // pruebas, y la revisión final de otra balanza lo contradecía.
      final provider = await nuevaSesion();
      final seca = provider.session!.sessionInfo.seca!;
      final sessionId = provider.session!.sessionInfo.sessionId!;
      completarBalanza(provider);
      provider.updateRepetibilidad(repetibilidad());

      final error = await provider.marcarBalanzaCompleta();
      expect(error, contains('Excentricidad'));
      final fila = await AppDatabase().getRegistroBySeca(seca, sessionId);
      expect(fila!['estado_servicio_bal'], isEmpty);

      provider.updateExcentricidad(excentricidad('67'));
      expect(await provider.marcarBalanzaCompleta(), isNull);
      final cerrada = await AppDatabase().getRegistroBySeca(seca, sessionId);
      expect(cerrada!['estado_servicio_bal'], 'Balanza Calibrada');
    });

    test('una balanza calibrada se ve completa al releerla de la base',
        () async {
      // La revisión final evalúa las otras balanzas desde su fila: tiene que
      // llegar al mismo resultado que tuvo la balanza al cerrarse.
      final provider = await nuevaSesion();
      final seca = provider.session!.sessionInfo.seca!;
      final sessionId = provider.session!.sessionInfo.sessionId!;
      completarBalanza(provider);
      provider.updateExcentricidad(excentricidad('67'));
      provider.updateRepetibilidad(repetibilidad());
      expect(await provider.marcarBalanzaCompleta(), isNull);

      final filas = await provider.getRegistrosCompletos(seca);
      final fila = filas.singleWhere((r) => r['session_id'] == sessionId);
      expect(
          ServiceSessionProvider.calibrationIssues(
              ServiceSession.fromMap(fila)),
          isEmpty);

      // Sin la fila de progreso (respaldo importado) sigue confirmada.
      final sinProgreso = Map<String, dynamic>.from(fila)
        ..remove('balanza_confirmed');
      expect(ServiceSession.fromMap(sinProgreso).metadata.balanzaConfirmed,
          isTrue);
    });

    test('las filas de la consulta del SECA se pueden subir tal cual',
        () async {
      // La pantalla de subida usa la misma consulta, que agrega columnas de
      // progreso local (servicio_status); ninguna debe llegar al servidor.
      final provider = await nuevaSesion();
      final seca = provider.session!.sessionInfo.seca!;
      completarBalanza(provider);
      provider.updateExcentricidad(excentricidad('67'));
      provider.updateRepetibilidad(repetibilidad());
      expect(await provider.marcarBalanzaCompleta(), isNull);

      final filas = await CalibrationRepository().getRegistrosPorSeca(seca);
      expect(filas.single['servicio_status'], 'completed');
      final subida = CalibrationDataNormalizer.normalizeForUpload(filas.single);
      expect(subida.keys, isNot(contains('servicio_status')));
      expect(subida.keys, isNot(contains('balanza_confirmed')));
      expect(subida['cod_metrica'], '0032-11-001');
    });

    test('los intentos descartados se distinguen en la consulta del SECA',
        () async {
      final provider = await nuevaSesion();
      final seca = provider.session!.sessionInfo.seca!;
      final sessionId = provider.session!.sessionInfo.sessionId!;
      provider.updateExcentricidad(excentricidad('67'));
      expect(await provider.flushAutoSave(), isTrue);
      await CalibrationRepository()
          .markServicioAbandonado(seca, sessionId, 'tecnico');

      final fila = (await provider.getRegistrosCompletos(seca))
          .singleWhere((r) => r['session_id'] == sessionId);
      expect(fila['servicio_status'], 'abandoned');
    });

    test(
        'interrumpir una balanza la deja descartada, con sus datos, y abre '
        'otra en la misma SECA', () async {
      final provider = await nuevaSesion();
      completarBalanza(provider);
      provider.updateExcentricidad(excentricidad('67'));
      final seca = provider.session!.sessionInfo.seca!;
      final interrumpida = provider.session!.sessionInfo.sessionId!;

      expect(await provider.interrumpirBalanza(), isNull);

      // La sesión nueva conserva cliente, planta y SECA, sin instrumento.
      final nueva = provider.session!;
      expect(nueva.sessionInfo.seca, seca);
      expect(nueva.sessionInfo.sessionId, isNot(interrumpida));
      expect(nueva.cliente?.nombreComercial, 'Cliente');
      expect(nueva.planta?.codigo, '0032-11');
      expect(nueva.balanza, isNull);
      expect(nueva.metadata.balanzaConfirmed, isFalse);
      expect(provider.currentStep, 3);

      // Lo registrado sigue en el teléfono, sin darse por calibrado.
      final fila = (await provider.getRegistrosCompletos(seca))
          .singleWhere((r) => r['session_id'] == interrumpida);
      expect(fila['servicio_status'], 'abandoned');
      expect(fila['cod_metrica'], '0032-11-001');
      expect(fila['carga']?.toString(), isNotEmpty);
      expect(fila['estado_servicio_bal'] ?? '', isNot('Balanza Calibrada'));
      // Y no vuelve a ofrecerse como calibración pendiente.
      final pendientes =
          await CalibrationRepository().getServiciosIncompletos('tecnico');
      expect(pendientes.map((r) => r['session_id']),
          isNot(contains(interrumpida)));
    });

    test('abrir una balanza finalizada no borra su marca de finalizada',
        () async {
      final provider = await nuevaSesion();
      final seca = provider.session!.sessionInfo.seca!;
      final sessionId = provider.session!.sessionInfo.sessionId!;
      completarBalanza(provider);
      provider.updateExcentricidad(excentricidad('67'));
      provider.updateRepetibilidad(repetibilidad());
      expect(await provider.marcarBalanzaCompleta(), isNull);
      await provider.finalizeCalibrationRecords(
        seca: seca,
        sessionIds: [sessionId],
        nombreCsv: '${seca}_test.csv',
        finalizedAt: DateTime(2026, 9, 23),
      );

      // Continuar el servicio guarda el avance: antes lo hacía con REPLACE y
      // la balanza volvía a entrar en la siguiente exportación.
      final reabierta = ServiceSessionProvider(CalibrationRepository());
      addTearDown(reabierta.dispose);
      await reabierta.initialize(
          userName: 'tecnico', secaValue: seca, sessionId: sessionId);
      reabierta.goToStep(10);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final estado = await AppDatabase().getServicioStatus(seca, sessionId);
      expect(estado!['finalized_at'], isNotNull);
      expect(estado['nombre_csv'], '${seca}_test.csv');
      expect(estado['current_step'], 10);
      await reabierta.flushPendingSave();
    });

    test('la relectura detecta un valor que no quedó en la base', () async {
      final provider = await nuevaSesion();
      final seca = provider.session!.sessionInfo.seca!;
      final sessionId = provider.session!.sessionInfo.sessionId!;
      provider.updateExcentricidad(excentricidad('67'));
      expect(await provider.flushAutoSave(), isTrue);

      final db = await AppDatabase().database;
      await db.update(
        'registros_calibracion',
        {'indicacion2': ''},
        where: 'seca = ? AND session_id = ?',
        whereArgs: [seca, sessionId],
      );

      final faltan = await CalibrationRepository()
          .findUnsavedColumns(seca, sessionId, provider.session!);
      expect(faltan, ['indicacion2']);
    });

    test('reducir los puntos borra de la base las posiciones que sobran',
        () async {
      final provider = await nuevaSesion();
      final seca = provider.session!.sessionInfo.seca!;
      final sessionId = provider.session!.sessionInfo.sessionId!;

      provider.updateExcentricidad(ExcentricidadData(
        tipoPlataforma: 'Rectangular',
        puntosIndicacion: 'Rectangular 5F',
        carga: '67',
        posiciones: [
          for (var i = 1; i <= 5; i++)
            PosicionData(posicion: '$i', indicacion: '67.0', retorno: '0'),
        ],
      ));
      expect(await provider.flushAutoSave(), isTrue);
      provider.updateExcentricidad(excentricidad('67'));
      expect(await provider.flushAutoSave(), isTrue);

      final fila = await AppDatabase().getRegistroBySeca(seca, sessionId);
      expect(fila!['indicacion3'], '67');
      expect(fila['indicacion4'], isEmpty);
      expect(fila['posicion5'], isEmpty);
    });
  });

  group('validaciones por paso', () {
    test('muestra todos los números rechazados del paso y su columna',
        () async {
      final provider = await nuevaSesion(conSeca: false);
      provider.updateExcentricidad(ExcentricidadData(
        tipoPlataforma: 'Rectangular',
        puntosIndicacion: 'Rectangular 3F',
        carga: 'no',
        posiciones: [
          PosicionData(posicion: '1', indicacion: 'abc', retorno: '0'),
          PosicionData(posicion: '2', indicacion: '', retorno: '0'),
          PosicionData(posicion: '3', indicacion: '', retorno: '0'),
        ],
      ));
      final issues = provider.stepIssues(6);
      expect(
          issues.map((i) => i.column), containsAll(['carga', 'indicacion1']));
      expect(provider.validateStep(6), issues.first.message);
    });

    test('Repetibilidad pide cada indicación de las cargas elegidas', () async {
      final provider = await nuevaSesion(conSeca: false);

      expect(provider.validateStep(7),
          'Debe seleccionar el N° de Cargas de repetibilidad.');

      provider.updateRepetibilidad(RepetibilidadData(cargas: [
        CargaRepetibilidad(
          carga: '100',
          indicaciones: ['100.0', null, '100.0'],
          retornos: ['0', '0', '0'],
        ),
      ]));
      expect(provider.validateStep(7), 'Falta la Indicación 2 de la Carga 1.');
    });

    test('Excentricidad solo pide las posiciones de la prueba', () async {
      final provider = await nuevaSesion(conSeca: false);

      // Una sesión recuperada puede traer más filas vacías que puntos.
      provider.updateExcentricidad(excentricidad('67', filasVacias: 3));
      expect(provider.validateStep(6), isNull);

      provider
          .updateExcentricidad(excentricidad('67', puntos: 'Rectangular 3'));
      expect(provider.validateStep(6),
          'Debe seleccionar la Posición del Indicador.');
    });

    test('Condiciones finales pide las lecturas ambientales', () async {
      final provider = await nuevaSesion(conSeca: false);

      provider.updateCondicionesFinales(CondicionesFinales(
        horaFin: '10:30',
        hriFin: '45',
        tiFin: '',
        patmiFin: '1012',
      ));
      expect(provider.validateStep(9),
          'Debe ingresar la Temperatura final (Ti Fin).');
    });

    test('Linealidad pide la indicación de cada carga registrada', () async {
      final provider = await nuevaSesion(conSeca: false);

      provider.updateLinealidad(LinealidadData(
        metodo: 'Ascenso Continuo por pasos',
        metodoCarga: 'Sin método',
        fotosPaths: ['/foto.jpg'],
        filas: [
          FilaLinealidad(carga: '50', indicacion: '50.0', retorno: '0'),
          FilaLinealidad(carga: '100', indicacion: '', retorno: '0'),
          FilaLinealidad(carga: '', indicacion: '', retorno: '0'),
        ],
      ));
      expect(provider.validateStep(8), 'Falta la Indicación de la Carga 2.');
    });
  });

  group('continuar una calibración pendiente', () {
    /// Guarda la sesión de [provider] y la abre en otro, como al tocar
    /// "Continuar" en una calibración pendiente.
    Future<ServiceSessionProvider> continuar(
        ServiceSessionProvider provider) async {
      expect(await provider.flushAutoSave(), isTrue);
      final info = provider.session!.sessionInfo;
      final continuada = ServiceSessionProvider(CalibrationRepository());
      addTearDown(continuada.dispose);
      await continuada.loadExistingSession(info.seca!, info.sessionId!);
      return continuada;
    }

    test('recupera la cotización del SECA, no el C01 de la memoria', () async {
      final provider = await nuevaSesion(conSeca: false);
      provider.updatePlanta(PlantaInfo(codigo: '0032-11', nombre: 'Planta'));
      provider.setCotizacionSuffix('C07');
      expect(await provider.confirmSeca(), isTrue);
      final continuada = await continuar(provider);
      expect(continuada.cotizacion, 'C07');
      // Un borrador no cambia el SECA que ya se confirmó.
      continuada.setCotizacionSuffix('C09');
      expect(continuada.cotizacion, 'C07');
    });

    test('una sesión nueva no hereda la cotización de la anterior', () async {
      final provider = await nuevaSesion(conSeca: false);
      expect(provider.cotizacion, 'C01');
      provider.setCotizacionSuffix('C08');
      expect(provider.cotizacion, 'C08');
      await provider.createNewSession('tecnico');
      expect(provider.cotizacion, 'C01');
    });

    test('linealidad conserva sus fotos y deja pasar al siguiente paso',
        () async {
      // El caso reportado: al continuar volvían los datos, pero no las fotos
      // ni el código de la balanza, así que linealidad exigía una foto y a
      // la vez no dejaba tomarla.
      final provider = await nuevaSesion();
      provider.updateBalanza(BalanzaInfo(
        codMetrica: '0032-11-020',
        fotosPaths: ['/fotos/001.jpg'],
      ));
      provider.updateSessionInfo(
          provider.session!.sessionInfo.copyWith(codMetrica: '0032-11-020'));
      provider.updateLinealidad(LinealidadData(
        metodo: 'Ascendente',
        metodoCarga: 'Sin cargas sustitutivas',
        filas: [FilaLinealidad(carga: '50', indicacion: '50.0', retorno: '0')],
        fotosPaths: ['/fotos/002.jpg'],
      ));
      provider.updateCondicionesFinales(CondicionesFinales(
        fotosFinalesPaths: ['/fotos/fotos_finales/001.jpg'],
      ));
      expect(provider.validateLinealidad(), isNull);

      final continuada = await continuar(provider);
      final sesion = continuada.session!;

      expect(sesion.balanza!.codMetrica, '0032-11-020');
      expect(sesion.balanza!.fotosPaths, ['/fotos/001.jpg']);
      expect(sesion.linealidad!.fotosPaths, ['/fotos/002.jpg']);
      expect(sesion.condicionesFinales!.fotosFinalesPaths,
          ['/fotos/fotos_finales/001.jpg']);
      expect(continuada.validateLinealidad(), isNull);
    });

    test('volver a tocar el mismo cliente no borra la planta', () async {
      final continuada = await continuar(await nuevaSesion());

      continuada.updateCliente(ClienteInfo(
        id: '1',
        codigoCliente: '0032',
        nombreComercial: 'Cliente',
        isNew: false,
      ));
      expect(continuada.session!.planta!.codigo, '0032-11');
      expect(continuada.session!.planta!.nombre, 'Planta');

      // Otro cliente sí la borra: la planta era del anterior.
      continuada.updateCliente(ClienteInfo(
        id: '2',
        codigoCliente: '0099',
        nombreComercial: 'Otro cliente',
        isNew: false,
      ));
      expect(continuada.session!.planta!.codigo, isNull);
    });
  });
}
