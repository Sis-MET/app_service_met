import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_options_menu.dart';
import 'package:service_met/widgets/service_ui/service_steps_drawer.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:service_met/theme/app_icons.dart';

/// Servicio de soporte de tres pasos que controla su paso actual.
class _Servicio extends StatefulWidget {
  final int initialStep;
  final Future<bool> Function()? onExit;
  final VoidCallback? onFirstStepBack;
  final String? Function(int step)? stepIssue;

  const _Servicio({
    this.initialStep = 2,
    this.onExit,
    this.onFirstStepBack,
    this.stepIssue,
  });

  @override
  State<_Servicio> createState() => _ServicioState();
}

class _ServicioState extends State<_Servicio> {
  late int step = widget.initialStep;

  @override
  Widget build(BuildContext context) {
    return ServiceWorkspaceLayout(
      title: 'Instalación',
      steps: const [
        StepData(title: 'Uno', subtitle: 'Condiciones', icon: Icons.info),
        StepData(title: 'Dos', subtitle: 'Pruebas', icon: AppIcons.balanza),
        StepData(title: 'Tres', subtitle: 'Cierre', icon: AppIcons.listo),
      ],
      stepWidgets: [
        for (var i = 1; i <= 3; i++) Center(child: Text('paso $i'))
      ],
      currentStep: step,
      onStepTapped: (index) => setState(() => step = index),
      stepIssue: widget.stepIssue,
      onNext: () {},
      onBack: step > 0 ? () => setState(() => step--) : widget.onFirstStepBack,
      onExit: widget.onExit,
      canPop: false,
    );
  }
}

void main() {
  Future<void> abrir(WidgetTester tester, Widget servicio) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => servicio)),
          child: const Text('inicio'),
        ),
      ),
    ));
    await tester.tap(find.text('inicio'));
    await tester.pumpAndSettle();
  }

  testWidgets('en un servicio no hay flecha y Atrás retrocede sin salir',
      (tester) async {
    await abrir(tester, _Servicio(onExit: () async => true));
    expect(find.text('paso 3'), findsOneWidget);
    expect(find.byType(AppBackButton), findsNothing);
    expect(find.byTooltip(ServiceStepsButton.tooltip), findsOneWidget);
    expect(find.byType(StepIndicator), findsNothing,
        reason: 'los pasos están en el panel ≡');
    expect(find.text('Paso 3 de 3 · Tres'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('paso 2'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('paso 1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('paso 1'), findsOneWidget, reason: 'sigue en el servicio');
    expect(find.textContaining('Es el primer paso'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('el panel ≡ marca los pasos y lleva al elegido', (tester) async {
    final semantics = tester.ensureSemantics();
    await abrir(
      tester,
      _Servicio(
        onExit: () async => true,
        // Al paso 2 le falta algo y el 3 (el actual) está a medias.
        stepIssue: (step) => step == 0 ? null : 'Falta',
      ),
    );

    await tester.tap(find.byTooltip(ServiceStepsButton.tooltip));
    await tester.pumpAndSettle();
    expect(find.text('1 de 3 pasos completos'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 1 de 3: Uno, completo'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 2 de 3: Dos, falta completar'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Paso 3 de 3: Tres, pendiente, paso actual'),
        findsOneWidget);
    expect(find.text('Falta completar'), findsOneWidget);

    await tester.tap(find.text('Uno'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing, reason: 'el panel se cierra');
    expect(find.text('paso 1'), findsOneWidget);
    expect(find.text('Paso 1 de 3 · Uno'), findsOneWidget);

    // Volver atrás no cambia lo recorrido: al 2 le sigue faltando algo, y el
    // 3 no se abre mientras el 2 esté incompleto.
    await tester.tap(find.byTooltip(ServiceStepsButton.tooltip));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Paso 1 de 3: Uno, completo, paso actual'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Paso 2 de 3: Dos, falta completar'),
        findsOneWidget);
    expect(
        find.bySemanticsLabel('Paso 3 de 3: Tres, bloqueado'), findsOneWidget);
    await tester.tap(
        find.descendant(of: find.byType(Drawer), matching: find.text('Tres')));
    await tester.pumpAndSettle();
    expect(find.text('paso 1'), findsOneWidget, reason: 'no salta adelante');
    semantics.dispose();
  });

  testWidgets('los pasos llenos se ven completos aunque se reabra antes',
      (tester) async {
    // Reabierto en el paso 1 con los tres pasos ya llenos: antes el panel
    // mostraba pendientes los de adelante hasta volver a pasar por ellos.
    final semantics = tester.ensureSemantics();
    await abrir(
      tester,
      _Servicio(
        initialStep: 0,
        onExit: () async => true,
        stepIssue: (_) => null,
      ),
    );
    await tester.tap(find.byTooltip(ServiceStepsButton.tooltip));
    await tester.pumpAndSettle();
    expect(find.text('3 de 3 pasos completos'), findsOneWidget);
    expect(
        find.bySemanticsLabel('Paso 3 de 3: Tres, completo'), findsOneWidget);
    await tester.tap(
        find.descendant(of: find.byType(Drawer), matching: find.text('Tres')));
    await tester.pumpAndSettle();
    expect(find.text('paso 3'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('sin requisitos, cuenta como completo lo ya recorrido',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await abrir(tester, _Servicio(onExit: () async => true));
    await tester.tap(find.byTooltip(ServiceStepsButton.tooltip));
    await tester.pumpAndSettle();
    expect(find.text('2 de 3 pasos completos'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 3 de 3: Tres, pendiente, paso actual'),
        findsOneWidget);
    semantics.dispose();
  });

  testWidgets('con el panel ≡ abierto, Atrás solo lo cierra', (tester) async {
    await abrir(tester, _Servicio(onExit: () async => true));
    await tester.tap(find.byTooltip(ServiceStepsButton.tooltip));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('paso 3'), findsOneWidget, reason: 'no retrocede');
  });

  testWidgets('un título largo queda en una línea y no pisa ≡ ni las acciones',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360 * 3, 720 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        drawer: const Drawer(),
        appBar: ServiceAppBar(
          title: 'Mantenimiento Preventivo Avanzado de Balanzas Camioneras',
          subtitle: 'Paso 6 de 9 · Protección contra rayos y células de carga',
          centerTitle: true,
          leading: const ServiceStepsButton(),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(AppIcons.deshacer)),
            IconButton(
                onPressed: () {}, icon: const Icon(AppIcons.masVertical)),
          ],
        ),
      ),
    ));

    final menu = tester.getRect(find.byType(ServiceStepsButton));
    final firstAction = tester.getRect(find.byIcon(AppIcons.deshacer));
    for (final text in [
      find.textContaining('Mantenimiento'),
      find.textContaining('Paso 6 de 9'),
    ]) {
      final widget = tester.widget<Text>(text);
      expect(widget.maxLines, 1);
      expect(widget.overflow, TextOverflow.ellipsis);
      final rect = tester.getRect(text);
      expect(rect.left, greaterThanOrEqualTo(menu.right));
      expect(rect.right, lessThanOrEqualTo(firstAction.left));
    }
    expect(tester.getRect(find.textContaining('Mantenimiento')).height,
        lessThan(30),
        reason: 'un solo renglón');
  });

  testWidgets('con el texto al 140 % las dos líneas caben en el encabezado',
      (tester) async {
    // 140 % es el máximo de Ajustes › Apariencia; la app no usa la escala
    // del sistema.
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360 * 3, 720 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: Scaffold(
        drawer: const Drawer(),
        appBar: ServiceAppBar(
          title: 'Mantenimiento Preventivo Avanzado',
          subtitle: 'Paso 6 de 9 · Protección / Células',
          centerTitle: true,
          leading: const ServiceStepsButton(),
          actions: [
            const SaveStatusIndicator(status: SaveStatus.pending),
            IconButton(
                onPressed: () {}, icon: const Icon(AppIcons.masVertical)),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'sin desbordes');
    final bar = tester.getRect(find.byType(AppBar));
    for (final text in [
      find.textContaining('Mantenimiento'),
      find.textContaining('Paso 6 de 9'),
    ]) {
      final rect = tester.getRect(text);
      expect(rect.top, greaterThanOrEqualTo(bar.top));
      expect(rect.bottom, lessThanOrEqualTo(bar.bottom));
    }
  });

  testWidgets('un título corto queda centrado en la pantalla', (tester) async {
    // La fuente de las pruebas dibuja cada letra tan ancha como alta.
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(600 * 3, 720 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        drawer: const Drawer(),
        appBar: ServiceAppBar(
          title: 'Calibración',
          subtitle: 'Paso 3 de 11 · SECA',
          centerTitle: true,
          leading: const ServiceStepsButton(),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(AppIcons.deshacer)),
            IconButton(
                onPressed: () {}, icon: const Icon(AppIcons.masVertical)),
          ],
        ),
      ),
    ));
    expect(tester.getCenter(find.text('Calibración')).dx, closeTo(300, 1));
    expect(
        tester.getCenter(find.text('Paso 3 de 11 · SECA')).dx, closeTo(300, 1));
  });

  testWidgets('el menú ⋮ confirma, guarda y recién entonces sale',
      (tester) async {
    var guardados = 0;
    await abrir(tester, _Servicio(onExit: () async {
      guardados++;
      return true;
    }));

    await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceOptionsMenu.exitLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(guardados, 0);
    expect(find.text('paso 3'), findsOneWidget);

    await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceOptionsMenu.exitLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(guardados, 1);
    expect(find.text('inicio'), findsOneWidget);
  });

  testWidgets('en la precarga Atrás retrocede y en el primer paso pide salir',
      (tester) async {
    var pedidos = 0;
    await abrir(
        tester, _Servicio(initialStep: 1, onFirstStepBack: () => pedidos++));
    expect(find.byType(ServiceOptionsMenu), findsNothing);
    expect(find.byType(ServiceStepsButton), findsNothing);
    expect(find.byType(StepIndicator), findsOneWidget,
        reason: 'la precarga conserva su barra de pasos');
    expect(find.byType(AppBackButton), findsOneWidget,
        reason: 'sin menú ⋮, la flecha es su forma de salir');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('paso 1'), findsOneWidget);
    expect(pedidos, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pedidos, 1);
  });

  testWidgets('el último paso ofrece solo Atrás y permite volver',
      (tester) async {
    var back = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
      child: ServiceNavPill(
          label: 'Siguiente', showNext: false, onBack: () => back++),
    ))));
    expect(find.text('Siguiente'), findsNothing);
    expect(find.byIcon(AppIcons.siguiente), findsNothing);
    await tester.tap(find.byTooltip('Anterior'));
    expect(back, 1);
  });

  testWidgets('un paso incompleto conserva Siguiente deshabilitado',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(
      child: ServiceNavPill(label: 'Siguiente'),
    ))));
    expect(find.text('Siguiente'), findsOneWidget);
    final button = tester.widget<InkWell>(find
        .ancestor(of: find.text('Siguiente'), matching: find.byType(InkWell))
        .first);
    expect(button.onTap, isNull);
  });

  testWidgets('la píldora queda encima de la barra de navegación de 3 botones',
      (tester) async {
    // La app dibuja detrás de la barra (edge-to-edge); con tres botones la
    // barra mide 48 de alto.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ServiceWorkspaceLayout(
          title: 'Diagnóstico',
          steps: const [
            StepData(title: 'Datos', subtitle: 'Paso 1', icon: Icons.info),
            StepData(
                title: 'Pruebas', subtitle: 'Paso 2', icon: AppIcons.balanza),
          ],
          stepWidgets: const [SizedBox(), SizedBox()],
          currentStep: 0,
          onNext: () {},
        ),
      ),
    );

    final pildora = tester.getRect(find.byType(ServiceNavPill));
    expect(pildora.bottom, lessThanOrEqualTo(800 - 48 - 20));

    // Los pasos llegan hasta el borde, por detrás de la barra, como en el
    // inicio: si terminaran encima quedaría una franja lisa que el degradado
    // inferior oscurece hasta verse negra.
    expect(tester.getRect(find.byType(PageView)).bottom, 800);
    final context = tester.element(find.byType(PageView));
    expect(ServiceNavPill.pagePadding(context).bottom, 100 + 48);
  });
}
