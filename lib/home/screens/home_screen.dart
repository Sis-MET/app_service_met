import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../login/services/connection_profile_service.dart';
import '../../repositories/calibration_repository.dart';
import '../../screens/calibracion/calibration_workspace_screen.dart';
import '../../screens/oportunidades/services/opportunity_auto_sync.dart';
import '../../screens/oportunidades/services/opportunity_repository.dart';
import '../../screens/precarga/descarga_de_datos.dart';
import '../../screens/soporte_new/precarga/precarga_screen.dart';
import '../../services/notification_service.dart';
import '../../services/notifications/notification_plan.dart';
import '../tabs/home_dashboard_tab.dart';
import '../tabs/otros_apartados_tab.dart';
import '../tabs/servicios_tab.dart';
import '../widgets/home_bottom_bar.dart';
import 'configuracion_screen.dart';
import 'vencimientos_screen.dart';

class HomeScreen extends StatefulWidget {
  final String dbName;

  const HomeScreen({super.key, this.dbName = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String userName = 'Cargando...';
  bool _userReady = false;
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null);
    WidgetsBinding.instance.addObserver(this);
    NotificationService().pendingTap.addListener(_handleNotificationTap);
    _fetchUserData().whenComplete(_onUserReady);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService().pendingTap.removeListener(_handleNotificationTap);
    // La sincronización sigue viva: otro inicio puede haberla tomado ya.
    OpportunityAutoSync.instance.lastReport.removeListener(_onOpportunitySync);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Salir de la app es el último momento en que cambian los datos: se
    // reprograman las notificaciones con lo que quedó pendiente.
    if (state == AppLifecycleState.paused && _userReady) {
      NotificationService().refresh(userName);
    }
    // Al volver puede haber conexión: se completan y envían las
    // oportunidades comerciales pendientes.
    if (state == AppLifecycleState.resumed && _userReady) {
      OpportunityAutoSync.instance.schedule();
    }
  }

  void _onUserReady() {
    if (!mounted) return;
    _userReady = true;
    NotificationService().refresh(userName);
    _handleNotificationTap();
    _startOpportunitySync();
  }

  /// Las oportunidades registradas sin conexión se completan y envían solas
  /// cuando el servidor vuelve a estar al alcance.
  void _startOpportunitySync() {
    final ConnectionProfileService profiles;
    try {
      profiles = context.read<ConnectionProfileService>();
    } catch (_) {
      return;
    }
    final sync = OpportunityAutoSync.instance;
    sync.lastReport.addListener(_onOpportunitySync);
    sync.start(apiUrl: () => profiles.perfilSeleccionado?.apiUrl);
  }

  /// Lo que pide atención (elegir una empresa, ingresar la contraseña) se
  /// avisa una vez por sesión; lo enviado, cada vez.
  bool _opportunityAttentionShown = false;

  void _onOpportunitySync() {
    final OpportunitySyncReport? report =
        OpportunityAutoSync.instance.lastReport.value;
    if (report == null || !mounted) return;
    final needsAttention = report.needCompany > 0 || report.authRequired;
    if (report.sent == 0 && (!needsAttention || _opportunityAttentionShown)) {
      return;
    }
    if (needsAttention) _opportunityAttentionShown = true;
    final message = report.message;
    if (message == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(needsAttention
            ? '$message Revíselas en Servicios › Oportunidades comerciales.'
            : message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Abre el destino de la notificación tocada. Solo desde el inicio: si el
  /// técnico está dentro de un servicio no se le cambia de pantalla.
  Future<void> _handleNotificationTap() async {
    final tap = NotificationService().pendingTap;
    final payload = tap.value;
    if (payload == null || !_userReady || !mounted) return;
    tap.value = null;
    if (ModalRoute.of(context)?.isCurrent == false) return;

    switch (payload) {
      case NoticePayload.vencimientosPatrones:
        await _push(const VencimientosScreen());
      case NoticePayload.vencimientosBalanzas:
        await _push(
          const VencimientosScreen(initialTab: VencimientosTab.balanzas),
        );
      case NoticePayload.soportePendiente:
        // La precarga de soporte ofrece retomar el servicio pendiente.
        await _push(PrecargaScreenSop(
          userName: userName,
          clienteId: '',
          plantaCodigo: '',
          tableName: '',
        ));
      case NoticePayload.precarga:
        await _push(DescargaDeDatosScreen(userName: userName));
      case NoticePayload.subidas || NoticePayload.resumen:
        _selectPage(0);
      default:
        final calibracion = NoticePayload.parseCalibracionPendiente(payload);
        if (calibracion != null) await _openCalibracionPendiente(calibracion);
    }
  }

  Future<void> _openCalibracionPendiente((String, String) calibracion) async {
    final (seca, sessionId) = calibracion;
    final pending =
        await CalibrationRepository().getServiciosIncompletos(userName);
    if (!mounted) return;
    final sigue = pending.any((row) =>
        row['seca']?.toString().trim() == seca &&
        row['session_id']?.toString().trim() == sessionId);
    if (!sigue) {
      _selectPage(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esa calibración ya no está pendiente.')),
      );
      return;
    }
    await _push(CalibrationWorkspaceScreen(
      userName: userName,
      secaValue: seca,
      sessionId: sessionId,
    ));
  }

  Future<void> _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  List<Widget> _screens() => [
        HomeDashboardTab(
          userName: userName,
          onSettings: _openSettings,
          goToServicios: () => _selectPage(1),
        ),
        ServiciosTab(userName: userName),
        OtrosApartadosTab(userName: userName),
      ];

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedUser = prefs.getString('logged_user');
      if (loggedUser == null || loggedUser.isEmpty) {
        if (mounted) setState(() => userName = 'Usuario');
        return;
      }

      final path = p.join(await getDatabasesPath(), 'usuarios.db');
      if (!await databaseExists(path)) {
        if (mounted) setState(() => userName = 'Usuario');
        return;
      }

      final db = await openDatabase(path, readOnly: true);
      final results = await db.query(
        'usuarios',
        where: 'usuario = ?',
        whereArgs: [loggedUser],
        limit: 1,
      );
      await db.close();
      if (!mounted) return;
      if (results.isEmpty) {
        setState(() => userName = 'Usuario');
        return;
      }

      final user = results.first;
      final title = user['titulo_abr']?.toString() ?? '';
      final firstName = user['nombre1']?.toString() ?? '';
      final lastName = user['apellido1']?.toString() ?? '';
      final secondLastName = user['apellido2']?.toString() ?? '';
      final secondInitial =
          secondLastName.isEmpty ? '' : '${secondLastName[0]}.';
      final fullName = '$title $firstName $lastName $secondInitial'.trim();
      setState(() => userName = fullName.isEmpty ? 'Usuario' : fullName);
    } catch (error) {
      debugPrint('No se pudo cargar el usuario del home: $error');
      if (mounted) setState(() => userName = 'Usuario');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: _screens(),
        ),
      ),
      bottomNavigationBar: HomeBottomBar(
        currentIndex: _currentIndex,
        onTap: _selectPage,
      ),
    );
  }

  void _selectPage(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
    );
  }
}
