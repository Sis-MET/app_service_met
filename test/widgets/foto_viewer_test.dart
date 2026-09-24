import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/home/models/servicio_model.dart';
import 'package:service_met/home/screens/registro_editor_screen.dart';
import 'package:service_met/widgets/foto_viewer.dart';

// PNG de 1x1: basta para que Image.file decodifique en la prueba.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late Directory dir;
  late String foto1;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fotos_test');
    foto1 = '${dir.path}/001.jpg';
    File(foto1).writeAsBytesSync(_png);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> abrirEditor(WidgetTester tester) async {
    final registro = {
      'cod_metrica': '0087-11-001',
      'marca': 'Marca',
      'linealidad_foto': jsonEncode([foto1, '${dir.path}/borrada.jpg']),
      'foto_balanza': foto1,
    };
    await tester.pumpWidget(MaterialApp(
      home: RegistroEditorScreen(
        servicio: ServicioResumen(
          tipo: TipoServicio.calibracion,
          codigo: '0087-11-C01-26',
          cantidad: 1,
          items: [registro],
        ),
        index: 0,
        item: registro,
      ),
    ));
    await tester.pump();
  }

  testWidgets('las fotos se ven en galería y no como texto editable',
      (tester) async {
    await abrirEditor(tester);
    expect(find.byType(FotoGallerySection), findsOneWidget);
    expect(find.text('Fotografías (3)'), findsOneWidget);
    expect(find.text('Linealidad'), findsOneWidget);
    expect(find.text('Balanza'), findsOneWidget);
    // Ninguna ruta aparece como campo de texto.
    expect(find.textContaining('001.jpg'), findsNothing);
    expect(find.text('Marca'), findsWidgets);
  });

  testWidgets('el visor abre la foto con compartir y guardar', (tester) async {
    await abrirEditor(tester);
    await tester.tap(find.bySemanticsLabel('Ver foto de Linealidad').first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(FotoViewerScreen), findsOneWidget);
    expect(find.text('Linealidad · 1 de 3'), findsOneWidget);
    expect(find.byTooltip('Compartir'), findsOneWidget);
    expect(find.byTooltip('Guardar en el teléfono'), findsOneWidget);

    // La segunda no existe en el teléfono: se avisa en lugar de fallar.
    await tester.fling(
        find.byType(FotoViewerScreen), const Offset(-600, 0), 1000);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Linealidad · 2 de 3'), findsOneWidget);
    expect(find.text('Foto no disponible en este teléfono'), findsOneWidget);
    final guardar = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.download_outlined));
    expect(guardar.onPressed, isNull);
  });

  test('nombre de archivo limpio para compartir', () {
    expect(
      nombreArchivo('0087-11-001',
          const FotoItem(path: '/x/001.jpg', grupo: 'Condiciones finales')),
      '0087-11-001_condiciones_finales_001.jpg',
    );
  });
}
