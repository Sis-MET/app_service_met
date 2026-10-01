import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_draft.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';

void main() {
  final now = DateTime(2026, 9, 29, 10, 32);

  test('calibración: toma cliente, planta, SECA y balanza de la sesión', () {
    final session = ServiceSession(
      sessionInfo: SessionInfo(
        seca: '1523-C01-26',
        sessionId: '0003',
        userName: 'Ing. Ana Quispe',
        fechaServicio: '2026-09-29',
      ),
      cliente: ClienteInfo(
        nombreComercial: 'Coca-Cola Embol S.A.',
        razonSocial: 'Embotelladoras Bolivianas Unidas S.A.',
      ),
      planta: PlantaInfo(nombre: 'Planta Viacha', departamento: 'La Paz'),
      balanza: BalanzaInfo(
        codMetrica: '0072-11-015',
        tipo: 'Báscula camionera',
        marca: 'Mettler Toledo',
        modelo: 'IND560',
        serie: 'ABC123',
        capMax1: '60000',
        d1: 20.0,
        unidad: 'kg',
        ubicacion: 'Portería',
      ),
      metadata: SessionMetadata(),
    );

    final context =
        OpportunityServiceContext.fromCalibration(session, now: now);

    expect(context.serviceType, OpportunityServiceType.calibracion);
    expect(context.serviceName, 'Calibración');
    expect(context.secaLabel, 'SECA');
    expect(context.seca, '1523-C01-26');
    expect(context.clientDisplay, 'Coca-Cola Embol S.A.');
    expect(context.plantName, 'Planta Viacha');
    expect(context.metricCode, '0072-11-015');
    expect(context.capacityWithUnit, '60000 kg');
    expect(context.divisionWithUnit, '20 kg');
    expect(context.technician, 'Ing. Ana Quispe');
    expect(context.serviceDate, '2026-09-29');
  });

  test('calibración en los primeros pasos: lo que no se conoce queda en null',
      () {
    final session = ServiceSession(
      sessionInfo: SessionInfo(seca: '  ', userName: 'Ing. Ana Quispe'),
      metadata: SessionMetadata(),
    );
    final context =
        OpportunityServiceContext.fromCalibration(session, now: now);
    expect(context.seca, isNull);
    expect(context.clientDisplay, isNull);
    expect(context.metricCode, isNull);
    expect(context.capacity, isNull);
    expect(context.division, isNull);
  });

  test('soporte: usa los datos con que la precarga abre el módulo', () {
    final context = OpportunityServiceContext.fromSupport(
      serviceName: 'Mantenimiento correctivo',
      otst: '26-0090-11-S02',
      codMetrica: '0090-11-014',
      userName: 'Tec. Luis Mamani',
      clienteNombre: 'EMBOL',
      plantaNombre: 'Viacha',
      instrumentoData: {
        'cod_metrica': '0090-11-014',
        'instrumento': 'Balanza de plataforma',
        'marca': 'OHAUS',
        'modelo': 'Defender',
        'inf_serie': 'S-77',
        'cap_max1': '150',
        'cap_max2': '300',
        'd1': '0.05',
        'd2': '0.1',
        'unidad': 'kg',
      },
      now: now,
    );
    expect(context.serviceType, OpportunityServiceType.soporte);
    expect(context.secaLabel, 'OTST');
    expect(context.seca, '26-0090-11-S02');
    expect(context.equipmentType, 'Balanza de plataforma');
    expect(context.serial, 'S-77');
    expect(context.capacityWithUnit, '150 / 300 kg');
    expect(context.divisionWithUnit, '0.05 / 0.1 kg');
    expect(context.serviceDate, '2026-09-29', reason: 'fecha local de hoy');
  });

  test('lleva los códigos de DataMET y la dirección de la planta para el RIM',
      () {
    final calibracion = OpportunityServiceContext.fromCalibration(
      ServiceSession(
        sessionInfo: SessionInfo(seca: '1523-C01-26', sessionId: '0003'),
        cliente: ClienteInfo(codigoCliente: '0072', nombreComercial: 'EMBOL'),
        planta: PlantaInfo(
          codigo: '0072-11',
          nombre: 'Planta Viacha',
          direccion: 'Carretera a Viacha km 14',
        ),
        metadata: SessionMetadata(),
      ),
      now: now,
    );
    expect(calibracion.clientCode, '0072');
    expect(calibracion.plantCode, '0072-11');
    expect(calibracion.plantAddress, 'Carretera a Viacha km 14');

    final soporte = OpportunityServiceContext.fromSupport(
      serviceName: 'Diagnóstico',
      otst: '26-0090-11-S02',
      codMetrica: '0090-11-014',
      userName: 'Tec. Luis Mamani',
      clienteId: '0090',
      plantaCodigo: '0090-11',
      plantaDireccion: ' ',
      now: now,
    );
    expect(soporte.clientCode, '0090');
    expect(soporte.plantCode, '0090-11');
    expect(soporte.plantAddress, isNull);

    final leido = OpportunityServiceContext.fromJson(calibracion.toJson());
    expect(leido.clientCode, '0072');
    expect(leido.plantCode, '0072-11');
    expect(leido.plantAddress, 'Carretera a Viacha km 14');
  });

  test('el borrador conserva todo al guardarse y leerse como JSON', () {
    final draft = OpportunityDraft(
      uuid: newOpportunityUuid(),
      service: OpportunityServiceContext.fromSupport(
        serviceName: 'Instalación',
        otst: 'OTST-1',
        codMetrica: 'MET-1',
        userName: 'Tec. Luis Mamani',
        now: now,
      ),
      companyId: 120,
      companyName: 'EMBOL S.A.',
      typeKey: 'repuestos',
      typeLabel: 'Repuestos',
      title: 'Oportunidad ServiceMET - Repuestos - EMBOL S.A.',
      description: 'Se requieren celdas de carga.',
      createdAt: now,
    );
    final copy = OpportunityDraft.fromJson(draft.toJson());
    expect(copy.uuid, draft.uuid);
    expect(copy.companyId, 120);
    expect(copy.service.serviceName, 'Instalación');
    expect(copy.service.capturedAt, now);
    expect(copy.createdAt, now);
    expect(copy.toJson()['service'], draft.toJson()['service']);
  });

  test('genera UUID v4 distintos y con el formato que valida el servidor', () {
    final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final uuids = List.generate(50, (_) => newOpportunityUuid());
    expect(uuids.every(pattern.hasMatch), isTrue);
    expect(uuids.toSet().length, 50);
  });
}
