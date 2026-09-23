import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/services/notifications/notification_plan.dart';
import 'package:service_met/services/notifications/notification_rules.dart';

void main() {
  // Miércoles 23/09/2026, 10:00.
  final now = DateTime(2026, 9, 23, 10);

  // Precarga al día: sin ella siempre aparecería el aviso de descarga.
  NotificationSnapshot snapshot({
    List<CertifiedItem> patrones = const [],
    List<BalanzaHistorial> balanzas = const [],
    List<PendingService> pendientes = const [],
    int subidasCalibracion = 0,
    int subidasSoporte = 0,
    bool precargaDescargada = true,
    DateTime? ultimaPrecarga,
    List<DateTime> calibraciones = const [],
  }) =>
      NotificationSnapshot(
        patrones: patrones,
        balanzas: balanzas,
        pendientes: pendientes,
        subidasCalibracion: subidasCalibracion,
        subidasSoporte: subidasSoporte,
        precargaDescargada: precargaDescargada,
        ultimaPrecarga: ultimaPrecarga ?? DateTime(2026, 9, 22),
        calibracionesHechas: calibraciones,
      );

  PlannedNotice? find(List<PlannedNotice> plan, int id) =>
      plan.where((n) => n.id == id).firstOrNull;

  CertifiedItem patron(String codigo, DateTime cert) => CertifiedItem(
        codigo: codigo,
        descripcion: 'Pesa',
        ultimaCalibracion: cert,
      );

  const calibracion = PendingService(
    esCalibracion: true,
    servicio: 'Calibración',
    codMetrica: '0123-01-005',
    cliente: 'Ingenio Sur',
    seca: '26-0101',
    sessionId: '0003',
  );

  test('sin nada pendiente solo queda el aviso futuro de la precarga', () {
    final plan = planNotifications(snapshot(), now);
    expect(plan.map((n) => n.id), [NoticeIds.precarga]);
    // Descargada el 22/09: se vuelve vieja el 29/09.
    expect(plan.single.at, DateTime(2026, 9, 29, 8));
  });

  group('patrones', () {
    test('un patrón vencido se recuerda la mañana siguiente', () {
      final plan = planNotifications(
        snapshot(patrones: [patron('P-1', DateTime(2025, 9, 1))]),
        now,
      );
      final notice = find(plan, NoticeIds.patrones)!;
      expect(notice.at, DateTime(2026, 9, 24, 8));
      expect(notice.title, 'Patrones con calibración vencida');
      expect(notice.channel, NoticeChannel.vencimientos);
      expect(notice.payload, NoticePayload.vencimientosPatrones);
      expect(notice.lines.single, 'P-1 · Pesa — vencido hace 23 días');
    });

    test('si solo hay por vencer basta el aviso del lunes', () {
      final plan = planNotifications(
        snapshot(patrones: [patron('P-1', DateTime(2025, 10, 10))]),
        now,
      );
      final notice = find(plan, NoticeIds.patrones)!;
      expect(notice.at, DateTime(2026, 9, 28, 8));
      expect(notice.title, 'Patrones por vencer');
      // El plazo se cuenta desde el lunes, cuando se lee la notificación.
      expect(notice.lines.single, endsWith('vence en 12 días'));
    });
  });

  test('balanzas de clientes se agrupan en el aviso del lunes', () {
    final plan = planNotifications(
      snapshot(balanzas: [
        BalanzaHistorial(
          codigo: '0123-01-005',
          ultimaCalibracion: DateTime(2025, 10, 5),
          cliente: 'Ingenio Sur',
          planta: 'Planta Norte',
        ),
      ]),
      now,
    );
    final notice = find(plan, NoticeIds.balanzas)!;
    expect(notice.at, DateTime(2026, 9, 28, 7, 45));
    expect(notice.body, startsWith('1 balanza en 1 cliente'));
    expect(
        notice.lines.single, 'Ingenio Sur · Planta Norte: 1 (vence en 7 días)');
    expect(notice.payload, NoticePayload.vencimientosBalanzas);
  });

  group('servicios pendientes', () {
    test('la calibración sin terminar abre esa misma sesión', () {
      final plan = planNotifications(
        snapshot(pendientes: [calibracion, calibracion]),
        now,
      );
      final notice = find(plan, NoticeIds.calibracionPendiente)!;
      expect(notice.at, DateTime(2026, 9, 23, 18));
      expect(notice.body, contains('0123-01-005 de Ingenio Sur'));
      expect(notice.body, contains('(+1 otra)'));
      expect(
        NoticePayload.parseCalibracionPendiente(notice.payload),
        ('26-0101', '0003'),
      );
      expect(find(plan, NoticeIds.soportePendiente), isNull);
    });

    test('el soporte pendiente usa el nombre del módulo', () {
      final plan = planNotifications(
        snapshot(pendientes: const [
          PendingService(
            esCalibracion: false,
            servicio: 'Diagnóstico',
            codMetrica: '0123-01-005',
            cliente: '',
            seca: 'OT-1',
            sessionId: 'SOP_1',
          ),
        ]),
        now,
      );
      final notice = find(plan, NoticeIds.soportePendiente)!;
      expect(notice.title, 'Diagnóstico sin terminar');
      expect(notice.payload, NoticePayload.soportePendiente);
    });

    test('los servicios sin subir se avisan al final de la jornada', () {
      final plan = planNotifications(
        snapshot(subidasCalibracion: 3, subidasSoporte: 1),
        now,
      );
      final notice = find(plan, NoticeIds.subidas)!;
      expect(notice.at, DateTime(2026, 9, 23, 17, 30));
      expect(
        notice.body,
        '3 calibraciones y 1 servicio de soporte terminados todavía no se '
        'subieron a DataMET.',
      );
    });
  });

  group('precarga', () {
    test('vieja: se avisa la próxima mañana con los días transcurridos', () {
      final plan = planNotifications(
        snapshot(ultimaPrecarga: DateTime(2026, 9, 10, 15)),
        now,
      );
      final notice = find(plan, NoticeIds.precarga)!;
      expect(notice.at, DateTime(2026, 9, 24, 8));
      expect(
          notice.body, startsWith('La última actualización fue hace 14 días'));
      expect(notice.channel, NoticeChannel.recordatorios);
    });

    test('se programa para el día en que se vuelve vieja', () {
      final plan = planNotifications(
        snapshot(ultimaPrecarga: DateTime(2026, 9, 20, 15)),
        now,
      );
      final notice = find(plan, NoticeIds.precarga)!;
      expect(notice.at, DateTime(2026, 9, 27, 8));
    });

    test('sin descargar pide la descarga', () {
      final plan = planNotifications(
        snapshot(precargaDescargada: false),
        now,
      );
      expect(find(plan, NoticeIds.precarga)!.title, 'Descarga la precarga');
    });
  });

  test('el resumen del lunes cuenta la semana previa y lo pendiente', () {
    final plan = planNotifications(
      snapshot(
        calibraciones: [
          DateTime(2026, 9, 22),
          DateTime(2026, 9, 25),
          // Fuera de la ventana de 7 días anterior al lunes.
          DateTime(2026, 9, 1),
        ],
        pendientes: [calibracion],
        subidasCalibracion: 2,
      ),
      now,
    );
    final notice = find(plan, NoticeIds.resumen)!;
    expect(notice.at, DateTime(2026, 9, 28, 7, 30));
    expect(notice.lines, [
      'Semana pasada: 2 calibraciones y 0 soportes.',
      '1 servicio sin terminar',
      '2 servicios sin subir',
    ]);
  });
}
