import 'notification_rules.dart';

/// Servicio iniciado por el técnico que todavía no se finalizó.
class PendingService {
  final bool esCalibracion;

  /// "Calibración" o el nombre del módulo de soporte.
  final String servicio;
  final String codMetrica;
  final String cliente;
  final String seca;
  final String sessionId;

  const PendingService({
    required this.esCalibracion,
    required this.servicio,
    required this.codMetrica,
    required this.cliente,
    required this.seca,
    required this.sessionId,
  });
}

/// Lo que la app sabe en el momento de planificar. Solo cambia mientras se
/// usa la app, así que planificar con esto cada vez que la app pasa a segundo
/// plano deja las notificaciones futuras siempre al día.
class NotificationSnapshot {
  final List<CertifiedItem> patrones;
  final List<BalanzaHistorial> balanzas;
  final List<PendingService> pendientes;
  final int subidasCalibracion;
  final int subidasSoporte;
  final bool precargaDescargada;
  final DateTime? ultimaPrecarga;
  final List<DateTime> calibracionesHechas;
  final List<DateTime> soportesHechos;

  const NotificationSnapshot({
    this.patrones = const [],
    this.balanzas = const [],
    this.pendientes = const [],
    this.subidasCalibracion = 0,
    this.subidasSoporte = 0,
    this.precargaDescargada = false,
    this.ultimaPrecarga,
    this.calibracionesHechas = const [],
    this.soportesHechos = const [],
  });
}

enum NoticeChannel {
  vencimientos(
    'vencimientos',
    'Vencimientos',
    'Patrones y balanzas de clientes con calibración vencida o por vencer',
  ),
  serviciosPendientes(
    'servicios_pendientes',
    'Servicios pendientes',
    'Servicios sin terminar y servicios terminados sin subir a DataMET',
  ),
  recordatorios(
    'recordatorios',
    'Recordatorios',
    'Actualización de la precarga y resumen semanal',
  );

  const NoticeChannel(this.id, this.name, this.description);

  final String id;
  final String name;
  final String description;
}

/// IDs fijos: cada tipo reemplaza a su notificación anterior en vez de
/// acumularse.
abstract final class NoticeIds {
  static const patrones = 10;
  static const balanzas = 11;
  static const calibracionPendiente = 20;
  static const soportePendiente = 21;
  static const subidas = 22;
  static const precarga = 30;
  static const resumen = 31;

  static const all = [
    patrones,
    balanzas,
    calibracionPendiente,
    soportePendiente,
    subidas,
    precarga,
    resumen,
  ];
}

/// Destino al tocar la notificación.
abstract final class NoticePayload {
  static const vencimientosPatrones = 'vencimientos:patrones';
  static const vencimientosBalanzas = 'vencimientos:balanzas';
  static const soportePendiente = 'soporte_pendiente';
  static const subidas = 'subidas';
  static const precarga = 'precarga';
  static const resumen = 'resumen';

  static const _calibracionPrefix = 'calibracion_pendiente:';

  static String calibracionPendiente(String seca, String sessionId) =>
      '$_calibracionPrefix$seca|$sessionId';

  /// `(seca, sessionId)` si [payload] apunta a una calibración pendiente.
  static (String, String)? parseCalibracionPendiente(String payload) {
    if (!payload.startsWith(_calibracionPrefix)) return null;
    final parts = payload.substring(_calibracionPrefix.length).split('|');
    if (parts.length != 2 || parts.any((p) => p.isEmpty)) return null;
    return (parts[0], parts[1]);
  }
}

class PlannedNotice {
  final int id;
  final NoticeChannel channel;
  final DateTime at;
  final String title;
  final String body;

  /// Líneas del detalle desplegado; vacío usa el cuerpo completo.
  final List<String> lines;
  final String payload;

  const PlannedNotice({
    required this.id,
    required this.channel,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
    this.lines = const [],
  });
}

const _morning = [(8, 0)];
const _pendingSlots = [(8, 30), (18, 0)];
const _uploadSlots = [(17, 30)];
const _maxLines = 6;

/// Decide qué notificar y cuándo. Los textos se calculan para la fecha en que
/// se mostrará la notificación, no para [now].
List<PlannedNotice> planNotifications(NotificationSnapshot s, DateTime now) {
  return [
    _patrones(s, now),
    _balanzas(s, now),
    _calibracionPendiente(s, now),
    _soportePendiente(s, now),
    _subidas(s, now),
    _precarga(s, now),
    _resumen(s, now),
  ].whereType<PlannedNotice>().toList();
}

/// Patrones vencidos se recuerdan cada mañana: no deben usarse en servicios.
/// Si solo hay por vencer, basta el aviso del lunes.
PlannedNotice? _patrones(NotificationSnapshot s, DateTime now) {
  final hoy = evaluatePatrones(s.patrones, now);
  if (hoy.isEmpty) return null;
  final at = hoy.any((p) => p.vencido)
      ? nextSlot(now, _morning, lead: const Duration(minutes: 5))
      : nextWeekdayAt(now, DateTime.monday, 8, 0);

  final items = evaluatePatrones(s.patrones, at);
  if (items.isEmpty) return null;
  final vencidos = items.where((p) => p.vencido).length;
  final porVencer = items.length - vencidos;

  return PlannedNotice(
    id: NoticeIds.patrones,
    channel: NoticeChannel.vencimientos,
    at: at,
    title: vencidos > 0
        ? 'Patrones con calibración vencida'
        : 'Patrones por vencer',
    body: [
      if (vencidos > 0) plural(vencidos, 'vencido', 'vencidos'),
      if (porVencer > 0)
        '${plural(porVencer, 'vence', 'vencen')} en los próximos '
            '${expiryWarning.inDays} días',
    ].join(' · '),
    lines: _limit(
      items.map((p) => '${_label(p.codigo, p.descripcion)} — ${p.plazo}'),
      items.length,
    ),
    payload: NoticePayload.vencimientosPatrones,
  );
}

PlannedNotice? _balanzas(NotificationSnapshot s, DateTime now) {
  final at = nextWeekdayAt(now, DateTime.monday, 7, 45);
  final plantas = evaluateBalanzas(s.balanzas, at);
  if (plantas.isEmpty) return null;
  final total = plantas.fold(0, (sum, p) => sum + p.balanzas.length);
  final clientes = plantas.map((p) => p.cliente).toSet().length;

  return PlannedNotice(
    id: NoticeIds.balanzas,
    channel: NoticeChannel.vencimientos,
    at: at,
    title: 'Calibraciones por vencer en clientes',
    body: '${plural(total, 'balanza', 'balanzas')} en '
        '${plural(clientes, 'cliente', 'clientes')} para planificar la semana',
    lines: _limit(
      plantas.map((p) {
        final vencidas = p.vencidas > 0 ? ', ${p.vencidas} vencidas' : '';
        return '${_label(p.cliente, p.planta)}: '
            '${p.balanzas.length}$vencidas (${p.balanzas.first.plazo})';
      }),
      plantas.length,
    ),
    payload: NoticePayload.vencimientosBalanzas,
  );
}

PlannedNotice? _calibracionPendiente(NotificationSnapshot s, DateTime now) {
  final pendientes = s.pendientes.where((p) => p.esCalibracion).toList();
  if (pendientes.isEmpty) return null;
  final last = pendientes.first;
  final extra = pendientes.length - 1;
  return PlannedNotice(
    id: NoticeIds.calibracionPendiente,
    channel: NoticeChannel.serviciosPendientes,
    at: nextSlot(now, _pendingSlots, lead: const Duration(hours: 1)),
    title: 'Calibración sin terminar',
    body: '${_pendingLabel(last)} quedó a medias. Toca para continuar.'
        '${extra > 0 ? ' (+${plural(extra, 'otra', 'otras')})' : ''}',
    payload: NoticePayload.calibracionPendiente(last.seca, last.sessionId),
  );
}

PlannedNotice? _soportePendiente(NotificationSnapshot s, DateTime now) {
  final pendientes = s.pendientes.where((p) => !p.esCalibracion).toList();
  if (pendientes.isEmpty) return null;
  final last = pendientes.first;
  final extra = pendientes.length - 1;
  return PlannedNotice(
    id: NoticeIds.soportePendiente,
    channel: NoticeChannel.serviciosPendientes,
    at: nextSlot(now, _pendingSlots, lead: const Duration(hours: 1)),
    title: '${last.servicio} sin terminar',
    body: '${_pendingLabel(last)} quedó a medias. Toca para continuar.'
        '${extra > 0 ? ' (+${plural(extra, 'otro', 'otros')})' : ''}',
    payload: NoticePayload.soportePendiente,
  );
}

PlannedNotice? _subidas(NotificationSnapshot s, DateTime now) {
  final total = s.subidasCalibracion + s.subidasSoporte;
  if (total == 0) return null;
  final partes = [
    if (s.subidasCalibracion > 0)
      plural(s.subidasCalibracion, 'calibración', 'calibraciones'),
    if (s.subidasSoporte > 0)
      plural(s.subidasSoporte, 'servicio de soporte', 'servicios de soporte'),
  ];
  return PlannedNotice(
    id: NoticeIds.subidas,
    channel: NoticeChannel.serviciosPendientes,
    at: nextSlot(now, _uploadSlots, lead: const Duration(minutes: 30)),
    title: 'Servicios sin subir',
    body: '${partes.join(' y ')} ${total == 1 ? 'terminado' : 'terminados'} '
        'todavía no ${total == 1 ? 'se subió' : 'se subieron'} a DataMET.',
    payload: NoticePayload.subidas,
  );
}

PlannedNotice? _precarga(NotificationSnapshot s, DateTime now) {
  final ultima = s.ultimaPrecarga;
  if (!s.precargaDescargada || ultima == null) {
    return PlannedNotice(
      id: NoticeIds.precarga,
      channel: NoticeChannel.recordatorios,
      at: nextSlot(now, _morning, lead: const Duration(minutes: 5)),
      title: 'Descarga la precarga',
      body: 'Aún no hay datos de clientes y balanzas en este equipo.',
      payload: NoticePayload.precarga,
    );
  }

  final stale = ultima.add(precargaStaleAfter);
  final firstStaleMorning = DateTime(stale.year, stale.month, stale.day, 8);
  final nextMorning = nextSlot(now, _morning, lead: const Duration(minutes: 5));
  final at =
      firstStaleMorning.isAfter(nextMorning) ? firstStaleMorning : nextMorning;
  final dias = daysBetween(ultima, at);

  return PlannedNotice(
    id: NoticeIds.precarga,
    channel: NoticeChannel.recordatorios,
    at: at,
    title: 'Precarga desactualizada',
    body: 'La última actualización fue hace $dias días '
        '(${ultima.day}/${ultima.month.toString().padLeft(2, '0')}). '
        'Actualízala para '
        'trabajar con clientes, balanzas y patrones al día.',
    payload: NoticePayload.precarga,
  );
}

PlannedNotice? _resumen(NotificationSnapshot s, DateTime now) {
  final at = nextWeekdayAt(now, DateTime.monday, 7, 30);
  final start = at.subtract(const Duration(days: 7));
  final calibraciones = countInWindow(s.calibracionesHechas, start, at);
  final soportes = countInWindow(s.soportesHechos, start, at);
  final pendientes = s.pendientes.length;
  final sinSubir = s.subidasCalibracion + s.subidasSoporte;
  final porVencer = evaluateBalanzas(s.balanzas, at)
      .fold(0, (sum, p) => sum + p.balanzas.length);

  if (calibraciones + soportes + pendientes + sinSubir + porVencer == 0) {
    return null;
  }

  final hecho = calibraciones + soportes == 0
      ? 'Sin servicios registrados la semana pasada.'
      : 'Semana pasada: '
          '${plural(calibraciones, 'calibración', 'calibraciones')} y '
          '${plural(soportes, 'soporte', 'soportes')}.';
  final lines = [
    hecho,
    if (pendientes > 0)
      '${plural(pendientes, 'servicio', 'servicios')} '
          'sin terminar',
    if (sinSubir > 0) '${plural(sinSubir, 'servicio', 'servicios')} sin subir',
    if (porVencer > 0)
      '${plural(porVencer, 'balanza', 'balanzas')} de '
          'clientes por vencer',
  ];

  return PlannedNotice(
    id: NoticeIds.resumen,
    channel: NoticeChannel.recordatorios,
    at: at,
    title: 'Resumen semanal',
    body: lines.join(' · '),
    lines: lines,
    payload: NoticePayload.resumen,
  );
}

String _pendingLabel(PendingService p) {
  final balanza = p.codMetrica.isEmpty ? 'El servicio' : p.codMetrica;
  return p.cliente.isEmpty ? balanza : '$balanza de ${p.cliente}';
}

String _label(String main, String detail) =>
    detail.trim().isEmpty ? main : '$main · $detail';

List<String> _limit(Iterable<String> lines, int total) {
  final list = lines.take(_maxLines).toList();
  if (total > _maxLines) list.add('y ${total - _maxLines} más');
  return list;
}
