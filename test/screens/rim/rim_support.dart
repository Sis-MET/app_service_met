import 'dart:convert';
import 'dart:typed_data';

import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/rim/data/rim_catalogo.dart';
import 'package:service_met/screens/rim/models/rim_documento.dart';
import 'package:service_met/screens/rim/models/rim_numeracion.dart';
import 'package:service_met/screens/rim/services/rim_store.dart';
import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

/// PNG de 1×1 píxel, como firma de prueba.
final Uint8List firmaDePrueba = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// Otro PNG de 1×1 píxel, de otro color, como firma del representante.
final Uint8List firmaRepresentanteDePrueba = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOQsyv4DwADFgHM'
  'Ma3dmwAAAABJRU5ErkJggg==',
);

OpportunityServiceContext servicioDePrueba({
  String sessionId = '0007',
  String codMetrica = '0090-11-014',
}) =>
    OpportunityServiceContext.fromSupport(
      serviceName: 'Mantenimiento correctivo',
      otst: '26-0090-11-S02',
      sessionId: sessionId,
      codMetrica: codMetrica,
      userName: 'Tec. Luis Mamani',
      clienteNombre: 'Coca-Cola Embol',
      clienteRazonSocial: 'Embotelladoras Bolivianas Unidas S.A.',
      plantaNombre: 'Planta Viacha',
      plantaDepartamento: 'LA PAZ',
      clienteId: '0090',
      plantaCodigo: '0090-11',
      plantaDireccion: 'Carretera a Viacha km 14',
      instrumentoData: const {
        'tipo_instrumento': 'Balanza de plataforma',
        'marca': 'OHAUS',
        'modelo': 'Defender 5000',
        'serie': 'B845123',
        'cap_max1': '150',
        'd1': '0.05',
        'unidad': 'kg',
        'ubicacion': 'Almacén de producto terminado',
      },
      now: DateTime(2026, 10, 1, 14, 30),
    );

/// Instalación de la app en las pruebas sin SQLite.
const instalacionDePrueba = '9b2d7c41-5e3a-4f8b-9c6d-1a2b3c4d5e6f';

RimDocumento rimDePrueba({
  String uuid = '3f2a8c1e-7b4d-4e9a-a1c2-5d6e7f8091ab',
  OpportunityServiceContext? service,
  DateTime? emitidoEn,
  String codigo = 'RIM-26-0041',
  String? instalacion = instalacionDePrueba,
}) =>
    RimDocumento(
      uuid: uuid,
      codigo: codigo,
      instalacion: instalacion,
      service: service ?? servicioDePrueba(),
      motivo: 'El indicador no enciende; no se pudo concluir el mantenimiento.',
      inventario: const {
        'indicator': RimEstadoComponente.present,
        'powerCable': RimEstadoComponente.missing,
        'loadCells': RimEstadoComponente.present,
        'manual': RimEstadoComponente.na,
      },
      cantidades: const {'loadCells': '4'},
      otrosComponentes: const [
        RimComponenteExtra('Cable RS232', RimEstadoComponente.present),
      ],
      observacionesInventario: 'Se recibe sin adaptador.',
      estadoGeneral: 'fair',
      danos: const {
        'scratches': ['platform', 'display'],
        'corrosion': [],
      },
      descripcionDanos: 'Rayones en la plataforma y óxido en la base.',
      nivelSuciedad: 'moderate',
      pruebasFuncionamiento: true,
      descripcionPruebas: 'Se probó con otra fuente: tampoco enciende.',
      contactoNombre: 'Juan Pérez Ñáñez',
      contactoCargo: 'Jefe de mantenimiento',
      contactoTelefono: '+591 70000000',
      representanteMetrica: 'Tec. Luis Mamani',
      lugarRecepcion: 'Planta Viacha - Carretera a Viacha km 14',
      tecnicoAsignado: '',
      emitidoEn: emitidoEn ?? DateTime(2026, 10, 1, 14, 45),
      creadoPor: 'lmamani',
      appVersion: '6.3.3+15',
    );

/// Tabla de RIM en memoria, para pruebas de pantalla sin SQLite. Empieza con
/// un talonario de la gestión en curso (números [desde] a [hasta]), salvo
/// que [conTalonario] sea false.
class MemoryRimStore extends RimStore {
  final List<RimRegistro> registros = [];
  final List<RimTalonario> talonariosEnMemoria = [];

  MemoryRimStore({bool conTalonario = true, int desde = 41, int hasta = 50}) {
    if (conTalonario) {
      talonariosEnMemoria.add(RimTalonario(
        id: 1,
        instalacion: instalacionDePrueba,
        gestion: DateTime.now().year,
        desde: desde,
        hasta: hasta,
        recibidoEn: DateTime(2026, 10, 1),
      ));
    }
  }

  @override
  Future<String> instalacion([DatabaseExecutor? executor]) async =>
      instalacionDePrueba;

  @override
  Future<RimNumero?> proximoNumero({
    required int gestion,
    DatabaseExecutor? executor,
  }) async {
    RimNumero? siguiente;
    var restantes = 0;
    for (final talonario
        in talonariosEnMemoria.where((item) => item.gestion == gestion)) {
      final usados = [
        for (final registro in registros)
          if (registro.documento.numeracion case final numeracion?)
            if (numeracion.gestion == gestion &&
                talonario.contiene(numeracion.numero))
              numeracion.numero,
      ];
      final primero = usados.isEmpty
          ? talonario.desde
          : usados.reduce((a, b) => a > b ? a : b) + 1;
      if (primero > talonario.hasta) continue;
      restantes += talonario.hasta - primero + 1;
      siguiente ??= RimNumero(
        talonarioId: talonario.id,
        instalacion: instalacionDePrueba,
        gestion: gestion,
        numero: primero,
        restantes: 0,
      );
    }
    final elegido = siguiente;
    if (elegido == null) return null;
    return RimNumero(
      talonarioId: elegido.talonarioId,
      instalacion: elegido.instalacion,
      gestion: elegido.gestion,
      numero: elegido.numero,
      restantes: restantes,
    );
  }

  @override
  Future<String> solicitudTalonario(int gestion) async =>
      'c4a1e2f3-6b7d-4e8f-a9b0-1c2d3e4f5a6b';

  @override
  Future<void> guardarTalonario(
    RimTalonario talonario, {
    required String solicitud,
  }) async {
    if (talonariosEnMemoria.every((item) => item.id != talonario.id)) {
      talonariosEnMemoria.add(talonario);
    }
  }

  @override
  Future<List<({RimTalonario talonario, int? ultimoUsado})>>
      talonariosPorCerrar(int gestion) async => const [];

  @override
  Future<RimRegistro> insert(
    RimDocumento documento,
    Uint8List firmaCliente,
    Uint8List firmaRepresentante,
  ) async {
    if (registros.any((registro) => registro.uuid == documento.uuid)) {
      throw StateError('UNIQUE constraint failed: form_rim.uuid');
    }
    final numeracion = documento.numeracion;
    final siguiente = numeracion == null
        ? null
        : await proximoNumero(gestion: numeracion.gestion);
    if (siguiente == null || siguiente.numero != numeracion!.numero) {
      throw RimNumeroNoDisponible('Número no disponible: ${documento.codigo}');
    }
    final registro = RimRegistro(
      id: registros.length + 1,
      documento: documento,
      firmaCliente: firmaCliente,
      firmaRepresentante: firmaRepresentante,
      estado: RimEstadoSubida.pending,
    );
    registros.add(registro);
    return registro;
  }

  @override
  Future<RimRegistro?> byUuid(String uuid) async {
    for (final registro in registros) {
      if (registro.uuid == uuid) return registro;
    }
    return null;
  }

  @override
  Future<List<RimRegistro>> list({int historyLimit = 50}) async =>
      List.of(registros);

  @override
  Future<int> countUnsent() async =>
      registros.where((registro) => registro.canUpload).length;

  @override
  Future<bool> existsForService({
    required String? sessionId,
    required String? codMetrica,
  }) async =>
      registros.any((registro) =>
          !registro.anulado &&
          registro.documento.service.sessionId == sessionId &&
          (codMetrica == null ||
              registro.documento.service.metricCode == codMetrica));
}

/// Da a [store] (SQLite) un talonario de la [gestion] para su instalación.
Future<void> darTalonario(
  RimStore store, {
  int id = 1,
  int gestion = 2026,
  int desde = 41,
  int hasta = 50,
}) async {
  final instalacion = await store.instalacion();
  await store.guardarTalonario(
    RimTalonario(
      id: id,
      instalacion: instalacion,
      gestion: gestion,
      desde: desde,
      hasta: hasta,
      recibidoEn: DateTime(2026, 10, 1),
    ),
    solicitud: await store.solicitudTalonario(gestion),
  );
}

/// RIM de prueba con el siguiente número de [store] en la [gestion].
Future<RimDocumento> rimSiguiente(
  RimStore store, {
  String uuid = '3f2a8c1e-7b4d-4e9a-a1c2-5d6e7f8091ab',
  DateTime? emitidoEn,
  int gestion = 2026,
}) async {
  final numero = (await store.proximoNumero(gestion: gestion))!;
  return rimDePrueba(
    uuid: uuid,
    emitidoEn: emitidoEn,
    codigo: numero.codigo,
    instalacion: numero.instalacion,
  );
}
