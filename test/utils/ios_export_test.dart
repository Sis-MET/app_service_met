import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:service_met/utils/foto_helper.dart';
import 'package:service_met/utils/saf_storage.dart';
import 'package:service_met/utils/service_exporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DocumentsPath extends PathProviderPlatform {
  _DocumentsPath(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bo.metrica.smet/saf');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late Directory exports;
  late PathProviderPlatform originalPaths;
  late bool available;
  late bool cancelPicker;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('servicemet_ios_');
    exports = await Directory(p.join(directory.path, 'Archivos')).create();
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsPath(directory.path);
    available = true;
    cancelPicker = false;
    await FotoHelper.reset();
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map?;
      switch (call.method) {
        case 'pickDirectory':
          return cancelPicker
              ? null
              : {'uri': 'ios-bookmark', 'name': 'Archivos'};
        case 'isTreeAvailable':
          return available;
        case 'releaseDirectory':
          return null;
        case 'writeDocument':
        case 'copyDocument':
          if (!available) throw PlatformException(code: 'tree_unavailable');
          final file = File(p.joinAll([
            exports.path,
            ...(args!['segments'] as List).cast<String>(),
            args['fileName'] as String,
          ]));
          await file.parent.create(recursive: true);
          if (call.method == 'writeDocument') {
            await file.writeAsBytes(args['bytes'] as Uint8List);
          } else {
            await File(args['sourcePath'] as String).copy(file.path);
          }
          return file.uri.toString();
        case 'openDocument':
          return File.fromUri(Uri.parse(args!['uri'] as String)).exists();
        default:
          throw MissingPluginException(call.method);
      }
    });
  });

  tearDown(() async {
    await FotoHelper.reset();
    messenger.setMockMethodCallHandler(channel, null);
    PathProviderPlatform.instance = originalPaths;
    debugDefaultTargetPlatformOverride = null;
    await directory.delete(recursive: true);
  });

  test('iOS recuerda la carpeta elegida y cancelar conserva la anterior',
      () async {
    expect(SafStorage.isSupported, isTrue);
    expect(await SafStorage.isConfigured(), isFalse);
    await SafStorage.chooseTree();
    expect(await SafStorage.isConfigured(), isTrue);
    cancelPicker = true;
    expect(await SafStorage.chooseTree(), isNull);
    expect((await SafStorage.savedTree())!.uri, 'ios-bookmark');
    await SafStorage.forget();
    expect(await SafStorage.savedTree(), isNull);
  });

  test('exporta documento y fotos por servicio sin modificar los originales',
      () async {
    await SafStorage.chooseTree();
    final service = await FotoHelper.getServicioDir('26-0041');
    final photo =
        File(p.join(service.path, 'calibracion_fotos', 'B01', '001.jpg'));
    await photo.parent.create(recursive: true);
    await photo.writeAsBytes([1, 2, 3]);

    final result = await ServiceExporter.exportServicio(
      codigoServicio: '26-0041',
      fileName: 'resumen.pdf',
      mimeType: ServiceExporter.pdfMime,
      bytes: Uint8List.fromList([37, 80, 68, 70]),
    );

    final folder = p.join(exports.path, 'ServiceMET', '26-0041');
    expect(result.saved, isTrue);
    expect(result.photoCount, 1);
    expect(await File(p.join(folder, 'resumen.pdf')).readAsBytes(),
        [37, 80, 68, 70]);
    expect(
        await File(p.join(folder, 'calibracion_fotos', 'B01', '001.jpg'))
            .readAsBytes(),
        [1, 2, 3]);
    expect(await photo.readAsBytes(), [1, 2, 3]);
    expect(await SafStorage.openDocument(result.uri!), isTrue);
  });

  test('un bookmark revocado informa que se debe elegir otra carpeta',
      () async {
    await SafStorage.chooseTree();
    available = false;
    expect(await SafStorage.isConfigured(), isFalse);
    await expectLater(
      SafStorage.writeBytes(
        segments: ['26-0041'],
        fileName: 'resumen.pdf',
        mimeType: ServiceExporter.pdfMime,
        bytes: Uint8List(0),
      ),
      throwsA(isA<SafUnavailableError>()),
    );
  });

  test('los segmentos especiales no pueden salir de la carpeta del servicio',
      () {
    for (final segment in ['', '.', '..']) {
      expect(SafStorage.sanitizeSegment(segment), 'sin_codigo');
    }
    expect(SafStorage.sanitizeSegment('../servicio'), '.._servicio');
    expect(SafStorage.sanitizeSegment('26-0041'), '26-0041');
  });
}
