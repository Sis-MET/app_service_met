import 'package:flutter/material.dart';
import 'package:service_met/widgets/numeric_keypad.dart';
import 'package:service_met/widgets/service_ui/balanza_info_button.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:service_met/theme/app_colors.dart';

/// Layout base de pantalla de servicio, réplica del workspace de Calibración:
/// Scaffold + AppBar plano + StepIndicator + PageView (sin swipe) +
/// pill de navegación flotante + FAB ámbar de info del instrumento.
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

  /// Metadatos de los pasos para el [StepIndicator].
  final List<StepData> steps;

  /// Contenido de cada paso (mismo orden que [steps]).
  final List<Widget> stepWidgets;

  /// Paso actual (controlado por el padre).
  final int currentStep;

  /// Tap en un segmento del indicador de pasos.
  final ValueChanged<int>? onStepTapped;

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

  const ServiceWorkspaceLayout({
    super.key,
    required this.title,
    required this.steps,
    required this.stepWidgets,
    required this.currentStep,
    this.onStepTapped,
    this.nextLabel = 'Siguiente',
    this.nextColor = AppColors.actionPositive,
    this.onNext,
    this.onBack,
    this.saveStatus = SaveStatus.idle,
    this.showSaveStatus = true,
    this.appBarActions,
    this.balanzaInfo,
    this.hideBackButton = false,
    this.onReadIndicator,
    this.canPop = true,
    this.onPopBlocked,
  });

  @override
  State<ServiceWorkspaceLayout> createState() => _ServiceWorkspaceLayoutState();
}

class _ServiceWorkspaceLayoutState extends State<ServiceWorkspaceLayout> {
  late PageController _pageController;

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
  void dispose() {
    _pageController.dispose();
    _keypad.dispose();
    super.dispose();
  }

  void _onPopInvoked(bool didPop) {
    if (didPop) return;
    // Atrás primero cierra el teclado, como con el del sistema.
    if (_keypad.visible) {
      _keypad.close();
      return;
    }
    widget.onPopBlocked?.call();
  }

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

    // Sin SafeArea abajo: los pasos pasan por detrás de la barra de
    // navegación, como en el inicio. La píldora, el botón de información y el
    // teclado se ubican encima de ella.
    return ValueListenableBuilder<bool>(
      valueListenable: _keypad.visibility,
      builder: (context, teclado, child) => PopScope(
        canPop: !teclado && widget.canPop,
        onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
        child: child!,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: ServiceAppBar(
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
              StepIndicator(
                currentStep: widget.currentStep,
                steps: widget.steps,
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
