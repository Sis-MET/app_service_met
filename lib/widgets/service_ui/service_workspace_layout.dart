import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:service_met/widgets/numeric_keypad.dart';
import 'package:service_met/widgets/service_ui/balanza_info_button.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_options_menu.dart';
import 'package:service_met/widgets/service_ui/service_steps_drawer.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:service_met/theme/app_colors.dart';

/// Layout base de pantalla de servicio, réplica del workspace de Calibración:
/// Scaffold + AppBar plano + PageView (sin swipe) + pill de navegación
/// flotante + FAB ámbar de info del instrumento.
///
/// En un servicio en curso ([onExit]) los pasos están en el panel ≡ del
/// AppBar y el título va centrado con el paso actual debajo. Sin [onExit]
/// (la precarga) se muestra la barra de pasos ([StepIndicator]) bajo el
/// AppBar.
///
/// El padre controla [currentStep] y las acciones [onNext]/[onBack];
/// este widget sincroniza el [PageView] automáticamente.
///
/// Como en la calibración, los campos numéricos de los pasos
/// (`CalibrationNumberField`) escriben con el teclado propio, que ocupa el
/// pie de la pantalla en lugar de la píldora. Con [onReadIndicator], las
/// lecturas del display ofrecen "Leer del indicador".
class ServiceWorkspaceLayout extends StatefulWidget {
  /// Título del AppBar.
  final String title;

  /// Metadatos de los pasos para el panel ≡ o el [StepIndicator].
  final List<StepData> steps;

  /// Contenido de cada paso (mismo orden que [steps]).
  final List<Widget> stepWidgets;

  /// Paso actual (controlado por el padre).
  final int currentStep;

  /// Paso elegido en el panel ≡ o en la barra de pasos.
  final ValueChanged<int>? onStepTapped;

  /// Qué le falta a un paso para darlo por completo; null si no le falta
  /// nada. Marca los pasos del panel ≡ cuando [steps] no traen su progreso,
  /// y deja abrir un paso adelante solo con los anteriores completos. Sin
  /// él, un paso cuenta como completo cuando el técnico ya pasó por él.
  final String? Function(int step)? stepIssue;

  /// Etiqueta del botón de acción ("Siguiente", "Guardar Datos", "Finalizar").
  final String nextLabel;

  /// Color del botón de acción.
  final Color nextColor;

  /// Acción del botón principal. Null = deshabilitado.
  final VoidCallback? onNext;

  /// Acción del botón atrás. Null = deshabilitado.
  final VoidCallback? onBack;

  /// Estado del guardado para el indicador del AppBar.
  final SaveStatus saveStatus;

  /// Si false, no muestra indicador de guardado en el AppBar.
  final bool showSaveStatus;

  /// Acciones extra del AppBar (antes del indicador de guardado).
  final List<Widget>? appBarActions;

  /// Opciones del menú ⋮, sobre "Salir (queda guardado)" (requiere [onExit]).
  final List<ServiceMenuAction> menuActions;

  /// Si se provee, muestra el FAB ámbar con la ficha del instrumento.
  final ServiceBalanzaInfo? balanzaInfo;

  /// Si true, el leading del AppBar queda deshabilitado.
  final bool hideBackButton;

  /// Lector del display de la balanza para los campos marcados como lectura
  /// (indicaciones y retornos). Sin él, el teclado no ofrece leer.
  final IndicatorReader? onReadIndicator;

  /// Si se puede salir con el botón o gesto Atrás. Con el teclado abierto,
  /// Atrás siempre lo cierra primero.
  final bool canPop;

  /// Atrás cuando [canPop] es false (y el teclado está cerrado): confirmar la
  /// salida, guardar, etc. La pantalla que lo usa decide si hace `pop`.
  final VoidCallback? onPopBlocked;

  /// Salida explícita de un servicio en curso: agrega el menú ⋮ con
  /// "Salir (queda guardado)", que confirma y luego llama a [onExit] (guardar
  /// lo pendiente y devolver si se puede cerrar).
  ///
  /// Con él, el AppBar lleva ≡ con los pasos en vez de flecha y Atrás del
  /// sistema solo retrocede entre pasos, como [onBack]: nunca saca del
  /// servicio. En el primer paso Atrás muestra un aviso.
  final Future<bool> Function()? onExit;

  const ServiceWorkspaceLayout({
    super.key,
    required this.title,
    required this.steps,
    required this.stepWidgets,
    required this.currentStep,
    this.onStepTapped,
    this.stepIssue,
    this.nextLabel = 'Siguiente',
    this.nextColor = AppColors.actionPositive,
    this.onNext,
    this.onBack,
    this.saveStatus = SaveStatus.idle,
    this.showSaveStatus = true,
    this.appBarActions,
    this.menuActions = const [],
    this.balanzaInfo,
    this.hideBackButton = false,
    this.onReadIndicator,
    this.canPop = true,
    this.onPopBlocked,
    this.onExit,
  });

  @override
  State<ServiceWorkspaceLayout> createState() => _ServiceWorkspaceLayoutState();
}

class _ServiceWorkspaceLayoutState extends State<ServiceWorkspaceLayout> {
  late PageController _pageController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Paso más avanzado al que llegó el técnico en esta pantalla.
  late int _reached = widget.currentStep;

  /// Siempre llama al lector vigente del widget: la pantalla puede
  /// reconstruirse con otra balanza sin rehacer el teclado.
  late final NumericKeypadController _keypad = NumericKeypadController(
    onReadIndicator: widget.onReadIndicator == null
        ? null
        : (context) async => widget.onReadIndicator?.call(context),
  );

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentStep);
  }

  @override
  void didUpdateWidget(covariant ServiceWorkspaceLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reached = math.max(_reached, widget.currentStep);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _keypad.dispose();
    super.dispose();
  }

  /// Con [ServiceWorkspaceLayout.onExit], Atrás nunca cierra la pantalla.
  bool get _stepsOnly => widget.onExit != null;

  void _onPopInvoked(bool didPop) {
    if (didPop) return;
    // Atrás primero cierra el panel de pasos o el teclado, como con los del
    // sistema.
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }
    if (_keypad.visible) {
      _keypad.close();
      return;
    }
    // Después retrocede un paso, igual que "Anterior" de la píldora.
    final onBack = widget.onBack;
    if (onBack != null && (_stepsOnly || !widget.canPop)) {
      onBack();
      return;
    }
    if (_stepsOnly) {
      ServiceOptionsMenu.showFirstStepHint(context);
      return;
    }
    widget.onPopBlocked?.call();
  }

  /// Progreso de cada paso para el panel ≡. El que ya lo trae se respeta.
  /// Con [ServiceWorkspaceLayout.stepIssue] manda lo registrado: completo si
  /// no le falta nada (también al reabrir el servicio) y, si le falta algo y
  /// el técnico ya pasó por él, por revisar. Sin reglas, cuenta como completo
  /// lo ya recorrido.
  StepProgress _progressOf(int index) {
    final given = widget.steps[index].progress;
    if (given != null) return given;
    final stepIssue = widget.stepIssue;
    if (stepIssue == null) {
      return index < _reached ? StepProgress.complete : StepProgress.pending;
    }
    if (stepIssue(index) == null) return StepProgress.complete;
    return index < _reached ? StepProgress.review : StepProgress.pending;
  }

  /// Con reglas, un paso adelante se abre solo con todos los anteriores
  /// completos, igual que al avanzar con "Siguiente".
  bool _canOpen(int index) {
    if (!widget.steps[index].isAccessible) return false;
    final stepIssue = widget.stepIssue;
    if (stepIssue == null || index <= widget.currentStep) return true;
    for (var i = 0; i < index; i++) {
      if (stepIssue(i) != null) return false;
    }
    return true;
  }

  List<StepData> get _stepsWithProgress => [
        for (var i = 0; i < widget.steps.length; i++)
          StepData(
            title: widget.steps[i].title,
            subtitle: widget.steps[i].subtitle,
            icon: widget.steps[i].icon,
            isAccessible: _canOpen(i),
            progress: _progressOf(i),
          ),
      ];

  /// Oculta [child] mientras el teclado ocupa el pie de la pantalla.
  Widget _hiddenWithKeypad(Widget child) => ValueListenableBuilder<bool>(
        valueListenable: _keypad.visibility,
        builder: (context, teclado, child) =>
            teclado ? const SizedBox.shrink() : child!,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    // Sincronizar el PageView si el paso cambió externamente
    if (_pageController.hasClients &&
        _pageController.page?.round() != widget.currentStep) {
      _pageController.jumpToPage(widget.currentStep);
    }

    final steps = _stepsOnly ? _stepsWithProgress : widget.steps;

    // Sin SafeArea abajo: los pasos pasan por detrás de la barra de
    // navegación, como en el inicio. La píldora, el botón de información y el
    // teclado se ubican encima de ella.
    return ValueListenableBuilder<bool>(
      valueListenable: _keypad.visibility,
      builder: (context, teclado, child) => PopScope(
        canPop: !teclado && widget.canPop && !_stepsOnly,
        onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
        child: child!,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // En un servicio en curso los pasos están en el panel ≡; al abrirlo
        // (con el botón o deslizando desde el borde) se cierran el teclado
        // numérico y el del sistema.
        drawer: _stepsOnly
            ? ServiceStepsDrawer(
                title: widget.title,
                steps: steps,
                currentStep: widget.currentStep,
                onStepSelected: widget.onStepTapped,
              )
            : null,
        onDrawerChanged: (isOpen) {
          if (!isOpen) return;
          _keypad.close();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        appBar: _stepsOnly
            ? ServiceAppBar(
                title: widget.title,
                subtitle: ServiceStepsDrawer.progressLabel(
                    widget.steps, widget.currentStep),
                centerTitle: true,
                leading: const ServiceStepsButton(),
                actions: [
                  ...?widget.appBarActions,
                  if (widget.showSaveStatus)
                    SaveStatusIndicator(status: widget.saveStatus),
                  ServiceOptionsMenu(
                    onExit: widget.onExit!,
                    actions: widget.menuActions,
                    onOpened: _keypad.close,
                  ),
                ],
              )
            : ServiceAppBar(
                title: widget.title,
                automaticallyImplyLeading: !widget.hideBackButton,
                actions: [
                  ...?widget.appBarActions,
                  if (widget.showSaveStatus)
                    SaveStatusIndicator(status: widget.saveStatus),
                ],
              ),
        body: NumericKeypadScope(
          controller: _keypad,
          child: Column(
            children: [
              if (!_stepsOnly)
                StepIndicator(
                  currentStep: widget.currentStep,
                  steps: steps,
                  onStepTapped: widget.onStepTapped,
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
                        children: widget.stepWidgets,
                      ),
                    ),

                    // FAB info del instrumento
                    if (widget.balanzaInfo != null)
                      Positioned(
                        bottom: ServiceNavPill.bottomOffset(context) + 68,
                        right: 20,
                        child: _hiddenWithKeypad(
                          BalanzaInfoButton(info: widget.balanzaInfo!),
                        ),
                      ),

                    // Pill de navegación flotante. El teclado numérico toma su
                    // lugar mientras está abierto.
                    Positioned(
                      bottom: ServiceNavPill.bottomOffset(context),
                      right: 20,
                      child: _hiddenWithKeypad(
                        ServiceNavPill(
                          label: widget.nextLabel,
                          actionColor: AppColors.actionPositive,
                          onNext: widget.onNext,
                          onBack: widget.onBack,
                        ),
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
    );
  }
}
