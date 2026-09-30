import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/widgets/service_ui/service_options_menu.dart';

void main() {
  Future<void> abrirMenu(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        appBar: AppBar(actions: [
          ServiceOptionsMenu(
            onExit: () async => false,
            actions: [
              ServiceMenuAction(
                icon: Icons.handshake_outlined,
                label: 'Registrar oportunidad comercial',
                onSelected: (_) {},
              ),
            ],
          ),
        ]),
      ),
    ));
    await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
    await tester.pumpAndSettle();
  }

  for (final (brightness, ink) in [
    (Brightness.light, AppDesign.ink),
    (Brightness.dark, Colors.white),
  ]) {
    testWidgets(
        'menú ⋮ redondeado y con íconos del color del tema '
        '(${brightness.name})', (tester) async {
      await abrirMenu(tester, brightness);

      for (final icon in [Icons.handshake_outlined, Icons.logout_rounded]) {
        expect(tester.widget<Icon>(find.byIcon(icon)).color, ink);
      }
      expect(find.byType(PopupMenuDivider), findsNothing,
          reason: 'una sola lista, sin líneas entre opciones');
      final ventana = tester.widgetList<Material>(find.ancestor(
          of: find.text(ServiceOptionsMenu.exitLabel),
          matching: find.byType(Material)));
      expect(
        ventana.any((material) =>
            material.shape ==
                RoundedRectangleBorder(borderRadius: AppDesign.mediumRadius) &&
            material.clipBehavior == Clip.antiAlias),
        isTrue,
        reason: 'bordes redondeados que también recortan el toque',
      );
    });
  }
}
