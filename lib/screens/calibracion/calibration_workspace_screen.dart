import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/screens/calibracion/widgets/step_indicator.dart';

// Import placeholder steps (they will be created in phase 5)
import 'steps/cliente_step.dart';
import 'steps/planta_step.dart';
import 'steps/seca_step.dart';
import 'steps/balanza_step.dart';
import 'steps/inspeccion_visual_step.dart';
import 'steps/precargas_ajuste_step.dart';
import 'steps/excentricidad_step.dart';
import 'steps/repetibilidad_step.dart';
import 'steps/linealidad_step.dart';
import 'steps/foto_carga_step.dart';
import 'steps/condiciones_finales_step.dart';
import 'steps/exportacion_step.dart';

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
  State<CalibrationWorkspaceScreen> createState() => _CalibrationWorkspaceScreenState();
}

class _CalibrationWorkspaceScreenState extends State<CalibrationWorkspaceScreen> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceSessionProvider>().initialize(
        userName: widget.userName,
        secaValue: widget.secaValue,
        sessionId: widget.sessionId,
      ).then((_) {
        // Sync page controller with loaded step
        final step = context.read<ServiceSessionProvider>().currentStep;
        if (_pageController.hasClients && step > 0) {
          _pageController.jumpToPage(step);
        }
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceSessionProvider>();
    
    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = provider.session;
    if (session == null) {
      return const Scaffold(body: Center(child: Text("Error al cargar la sesión")));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Validate accessibility for steps
    bool hasSeca = session.metadata.secaConfirmed;
    
    final steps = [
      StepData(title: 'Cliente', subtitle: session.cliente?.nombreComercial ?? 'Seleccione cliente', icon: Icons.business),
      StepData(title: 'Planta', subtitle: session.planta?.nombre ?? 'Seleccione planta', icon: Icons.factory),
      StepData(title: 'SECA', subtitle: session.sessionInfo.seca ?? 'Ingresar SECA', icon: Icons.qr_code),
      StepData(title: 'Instrumento', subtitle: session.balanza?.codMetrica ?? 'Seleccionar balanza', icon: Icons.scale, isAccessible: hasSeca),
      StepData(title: 'Inspección', subtitle: 'Visual', icon: Icons.visibility, isAccessible: hasSeca),
      StepData(title: 'Precarga/Ajuste', subtitle: 'Datos', icon: Icons.settings, isAccessible: hasSeca),
      StepData(title: 'Excentricidad', subtitle: 'Prueba', icon: Icons.center_focus_strong, isAccessible: hasSeca),
      StepData(title: 'Repetibilidad', subtitle: 'Prueba', icon: Icons.repeat, isAccessible: hasSeca),
      StepData(title: 'Linealidad', subtitle: 'Prueba', icon: Icons.show_chart, isAccessible: hasSeca),
      StepData(title: 'Foto Carga', subtitle: 'Evidencia', icon: Icons.camera_alt, isAccessible: hasSeca),
      StepData(title: 'Final', subtitle: 'Condiciones', icon: Icons.check_circle, isAccessible: hasSeca),
      StepData(title: 'Exportar', subtitle: 'Reporte', icon: Icons.download, isAccessible: hasSeca),
    ];

    // Sync page controller if provider step changed externally
    if (_pageController.hasClients && _pageController.page?.round() != provider.currentStep) {
      // Usamos jumpToPage porque el usuario prefirió IndexedStack/PageView sin scroll/animación visible, 
      // pero PageView permite inicialización diferida de widgets.
      _pageController.jumpToPage(provider.currentStep);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CALIBRACIÓN'),
        actions: [
          if (provider.isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else if (!provider.lastSaveSuccessful)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Icon(Icons.error_outline, color: Colors.red),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Icon(Icons.cloud_done, color: Colors.green),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          StepIndicator(
            currentStep: provider.currentStep,
            steps: steps,
            onStepTapped: (index) {
              if (provider.canGoToStep(index)) {
                provider.goToStep(index);
              }
            },
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Desactivamos swipe manual para obligar uso del UI de navegación
              children: const [
                ClienteStep(),
                PlantaStep(),
                SecaStep(),
                BalanzaStep(),
                InspeccionVisualStep(),
                PrecargasAjusteStep(),
                ExcentricidadStep(),
                RepetibilidadStep(),
                LinealidadStep(),
                FotoCargaStep(),
                CondicionesFinalesStep(),
                ExportacionStep(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: provider.currentStep > 0
                    ? () => provider.previousStep()
                    : null,
                child: const Text('Anterior'),
              ),
              ElevatedButton(
                onPressed: provider.currentStep < steps.length - 1 && provider.canGoToStep(provider.currentStep + 1)
                    ? () => provider.nextStep()
                    : null,
                child: const Text('Siguiente'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: hasSeca
          ? FloatingActionButton(
              onPressed: () {
                // TODO: Show balanza info dialog
              },
              child: const Icon(Icons.info_outline),
              mini: true,
            )
          : null,
    );
  }
}
