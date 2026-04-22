// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_met/screens/calibracion/precarga/widgets/step_indicator.dart';
import 'fin_servicios_controller.dart';
import 'widgets/condiciones_finales_step.dart';
import 'widgets/exportacion_step.dart';

class FinServiciosScreen extends StatelessWidget {
  final String secaValue;
  final String sessionId;
  final String codMetrica;
  final Map<String, dynamic> selectedBalanza;

  const FinServiciosScreen({
    super.key,
    required this.secaValue,
    required this.sessionId,
    required this.codMetrica,
    required this.selectedBalanza,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FinServiciosController(
        secaValue: secaValue,
        sessionId: sessionId,
        codMetrica: codMetrica,
        context: context,
      ),
      child: Consumer<FinServiciosController>(
        builder: (context, controller, child) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDarkMode ? Colors.white : Colors.black;

          final List<StepData> steps = [
            StepData(
              title: 'Condiciones Finales',
              subtitle: 'Registro de datos',
              icon: Icons.assignment,
            ),
            StepData(
              title: 'Finalizar',
              subtitle: 'Exportación',
              icon: Icons.check_circle,
            ),
          ];

          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 70,
              title: Text(
                'CALIBRACIÓN',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              backgroundColor: isDarkMode ? Colors.transparent : Colors.white,
              elevation: 0,
              flexibleSpace: isDarkMode
                  ? ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(color: Colors.black.withOpacity(0.4)),
                      ),
                    )
                  : null,
              iconTheme: IconThemeData(color: textColor),
              centerTitle: true,
            ),
            body: Column(
              children: [
                StepIndicator(
                  currentStep: controller.currentStep,
                  steps: steps,
                ),
                Expanded(
                  child: IndexedStack(
                    index: controller.currentStep,
                    children: const [
                      CondicionesFinalesStep(),
                      ExportacionStep(),
                    ],
                  ),
                ),
                _buildBottomButtons(context, controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomButtons(
      BuildContext context, FinServiciosController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador de auto-guardado
          _buildAutoSaveIndicator(controller),
          const SizedBox(height: 8),
          Row(
            children: [
              if (controller.currentStep > 0)
                SizedBox(
                  width: 110,
                  child: OutlinedButton.icon(
                    onPressed: () => controller.previousStep(),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Anterior'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (controller.currentStep > 0) const SizedBox(width: 12),
              if (controller.currentStep == 0)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (controller.validateStep1()) {
                        await controller.saveStep1();
                        if (controller.isDataSaved) {
                          controller.nextStep();
                        }
                      }
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Siguiente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSaveIndicator(FinServiciosController controller) {
    if (controller.currentStep != 0) return const SizedBox.shrink();

    if (controller.isAutoSaving) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Guardando...',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      );
    } else if (controller.lastSaveSuccessful) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done_outlined, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            'Guardado automáticamente',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
