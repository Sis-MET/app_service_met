import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/numeric_keypad.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/widgets/service_ui/service_options_menu.dart';
import 'package:service_met/widgets/service_ui/service_steps_drawer.dart';
import 'package:service_met/widgets/service_ui/balanza_info_button.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/oportunidades/widgets/opportunity_menu_action.dart';
import 'package:service_met/screens/rim/rim_flow.dart';

import 'steps/cliente_step.dart';
import 'steps/planta_step.dart';
import 'steps/seca_step.dart';
import 'steps/balanza_step.dart';
import 'steps/inspeccion_visual_step.dart';
import 'steps/precargas_ajuste_step.dart';
import 'steps/excentricidad_step.dart';
import 'steps/repetibilidad_step.dart';
import 'steps/linealidad_step.dart';
import 'steps/condiciones_finales_step.dart';
import 'steps/exportacion_step.dart';
import 'widgets/indicator_reader_screen.dart';
import 'widgets/save_blocked_dialog.dart';
import 'widgets/calibration_number_field.dart';
import '../../theme/app_icons.dart';

class CalibrationWorkspaceScreen extends StatefulWidget {
  final String userName;
  final String? secaValue;
  final String? sessionId;

  const CalibrationWorkspaceScreen({
    super.key,
    required this.userName,
    this.secaValue,
    this.sessionId,
  });

  @override
  State<CalibrationWorkspaceScreen> createState() =>
      _CalibrationWorkspaceScreenState();
}

class _CalibrationWorkspaceScreenState extends State<CalibrationWorkspaceScreen>
    with WidgetsBindingObserver {
  PageController _pageController = PageController();
  bool _infoButtonVisible = true;
  Timer? _showButtonTimer;

  /// Teclado numérico propio de las lecturas. Mientras escribe ocupa el pie de
  /// la pantalla, donde flota la navegación. En las lecturas del display
  /// ofrece leerlas con la cámara.
  late final NumericKeypadController _keypad;
  late final ServiceSessionProvider _provider;
  final _fieldNavigator = CalibrationFieldNavigator();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _historySessionId;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ServiceSessionProvider>();
    _keypad = NumericKeypadController(
      onReadIndicator: (context) => IndicatorReaderScreen.read(
        context,
        balanza: _provider.session?.balanza,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ServiceSessionProvider>()
          .initialize(
            userName: widget.userName,
            secaValue: widget.secaValue,
            sessionId: widget.sessionId,
          )
          .then((_) {
        if (!mounted) return;
        final step = context.read<ServiceSessionProvider>().currentStep;
        if (step > 0) {
          setState(() {
            _pageController.dispose();
            _pageController = PageController(initialPage: step);
          });
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // En segundo plano Android puede cerrar la aplicación: lo pendiente del
    // autoguardado se escribe ya.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _provider.flushPendingSave();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Fuera del desmontaje: guardar avisa a los oyentes del provider y el
    // árbol está bloqueado.
    final provider = _provider;
    Future.microtask(provider.flushPendingSave);
    _showButtonTimer?.cancel();
    _pageController.dispose();
    _keypad.dispose();
    super.dispose();
  }

  /// Deja el paso [step] solo si sus datos están completos y quedaron
  /// guardados. Si no, dice por qué y se queda: antes se avanzaba aunque el
  /// guardado hubiera fallado y los datos solo existían en pantalla.
  Future<bool> _commitStep(
      BuildContext ctx, ServiceSessionProvider provider, int step) async {
    final issues = provider.stepIssues(step);
    if (issues.isNotEmpty) {
      if (ctx.mounted) {
        await showModalBottomSheet<void>(
          context: ctx,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Datos pendientes',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Corrige estos datos antes de continuar.'),
                const SizedBox(height: 12),
                Flexible(
                    child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: issues.length,
                  itemBuilder: (_, index) {
                    final issue = issues[index];
                    return ListTile(
                      leading: const Icon(AppIcons.error,
                          color: AppColors.actionNegative),
                      title: Text(issue.message),
                      trailing: issue.column == null
                          ? null
                          : const Icon(AppIcons.siguiente, size: 16),
                      onTap: issue.column == null
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              await Future<void>.delayed(
                                  const Duration(milliseconds: 100));
                              if (mounted) {
                                await _fieldNavigator.reveal(issue.column!);
                              }
                            },
                    );
                  },
                )),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cerrar'))),
              ]),
            ),
          ),
        );
      }
      return false;
    }
    if (!await provider.flushAutoSave()) {
      if (ctx.mounted) {
        TopAlert.show(ctx, provider.saveError ?? 'No se pudo guardar.',
            isError: true);
      }
      return false;
    }
    return true;
  }

  /// Atrás del sistema (gesto o botón): primero cierra el panel de pasos o el
  /// teclado, como con los del sistema; después retrocede un paso, igual que
  /// "Anterior". Nunca sale de la calibración: en el primer paso solo avisa
  /// cómo salir.
  void _onSystemBack(ServiceSessionProvider provider) {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }
    if (_keypad.visible) {
      _keypad.close();
      return;
    }
    if (provider.currentStep > 0) {
      provider.previousStep();
      return;
    }
    ServiceOptionsMenu.showFirstStepHint(context);
  }

  /// "Salir (queda guardado)" del menú ⋮, ya confirmado: guarda lo pendiente
  /// y, solo si no se pudo, pregunta antes de cerrar. Devuelve si se puede
  /// cerrar la pantalla.
  Future<bool> _guardarParaSalir(ServiceSessionProvider provider) async {
    _keypad.close();
    if (await provider.flushAutoSave()) return true;
    final error = provider.saveError ?? 'No se pudo guardar.';
    if (!mounted) return false;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hay datos sin guardar'),
        content: SingleChildScrollView(
          child: Text('$error\n\n'
              'Si sale ahora, lo que escribió desde entonces se perderá.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir sin guardar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Corregir'),
          ),
        ],
      ),
    );
    return salir == true;
  }

  /// "Cambiar de balanza" tras emitir el RIM: la balanza en curso queda sin
  /// concluir y se vuelve al paso Instrumento, con la misma SECA.
  Future<void> _cambiarBalanza(BuildContext context) async {
    _keypad.close();
    final error = await _provider.interrumpirBalanza();
    if (!context.mounted) return;
    TopAlert.show(
      context,
      error ?? 'Balanza cerrada sin concluir. Seleccione la siguiente.',
      isError: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceSessionProvider>();

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = provider.session;
    if (session == null) {
      return const Scaffold(
          body: Center(child: Text("Error al cargar la sesión")));
    }
    if (_historySessionId != session.sessionInfo.sessionId) {
      _fieldNavigator.clearHistory();
      _historySessionId = session.sessionInfo.sessionId;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Reset info button visibility when entering a technical step
    if (provider.currentStep >= 5 && !_infoButtonVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.currentStep >= 5) {
          setState(() => _infoButtonVisible = true);
        }
      });
    }

    // Un paso se abre desde el panel ≡ solo si sus anteriores lo permiten
    // (cliente, planta y SECA confirmado). De Inspección en adelante, además,
    // con el instrumento confirmado, como con "Guardar Datos": si no, tras
    // "otra balanza" se podían escribir lecturas sin balanza elegida.
    bool open(int index) =>
        provider.canGoToStep(index) &&
        (index <= 3 || session.metadata.balanzaConfirmed);

    StepProgress progress(int index) {
      final complete = switch (index) {
        0 => (session.cliente?.nombreComercial?.isNotEmpty ?? false),
        1 => (session.planta?.nombre?.isNotEmpty ?? false),
        2 => session.metadata.secaConfirmed,
        3 => session.metadata.balanzaConfirmed,
        >= 4 && <= 9 => provider.validateStep(index) == null,
        _ => false,
      };
      if (complete) return StepProgress.complete;
      return index < provider.currentStep
          ? StepProgress.review
          : StepProgress.pending;
    }

    final steps = [
      StepData(
          title: 'Cliente',
          progress: progress(0),
          subtitle: session.cliente?.nombreComercial ?? 'Seleccione cliente',
          icon: AppIcons.empresa),
      StepData(
          title: 'Planta',
          progress: progress(1),
          subtitle: session.planta?.nombre ?? 'Seleccione planta',
          icon: AppIcons.planta,
          isAccessible: open(1)),
      StepData(
          title: 'SECA',
          progress: progress(2),
          subtitle: session.sessionInfo.seca ?? 'Ingresar SECA',
          icon: AppIcons.qr,
          isAccessible: open(2)),
      StepData(
          title: 'Instrumento',
          progress: progress(3),
          subtitle: session.balanza?.codMetrica ?? 'Seleccionar balanza',
          icon: AppIcons.balanza,
          isAccessible: open(3)),
      StepData(
          title: 'Inspección',
          progress: progress(4),
          subtitle: 'Visual',
          icon: AppIcons.ver,
          isAccessible: open(4)),
      StepData(
          title: 'Precarga/Ajuste',
          progress: progress(5),
          subtitle: 'Datos',
          icon: AppIcons.ajustes,
          isAccessible: open(5)),
      StepData(
          title: 'Excentricidad',
          progress: progress(6),
          subtitle: 'Prueba',
          icon: AppIcons.enfocar,
          isAccessible: open(6)),
      StepData(
          title: 'Repetibilidad',
          progress: progress(7),
          subtitle: 'Prueba',
          icon: AppIcons.repetir,
          isAccessible: open(7)),
      StepData(
          title: 'Linealidad',
          progress: progress(8),
          subtitle: 'Prueba',
          icon: AppIcons.grafico,
          isAccessible: open(8)),
      StepData(
          title: 'Final',
          progress: progress(9),
          subtitle: 'Condiciones',
          icon: AppIcons.completo,
          isAccessible: open(9)),
      StepData(
          title: 'Finalizar',
          progress: progress(10),
          subtitle: 'Reporte',
          icon: AppIcons.descargar,
          isAccessible: open(10)),
    ];

    // Sync page controller if provider step changed externally
    if (_pageController.hasClients &&
        _pageController.page?.round() != provider.currentStep) {
      // Usamos jumpToPage porque el usuario prefirió IndexedStack/PageView sin scroll/animación visible,
      // pero PageView permite inicialización diferida de widgets.
      _pageController.jumpToPage(provider.currentStep);
    }

    // Atrás del sistema nunca cierra: retrocede entre los pasos (ver
    // _onSystemBack); se sale con el menú ⋮. Sin SafeArea abajo: los pasos
    // pasan por detrás de la barra de navegación, como en el inicio. La
    // píldora, el botón de información y el teclado se ubican encima de ella.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onSystemBack(provider);
      },
      child: Scaffold(
        key: _scaffoldKey,
        // Los 11 pasos están en el panel ≡: marca los completos y lleva a
        // cualquiera habilitado. Al abrirlo se cierran el teclado numérico y
        // el del sistema.
        drawer: ServiceStepsDrawer(
          title: 'Calibración',
          steps: steps,
          currentStep: provider.currentStep,
          onStepSelected: (index) {
            if (open(index)) provider.goToStep(index);
          },
        ),
        onDrawerChanged: (isOpen) {
          if (!isOpen) return;
          _keypad.close();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        appBar: ServiceAppBar(
          title: 'Calibración',
          subtitle:
              ServiceStepsDrawer.progressLabel(steps, provider.currentStep),
          centerTitle: true,
          // Sin flecha: entre pasos se navega con la píldora, el panel ≡ o el
          // gesto Atrás, y se sale con el menú ⋮.
          leading: const ServiceStepsButton(),
          actions: [
            if (_fieldNavigator.canUndoInStep(provider.currentStep))
              IconButton(
                tooltip: 'Deshacer última entrada',
                onPressed: () =>
                    _fieldNavigator.undoInStep(provider.currentStep),
                icon: const Icon(AppIcons.deshacer),
              ),
            if (session.metadata.secaConfirmed)
              SaveStatusIndicator(
                status: provider.saveError != null
                    ? SaveStatus.error
                    : provider.isSaving
                        ? SaveStatus.saving
                        : provider.hasPendingSave
                            ? SaveStatus.pending
                            : SaveStatus.local,
              ),
            // RIM y oportunidad comercial (opcionales, en cualquier paso y
            // sin salir de la calibración: leen la sesión, no la modifican) y
            // la única salida a medias, explícita y confirmada. Al salir con
            // una balanza sin terminar se sugiere el RIM.
            ServiceOptionsMenu(
              serviceName: 'la calibración',
              onOpened: _keypad.close,
              onExit: () => _guardarParaSalir(provider),
              exitSuggestion: rimExitSuggestion(
                contextBuilder: () => OpportunityServiceContext.fromCalibration(
                    _provider.session ?? session),
                onCambiarBalanza: _cambiarBalanza,
                enCurso: () =>
                    (_provider.session?.metadata.balanzaConfirmed ?? false) &&
                    _provider.currentStep < 10,
              ),
              actions: [
                RimMenuAction(
                  contextBuilder: () =>
                      OpportunityServiceContext.fromCalibration(
                          _provider.session ?? session),
                  onCambiarBalanza: _cambiarBalanza,
                ),
                OpportunityMenuAction(
                  contextBuilder: () =>
                      OpportunityServiceContext.fromCalibration(
                          _provider.session ?? session),
                ),
              ],
            ),
          ],
        ),
        body: CalibrationFieldNavigationScope(
          navigator: _fieldNavigator,
          child: NumericKeypadScope(
            controller: _keypad,
            child: Column(
              children: [
                if (provider.saveError != null)
                  _SaveErrorBanner(
                    message: provider.saveError!,
                    saving: provider.isSaving,
                    onRetry: provider.flushAutoSave,
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      // Tocar fuera de un campo cierra el teclado numérico. Los
                      // campos, botones y listas atienden su toque antes, y
                      // desplazar la página no cuenta como toque.
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _keypad.close,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            const ClienteStep(),
                            const PlantaStep(),
                            const SecaStep(),
                            const BalanzaStep(),
                            const InspeccionVisualStep(),
                            _scrollHide(const PrecargasAjusteStep()),
                            _scrollHide(const ExcentricidadStep()),
                            _scrollHide(const RepetibilidadStep()),
                            _scrollHide(const LinealidadStep()),
                            _scrollHide(const CondicionesFinalesStep()),
                            _scrollHide(ExportacionStep(
                              key: ValueKey(session.sessionInfo.sessionId),
                            )),
                          ],
                        ),
                      ),

                      // Info button — visible on technical steps, hides on scroll
                      // and while the numeric keypad is open.
                      if (session.balanza != null && provider.currentStep >= 5)
                        Positioned(
                          bottom: ServiceNavPill.bottomOffset(context) + 68,
                          right: 20,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _keypad.visibility,
                            builder: (context, teclado, child) =>
                                teclado ? const SizedBox.shrink() : child!,
                            child: AnimatedOpacity(
                              opacity: _infoButtonVisible ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: AnimatedSlide(
                                offset: _infoButtonVisible
                                    ? Offset.zero
                                    : const Offset(0, 0.3),
                                duration: const Duration(milliseconds: 200),
                                child:
                                    _buildBalanzaInfoButton(provider, isDark),
                              ),
                            ),
                          ),
                        ),

                      // Floating nav buttons — bottom-right, pill grouped. The
                      // numeric keypad takes their place while it is open.
                      Positioned(
                        bottom: ServiceNavPill.bottomOffset(context),
                        right: 20,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _keypad.visibility,
                          builder: (ctx, teclado, _) {
                            if (teclado) return const SizedBox.shrink();
                            final step = provider.currentStep;
                            final meta = provider.session?.metadata;

                            String label = 'Siguiente';
                            Color actionColor = AppColors.actionPositive;
                            VoidCallback? onNext;

                            if (step == 2 &&
                                meta != null &&
                                !meta.secaConfirmed) {
                              label = 'Confirmar SECA';
                              actionColor = AppColors.actionPositive;
                              onNext = () async {
                                if (!await provider.confirmSeca() &&
                                    ctx.mounted) {
                                  TopAlert.show(
                                      ctx,
                                      provider.saveError ??
                                          'No se pudo guardar.',
                                      isError: true);
                                }
                              };
                            } else if (step == 2 &&
                                meta != null &&
                                meta.secaConfirmed) {
                              label = 'Siguiente';
                              actionColor = AppColors.actionPositive;
                              onNext = () async {
                                if (provider.isQrMode) {
                                  final error =
                                      await provider.autoSelectBalanzaFromQr();
                                  if (error != null) {
                                    if (ctx.mounted) {
                                      TopAlert.show(ctx, error, isError: true);
                                    }
                                    return;
                                  }
                                  if (ctx.mounted) {
                                    TopAlert.show(ctx,
                                        'Instrumento identificado automáticamente');
                                  }
                                }
                                provider.nextStep();
                              };
                            } else if (step == 3 &&
                                meta != null &&
                                !meta.balanzaConfirmed) {
                              label = 'Guardar Datos';
                              actionColor = AppColors.actionPositive;
                              onNext = () async {
                                final error = provider.validateStep(3);
                                if (error != null) {
                                  if (ctx.mounted) {
                                    TopAlert.show(ctx, error, isError: true);
                                  }
                                  return;
                                }
                                final duplicateError =
                                    await provider.validateDuplicateBalanza();
                                if (duplicateError != null) {
                                  if (ctx.mounted) {
                                    TopAlert.show(ctx, duplicateError,
                                        isError: true);
                                  }
                                  return;
                                }
                                if (!ctx.mounted) return;
                                final session = provider.session;
                                final b = session?.balanza;
                                final eq = session?.equipos ?? [];
                                final pesas = eq.where((e) {
                                  final t = e.tipo?.toLowerCase() ?? '';
                                  return t.contains('pesa') ||
                                      t.contains('masa') ||
                                      t.contains('patron') ||
                                      t.contains('patr');
                                }).toList();
                                final otros = eq.where((e) {
                                  final t = e.tipo?.toLowerCase() ?? '';
                                  return !(t.contains('pesa') ||
                                      t.contains('masa') ||
                                      t.contains('patron') ||
                                      t.contains('patr'));
                                }).toList();
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (ctx2) {
                                    final isDark = Theme.of(ctx2).brightness ==
                                        Brightness.dark;
                                    return AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(AppIcons.info,
                                              color: isDark
                                                  ? Colors.amber[300]
                                                  : Colors.amber[800],
                                              size: 22),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text('Verificar datos',
                                                  style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? Colors.white
                                                          : AppColors
                                                              .textPrimaryLight))),
                                        ],
                                      ),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                                'Revise la información antes de guardar.',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? Colors.white60
                                                        : Colors.black54)),
                                            const SizedBox(height: 12),
                                            _summaryRow(
                                                'RECA',
                                                session?.sessionInfo.nReca ??
                                                    '-',
                                                isDark),
                                            _summaryRow(
                                                'Sticker',
                                                session?.sessionInfo.sticker ??
                                                    '-',
                                                isDark),
                                            const Divider(height: 16),
                                            _summaryRow('Cód. Métrica',
                                                b?.codMetrica ?? '-', isDark),
                                            _summaryRow(
                                                'Tipo', b?.tipo ?? '-', isDark),
                                            _summaryRow('Marca',
                                                b?.marca ?? '-', isDark),
                                            _summaryRow('Modelo',
                                                b?.modelo ?? '-', isDark),
                                            _summaryRow('Serie',
                                                b?.serie ?? '-', isDark),
                                            const Divider(height: 16),
                                            Text(
                                                'Pesas Patrón (${pesas.length}): ${pesas.map((e) => e.codInstrumento ?? '?').join(', ')}',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black87)),
                                            const SizedBox(height: 4),
                                            Text(
                                                'Ambiente (${otros.length}): ${otros.map((e) => e.codInstrumento ?? '?').join(', ')}',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black87)),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx2, false),
                                          child: Text('Cancelar',
                                              style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white60
                                                      : Colors.black54)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx2, true),
                                          child:
                                              const Text('Confirmar y Guardar'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (confirm == true &&
                                    !await provider.confirmBalanza() &&
                                    ctx.mounted) {
                                  TopAlert.show(
                                      ctx,
                                      provider.saveError ??
                                          'No se pudo guardar.',
                                      isError: true);
                                }
                              };
                            } else if (step == 5) {
                              onNext = () async {
                                if (!await _commitStep(ctx, provider, step)) {
                                  return;
                                }
                                if (provider.returnToCondicionesFinales) {
                                  provider.returnToCondicionesFinales = false;
                                  provider.goToStep(9);
                                } else {
                                  provider.nextStep();
                                }
                              };
                            } else if (step >= 3 && step <= 8) {
                              // Instrumento ya confirmado, Inspección y las pruebas
                              // de excentricidad, repetibilidad y linealidad.
                              onNext = () async {
                                if (!await _commitStep(ctx, provider, step)) {
                                  return;
                                }
                                provider.nextStep();
                              };
                            } else if (step == 9) {
                              onNext = () async {
                                provider.returnToCondicionesFinales = false;
                                if (!await _commitStep(ctx, provider, step)) {
                                  return;
                                }
                                if (!ctx.mounted) return;
                                final mismatch =
                                    provider.validarCondicionesAmbientales();
                                if (mismatch != null && ctx.mounted) {
                                  final isDark = Theme.of(ctx).brightness ==
                                      Brightness.dark;
                                  final accion = await showDialog<String>(
                                    context: ctx,
                                    builder: (ctx2) => AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(AppIcons.advertencia,
                                              color: isDark
                                                  ? Colors.amber[300]
                                                  : Colors.amber[800],
                                              size: 22),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  'Valores ambientales fuera de rango',
                                                  style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? Colors.white
                                                          : AppColors
                                                              .textPrimaryLight))),
                                        ],
                                      ),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              mismatch,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black87),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Puede editar las condiciones iniciales o ignorar y continuar.',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx2, 'editar'),
                                          child: Text(
                                              'Editar condiciones iniciales',
                                              style: TextStyle(
                                                  color: isDark
                                                      ? Colors.amber[300]
                                                      : Colors.amber[800])),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx2, 'ignorar'),
                                          child:
                                              const Text('Ignorar y continuar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (accion == 'editar') {
                                    provider.returnToCondicionesFinales = true;
                                    provider.goToStep(5);
                                    return;
                                  }
                                  if (accion == null) return;
                                }
                                // Solo se marca calibrada si lo escrito quedó en
                                // la base; si no, la balanza sigue abierta.
                                final cierre =
                                    await provider.marcarBalanzaCompleta();
                                if (cierre != null) {
                                  if (ctx.mounted) {
                                    await showSaveBlockedDialog(ctx, cierre);
                                  }
                                  return;
                                }
                                provider.nextStep();
                              };
                            } else {
                              onNext = step < steps.length - 1 &&
                                      provider.canGoToStep(step + 1)
                                  ? () => provider.nextStep()
                                  : null;
                            }

                            return ServiceNavPill(
                              label: label,
                              actionColor: actionColor,
                              onNext: onNext,
                              onBack: provider.currentStep > 0
                                  ? provider.previousStep
                                  : null,
                              // El último paso es el reporte: desde ahí solo se
                              // vuelve atrás.
                              showNext: step < steps.length - 1,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                NumericKeypadSlot(controller: _keypad),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scrollHide(Widget child) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        // Ocultar inmediatamente en cualquier movimiento de scroll
        _showButtonTimer?.cancel();
        if (_infoButtonVisible) {
          setState(() => _infoButtonVisible = false);
        }
        return false;
      },
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (n) {
          // Solo volver a mostrar si el usuario regresó al tope,
          // con un delay para evitar que reaparezca por rebote.
          if (n.metrics.pixels <= 10) {
            _showButtonTimer?.cancel();
            _showButtonTimer = Timer(const Duration(milliseconds: 500), () {
              if (mounted && !_infoButtonVisible) {
                setState(() => _infoButtonVisible = true);
              }
            });
          }
          return false;
        },
        child: child,
      ),
    );
  }

  Widget _buildBalanzaInfoButton(ServiceSessionProvider provider, bool isDark) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.amber,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(AppIcons.info, color: Colors.black87, size: 22),
        onPressed: () {
          final b = provider.session?.balanza;
          final eq = provider.session?.equipos ?? [];
          if (b != null) _showBalanzaInfo(context, b, eq, isDark);
        },
      ),
    );
  }

  void _showBalanzaInfo(BuildContext context, BalanzaInfo b,
      List<EquipoInfo> equipos, bool isDark) {
    bool esPesa(EquipoInfo e) {
      final t = e.tipo?.toLowerCase() ?? '';
      return t.contains('pesa') ||
          t.contains('masa') ||
          t.contains('patron') ||
          t.contains('patr');
    }

    String linea(EquipoInfo e) =>
        '${e.codInstrumento ?? '-'} x${e.cantidad ?? '1'}';
    String? texto(double? valor) => valor?.toString();

    // La misma ficha que en soporte: rangos de menor a mayor capacidad.
    showBalanzaInfoSheet(
      context,
      ServiceBalanzaInfo(
        codMetrica: b.codMetrica,
        tipo: b.tipo,
        categoria: b.categoria,
        marca: b.marca,
        modelo: b.modelo,
        serie: b.serie,
        tecnologia: b.tecnologia,
        clase: b.clase,
        codInterno: b.codInterno,
        unidad: b.unidad,
        ubicacion: b.ubicacion,
        rango: b.rango,
        nCeldas: b.nCeldas,
        capMax1: b.capMax1,
        d1: texto(b.d1),
        e1: texto(b.e1),
        dec1: texto(b.dec1),
        capMax2: b.capMax2,
        d2: texto(b.d2),
        e2: texto(b.e2),
        dec2: texto(b.dec2),
        capMax3: b.capMax3,
        d3: texto(b.d3),
        e3: texto(b.e3),
        dec3: texto(b.dec3),
        pesasPatron: equipos.where(esPesa).map(linea).toList(),
        ambiente: equipos.where((e) => !esPesa(e)).map(linea).toList(),
      ),
      isDark,
    );
  }

  // ponytail: summary helper for confirmation dialog
  Widget _summaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso fijo bajo los pasos mientras la base rechaza el guardado: lo escrito
/// sigue en pantalla pero no está en el teléfono. Antes solo cambiaba el
/// ícono de la barra y el técnico seguía trabajando sin saberlo.
class _SaveErrorBanner extends StatelessWidget {
  const _SaveErrorBanner({
    required this.message,
    required this.saving,
    required this.onRetry,
  });

  final String message;
  final bool saving;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.actionNegative.withOpacity(isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.actionNegative.withOpacity(isDark ? 0.5 : 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(AppIcons.sinConexion,
                  color: AppColors.actionNegative, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$message\n'
                'Lo escrito no se guardará hasta corregirlo.',
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ),
            TextButton(
              onPressed: saving ? null : onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
