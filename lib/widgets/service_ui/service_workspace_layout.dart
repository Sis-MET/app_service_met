import 'package:flutter/material.dart';
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
  });

  @override
  State<ServiceWorkspaceLayout> createState() => _ServiceWorkspaceLayoutState();
}

class _ServiceWorkspaceLayoutState extends State<ServiceWorkspaceLayout> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentStep);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sincronizar el PageView si el paso cambió externamente
    if (_pageController.hasClients &&
        _pageController.page?.round() != widget.currentStep) {
      _pageController.jumpToPage(widget.currentStep);
    }

    // La app dibuja detrás de la barra de navegación (edge-to-edge): la
    // pantalla termina encima de ella. Con navegación de tres botones la
    // barra es alta y tapaba la píldora de Siguiente.
    return SafeArea(
      top: false,
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
        body: Column(
          children: [
            StepIndicator(
              currentStep: widget.currentStep,
              steps: widget.steps,
              onStepTapped: widget.onStepTapped,
            ),
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: widget.stepWidgets,
                  ),

                  // FAB info del instrumento
                  if (widget.balanzaInfo != null)
                    Positioned(
                      bottom: 88,
                      right: 20,
                      child: BalanzaInfoButton(info: widget.balanzaInfo!),
                    ),

                  // Pill de navegación flotante
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: ServiceNavPill(
                      label: widget.nextLabel,
                      actionColor: AppColors.actionPositive,
                      onNext: widget.onNext,
                      onBack: widget.onBack,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
