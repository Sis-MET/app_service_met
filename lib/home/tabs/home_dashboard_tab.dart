import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

import '../models/servicio_model.dart';
import '../widgets/welcome_header.dart';
import '../widgets/tipo_servicio_selector.dart';
import '../widgets/service_card.dart';
import '../../theme/app_colors.dart';

class HomeDashboardTab extends StatefulWidget {
  final String userName;
  final VoidCallback goToServicios;

  const HomeDashboardTab({
    super.key,
    required this.userName,
    required this.goToServicios,
  });

  @override
  State<HomeDashboardTab> createState() => _HomeDashboardTabState();
}

class _HomeDashboardTabState extends State<HomeDashboardTab> {
  int _tipoServicioSeleccionado = 0;
  int totalServiciosCal = 0;
  int totalServiciosSop = 0;
  String fechaUltimaPrecarga = "Sin datos";

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await _getTotalServiciosCal();
    await _getFechaUltimaPrecarga();
    await _getTotalServiciosSop();
  }

  Future<void> _getTotalServiciosSop() async {
    try {
      final Map<String, String> databasesMap = {
        'ajustes.db': 'ajustes_metrologicos',
        'diagnostico.db': 'diagnostico',
        'instalacion.db': 'instalacion',
        'mnt_correctivo.db': 'mnt_correctivo',
        'mnt_prv_avanzado_stac.db': 'mnt_prv_avanzado_stac',
        'mnt_prv_avanzado_stil.db': 'mnt_prv_avanzado_stil',
        'mnt_prv_regular_stac.db': 'mnt_prv_regular_stac',
        'mnt_prv_regular_stil.db': 'mnt_prv_regular_stil',
        'relevamiento_de_datos.db': 'relevamiento_de_datos',
        'verificaciones.db': 'verificaciones_internas',
      };
      final databasesPath = await getDatabasesPath();
      final results = await Future.wait(
        databasesMap.entries.map((entry) async {
          final dbPath = p.join(databasesPath, entry.key);
          if (await databaseExists(dbPath)) {
            try {
              final db = await openDatabase(dbPath, readOnly: true);
              final result = await db
                  .rawQuery('SELECT COUNT(*) as total FROM ${entry.value}');
              await db.close();
              return result.isNotEmpty ? (result.first['total'] as int) : 0;
            } catch (_) {
              return 0;
            }
          }
          return 0;
        }),
      );
      if (mounted) {
        setState(() {
          totalServiciosSop = results.fold(0, (s, c) => s + c);
        });
      }
    } catch (_) {
      if (mounted) setState(() => totalServiciosSop = 0);
    }
  }

  Future<void> _getTotalServiciosCal() async {
    try {
      final dbPath = p.join(await getDatabasesPath(), 'calibracion.db');
      if (await databaseExists(dbPath)) {
        final db = await openDatabase(dbPath);
        final result = await db.rawQuery(
            'SELECT COUNT(*) as total FROM registros_calibracion WHERE estado_servicio_bal = ?',
            ['Balanza Calibrada']);
        await db.close();
        if (mounted) {
          setState(() {
            totalServiciosCal =
                result.isNotEmpty ? result.first['total'] as int : 0;
          });
        }
      } else {
        if (mounted) setState(() => totalServiciosCal = 0);
      }
    } catch (_) {
      if (mounted) setState(() => totalServiciosCal = 0);
    }
  }

  Future<void> _getFechaUltimaPrecarga() async {
    try {
      final dbPath =
          p.join(await getDatabasesPath(), 'precarga_database.db');
      if (await databaseExists(dbPath)) {
        final lastModified = await File(dbPath).lastModified();
        final formatted =
            DateFormat("d 'de' MMMM 'de' y", 'es_ES').format(lastModified);
        if (mounted) setState(() => fechaUltimaPrecarga = formatted);
      } else {
        if (mounted) setState(() => fechaUltimaPrecarga = "No existe");
      }
    } catch (_) {
      if (mounted) setState(() => fechaUltimaPrecarga = "Error");
    }
  }

  String _obtenerTipoServicio(String dbName) {
    switch (dbName) {
      case 'ajustes.db':
        return 'Ajustes';
      case 'diagnostico.db':
        return 'Diagnóstico';
      case 'instalacion.db':
        return 'Instalación';
      case 'mnt_correctivo.db':
        return 'Mantenimiento Correctivo';
      case 'mnt_prv_avanzado_stac.db':
        return 'Mnt. Preventivo Avanzado STAC';
      case 'mnt_prv_avanzado_stil.db':
        return 'Mnt. Preventivo Avanzado STIL';
      case 'mnt_prv_regular_stac.db':
        return 'Mnt. Preventivo Regular STAC';
      case 'mnt_prv_regular_stil.db':
        return 'Mnt. Preventivo Regular STIL';
      case 'relevamiento_de_datos.db':
        return 'Relevamiento';
      case 'verificaciones.db':
        return 'Verificaciones';
      default:
        return 'Soporte Técnico';
    }
  }

  Future<List<ServicioResumen>> _getServiciosCalibracionPorSeca() async {
    final List<ServicioResumen> servicios = [];
    try {
      final dbPath = p.join(await getDatabasesPath(), 'calibracion.db');
      if (await databaseExists(dbPath)) {
        final db = await openDatabase(dbPath);
        final registros = await db.query('registros_calibracion');
        final Map<String, List<Map<String, dynamic>>> agrupados = {};
        for (var r in registros) {
          final seca = r['seca']?.toString() ?? 'Sin SECA';
          agrupados.putIfAbsent(seca, () => []).add(r);
        }
        agrupados.forEach((seca, balanzas) {
          servicios.add(ServicioResumen(
              tipo: TipoServicio.calibracion,
              codigo: seca,
              cantidad: balanzas.length,
              items: balanzas));
        });
        await db.close();
      }
      servicios.sort((a, b) => a.codigo.compareTo(b.codigo));
    } catch (_) {}
    return servicios;
  }

  Future<List<ServicioResumen>> _getServiciosSoportePorOtst() async {
    final List<ServicioResumen> servicios = [];
    try {
      final Map<String, String> databasesMap = {
        'ajustes.db': 'ajustes_metrologicos',
        'diagnostico.db': 'diagnostico',
        'instalacion.db': 'instalacion',
        'mnt_correctivo.db': 'mnt_correctivo',
        'mnt_prv_avanzado_stac.db': 'mnt_prv_avanzado_stac',
        'mnt_prv_avanzado_stil.db': 'mnt_prv_avanzado_stil',
        'mnt_prv_regular_stac.db': 'mnt_prv_regular_stac',
        'mnt_prv_regular_stil.db': 'mnt_prv_regular_stil',
        'relevamiento_de_datos.db': 'relevamiento_de_datos',
        'verificaciones.db': 'verificaciones_internas',
      };
      final Map<String, List<Map<String, dynamic>>> agrupados = {};
      final databasesPath = await getDatabasesPath();
      final results = await Future.wait(
        databasesMap.entries.map((entry) async {
          final dbPath = p.join(databasesPath, entry.key);
          if (await databaseExists(dbPath)) {
            try {
              final db = await openDatabase(dbPath, readOnly: true);
              final registros = await db.query(entry.value);
              await db.close();
              return registros.map((r) {
                final m = Map<String, dynamic>.from(r);
                m['tipo_servicio'] = _obtenerTipoServicio(entry.key);
                return m;
              }).toList();
            } catch (_) {
              return <Map<String, dynamic>>[];
            }
          }
          return <Map<String, dynamic>>[];
        }),
      );
      for (var dbRegistros in results) {
        for (var r in dbRegistros) {
          final otst = r['otst']?.toString() ?? 'Sin OTST';
          agrupados.putIfAbsent(otst, () => []).add(r);
        }
      }
      agrupados.forEach((otst, list) {
        servicios.add(ServicioResumen(
            tipo: TipoServicio.soporte, codigo: otst, cantidad: list.length, items: list));
      });
      servicios.sort((a, b) => a.codigo.compareTo(b.codigo));
    } catch (_) {}
    return servicios;
  }

  // ─────────────────────────────────────────
  //  UI HELPERS
  // ─────────────────────────────────────────

  Widget _buildSummaryCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.brightness == Brightness.dark ? Colors.white : cs.primary;
    final cardBg = cs.brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white;
    final divider = cs.brightness == Brightness.dark ? AppColors.borderDarkSoft : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.brightness == Brightness.dark ? AppColors.borderDarkSoft : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(cs.brightness == Brightness.dark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Dos stats ──
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: FontAwesomeIcons.screwdriverWrench,
                  value: totalServiciosSop.toString(),
                  label: 'Soporte\nTécnico',
                  accent: accent,
                  onTap: () => setState(() => _tipoServicioSeleccionado = 1),
                ),
              ),
              Container(
                width: 1,
                height: 64,
                color: divider,
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: FontAwesomeIcons.scaleBalanced,
                  value: totalServiciosCal.toString(),
                  label: 'Balanzas\nCalibradas',
                  accent: accent,
                  onTap: () => setState(() => _tipoServicioSeleccionado = 0),
                ),
              ),
            ],
          ),
          // ── Divider + precarga ──
          Container(
            height: 1,
            color: divider,
            margin: const EdgeInsets.symmetric(vertical: 16),
          ),
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.cloudArrowDown,
                size: 13,
                color: cs.onSurface.withOpacity(0.38),
              ),
              const SizedBox(width: 8),
              Text(
                'Última precarga: ',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.38),
                ),
              ),
              Expanded(
                child: Text(
                  fechaUltimaPrecarga,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.70),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  Widget _buildStatItem({
    required dynamic icon,
    required String value,
    required String label,
    required Color accent,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon is IconData ? Icon(icon, size: 26, color: accent) : FaIcon(icon, size: 26, color: accent),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: cs.onSurface.withOpacity(0.38),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mis Servicios',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            Text(
              'Registros en este dispositivo',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.38),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required dynamic icon,
    required String title,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.brightness == Brightness.dark ? AppColors.borderDarkSoft : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          icon is IconData ? Icon(icon,
              size: 40,
              color: cs.onSurface.withOpacity(0.24)) : FaIcon(icon,
              size: 40,
              color: cs.onSurface.withOpacity(0.24)),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.54),
              )),
          const SizedBox(height: 6),
          Text(subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.38),
              ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadDashboardData();
        setState(() {});
      },
      color: cs.brightness == Brightness.dark ? Colors.white : cs.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Saludo ──
            WelcomeHeader(userName: widget.userName),
            const SizedBox(height: 28),

            // ── 2. Card resumen ──
            _buildSummaryCard(context),
            const SizedBox(height: 32),

            // ── 3. Encabezado sección ──
            _buildSectionHeader(context),
            const SizedBox(height: 14),

            // ── 4. Selector tipo ──
            TipoServicioSelector(
              selectedIndex: _tipoServicioSeleccionado,
              onSelected: (i) =>
                  setState(() => _tipoServicioSeleccionado = i),
            ).animate().fadeIn(delay: 550.ms),
            const SizedBox(height: 20),

            // ── 5. Lista ──
            if (_tipoServicioSeleccionado == 0)
              _buildListaCalibracion(context)
            else
              _buildListaSoporte(context),
          ],
        ),
      ),
    );
  }

  Widget _buildListaCalibracion(BuildContext context) {
    return FutureBuilder<List<ServicioResumen>>(
      future: _getServiciosCalibracionPorSeca(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            context: context,
            icon: FontAwesomeIcons.scaleBalanced,
            title: 'Sin servicios de calibración',
            subtitle:
                'Los registros de calibración aparecerán aquí cuando estén disponibles.',
          );
        }
        return Column(
          children: snapshot.data!.asMap().entries.map((e) {
            return ServiceCard(servicio: e.value)
                .animate(delay: Duration(milliseconds: 600 + e.key * 80))
                .fadeIn()
                .slideX(begin: 0.2);
          }).toList(),
        );
      },
    );
  }

  Widget _buildListaSoporte(BuildContext context) {
    return FutureBuilder<List<ServicioResumen>>(
      future: _getServiciosSoportePorOtst(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            context: context,
            icon: FontAwesomeIcons.screwdriverWrench,
            title: 'Sin servicios de soporte',
            subtitle:
                'Los registros de soporte técnico aparecerán aquí cuando estén disponibles.',
          );
        }
        return Column(
          children: snapshot.data!.asMap().entries.map((e) {
            return ServiceCard(servicio: e.value)
                .animate(delay: Duration(milliseconds: 600 + e.key * 80))
                .fadeIn()
                .slideX(begin: 0.2);
          }).toList(),
        );
      },
    );
  }
}
