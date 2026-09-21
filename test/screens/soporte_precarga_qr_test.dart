import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:service_met/database/precarga_bd.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> borrarCatalogo() async {
    await DatabaseHelperPrecarga().close();
    await deleteDatabase(
        p.join(await getDatabasesPath(), 'precarga_database.db'));
  }

  setUp(() async {
    await borrarCatalogo();
    final db = await DatabaseHelperPrecarga().database;
    await db.insert('clientes', {
      'codigo_cliente': '0032',
      'cliente_id': '7',
      'cliente': 'Molinos Andinos',
      'razonsocial': 'Molinos Andinos S.A.',
    });
    await db.insert('clientes', {
      'codigo_cliente': '0099',
      'cliente_id': '9',
      'cliente': 'Otro cliente',
    });
    await db.insert('plantas', {
      'planta': 'Planta Norte',
      'codigo_planta': '0032-11',
      'cliente_id': '7',
    });
  });
  tearDown(borrarCatalogo);

  group('QR en la precarga de soporte', () {
    test('elige el cliente y la planta del equipo y espera la OTST', () async {
      final controller = PrecargaController()
        ..selectServicio('DIAGNÓSTICO')
        ..setStep(1);
      addTearDown(controller.dispose);

      // El QR a veces trae texto después del código.
      final error =
          await controller.processQrCode('0032-11-020 Balanza Mettler');

      expect(error, isNull);
      expect(controller.selectedCliente?['cliente'], 'Molinos Andinos');
      expect(controller.clienteId, '7');
      expect(controller.selectedPlanta?['planta'], 'Planta Norte');
      expect(controller.plantaCodigo, '0032-11');
      expect(controller.qrCodMetrica, '0032-11-020');
      expect(controller.currentStep, 3);
      expect(controller.canProceedFromStep(2), isTrue);
    });

    test('avisa si el cliente o la planta no están en el catálogo', () async {
      final controller = PrecargaController()..selectServicio('DIAGNÓSTICO');
      addTearDown(controller.dispose);

      expect(await controller.processQrCode('0500-11-020'),
          'No se encontró cliente con código: 0500');
      expect(await controller.processQrCode('0099-01-003'),
          'No se encontró planta con código: 0099-01');
      expect(controller.qrCodMetrica, isNull);
      expect(await controller.processQrCode('BALANZA'),
          'Formato de código QR inválido: BALANZA');
    });

    test('elegir otra planta a mano descarta el equipo del QR', () async {
      final controller = PrecargaController()..selectServicio('DIAGNÓSTICO');
      addTearDown(controller.dispose);
      await controller.processQrCode('0032-11-020');

      controller.selectPlanta({'planta': 'Otra', 'codigo_planta': '0032-12'});

      expect(controller.qrCodMetrica, isNull);
    });

    test('limpia el código que trae el QR', () {
      expect(PrecargaController.codMetricaFromQr('0032-11-020'), '0032-11-020');
      expect(PrecargaController.codMetricaFromQr(' 0032-11-020 Balanza X '),
          '0032-11-020');
      expect(PrecargaController.codMetricaFromQr('0032-11'), isNull);
      expect(PrecargaController.codMetricaFromQr('0032-11-X1'), isNull);
    });
  });
}
