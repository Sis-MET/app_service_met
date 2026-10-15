import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/home/models/servicio_model.dart';
import 'package:service_met/home/screens/fotos_registro_screen.dart';
import 'package:service_met/home/screens/servicio_detalles_screen.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/widgets/foto_viewer.dart';
import 'package:service_met/theme/app_icons.dart';

// PNG de 1x1: basta para que Image.file decodifique en la prueba.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late Directory dir;
  late String foto1;
  late List<String> fotos;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fotos_test');
    foto1 = '${dir.path}/001.jpg';
    fotos = [
      for (var i = 1; i <= 6; i++) '${dir.path}/00$i.jpg',
    ];
    for (final foto in fotos) {
      File(foto).writeAsBytesSync(_png);
    }
  });
  tearDown(() => dir.deleteSync(recursive: true));

  void telefono(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Deja correr la transición sin esperar a que cargue la foto grande.
  Future<void> esperarTransicion(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Detalle (solo lectura) de un registro con una foto que ya no está.
  Future<void> abrirDetalle(WidgetTester tester) async {
    final registro = {
      'cod_metrica': '0087-11-001',
      'marca': 'Marca',
      'linealidad_foto': jsonEncode([foto1, '${dir.path}/borrada.jpg']),
      'foto_balanza': foto1,
    };
    await tester.pumpWidget(MaterialApp(
      home: ServicioDetallesScreen(
        servicio: ServicioResumen(
          tipo: TipoServicio.calibracion,
          codigo: '0087-11-C01-26',
          cantidad: 1,
          items: [registro],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0087-11-001'));
    await tester.pumpAndSettle();
  }

  /// "Registros" de una SECA con una balanza con 6 fotos y otra sin fotos.
  Future<void> abrirRegistros(WidgetTester tester) async {
    telefono(tester);
    final conFotos = {
      'cod_metrica': '0087-11-001',
      'marca': 'OHAUS',
      'foto_balanza': fotos[0],
      'linealidad_foto': jsonEncode([fotos[1], fotos[2], fotos[3]]),
      'condiciones_finales_foto': jsonEncode([fotos[4], fotos[5]]),
    };
    final sinFotos = {'cod_metrica': '0087-11-002', 'marca': 'Mettler'};
    await tester.pumpWidget(MaterialApp(
      home: ServicioDetallesScreen(
        servicio: ServicioResumen(
          tipo: TipoServicio.calibracion,
          codigo: '0087-11-C01-26',
          cantidad: 2,
          items: [conFotos, sinFotos],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  test('reúne las fotos de calibración y de soporte por sección', () {
    final registro = {
      'cod_metrica': '0087-11-001',
      'foto_balanza': fotos[0],
      'marca': 'OHAUS',
      // Soporte técnico guarda varias rutas separadas por comas.
      'carcasa_foto': '${fotos[1]},${fotos[2]}',
      'conector_cables_foto': jsonEncode([fotos[3]]),
      'pantalla_foto': '',
    };
    final resultado = fotosDelRegistro(registro);
    expect(resultado.map((foto) => foto.grupo), [
      'Balanza',
      'Carcasa',
      'Carcasa',
      'Conector Cables',
    ]);
    expect(resultado.map((foto) => foto.path), fotos.take(4));
  });

  testWidgets('las fotos se ven en galería y no como texto', (tester) async {
    await abrirDetalle(tester);
    expect(find.byType(FotoGallerySection), findsOneWidget);
    expect(find.text('Fotografías (3)'), findsOneWidget);
    expect(find.text('Linealidad'), findsOneWidget);
    expect(find.text('Balanza'), findsWidgets);
    // Ninguna ruta aparece como dato.
    expect(find.textContaining('001.jpg'), findsNothing);
    // El detalle es de solo lectura: no hay campos para editar.
    expect(find.text('Solo lectura'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('el visor abre la foto con compartir y guardar', (tester) async {
    await abrirDetalle(tester);
    // La galería del detalle, no la tira de la tarjeta que queda detrás.
    await tester.tap(find
        .descendant(
            of: find.byType(FotoGallerySection),
            matching: find.bySemanticsLabel('Ver foto de Linealidad'))
        .first);
    await esperarTransicion(tester);
    expect(find.byType(FotoViewerScreen), findsOneWidget);
    expect(find.text('Linealidad · 1 de 3'), findsOneWidget);
    expect(find.byTooltip('Compartir'), findsOneWidget);
    expect(find.byTooltip('Guardar en el teléfono'), findsOneWidget);

    // La segunda no existe en el teléfono: se avisa en lugar de fallar.
    await tester.fling(
        find.byType(FotoViewerScreen), const Offset(-600, 0), 1000);
    await esperarTransicion(tester);
    expect(find.text('Linealidad · 2 de 3'), findsOneWidget);
    expect(find.text('Foto no disponible en este teléfono'), findsOneWidget);
    final guardar = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, AppIcons.descargar));
    expect(guardar.onPressed, isNull);
  });

  testWidgets(
      'la tira del visor salta a otra foto y tocar oculta los controles',
      (tester) async {
    telefono(tester);
    await tester.pumpWidget(MaterialApp(
      home: FotoViewerScreen(
        fotos: [
          FotoItem(path: fotos[0], grupo: 'Balanza'),
          FotoItem(path: fotos[1], grupo: 'Linealidad'),
          FotoItem(path: '${dir.path}/borrada.jpg', grupo: 'Carcasa'),
        ],
        initialIndex: 0,
        nombreBase: '0087-11-001',
      ),
    ));
    await esperarTransicion(tester);
    expect(find.text('Balanza · 1 de 3'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Ver foto de Carcasa'));
    await esperarTransicion(tester);
    expect(find.text('Carcasa · 3 de 3'), findsOneWidget);

    double opacidadDeLaBarra() => tester
        .widget<AnimatedOpacity>(find
            .ancestor(
                of: find.byType(AppBar), matching: find.byType(AnimatedOpacity))
            .first)
        .opacity;
    expect(opacidadDeLaBarra(), 1);
    await tester.tap(find.text('Foto no disponible en este teléfono'));
    await esperarTransicion(tester);
    expect(opacidadDeLaBarra(), 0);
    await tester.tap(find.text('Foto no disponible en este teléfono'));
    await esperarTransicion(tester);
    expect(opacidadDeLaBarra(), 1);
  });

  testWidgets('Registros muestra las fotos de cada balanza sin abrir el editor',
      (tester) async {
    await abrirRegistros(tester);

    // Solo la balanza con fotos lleva la tira: 3 miniaturas y "+3".
    expect(find.byType(FotoTiraMiniaturas), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.textContaining('6 fotos'), findsOneWidget);

    // Una miniatura abre esa foto en grande.
    await tester.tap(find.bySemanticsLabel('Ver foto de Balanza'));
    await esperarTransicion(tester);
    expect(find.text('Balanza · 1 de 6'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // "+3" abre todas, por sección.
    await tester.tap(find.text('+3'));
    await tester.pumpAndSettle();
    expect(find.byType(FotosRegistroScreen), findsOneWidget);
    expect(find.text('Fotografías'), findsOneWidget);
    expect(find.text('0087-11-001 · SECA 0087-11-C01-26'), findsOneWidget);
    expect(find.text('6 fotos'), findsOneWidget);
    expect(find.text('3 secciones'), findsOneWidget);
    expect(find.text('Linealidad'), findsOneWidget);
    expect(find.text('Condiciones finales'), findsOneWidget);
    expect(find.text('3 fotos'), findsOneWidget);

    await tester
        .tap(find.bySemanticsLabel('Ver foto de Condiciones finales').first);
    await esperarTransicion(tester);
    expect(find.text('Condiciones finales · 5 de 6'), findsOneWidget);
  });

  testWidgets('el menú del registro ofrece "Ver fotos"', (tester) async {
    await abrirRegistros(tester);

    await tester.longPress(find.text('0087-11-001'));
    await tester.pumpAndSettle();
    expect(find.text('Ver fotos'), findsOneWidget);
    expect(find.text('6 fotografías de este registro'), findsOneWidget);
    await tester.tap(find.text('Ver fotos'));
    await tester.pumpAndSettle();
    expect(find.byType(FotosRegistroScreen), findsOneWidget);

    // La balanza sin fotos no lo ofrece.
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('0087-11-002'));
    await tester.pumpAndSettle();
    expect(find.text('Ver fotos'), findsNothing);
    // Los registros técnicos no se editan desde la app.
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Exportar CSV'), findsOneWidget);
  });

  testWidgets('el detalle muestra las fotos y no sus rutas', (tester) async {
    await abrirRegistros(tester);

    await tester.tap(find.text('0087-11-001'));
    await tester.pumpAndSettle();
    expect(find.byType(FotoGallerySection), findsOneWidget);
    expect(find.text('Fotografías (6)'), findsOneWidget);
    // Debajo de las fotos siguen los datos, sin las rutas de las fotos.
    await tester.scrollUntilVisible(
      find.text('OHAUS'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('OHAUS'), findsOneWidget);
    expect(find.textContaining('.jpg'), findsNothing);
  });

  testWidgets('el álbum avisa las fotos que ya no están en el teléfono',
      (tester) async {
    telefono(tester);
    await tester.pumpWidget(MaterialApp(
      home: FotosRegistroScreen(
        fotos: [
          FotoItem(path: fotos[0], grupo: 'Balanza'),
          FotoItem(path: '${dir.path}/borrada.jpg', grupo: 'Balanza'),
        ],
        titulo: '0087-11-001',
        servicio: 'OTST 26-0087-11-S01',
        nombreBase: '0087-11-001',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2 fotos'), findsWidgets);
    expect(find.text('1 sección'), findsOneWidget);
    expect(find.text('1 no está en el teléfono'), findsOneWidget);
    expect(find.byIcon(AppIcons.imagenNoDisponible), findsWidgets);
  });

  test('nombre de archivo limpio para compartir', () {
    expect(
      nombreArchivo('0087-11-001',
          const FotoItem(path: '/x/001.jpg', grupo: 'Condiciones finales')),
      '0087-11-001_condiciones_finales_001.jpg',
    );
  });
}
