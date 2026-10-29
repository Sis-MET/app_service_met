import 'package:flutter/material.dart';

import '../../models/service_session.dart';
import '../../repositories/calibration_repository.dart';
import '../../screens/calibracion/calibration_workspace_screen.dart';
import '../../screens/calibracion/tipo_calibracion_screen.dart';
import '../../screens/calibracion_temperatura/data/temperatura_store.dart';
import '../../screens/calibracion_temperatura/models/temperatura_models.dart';
import '../../screens/calibracion_temperatura/temperatura_registros_screen.dart';
import '../../screens/calibracion_temperatura/temperatura_workspace_screen.dart';
import '../../screens/oportunidades/models/opportunity_service_context.dart';
import '../../screens/oportunidades/services/opportunity_auto_sync.dart';
import '../../screens/oportunidades/widgets/opportunities_entry_tile.dart';
import '../../screens/rim/rim_flow.dart';
import '../../screens/rim/widgets/rim_entry_tile.dart';
import '../../screens/soporte_new/precarga/precarga_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../theme/app_icons.dart';
import '../../widgets/requiere_ubicacion.dart';

const _stepNames = [
  'Cliente',
  'Planta',
  'SECA',
  'Instrumento',
  'Inspección visual',
  'Precarga/Ajuste',
  'Excentricidad',
  'Repetibilidad',
  'Linealidad',
  'Foto de carga',
  'Condiciones finales',
  'Exportación',
];

class ServiciosTab extends StatefulWidget {
  final String userName;

  const ServiciosTab({super.key, required this.userName});

  @override
  State<ServiciosTab> createState() => _ServiciosTabState();
}

class _ServiciosTabState extends State<ServiciosTab> {
  String get userName => widget.userName;

  /// Cambia al volver de un servicio, para que los accesos a los
  /// formularios vuelvan a contar sus pendientes.
  int _formulariosVersion = 0;

  void _refrescarFormularios() {
    if (mounted) setState(() => _formulariosVersion++);
  }

  @override
  void initState() {
    super.initState();
    // Lo que se envía solo también cambia los pendientes.
    OpportunityAutoSync.instance.lastReport.addListener(_refrescarFormularios);
  }

  @override
  void dispose() {
    OpportunityAutoSync.instance.lastReport
        .removeListener(_refrescarFormularios);
    super.dispose();
  }

  Future<void> _openSoporte() async {
    await Navigator.push(
      context,
      RequiereUbicacion.ruta(PrecargaScreenSop(
        userName: userName,
        clienteId: '',
        plantaCodigo: '',
        tableName: '',
      )),
    );
    _refrescarFormularios();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDesign.pagePadding,
        24,
        AppDesign.pagePadding,
        112,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Servicios', style: AppDesign.displayStyle(context)),
              const SizedBox(height: 8),
              Text(
                'Selecciona el tipo de trabajo que realizarás hoy.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: AppStatusPill(
                  icon: AppIcons.trabajo,
                  label: '2 módulos disponibles',
                  color: AppColors.actionPositive,
                ),
              ),
              const SizedBox(height: 28),
              _ServiceModuleCard(
                icon: AppIcons.balanza,
                title: 'Calibración',
                eyebrow: 'METROLOGÍA',
                description:
                    'Calibración de balanzas y de equipos de temperatura (muflas, hornos, estufas) con seguimiento por etapas.',
                actionLabel: 'Iniciar calibración',
                color: AppColors.actionPositive,
                onTap: () => _openCalibration(context),
              ),
              const SizedBox(height: 14),
              _ServiceModuleCard(
                icon: AppIcons.soporte,
                title: 'Soporte técnico',
                eyebrow: 'MANTENIMIENTO',
                description:
                    'Diagnóstico, instalación y mantenimiento de balanzas y básculas de camiones.',
                actionLabel: 'Abrir soporte',
                color: AppColors.shimmerGold,
                onTap: _openSoporte,
              ),
              const SizedBox(height: 28),
              Text(
                'Formularios adicionales',
                style: AppDesign.titleStyle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Llénelos directamente desde aquí o, dentro de un servicio, '
                'desde el menú ⋮. Aquí también se revisan y se envían.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              RimEntryTile(
                key: ValueKey('rim-$_formulariosVersion'),
                userName: userName,
              ),
              const SizedBox(height: 12),
              OpportunitiesEntryTile(
                key: ValueKey('oportunidades-$_formulariosVersion'),
                userName: userName,
              ),
              const SizedBox(height: 22),
              AppPanel(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      AppIcons.consejo,
                      color: AppColors.shimmerGold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Si tienes una calibración sin finalizar, ServiceMET te ofrecerá continuar exactamente desde el último paso guardado.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCalibration(BuildContext context) async {
    var pendientes = 0;
    try {
      pendientes = await TemperaturaStore().contarSinSubir();
    } catch (_) {
      // Sin el conteo se abre igual.
    }
    if (!context.mounted) return;
    final tipo = await TipoCalibracionScreen.elegir(
      context,
      pendientesTemperatura: pendientes,
      onRegistrosTemperatura: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TemperaturaRegistrosScreen(userName: userName),
        ),
      ),
    );
    if (!context.mounted || tipo == null) return;
    switch (tipo) {
      case TipoCalibracion.balanzas:
        await _startCalibration(context);
      case TipoCalibracion.temperatura:
        await _startTemperatura(context);
    }
    _refrescarFormularios();
  }

  /// Calibración de temperatura: si hay una sin terminar, se ofrece
  /// continuarla; descartarla la deja guardada como descartada.
  Future<void> _startTemperatura(BuildContext context) async {
    final store = TemperaturaStore();
    List<TempServicio> pendientes;
    try {
      pendientes = await store.pendientes(userName);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudieron leer las calibraciones: $error'),
        ));
      }
      return;
    }
    if (!context.mounted) return;
    String? uuid;
    if (pendientes.isNotEmpty) {
      final last = pendientes.first;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(AppIcons.pendiente, color: AppColors.warning),
          title: const Text('Calibración de temperatura pendiente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Encontramos una calibración que todavía no '
                  'finalizaste.'),
              const SizedBox(height: 16),
              AppPanel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _detail('Cliente', last.cliente?.nombre),
                    _detail('Planta', last.planta?.nombre),
                    _detail('SECA', last.seca),
                    _detail('Equipo', last.equipo?.codMetrica),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'new'),
              child: const Text('Descartar y crear otra'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'continue'),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (action == null || !context.mounted) return;
      if (action == 'continue') {
        uuid = last.uuid;
      } else {
        try {
          await store.abandonar(last.uuid);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No se pudo descartar la calibración pendiente.'),
            ));
          }
          return;
        }
      }
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      RequiereUbicacion.ruta(
        TemperaturaWorkspaceScreen(userName: userName, uuid: uuid),
      ),
    );
  }

  Future<void> _startCalibration(BuildContext context) async {
    final pending =
        await CalibrationRepository().getServiciosIncompletos(userName);
    if (!context.mounted) return;

    if (pending.isNotEmpty) {
      final last = pending.first;
      final step = _inferStep(last);
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            AppIcons.pendiente,
            color: AppColors.warning,
          ),
          title: const Text('Calibración pendiente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Encontramos un proceso que todavía no finalizaste.'),
              const SizedBox(height: 16),
              AppPanel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _detail('Cliente', last['cliente']),
                    _detail('Planta', last['planta']),
                    _detail('SECA', last['seca']),
                    _detail('Instrumento', last['cod_metrica']),
                    _detail('Último paso', _stepNames[step]),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'new'),
              child: const Text('Descartar y crear otro'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'continue'),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      // Si el sistema cierra el diálogo sin una elección explícita, no se
      // debe crear otra sesión ni alterar la pendiente.
      if (action == null) return;

      if (action == 'continue' && context.mounted) {
        await Navigator.push(
          context,
          RequiereUbicacion.ruta(CalibrationWorkspaceScreen(
            userName: userName,
            secaValue: last['seca']?.toString(),
            sessionId: last['session_id']?.toString(),
          )),
        );
        return;
      }

      if (action == 'new') {
        // La balanza queda sin calibrar: si fue por un problema del
        // instrumento, corresponde dejar el RIM antes de descartarla.
        final service = _pendingServiceContext(last);
        if (service != null &&
            (!context.mounted ||
                !await RimFlow.sugerirAntesDeDescartar(context, service))) {
          return;
        }
        final seca = last['seca']?.toString() ?? '';
        final sessionId = last['session_id']?.toString() ?? '';
        if (seca.isNotEmpty && sessionId.isNotEmpty) {
          try {
            await CalibrationRepository().markServicioAbandonado(
              seca,
              sessionId,
              userName,
            );
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No se pudo descartar la calibración pendiente.',
                  ),
                ),
              );
            }
            return;
          }
        }
        if (!context.mounted) return;
      }
    }

    if (context.mounted) {
      await Navigator.push(
        context,
        RequiereUbicacion.ruta(CalibrationWorkspaceScreen(userName: userName)),
      );
    }
  }

  /// Lo que la calibración pendiente [row] sabe del servicio, para su RIM.
  /// Null si la fila no se puede leer: entonces no se sugiere el RIM.
  OpportunityServiceContext? _pendingServiceContext(Map<String, dynamic> row) {
    try {
      return OpportunityServiceContext.fromCalibration(
        ServiceSession.fromMap(row),
      );
    } catch (error) {
      debugPrint('No se pudo leer la calibración pendiente: $error');
      return null;
    }
  }

  Widget _detail(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true ? value.toString() : '—',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  int _inferStep(Map<String, dynamic> map) {
    if (_hasData(map['emp'])) return 11;
    if (_hasData(map['hora_fin'])) return 10;
    if (_hasData(map['lin1'])) return 8;
    if (_hasData(map['repetibilidad1'])) return 7;
    if (_hasData(map['carga'])) return 6;
    if (_hasData(map['precarga1'])) return 5;
    if (_hasData(map['hora_inicio'])) return 4;
    if (_hasData(map['cod_metrica'])) return 3;
    if (_hasData(map['seca'])) return 2;
    return 0;
  }

  bool _hasData(Object? value) =>
      value != null && value.toString().trim().isNotEmpty;
}

class _ServiceModuleCard extends StatelessWidget {
  final dynamic icon;
  final String title;
  final String eyebrow;
  final String description;
  final String actionLabel;
  final Color color;
  final VoidCallback onTap;

  const _ServiceModuleCard({
    required this.icon,
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.actionLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: AppDesign.mediumRadius,
                ),
                child: Center(child: Icon(icon, color: color, size: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: AppDesign.titleStyle(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(AppIcons.adelante),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
