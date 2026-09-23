import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/widgets/patron_weights_selector.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final catalog = List.generate(
      6,
      (i) => EquipoInfo(
          codInstrumento: 'MP-00${i + 1}',
          tipo: 'Juego de pesas ${i + 1}',
          cantidad: '1',
          certFecha: DateTime.now().toIso8601String()));

  Future<void> pumpSelector(
    WidgetTester tester, {
    List<EquipoInfo> selected = const [],
    ValueChanged<List<EquipoInfo>>? onChanged,
    ValueChanged<EquipoInfo>? onEdit,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green, brightness: brightness)),
      home: Scaffold(
          body: SingleChildScrollView(
              child: PatronWeightsSelector(
        catalog: catalog,
        selected: selected,
        onChanged: onChanged ?? (_) {},
        onEditQuantity: onEdit ?? (_) {},
      ))),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Seleccionar pesas patrón').evaluate().isNotEmpty
        ? find.text('Seleccionar pesas patrón')
        : find.text('Cambiar selección'));
    await tester.pumpAndSettle();
  }

  testWidgets('buscar, marcar y cancelar no modifica el servicio',
      (tester) async {
    var changes = 0;
    await pumpSelector(tester, onChanged: (_) => changes++);
    await open(tester);
    await tester.enterText(find.byType(TextField), 'MP-003');
    await tester.pumpAndSettle();
    expect(find.text('MP-001'), findsNothing);
    await tester.tap(find.text('MP-003').last);
    await tester.pumpAndSettle();
    expect(find.text('Confirmar selección (1)'), findsOneWidget);
    expect(changes, 0);
    await tester.tap(find.byTooltip('Cancelar selección'));
    await tester.pumpAndSettle();
    expect(changes, 0);
  });

  testWidgets('confirmar conserva cantidades y agrega el patrón buscado',
      (tester) async {
    List<EquipoInfo>? result;
    await pumpSelector(tester,
        selected: [catalog.first.copyWith(cantidad: '12')],
        onChanged: (value) => result = value);
    await open(tester);
    // Desmarcar y volver a marcar no debe restablecer la cantidad a uno.
    await tester.tap(find.text('MP-001').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP-001').last);
    await tester.enterText(find.byType(TextField), 'MP-006');
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP-006').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar selección (2)'));
    await tester.pumpAndSettle();
    expect(result!.map((e) => e.codInstrumento), ['MP-001', 'MP-006']);
    expect(result!.first.cantidad, '12');
  });

  testWidgets('el límite de cinco permite quitar antes de añadir otra',
      (tester) async {
    List<EquipoInfo>? result;
    await pumpSelector(tester,
        selected: catalog.take(5).toList(),
        onChanged: (value) => result = value);
    await tester.ensureVisible(find.text('Cambiar selección'));
    await open(tester);
    await tester.enterText(find.byType(TextField), 'MP-006');
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(find.text('Límite de 5 alcanzado. Quita una para elegir otra.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'MP-001');
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP-001').last);
    await tester.enterText(find.byType(TextField), 'MP-006');
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP-006').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar selección (5)'));
    await tester.pumpAndSettle();
    expect(result!.length, 5);
    expect(result!.map((e) => e.codInstrumento), isNot(contains('MP-001')));
    expect(result!.last.codInstrumento, 'MP-006');
  });

  testWidgets('cantidad y quitar actúan sobre el patrón correcto',
      (tester) async {
    EquipoInfo? editing;
    List<EquipoInfo>? result;
    await pumpSelector(tester,
        selected: [catalog.first],
        onChanged: (value) => result = value,
        onEdit: (value) => editing = value);
    await tester.tap(find.text('Cantidad utilizada'));
    expect(editing!.codInstrumento, 'MP-001');
    await tester.tap(find.byTooltip('Quitar MP-001'));
    expect(result, isEmpty);
  });

  for (final brightness in Brightness.values) {
    testWidgets('móvil estrecho, texto grande y teclado en $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSelector(tester,
          selected: [catalog.first], brightness: brightness);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cambiar selección'));
      await open(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Confirmar selección (1)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
