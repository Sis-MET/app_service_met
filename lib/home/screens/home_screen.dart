import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../tabs/home_dashboard_tab.dart';
import '../tabs/otros_apartados_tab.dart';
import '../tabs/servicios_tab.dart';
import '../widgets/home_bottom_bar.dart';
import 'configuracion_screen.dart';

class HomeScreen extends StatefulWidget {
  final String dbName;

  const HomeScreen({super.key, this.dbName = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = 'Cargando...';
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null);
    _fetchUserData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
