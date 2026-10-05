import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/login/screens/initial_setup_screen.dart';
import 'package:service_met/login/models/user_model.dart';
import 'package:service_met/login/services/connection_profile_service.dart';
import 'package:service_met/login/widgets/login/login_form.dart';
import 'package:service_met/login/widgets/login/password_field.dart';
import 'package:service_met/login/widgets/login/user_selector_dialog.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/theme/app_icons.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    required Brightness brightness,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: brightness,
          colorSchemeSeed: Colors.black,
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: LoginForm(
                formKey: GlobalKey<FormState>(),
                passController: TextEditingController(),
                userController: TextEditingController(),
                loading: false,
                savedUser: 'tecnico',
                savedUserFullName: 'Tec. Usuario ServiceMET',
                lastUpdate: '2026-08-11T09:00:00',
                isAddingNewUser: false,
                deviceAuthAvailable: true,
                deviceAuthEnabled: true,
                onSubmit: () {},
                onDeviceAuth: () {},
                onSelectUser: () {},
                onCancelAddingUser: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renderiza el acceso móvil en modo claro sin desbordes',
      (tester) async {
    await pumpLogin(tester, brightness: Brightness.light);

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Trabajo de campo'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renderiza el acceso móvil en modo oscuro sin desbordes',
      (tester) async {
    await pumpLogin(tester, brightness: Brightness.dark);

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Ingresar con huella o biometría'), findsNothing);
    final biometric = find.byKey(const ValueKey('biometric-login-button'));
    final password = find.byType(PasswordField);
    final submit = find.widgetWithText(FilledButton, 'Ingresar');
    expect(biometric, findsOneWidget);
    expect(find.byIcon(AppIcons.huella), findsOneWidget);
    expect(
      tester.getTopLeft(biometric).dy,
      greaterThan(tester.getTopLeft(password).dy),
    );
    expect(
      tester.getTopLeft(biometric).dy,
      lessThan(tester.getTopLeft(submit).dy),
    );
    final biometricButton = tester.widget<IconButton>(biometric);
    expect(
      biometricButton.style?.backgroundColor?.resolve({}),
      AppColors.actionPositive,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renderiza la configuración inicial en claro y oscuro',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ConnectionProfileService(),
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              brightness: brightness,
              colorSchemeSeed: Colors.black,
            ),
            home: const InitialSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Configura tu espacio de trabajo'), findsOneWidget);
      expect(find.text('Local o VPN'), findsOneWidget);
      final logo = tester.widget<Image>(find.byType(Image).first);
      expect(logo.fit, BoxFit.contain);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('muestra usuarios guardados con selección y estados',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var addRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: UserSelectorSheet(
            selectedUsername: 'tecnico',
            users: [
              UserModel(
                usuario: 'tecnico',
                nombre1: 'Ana',
                apellido1: 'Pérez',
                apellido2: '',
                tituloAbr: 'Ing.',
                estado: 'ACTIVO',
                accesoApp: '1',
                lastVerifiedAt: DateTime.now(),
              ),
              UserModel(
                usuario: 'inactivo',
                nombre1: 'Luis',
                apellido1: 'Rojas',
                apellido2: '',
                tituloAbr: 'Tec.',
                estado: 'INACTIVO',
                accesoApp: '1',
              ),
            ],
            onAdd: () => addRequested = true,
            onDelete: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usuarios del dispositivo'), findsOneWidget);
    expect(find.text('OFFLINE LISTO'), findsOneWidget);
    expect(find.text('INACTIVO'), findsOneWidget);
    expect(find.text('EN USO'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.quitarPersona).first);
    await tester.pumpAndSettle();
    final removeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Quitar acceso'),
    );
    expect(
      removeButton.style?.backgroundColor?.resolve({}),
      AppColors.actionNegative,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vincular otro usuario'));
    expect(addRequested, isTrue);
    expect(tester.takeException(), isNull);
  });
}
