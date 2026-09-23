import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/services/notifications/notification_rules.dart';

void main() {
  // Miércoles.
  final now = DateTime(2026, 9, 23, 10);

  CertifiedItem patron(String codigo, DateTime cert) => CertifiedItem(
        codigo: codigo,
        descripcion: 'Pesa $codigo',
        ultimaCalibracion: cert,
      );

  BalanzaHistorial balanza(
    String codigo,
    DateTime ultima, {
    String cliente = 'Cliente A',
    String planta = 'Planta 1',
  }) =>
      BalanzaHistorial(
        codigo: codigo,
        ultimaCalibracion: ultima,
        cliente: cliente,
        planta: planta,
      );

  group('parseServiceDate', () {
    test('acepta ISO, ISO con hora y formato día/mes/año', () {
      expect(parseServiceDate('2026-08-12'), DateTime(2026, 8, 12));
      expect(
        parseServiceDate('2026-08-12 10:30:00'),
        DateTime(2026, 8, 12, 10, 30),
      );
      expect(parseServiceDate('12/08/2026'), DateTime(2026, 8, 12));
      expect(parseServiceDate('12-08-2026'), DateTime(2026, 8, 12));
    });

    test('rechaza vacíos y fechas imposibles', () {
      expect(parseServiceDate(null), isNull);
      expect(parseServiceDate('  '), isNull);
      expect(parseServiceDate('31/02/2026'), isNull);
      expect(parseServiceDate('sin fecha'), isNull);
    });
  });

  group('evaluatePatrones', () {
    test('lista vencidos y por vencer, del más urgente al menos', () {
      final items = evaluatePatrones([
        patron('AL-DIA', DateTime(2026, 6, 1)),
        patron('POR-VENCER', DateTime(2025, 10, 3)),
        patron('VENCIDO', DateTime(2025, 9, 1)),
      ], now);

      expect(items.map((i) => i.codigo), ['VENCIDO', 'POR-VENCER']);
      expect(items[0].vencido, isTrue);
      expect(items[0].plazo, 'vencido hace 22 días');
      expect(items[1].diasRestantes, 10);
      expect(items[1].plazo, 'vence en 10 días');
    });

    test('textos de plazo en singular y para hoy', () {
      expect(DueItem(patron('A', now), 0).plazo, 'vence hoy');
      expect(DueItem(patron('A', now), 1).plazo, 'vence mañana');
      expect(DueItem(patron('A', now), -1).plazo, 'vencido hace 1 día');
    });
  });

  group('evaluateBalanzas', () {
    test('agrupa por cliente y planta y descarta las fuera de ventana', () {
      final plantas = evaluateBalanzas([
        balanza('A-1-001', DateTime(2025, 10, 1)),
        balanza('A-1-002', DateTime(2025, 9, 1)),
        balanza('B-1-001', DateTime(2025, 10, 20), cliente: 'Cliente B'),
        // Vencida hace más de 60 días: se ignora.
        balanza('A-1-003', DateTime(2025, 6, 1)),
        // Al día.
        balanza('A-1-004', DateTime(2026, 5, 1)),
      ], now);

      expect(plantas.map((p) => p.cliente), ['Cliente A', 'Cliente B']);
      expect(
        plantas.first.balanzas.map((b) => b.codigo),
        ['A-1-002', 'A-1-001'],
      );
      expect(plantas.first.vencidas, 1);
    });
  });

  test('latestServiceByCodMetrica se queda con la fecha más reciente', () {
    final latest = latestServiceByCodMetrica([
      {'cod_metrica': 'A-1-001', 'reg_fecha': '2024-01-10'},
      {'cod_metrica': 'A-1-001', 'reg_fecha': '10/03/2025'},
      {'cod_metrica': 'A-1-001', 'reg_fecha': ''},
      {'cod_metrica': '', 'reg_fecha': '2025-01-01'},
    ]);
    expect(latest, {'A-1-001': DateTime(2025, 3, 10)});
  });

  group('ubicación de la balanza', () {
    test('plantaPrefix compone cliente y planta como el repositorio', () {
      expect(plantaPrefix('01', '0123'), '0123-01');
      expect(plantaPrefix('0123-01', '0123'), '0123-01');
      expect(plantaPrefix('01', ''), '01');
    });

    test('elige el prefijo más largo que coincide', () {
      final plantas = {'0123': 'cliente', '0123-01': 'planta 01'};
      expect(plantaForCodMetrica('0123-01-005', plantas), 'planta 01');
      expect(plantaForCodMetrica('0123-02-005', plantas), 'cliente');
      expect(plantaForCodMetrica('9999-01-005', plantas), isNull);
    });
  });

  group('horarios', () {
    test('nextSlot respeta la anticipación mínima', () {
      final slots = [(8, 30), (18, 0)];
      expect(nextSlot(now, slots), DateTime(2026, 9, 23, 18));
      expect(
        nextSlot(DateTime(2026, 9, 23, 17, 30), slots,
            lead: const Duration(hours: 1)),
        DateTime(2026, 9, 24, 8, 30),
      );
    });

    test('nextWeekdayAt siempre cae en el futuro', () {
      expect(
        nextWeekdayAt(now, DateTime.monday, 7, 30),
        DateTime(2026, 9, 28, 7, 30),
      );
      final lunes = DateTime(2026, 9, 28, 7, 30);
      expect(
        nextWeekdayAt(lunes, DateTime.monday, 7, 30),
        DateTime(2026, 10, 5, 7, 30),
      );
    });

    test('countInWindow incluye el inicio y excluye el final', () {
      final start = DateTime(2026, 9, 21);
      final end = DateTime(2026, 9, 28);
      expect(
        countInWindow(
          [DateTime(2026, 9, 21), DateTime(2026, 9, 27), end],
          start,
          end,
        ),
        2,
      );
    });
  });
}
