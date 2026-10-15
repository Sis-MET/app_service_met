import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/services/permisos_app.dart';
import 'package:service_met/widgets/dialogo_permiso.dart';
import 'package:service_met/widgets/requiere_ubicacion.dart';

class _UbicacionFalsa extends AccesoUbicacion {
  _UbicacionFalsa(this.actual, {this.trasSolicitar});

  EstadoUbicacion actual;
  final EstadoUbicacion? trasSolicitar;
  int solicitudes = 0;
  int ajustesApp = 0;
  int ajustesUbicacion = 0;

  @override
  Future<EstadoUbicacion> estado() async => actual;

  @override
  Future<EstadoUbicacion> solicitar() async {
    solicitudes++;
    return actual = trasSolicitar ?? actual;
  }

  @override
  Future<void> abrirAjustesApp() async => ajustesApp++;

  @override
  Future<void> abrirAjustesUbicacion() async => ajustesUbicacion++;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  tearDown(() {
    AccesoUbicacion.instancia = const AccesoUbicacion();
    PermisoCamara.concedidoOverride = null;
  });

  group('aviso previo', () {
    test('cada permiso se pide por procedimientos de la empresa', () {
      for (final permiso in PermisoApp.values) {
        expect(DialogoPermiso.requerimiento(permiso),
            startsWith('Por procedimientos de la empresa'));
      }
    });

    test('el de ubicación no explica para qué se usa', () {
      final texto =
          DialogoPermiso.requerimiento(PermisoApp.ubicacion).toLowerCase();
      for (final explicacion in ['registr', 'dónde', 'coordenad', 'para ']) {
        expect(texto, isNot(contains(explicacion)));
      }
    });

    Future<bool?> abrir(WidgetTester tester, PermisoApp permiso,
        {bool irAAjustes = false}) async {
      bool? respuesta;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async => respuesta = await confirmarPermiso(
                  context, permiso,
                  irAAjustes: irAAjustes),
              child: const Text('Pedir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Pedir'));
      await tester.pumpAndSettle();
      return respuesta;
    }

    testWidgets('continuar o no continuar', (tester) async {
      await abrir(tester, PermisoApp.notificaciones);
      expect(find.text('Permiso de notificaciones'), findsOneWidget);
      expect(find.textContaining('Por procedimientos de la empresa'),
          findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.byType(DialogoPermiso), findsNothing);
    });

    testWidgets('si ya se rechazó, lleva a los ajustes', (tester) async {
      await abrir(tester, PermisoApp.notificaciones, irAAjustes: true);
      expect(find.text('Abrir ajustes'), findsOneWidget);
      expect(find.textContaining('Ajustes › Permisos'), findsOneWidget);
    });

    testWidgets('la cámara avisa solo si todavía no hay permiso',
        (tester) async {
      bool? resultado;
      Future<void> pedir() async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async =>
                    resultado = await asegurarCamara(context),
                child: const Text('Cámara'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('Cámara'));
        await tester.pumpAndSettle();
      }

      PermisoCamara.concedidoOverride = () async => true;
      await pedir();
      expect(find.byType(DialogoPermiso), findsNothing);
      expect(resultado, isTrue);

      PermisoCamara.concedidoOverride = () async => false;
      await pedir();
      expect(find.text('Permiso de cámara'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(resultado, isFalse);
    });
  });

  group('servicio bloqueado sin ubicación', () {
    Future<_UbicacionFalsa> abrirServicio(
      WidgetTester tester,
      EstadoUbicacion estado, {
      EstadoUbicacion? trasSolicitar,
    }) async {
      final falsa = _UbicacionFalsa(estado, trasSolicitar: trasSolicitar);
      AccesoUbicacion.instancia = falsa;
      await tester.pumpWidget(const MaterialApp(
        home: RequiereUbicacion(child: Text('Servicio abierto')),
      ));
      await tester.pumpAndSettle();
      return falsa;
    }

    testWidgets('con el permiso concedido entra sin preguntar', (tester) async {
      final falsa = await abrirServicio(tester, EstadoUbicacion.concedida);
      expect(find.text('Servicio abierto'), findsOneWidget);
      expect(find.byType(DialogoPermiso), findsNothing);
      expect(falsa.solicitudes, 0);
    });

    testWidgets('avisa antes de pedirlo y, si se concede, abre el servicio',
        (tester) async {
      final falsa = await abrirServicio(tester, EstadoUbicacion.denegada,
          trasSolicitar: EstadoUbicacion.concedida);

      // Primero el aviso de la app, sin solicitud del sistema todavía.
      expect(find.text('Permiso de ubicación'), findsOneWidget);
      expect(find.textContaining('no se puede iniciar ni continuar'),
          findsOneWidget);
      expect(falsa.solicitudes, 0);
      expect(find.text('Servicio abierto'), findsNothing);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(falsa.solicitudes, 1);
      expect(find.text('Servicio abierto'), findsOneWidget);
    });

    testWidgets('si no se concede, el servicio queda bloqueado',
        (tester) async {
      final falsa = await abrirServicio(tester, EstadoUbicacion.denegada);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(falsa.solicitudes, 0);
      expect(find.text('Servicio abierto'), findsNothing);
      expect(find.text('Ubicación requerida'), findsOneWidget);
      expect(find.textContaining('Por procedimientos de la empresa'),
          findsOneWidget);

      // Desde el bloqueo se vuelve a pedir; rechazado otra vez, sigue igual.
      await tester.tap(find.text('Permitir ubicación'));
      await tester.pumpAndSettle();
      expect(falsa.solicitudes, 1);
      expect(find.text('Servicio abierto'), findsNothing);
    });

    testWidgets('rechazado para siempre: lleva a Ajustes y revisa al volver',
        (tester) async {
      final falsa =
          await abrirServicio(tester, EstadoUbicacion.denegadaSiempre);
      expect(find.byType(DialogoPermiso), findsNothing);
      expect(find.text('Ubicación requerida'), findsOneWidget);

      await tester.tap(find.text('Abrir ajustes'));
      await tester.pumpAndSettle();
      expect(falsa.ajustesApp, 1);

      // El técnico lo concede en Ajustes y vuelve a la app.
      falsa.actual = EstadoUbicacion.concedida;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Servicio abierto'), findsOneWidget);
    });

    testWidgets('con la ubicación del teléfono apagada pide activarla',
        (tester) async {
      final falsa = await abrirServicio(tester, EstadoUbicacion.apagada);
      expect(find.text('Servicio abierto'), findsNothing);
      await tester.tap(find.text('Activar ubicación'));
      await tester.pumpAndSettle();
      expect(falsa.ajustesUbicacion, 1);

      falsa.actual = EstadoUbicacion.concedida;
      await tester.tap(find.text('Ya lo activé'));
      await tester.pumpAndSettle();
      expect(find.text('Servicio abierto'), findsOneWidget);
    });
  });
}
