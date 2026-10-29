import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../utils/top_alert.dart';
import '../../widgets/service_ui/nav_pill.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../../widgets/service_ui/service_options_menu.dart';
import '../../widgets/service_ui/service_steps_drawer.dart';
import '../../widgets/service_ui/step_indicator.dart';
import '../oportunidades/widgets/opportunity_password_prompt.dart'
    show serviceMetAppVersion;
import 'controllers/temperatura_controller.dart';
import 'models/temperatura_models.dart';
import 'steps/cierre_step.dart';
import 'steps/equipo_step.dart';
import 'steps/inicio_steps.dart';
import 'steps/medicion_step.dart';
import 'steps/patrones_step.dart';
import 'steps/puntos_step.dart';
import 'steps/resumen_step.dart';

/// Calibración de temperatura de un equipo (mufla, horno, estufa…), paso a
/// paso, con la misma forma que la calibración de balanzas: panel ≡ con los
/// pasos, píldora para avanzar, guardado automático y ⋮ para salir.
class TemperaturaWorkspaceScreen extends StatefulWidget {
  const TemperaturaWorkspaceScreen({
    super.key,
    required this.userName,
    this.uuid,
    this.controllerBuilder,
  });

  final String userName;

  /// El registro a continuar; sin él se crea uno nuevo.
  final String? uuid;

  /// Solo para pruebas.
  final TemperaturaController Function()? controllerBuilder;

  @override
  State<TemperaturaWorkspaceScreen> createState() =>
      _TemperaturaWorkspaceScreenState();
}

class _TemperaturaWorkspaceScreenState extends State<TemperaturaWorkspaceScreen>
    with WidgetsBindingObserver {
  late final TemperaturaController _controller =
      widget.controllerBuilder?.call() ??
          TemperaturaController(
            userName: widget.userName,
            appVersion: serviceMetAppVersion,
          );
  final _cotizacion = ValueNotifier('C01');
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  PageController? _pages;
  String? _uuid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_syncPage);
    _controller.abrir(uuid: widget.uuid);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.guardarYa();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_syncPage);
    _controller.dispose();
    _cotizacion.dispose();
    _pages?.dispose();
    super.dispose();
  }

  int get _visible => _controller.servicio.finalizado
      ? PasoTemp.resumen
      : _controller.paso.clamp(0, PasoTemp.total - 1);

  void _syncPage() {
    if (!_controller.listo) return;
    // Otro registro (otro equipo de la misma SECA): la página vuelve a
    // empezar en su paso.
    if (_uuid != _controller.servicio.uuid) {
      _uuid = _controller.servicio.uuid;
      _pages?.dispose();
      _pages = PageController(initialPage: _visible);
      if (mounted) setState(() {});
      return;
    }
    final pages = _pages;
    if (pages != null && pages.hasClients && pages.page?.round() != _visible) {
      pages.jumpToPage(_visible);
    }
  }

  Future<void> _mostrarFaltantes(List<String> faltan) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Datos pendientes',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Complete estos datos antes de continuar.'),
              const SizedBox(height: 8),
              for (final texto in faltan)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.error,
                      color: AppColors.actionNegative),
                  title: Text(texto),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _siguiente() async {
    final c = _controller;
    final paso = c.paso;
    switch (paso) {
      case PasoTemp.seca when !c.servicio.secaConfirmada:
        final error = await c.confirmarSeca(c.secaPropuesta(_cotizacion.value));
        if (!mounted) return;
        if (error != null) {
          TopAlert.show(context, error, isError: true);
        } else {
          TopAlert.show(context, 'SECA ${c.servicio.seca} confirmada.');
        }
        return;
      case PasoTemp.equipo when !c.servicio.equipoConfirmado:
        await _confirmarEquipo();
        return;
      case PasoTemp.cierre:
        await _finalizar();
        return;
    }
    final faltan = c.faltantes(paso);
    if (faltan.isNotEmpty) {
      await _mostrarFaltantes(faltan);
      return;
    }
    if (!await c.guardarYa()) {
      if (mounted) {
        TopAlert.show(context, c.saveError ?? 'No se pudo guardar.',
            isError: true);
      }
      return;
    }
    await c.irA(paso + 1);
  }

  Future<void> _confirmarEquipo() async {
    final c = _controller;
    final faltan = c.faltantes(PasoTemp.equipo);
    if (faltan.isNotEmpty) {
      await _mostrarFaltantes(faltan);
      return;
    }
    final equipo = c.servicio.equipo!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(AppIcons.temperatura),
        title: const Text('Confirmar equipo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Revise los datos: después quedan fijos en el '
                  'registro.'),
              const SizedBox(height: 12),
              for (final (etiqueta, valor) in datosEquipo(equipo))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('$etiqueta: ${valor ?? '—'}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar y guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await c.confirmarEquipo();
    if (!mounted) return;
    if (error != null) {
      TopAlert.show(context, error, isError: true);
    } else {
      await c.irA(PasoTemp.patrones);
    }
  }

  Future<void> _finalizar() async {
    final c = _controller;
    final faltan = [
      ...c.faltantes(PasoTemp.medicion),
      ...c.faltantes(PasoTemp.cierre),
    ];
    if (faltan.isNotEmpty) {
      await _mostrarFaltantes(faltan);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(AppIcons.bloqueado),
        title: const Text('Finalizar la calibración'),
        content: const Text(
          'Desde aquí el registro ya no se modifica: las lecturas, '
          'correcciones y datos quedan como están para subirlos a DataMET.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await c.finalizar();
    if (!mounted) return;
    TopAlert.show(context, error ?? 'Calibración finalizada.',
        isError: error != null);
  }

  void _atras() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }
    final c = _controller;
    if (!c.listo || c.servicio.finalizado || c.paso == 0) {
      if (c.listo && c.servicio.finalizado) {
        Navigator.of(context).maybePop();
        return;
      }
      ServiceOptionsMenu.showFirstStepHint(context);
      return;
    }
    c.irA(c.paso - 1);
  }

  Future<bool> _salir() async {
    if (await _controller.guardarYa()) return true;
    if (!mounted) return false;
    final salir = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hay datos sin guardar'),
        content: Text('${_controller.saveError ?? 'No se pudo guardar.'}\n\n'
            'Si sale ahora, lo que escribió desde entonces se perderá.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir sin guardar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Corregir'),
          ),
        ],
      ),
    );
    return salir == true;
  }

  List<StepData> _pasos(TemperaturaController c) {
    final s = c.servicio;
    StepProgress progreso(int i) {
      final completo = switch (i) {
        PasoTemp.resumen => s.finalizado,
        PasoTemp.cierre => s.finalizado,
        _ => c.faltantes(i).isEmpty,
      };
      if (completo) return StepProgress.complete;
      return i < c.paso ? StepProgress.review : StepProgress.pending;
    }

    StepData paso(int i, String titulo, String subtitulo, IconData icon) =>
        StepData(
          title: titulo,
          subtitle: subtitulo,
          icon: icon,
          progress: progreso(i),
          isAccessible: c.puedeAbrir(i),
        );

    final unidad = s.equipo?.unidad ?? '°C';
    return [
      paso(PasoTemp.cliente, 'Cliente',
          s.cliente?.nombre ?? 'Seleccione cliente', AppIcons.empresa),
      paso(PasoTemp.planta, 'Planta', s.planta?.nombre ?? 'Seleccione planta',
          AppIcons.planta),
      paso(PasoTemp.seca, 'SECA', s.seca ?? 'Confirmar SECA', AppIcons.qr),
      paso(PasoTemp.equipo, 'Equipo',
          s.equipo?.codMetrica ?? 'Seleccionar equipo', AppIcons.temperatura),
      paso(
          PasoTemp.patrones,
          'Patrones y sensores',
          '${c.canales.where((k) => k.rol == RolCanal.patron).length} sensores',
          AppIcons.laboratorio),
      paso(
          PasoTemp.puntos,
          'Puntos',
          c.puntos.isEmpty
              ? 'Configurar'
              : c.puntos
                  .map((p) => '${textoNumero(p.temperaturaNominal)} $unidad')
                  .join(' · '),
          AppIcons.listaNumerada),
      paso(PasoTemp.medicion, 'Medición', 'Captura programada',
          AppIcons.grafico),
      paso(PasoTemp.cierre, 'Cierre', 'Condiciones finales',
          AppIcons.formularioCompleto),
      paso(
          PasoTemp.resumen, 'Resumen', 'Resultados y subida', AppIcons.resumen),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<TemperaturaController>(
        builder: (context, c, _) {
          if (c.cargando && !c.listo) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!c.listo) {
            return Scaffold(
              appBar: const ServiceAppBar(title: 'Temperatura'),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child:
                      Text(c.errorCarga ?? 'No se pudo abrir la calibración.'),
                ),
              ),
            );
          }
          final pages = _pages ??= PageController(initialPage: _visible);
          _uuid ??= c.servicio.uuid;
          final pasos = _pasos(c);
          final visible = _visible;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _atras();
            },
            child: Scaffold(
              key: _scaffoldKey,
              drawer: ServiceStepsDrawer(
                title: 'Calibración de temperatura',
                steps: pasos,
                currentStep: visible,
                onStepSelected: (i) {
                  if (c.puedeAbrir(i)) c.irA(i);
                },
              ),
              onDrawerChanged: (open) {
                if (open) FocusManager.instance.primaryFocus?.unfocus();
              },
              appBar: ServiceAppBar(
                title: 'Temperatura',
                subtitle: ServiceStepsDrawer.progressLabel(pasos, visible),
                centerTitle: true,
                leading: const ServiceStepsButton(),
                actions: [
                  if (c.servicio.secaConfirmada && c.editable)
                    SaveStatusIndicator(
                      status: c.saveError != null
                          ? SaveStatus.error
                          : c.guardando
                              ? SaveStatus.saving
                              : c.pendiente
                                  ? SaveStatus.pending
                                  : SaveStatus.local,
                    ),
                  ServiceOptionsMenu(
                    serviceName: 'la calibración de temperatura',
                    onExit: _salir,
                  ),
                ],
              ),
              body: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: PageView(
                      controller: pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        const ClienteTempStep(),
                        const PlantaTempStep(),
                        SecaTempStep(cotizacion: _cotizacion),
                        const EquipoTempStep(),
                        const PatronesTempStep(),
                        const PuntosTempStep(),
                        const MedicionTempStep(),
                        const CierreTempStep(),
                        const ResumenTempStep(),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: ServiceNavPill.bottomOffset(context),
                    right: 20,
                    child: ServiceNavPill(
                      label: switch (visible) {
                        PasoTemp.seca when !c.servicio.secaConfirmada =>
                          'Confirmar SECA',
                        PasoTemp.equipo when !c.servicio.equipoConfirmado =>
                          'Guardar equipo',
                        PasoTemp.cierre => 'Finalizar',
                        _ => 'Siguiente',
                      },
                      actionColor: visible == PasoTemp.cierre
                          ? AppColors.navFinalize
                          : AppColors.actionPositive,
                      onNext: visible >= PasoTemp.resumen ? null : _siguiente,
                      onBack: c.servicio.finalizado || visible == 0
                          ? null
                          : () => c.irA(visible - 1),
                      showNext: visible < PasoTemp.resumen,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
