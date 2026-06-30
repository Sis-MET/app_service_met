// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import 'configuracion_screen.dart';
import '../tabs/otros_apartados_tab.dart';
import '../tabs/servicios_tab.dart';
import '../tabs/home_dashboard_tab.dart';
import '../widgets/home_bottom_bar.dart';

class HomeScreen extends StatefulWidget {
  final String dbName;
  const HomeScreen({super.key, this.dbName = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _modoDemo = false;
  String userName = "Cargando...";

  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
    _checkModoDemo();
    _fetchUserData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkModoDemo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _modoDemo = prefs.getBool('modoDemo') ?? false;
    });
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('es_ES', null);
  }

  List<Widget> _screens(BuildContext context) => [
        HomeDashboardTab(
            userName: userName,
            goToServicios: () {
              setState(() {
                _currentIndex = 1;
              });
              _pageController.animateToPage(1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut);
            }),
        ServiciosTab(userName: userName),
        OtrosApartadosTab(userName: userName),
      ];

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usuarioLogueado = prefs.getString('logged_user');

      if (usuarioLogueado == null || usuarioLogueado.isEmpty) {
        setState(() => userName = "Usuario");
        return;
      }

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'usuarios.db');

      if (!await databaseExists(path)) {
        setState(() => userName = "Usuario");
        return;
      }

      final db = await openDatabase(path);
      final results = await db.query(
        'usuarios',
        where: 'usuario = ?',
        whereArgs: [usuarioLogueado],
        limit: 1,
      );
      await db.close();

      if (results.isEmpty) {
        setState(() => userName = "Usuario");
        return;
      }

      final userData = results.first;
      final tituloAbr = userData['titulo_abr']?.toString() ?? '';
      final nombre1 = userData['nombre1']?.toString() ?? '';
      final apellido1 = userData['apellido1']?.toString() ?? '';
      final apellido2 = userData['apellido2']?.toString() ?? '';

      String inicialApellido2 = '';
      if (apellido2.isNotEmpty) {
        inicialApellido2 = '${apellido2[0]}.';
      }

      final fullName =
          '$tituloAbr $nombre1 $apellido1 $inicialApellido2'.trim();

      setState(() {
        userName = fullName.isNotEmpty ? fullName : "Usuario";
      });

      debugPrint('[OK] Usuario cargado: $userName (ID: $usuarioLogueado)');
    } catch (e) {
      debugPrint('[ERROR] Error obteniendo datos del usuario: $e');
      setState(() => userName = "Usuario");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final accent = cs.primary;

    return Scaffold(
      // extendBody permite que el nav bar flotante no corte el scroll
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
        centerTitle: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getAppBarTitle(),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                height: 1.1,
              ),
            ),
            if (_modoDemo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : accent).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isDark ? Colors.white : accent).withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_outlined,
                        size: 11, color: isDark ? Colors.white : accent),
                    const SizedBox(width: 4),
                    Text(
                      'DEMO',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!_modoDemo)
            IconButton(
              icon: FaIcon(FontAwesomeIcons.gear,
                  size: 18, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConfiguracionScreen(),
                  ),
                );
              },
              tooltip: 'Configuración',
            ),
          if (_modoDemo)
            IconButton(
              icon: Icon(Icons.logout_rounded,
                  size: 20, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
              tooltip: 'Salir del modo DESCONECTADO',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Row(
                      children: [
                        Icon(Icons.logout,
                            color: isDark ? Colors.white : accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Salir del modo DESCONECTADO',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      '¿Deseas salir del modo DESCONECTADO y volver al login?',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : accent,
                        ),
                        child: Text(
                          'Salir',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setBool('modoDemo', false);
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(
                        context, '/login');
                  }
                }
              },
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens(context),
      ),
      bottomNavigationBar: HomeBottomBar(
        currentIndex: _currentIndex,
        modoDemo: _modoDemo,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Inicio';
      case 1:
        return 'Servicios';
      case 2:
        return 'Precarga';
      default:
        return 'Inicio';
    }
  }
}
