import 'dart:math';

import '../data/tipos_oportunidad.dart';
import '../services/bitrix_company_matcher.dart' show CompanySource;
import 'bitrix_crm.dart';
import 'opportunity_service_context.dart';

/// UUID v4 con `Random.secure()`. Identifica la oportunidad en el teléfono y
/// en Bitrix24 (`originId`), para que reenviarla nunca cree un segundo prospecto.
String newOpportunityUuid([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Oportunidad tal como la completa el técnico. Es exactamente lo que se
/// envía a la API METRICA y lo que se guarda en `payload`, para que un
/// reenvío mande lo mismo con el mismo [uuid].
class OpportunityDraft {
  final String uuid;
  final OpportunityServiceContext service;
  final int? companyId;
  final String? companyName;

  /// Cómo se asignó la empresa; null en las oportunidades anteriores a esta
  /// versión (todas elegidas a mano) o si todavía no tiene empresa.
  final CompanySource? companySource;
  final int? contactId;
  final String? contactName;
  final String typeKey;
  final String typeLabel;

  /// Línea comercial de Bitrix24 (VENTA, SOPORTE TECNICO, CALIBRACIÓN).
  final String? typeLine;

  /// Ciudad elegida por el técnico. Null = el servidor la deduce del
  /// departamento de la planta.
  final String? city;
  final String title;
  final String description;
  final OpportunityPriority? priority;
  final String notes;
  final DateTime createdAt;

  /// Usuario de ServiceMET que la registró (`logged_user`).
  final String? createdBy;
  final String? appVersion;

  const OpportunityDraft({
    required this.uuid,
    required this.service,
    required this.typeKey,
    required this.typeLabel,
    required this.title,
    required this.description,
    required this.createdAt,
    this.typeLine,
    this.city,
    this.companyId,
    this.companyName,
    this.companySource,
    this.contactId,
    this.contactName,
    this.priority,
    this.notes = '',
    this.createdBy,
    this.appVersion,
  });

  bool get hasCompany => companyId != null;

  /// La misma oportunidad con la empresa de Bitrix24 ya resuelta. El
  /// contacto se elige con la empresa a la vista, así que queda vacío.
  OpportunityDraft withCompany(BitrixCompany company, CompanySource source) =>
      OpportunityDraft(
        uuid: uuid,
        service: service,
        companyId: company.id,
        companyName: company.title,
        companySource: source,
        typeKey: typeKey,
        typeLabel: typeLabel,
        typeLine: typeLine,
        city: city,
        title: title,
        description: description,
        priority: priority,
        notes: notes,
        createdAt: createdAt,
        createdBy: createdBy,
        appVersion: appVersion,
      );

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'companyId': companyId,
        'companyName': companyName,
        'companySource': companySource?.name,
        'contactId': contactId,
        'contactName': contactName,
        'opportunityType': {
          'key': typeKey,
          'label': typeLabel,
          'line': typeLine,
        },
        'city': city,
        'title': title,
        'description': description,
        'priority': priority?.name,
        'notes': notes,
        'service': service.toJson(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'createdBy': createdBy,
        'appVersion': appVersion,
      };

  factory OpportunityDraft.fromJson(Map<String, dynamic> json) {
    final type = json['opportunityType'] is Map
        ? Map<String, dynamic>.from(json['opportunityType'] as Map)
        : const <String, dynamic>{};
    final service = json['service'] is Map
        ? Map<String, dynamic>.from(json['service'] as Map)
        : const <String, dynamic>{};
    return OpportunityDraft(
      uuid: json['uuid'].toString(),
      service: OpportunityServiceContext.fromJson(service),
      companyId: (json['companyId'] as num?)?.toInt(),
      companyName: json['companyName']?.toString(),
      companySource: CompanySource.fromName(json['companySource']?.toString()),
      contactId: (json['contactId'] as num?)?.toInt(),
      contactName: json['contactName']?.toString(),
      typeKey: type['key']?.toString() ?? OpportunityTypeCatalog.otro.key,
      typeLabel: type['label']?.toString() ?? OpportunityTypeCatalog.otro.label,
      typeLine: type['line']?.toString(),
      city: json['city']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priority: OpportunityPriority.fromName(json['priority']?.toString()),
      notes: json['notes']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      createdBy: json['createdBy']?.toString(),
      appVersion: json['appVersion']?.toString(),
    );
  }
}

/// Estado local del envío a Bitrix24.
enum OpportunityStatus {
  /// Guardada para enviarla después (sin conexión o por decisión del técnico).
  pending,

  /// Se estaba enviando. Si la app se cerró en ese momento no se sabe si
  /// llegó: reenviarla es seguro gracias al UUID.
  sending,

  /// Registrada en Bitrix24; [PendingOpportunity.bitrixLeadId] tiene el
  /// número del prospecto (Lead).
  sent,

  /// El servidor la rechazó; necesita corrección o revisión antes de reenviar.
  error;

  static OpportunityStatus fromName(String? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return pending;
  }
}

/// Fila de `pending_bitrix_opportunities`.
class PendingOpportunity {
  final int id;
  final OpportunityDraft draft;
  final OpportunityStatus status;
  final int retryCount;
  final String? lastError;
  final int? bitrixLeadId;
  final DateTime updatedAt;
  final DateTime? sentAt;

  const PendingOpportunity({
    required this.id,
    required this.draft,
    required this.status,
    required this.retryCount,
    required this.updatedAt,
    this.lastError,
    this.bitrixLeadId,
    this.sentAt,
  });

  String get uuid => draft.uuid;
  bool get isSent => status == OpportunityStatus.sent;

  /// Se reenvía tal cual. Sin empresa, o si el servidor la rechazó, primero
  /// se revisa en el formulario.
  bool get canSendDirectly =>
      (status == OpportunityStatus.pending ||
          status == OpportunityStatus.sending) &&
      draft.hasCompany;

  /// La sincronización automática la toma: está por enviar y el servidor no
  /// la rechazó. Sin empresa, primero se busca la que corresponde al cliente.
  bool get canSync =>
      status == OpportunityStatus.pending ||
      status == OpportunityStatus.sending;
}
