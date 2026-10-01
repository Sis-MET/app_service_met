import 'dart:convert';
import 'dart:typed_data';

import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/rim/data/rim_catalogo.dart';
import 'package:service_met/screens/rim/models/rim_documento.dart';
import 'package:service_met/screens/rim/services/rim_store.dart';

/// PNG de 1×1 píxel, como firma de prueba.
final Uint8List firmaDePrueba = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
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

RimDocumento rimDePrueba({
  String uuid = '3f2a8c1e-7b4d-4e9a-a1c2-5d6e7f8091ab',
  OpportunityServiceContext? service,
  DateTime? emitidoEn,
}) =>
    RimDocumento(
      uuid: uuid,
      codigo: 'RIM-0090-11-26',
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

/// Tabla de RIM en memoria, para pruebas de pantalla sin SQLite.
class MemoryRimStore extends RimStore {
  final List<RimRegistro> registros = [];

  @override
  Future<RimRegistro> insert(
    RimDocumento documento,
    Uint8List firmaCliente,
  ) async {
    if (registros.any((registro) => registro.uuid == documento.uuid)) {
      throw StateError('UNIQUE constraint failed: form_rim.uuid');
    }
    final registro = RimRegistro(
      id: registros.length + 1,
      documento: documento,
      firmaCliente: firmaCliente,
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
