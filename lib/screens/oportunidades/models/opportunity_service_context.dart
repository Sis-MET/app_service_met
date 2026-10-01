import 'package:intl/intl.dart';
import 'package:service_met/models/service_session.dart';

enum OpportunityServiceType {
  calibracion('Calibración'),
  soporte('Soporte técnico'),

  /// Formulario llenado fuera de un servicio: el técnico elige el cliente,
  /// la planta y el instrumento desde Servicios.
  directo('Registro directo');

  final String label;
  const OpportunityServiceType(this.label);

  static OpportunityServiceType fromName(String? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return calibracion;
  }
}

/// Lo que ServiceMET ya sabe del servicio en curso, normalizado para que un
/// único formulario de oportunidad sirva a Calibración y a Soporte técnico.
///
/// Es una foto de solo lectura tomada al abrir el formulario: no hay una
/// segunda fuente de verdad ni se escribe nada en el servicio. Los campos que
/// el flujo todavía no conoce quedan en null.
class OpportunityServiceContext {
  final OpportunityServiceType serviceType;

  /// Nombre visible del servicio: "Calibración", "Instalación", etc.
  final String serviceName;
  final String? seca;
  final String? sessionId;
  final String? clientName;
  final String? clientLegalName;
  final String? plantName;
  final String? plantDepartment;

  /// Códigos de DataMET y dirección de la planta. Bitrix24 no los usa; los
  /// necesita la recepción de instrumentos (RIM).
  final String? clientCode;
  final String? plantCode;
  final String? plantAddress;
  final String? metricCode;
  final String? equipmentType;
  final String? brand;
  final String? model;
  final String? serial;

  /// Capacidades máximas de los rangos, sin unidad ("60000" o "30 / 60").
  final String? capacity;

  /// Divisiones de escala de los rangos, sin unidad.
  final String? division;
  final String? unit;
  final String? location;
  final String? technician;

  /// Fecha del servicio (AAAA-MM-DD) cuando el flujo la registra.
  final String? serviceDate;

  /// Momento en que el técnico abrió el formulario.
  final DateTime capturedAt;

  const OpportunityServiceContext({
    required this.serviceType,
    required this.serviceName,
    required this.capturedAt,
    this.seca,
    this.sessionId,
    this.clientName,
    this.clientLegalName,
    this.plantName,
    this.plantDepartment,
    this.clientCode,
    this.plantCode,
    this.plantAddress,
    this.metricCode,
    this.equipmentType,
    this.brand,
    this.model,
    this.serial,
    this.capacity,
    this.division,
    this.unit,
    this.location,
    this.technician,
    this.serviceDate,
  });

  /// Adapter de Calibración: lee la sesión del [ServiceSessionProvider].
  factory OpportunityServiceContext.fromCalibration(
    ServiceSession session, {
    DateTime? now,
  }) {
    final info = session.sessionInfo;
    final balanza = session.balanza;
    return OpportunityServiceContext(
      serviceType: OpportunityServiceType.calibracion,
      serviceName: OpportunityServiceType.calibracion.label,
      capturedAt: now ?? DateTime.now(),
      seca: _text(info.seca),
      sessionId: _text(info.sessionId),
      clientName: _text(session.cliente?.nombreComercial),
      clientLegalName: _text(session.cliente?.razonSocial),
      plantName: _text(session.planta?.nombre),
      plantDepartment: _text(session.planta?.departamento),
      clientCode: _text(session.cliente?.codigoCliente),
      plantCode: _text(session.planta?.codigo),
      plantAddress: _text(session.planta?.direccion),
      metricCode: _text(balanza?.codMetrica) ?? _text(info.codMetrica),
      equipmentType: _text(balanza?.tipo),
      brand: _text(balanza?.marca),
      model: _text(balanza?.modelo),
      serial: _text(balanza?.serie),
      capacity:
          _joinRanges([balanza?.capMax1, balanza?.capMax2, balanza?.capMax3]),
      division: _joinRanges([
        _measure(balanza?.d1),
        _measure(balanza?.d2),
        _measure(balanza?.d3),
      ]),
      unit: _text(balanza?.unidad),
      location: _text(balanza?.ubicacion),
      technician: _text(info.userName),
      serviceDate: _text(info.fechaServicio),
    );
  }

  /// Adapter de Soporte técnico: recibe los mismos datos con los que la
  /// precarga abre cada módulo; [instrumentoData] es el mapa de
  /// `DatabaseHelperPrecarga.getBalanzasPorPrefix` (balanzas.* + inf.*).
  factory OpportunityServiceContext.fromSupport({
    required String serviceName,
    required String otst,
    required String codMetrica,
    required String userName,
    String? sessionId,
    String? clienteNombre,
    String? clienteRazonSocial,
    String? plantaNombre,
    String? plantaDepartamento,
    String? clienteId,
    String? plantaCodigo,
    String? plantaDireccion,
    Map<String, dynamic>? instrumentoData,
    DateTime? now,
  }) {
    final data = instrumentoData ?? const <String, dynamic>{};
    String? value(String key) => _text(data[key]?.toString());
    final capturedAt = now ?? DateTime.now();
    return OpportunityServiceContext(
      serviceType: OpportunityServiceType.soporte,
      serviceName: serviceName,
      capturedAt: capturedAt,
      // El técnico está en planta: el servicio es de hoy (fecha local, para
      // que el mes no dependa de la hora UTC).
      serviceDate: DateFormat('yyyy-MM-dd').format(capturedAt),
      seca: _text(otst),
      sessionId: _text(sessionId),
      clientName: _text(clienteNombre),
      clientLegalName: _text(clienteRazonSocial),
      plantName: _text(plantaNombre),
      plantDepartment: _text(plantaDepartamento),
      clientCode: _text(clienteId),
      plantCode: _text(plantaCodigo),
      plantAddress: _text(plantaDireccion),
      metricCode: value('cod_metrica') ?? _text(codMetrica),
      equipmentType: value('tipo_instrumento') ?? value('instrumento'),
      brand: value('marca'),
      model: value('modelo'),
      serial: value('inf_serie') ?? value('serie'),
      capacity: _joinRanges(
          [value('cap_max1'), value('cap_max2'), value('cap_max3')]),
      division: _joinRanges([
        _measure(double.tryParse(value('d1') ?? '')) ?? value('d1'),
        _measure(double.tryParse(value('d2') ?? '')) ?? value('d2'),
        _measure(double.tryParse(value('d3') ?? '')) ?? value('d3'),
      ]),
      unit: value('unidad'),
      location: value('ubicacion'),
      technician: _text(userName),
    );
  }

  /// Sin servicio en curso: el técnico eligió [cliente], [planta] e
  /// [instrumento] en la selección rápida. Son filas de la precarga
  /// (`clientes`, `plantas` y `getBalanzasPorPrefix`); la planta y el
  /// instrumento pueden faltar.
  factory OpportunityServiceContext.directo({
    required String userName,
    required Map<String, dynamic> cliente,
    Map<String, dynamic>? planta,
    Map<String, dynamic>? instrumento,
    DateTime? now,
  }) {
    String? de(Map<String, dynamic>? row, String key) => row?[key]?.toString();
    final base = OpportunityServiceContext.fromSupport(
      serviceName: OpportunityServiceType.directo.label,
      otst: '',
      codMetrica: de(instrumento, 'cod_metrica') ?? '',
      userName: userName,
      clienteNombre: de(cliente, 'cliente'),
      clienteRazonSocial: de(cliente, 'razonsocial'),
      plantaNombre: de(planta, 'planta'),
      plantaDepartamento: de(planta, 'dep'),
      clienteId: de(cliente, 'codigo_cliente'),
      plantaCodigo: de(planta, 'codigo_planta'),
      plantaDireccion: de(planta, 'dir'),
      instrumentoData: instrumento,
      now: now,
    );
    return OpportunityServiceContext.fromJson({
      ...base.toJson(),
      'serviceType': OpportunityServiceType.directo.name,
    });
  }

  factory OpportunityServiceContext.fromJson(Map<String, dynamic> json) {
    String? s(String key) => _text(json[key]?.toString());
    return OpportunityServiceContext(
      serviceType: OpportunityServiceType.fromName(s('serviceType')),
      serviceName: s('serviceName') ?? OpportunityServiceType.calibracion.label,
      capturedAt:
          DateTime.tryParse(s('capturedAt') ?? '')?.toLocal() ?? DateTime.now(),
      seca: s('seca'),
      sessionId: s('sessionId'),
      clientName: s('clientName'),
      clientLegalName: s('clientLegalName'),
      plantName: s('plantName'),
      plantDepartment: s('plantDepartment'),
      clientCode: s('clientCode'),
      plantCode: s('plantCode'),
      plantAddress: s('plantAddress'),
      metricCode: s('metricCode'),
      equipmentType: s('equipmentType'),
      brand: s('brand'),
      model: s('model'),
      serial: s('serial'),
      capacity: s('capacity'),
      division: s('division'),
      unit: s('unit'),
      location: s('location'),
      technician: s('technician'),
      serviceDate: s('serviceDate'),
    );
  }

  /// Mismas claves que valida `POST /api/bitrix/opportunities` (`service`),
  /// que ignora las que no conoce, y `POST /api/extras/rim`.
  Map<String, dynamic> toJson() => {
        'serviceType': serviceType.name,
        'serviceName': serviceName,
        'seca': seca,
        'sessionId': sessionId,
        'clientName': clientName,
        'clientLegalName': clientLegalName,
        'plantName': plantName,
        'plantDepartment': plantDepartment,
        'clientCode': clientCode,
        'plantCode': plantCode,
        'plantAddress': plantAddress,
        'metricCode': metricCode,
        'equipmentType': equipmentType,
        'brand': brand,
        'model': model,
        'serial': serial,
        'capacity': capacity,
        'division': division,
        'unit': unit,
        'location': location,
        'technician': technician,
        'serviceDate': serviceDate,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
      };

  /// "SECA" en calibración y "OTST" en soporte. Un registro directo no
  /// tiene ninguna de las dos ([seca] es null).
  String get secaLabel =>
      serviceType == OpportunityServiceType.soporte ? 'OTST' : 'SECA';

  /// Servicio de origen en una línea: "Calibración", "Soporte técnico ·
  /// Instalación" o "Registro directo".
  String get serviceLabel => serviceType == OpportunityServiceType.soporte
      ? '${serviceType.label} · $serviceName'
      : serviceName;

  /// Cliente tal como lo conoce ServiceMET (solo referencia para Bitrix).
  String? get clientDisplay => clientName ?? clientLegalName;

  String? get capacityWithUnit => _withUnit(capacity);
  String? get divisionWithUnit => _withUnit(division);

  String? _withUnit(String? value) {
    if (value == null) return null;
    return unit == null ? value : '$value $unit';
  }

  static String? _text(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// 20.0 → "20", 0.0050 → "0.005".
  static String? _measure(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return null;
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static String? _joinRanges(List<String?> values) {
    final present = <String>[];
    for (final value in values) {
      final text = _text(value);
      if (text != null && text != '0' && !present.contains(text)) {
        present.add(text);
      }
    }
    return present.isEmpty ? null : present.join(' / ');
  }
}
