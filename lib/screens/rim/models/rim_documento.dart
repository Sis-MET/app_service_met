import 'dart:convert';
import 'dart:typed_data';

import '../../oportunidades/models/opportunity_service_context.dart';
import '../data/rim_catalogo.dart';

/// Código visible del RIM, con el mismo formato que el formulario web:
/// `RIM-{CÓDIGO DE PLANTA}-{GESTIÓN}` ("RIM-0103-11-26"). El código de planta
/// ya incluye al cliente; sin planta se usa el del cliente.
///
/// No es único: dos RIM de la misma planta en el año comparten código. Cada
/// RIM se identifica por su UUID y por el código métrica del instrumento.
String rimCodigo({String? plantCode, String? clientCode, required int year}) {
  final gestion = (year % 100).toString().padLeft(2, '0');
  final planta = plantCode?.trim() ?? '';
  if (planta.isNotEmpty) return 'RIM-$planta-$gestion';
  final cliente = clientCode?.trim() ?? '';
  return 'RIM-${cliente.isEmpty ? 'XXXX' : cliente}-XX-$gestion';
}

/// Componente que el técnico agrega al inventario ("Cable RS232").
class RimComponenteExtra {
  final String nombre;
  final RimEstadoComponente estado;

  const RimComponenteExtra(this.nombre, this.estado);

  Map<String, dynamic> toJson() => {'name': nombre, 'status': estado.name};
}

/// Contenido de un RIM tal como se emitió. Es inmutable: lo que firmó el
/// cliente no se edita; un RIM equivocado se anula y se emite otro.
class RimDocumento {
  final String uuid;
  final String codigo;

  /// Servicio, cliente, planta e instrumento al momento de emitir.
  final OpportunityServiceContext service;

  /// Por qué se recibe el instrumento o no pudo concluirse el servicio.
  final String motivo;

  /// Estado de cada componente de [RimCatalogo.componentes] que se registró.
  final Map<String, RimEstadoComponente> inventario;

  /// Cantidad recibida de los componentes que la llevan (celdas, patas).
  final Map<String, String> cantidades;
  final List<RimComponenteExtra> otrosComponentes;
  final String observacionesInventario;

  /// Clave de [RimCatalogo.estadosGenerales].
  final String estadoGeneral;

  /// Tipo de daño → ubicaciones donde se observó.
  final Map<String, List<String>> danos;
  final String descripcionDanos;

  /// Clave de [RimCatalogo.nivelesSuciedad].
  final String nivelSuciedad;
  final bool pruebasFuncionamiento;
  final String descripcionPruebas;

  /// Persona del cliente que entrega el instrumento y firma.
  final String contactoNombre;
  final String contactoCargo;
  final String contactoTelefono;

  /// Técnico con sesión iniciada que recibe el instrumento.
  final String representanteMetrica;
  final String lugarRecepcion;
  final String tecnicoAsignado;

  /// Momento en que se emitió, con la hora del teléfono.
  final DateTime emitidoEn;

  /// Usuario de ServiceMET que lo emitió (`logged_user`).
  final String? creadoPor;
  final String? appVersion;

  const RimDocumento({
    required this.uuid,
    required this.codigo,
    required this.service,
    required this.motivo,
    required this.estadoGeneral,
    required this.nivelSuciedad,
    required this.pruebasFuncionamiento,
    required this.contactoNombre,
    required this.representanteMetrica,
    required this.lugarRecepcion,
    required this.emitidoEn,
    this.inventario = const {},
    this.cantidades = const {},
    this.otrosComponentes = const [],
    this.observacionesInventario = '',
    this.danos = const {},
    this.descripcionDanos = '',
    this.descripcionPruebas = '',
    this.contactoCargo = '',
    this.contactoTelefono = '',
    this.tecnicoAsignado = '',
    this.creadoPor,
    this.appVersion,
  });

  /// Lo que se guarda en `payload` y lo que recibe `POST /api/extras/rim`
  /// (junto con la firma).
  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'code': codigo,
        'service': service.toJson(),
        'reason': motivo,
        'inventory': {
          for (final entry in inventario.entries) entry.key: entry.value.name,
        },
        'quantities': cantidades,
        'otherItems': [for (final item in otrosComponentes) item.toJson()],
        'inventoryNotes': observacionesInventario,
        'damageLevel': estadoGeneral,
        'damageTypes': danos,
        'damageDescription': descripcionDanos,
        'cleanlinessLevel': nivelSuciedad,
        'functionalityTestPerformed': pruebasFuncionamiento,
        'functionalityTestDescription': descripcionPruebas,
        'contactName': contactoNombre,
        'contactPosition': contactoCargo,
        'contactPhone': contactoTelefono,
        'metricaRepresentative': representanteMetrica,
        'receptionLocation': lugarRecepcion,
        'assignedTechnician': tecnicoAsignado,
        'issuedAt': emitidoEn.toUtc().toIso8601String(),
        'createdBy': creadoPor,
        'appVersion': appVersion,
      };

  factory RimDocumento.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString() ?? '';
    Map<String, dynamic> map(String key) => json[key] is Map
        ? Map<String, dynamic>.from(json[key] as Map)
        : const <String, dynamic>{};

    final inventario = <String, RimEstadoComponente>{};
    map('inventory').forEach((key, value) {
      final estado = RimEstadoComponente.fromName(value?.toString());
      if (estado != null) inventario[key] = estado;
    });

    final otros = <RimComponenteExtra>[];
    for (final item in json['otherItems'] as List? ?? const []) {
      if (item is! Map) continue;
      final estado = RimEstadoComponente.fromName(item['status']?.toString());
      final nombre = item['name']?.toString().trim() ?? '';
      if (estado != null && nombre.isNotEmpty) {
        otros.add(RimComponenteExtra(nombre, estado));
      }
    }

    return RimDocumento(
      uuid: text('uuid'),
      codigo: text('code'),
      service: OpportunityServiceContext.fromJson(map('service')),
      motivo: text('reason'),
      inventario: inventario,
      cantidades: map('quantities')
          .map((key, value) => MapEntry(key, value?.toString() ?? '')),
      otrosComponentes: otros,
      observacionesInventario: text('inventoryNotes'),
      estadoGeneral: text('damageLevel'),
      danos: map('damageTypes').map((key, value) => MapEntry(
            key,
            [for (final place in value as List? ?? const []) place.toString()],
          )),
      descripcionDanos: text('damageDescription'),
      nivelSuciedad: text('cleanlinessLevel'),
      pruebasFuncionamiento: json['functionalityTestPerformed'] == true,
      descripcionPruebas: text('functionalityTestDescription'),
      contactoNombre: text('contactName'),
      contactoCargo: text('contactPosition'),
      contactoTelefono: text('contactPhone'),
      representanteMetrica: text('metricaRepresentative'),
      lugarRecepcion: text('receptionLocation'),
      tecnicoAsignado: text('assignedTechnician'),
      emitidoEn: DateTime.tryParse(text('issuedAt'))?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      creadoPor: json['createdBy']?.toString(),
      appVersion: json['appVersion']?.toString(),
    );
  }
}

/// Estado local de la subida del RIM al servidor.
enum RimEstadoSubida {
  /// Emitido y guardado en el teléfono; todavía no se subió.
  pending,

  /// Se estaba subiendo. Si la app se cerró en ese momento no se sabe si
  /// llegó: volver a subirlo es seguro gracias al UUID.
  sending,

  /// Registrado en el servidor; [RimRegistro.serverN] es su correlativo.
  sent,

  /// El servidor lo rechazó; hay que revisar el motivo antes de reintentar.
  error;

  static RimEstadoSubida fromName(String? value) {
    for (final estado in values) {
      if (estado.name == value) return estado;
    }
    return pending;
  }
}

/// Fila de `form_rim`: el documento emitido, la firma del cliente y el estado
/// de la subida.
class RimRegistro {
  final int id;
  final RimDocumento documento;

  /// Firma del cliente, en PNG.
  final Uint8List firmaCliente;
  final RimEstadoSubida estado;
  final int retryCount;
  final String? lastError;
  final int? serverN;
  final DateTime? sentAt;
  final bool anulado;
  final String? anuladoPor;
  final DateTime? anuladoEn;
  final String? motivoAnulacion;

  const RimRegistro({
    required this.id,
    required this.documento,
    required this.firmaCliente,
    required this.estado,
    this.retryCount = 0,
    this.lastError,
    this.serverN,
    this.sentAt,
    this.anulado = false,
    this.anuladoPor,
    this.anuladoEn,
    this.motivoAnulacion,
  });

  String get uuid => documento.uuid;
  bool get isSent => estado == RimEstadoSubida.sent;

  /// Un RIM anulado queda en el teléfono como constancia y no se sube.
  bool get canUpload => !anulado && !isSent;

  /// Solo se anula lo que todavía no está en el servidor: la API no modifica
  /// registros ya subidos.
  bool get canAnular => !anulado && !isSent;

  /// Cuerpo de `POST /api/extras/rim`.
  Map<String, dynamic> toUploadJson() => {
        ...documento.toJson(),
        'clientSignature': base64Encode(firmaCliente),
      };
}
