import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/screens/soporte/widgets/balanza_speed_dial.dart';

class SoporteStepData {
  final String title;
  final String subtitle;
  final IconData icon;

  SoporteStepData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class SoporteStepperLayout extends StatelessWidget {
  final String title;
  final String codMetrica;
  final List<SoporteStepData> steps;
  final int currentStep;
  final bool isSaving;
  final bool isLoading;
  final Widget stepContent;
  
  // Callbacks
  final Future<void> Function(int) onStepTapped;
  final Future<void> Function() onNext;
  final VoidCallback onBack;
  final Future<bool> Function() onWillPop;
  
  // Opcionales para el AutoSave
  final ValueNotifier<bool>? isAutoSavingNotifier;
  final ValueNotifier<bool>? lastSaveSuccessfulNotifier;
  
  // Customizacion
  final String nextButtonText;
  final String finalButtonText;

  const SoporteStepperLayout({
    super.key,
    required this.title,
    required this.codMetrica,
    required this.steps,
    required this.currentStep,
    required this.stepContent,
    required this.onStepTapped,
    required this.onNext,
    required this.onBack,
    required this.onWillPop,
    this.isSaving = false,
    this.isLoading = false,
    this.isAutoSavingNotifier,
    this.lastSaveSuccessfulNotifier,
    this.nextButtonText = 'SIGUIENTE',
    this.finalButtonText = 'FINALIZAR',
  });

  Widget _buildAutoSaveIndicator() {
    if (isAutoSavingNotifier == null || lastSaveSuccessfulNotifier == null) {
      return const SizedBox.shrink();
    }
    
    return ValueListenableBuilder<bool>(
      valueListenable: isAutoSavingNotifier!,
      builder: (context, isSaving, _) {
        if (isSaving) {
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
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: lastSaveSuccessfulNotifier!,
          builder: (context, success, _) {
            if (success) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done_outlined,
                      size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Guardado automáticamente',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, bool isDarkMode) {
    final primaryColor = Theme.of(context).primaryColor;
    if (steps.isEmpty) return const SizedBox.shrink();
    
    final step = steps[currentStep];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Pill con icono + nombre
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(step.icon, size: 13, color: primaryColor),
                    const SizedBox(width: 5),
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Subtitle sutil
              Expanded(
                child: Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Contador
              Text(
                '${currentStep + 1} / ${steps.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Barra delgada segmentada animada
          Row(
            children: List.generate(steps.length, (i) {
              final isCompleted = i < currentStep;
              final isCurrent = i == currentStep;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onStepTapped(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: 3,
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? primaryColor
                          : isCurrent
                              ? primaryColor.withOpacity(0.55)
                              : (isDarkMode
                                  ? Colors.white12
                                  : Colors.black.withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black26 : Colors.white,
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
          _buildAutoSaveIndicator(),
          if (isAutoSavingNotifier != null) const SizedBox(height: 8),
          Row(
            children: [
              // Botón Anterior
              if (currentStep > 0)
                SizedBox(
                  width: 110,
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : onBack,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('ANTERIOR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

              if (currentStep > 0) const SizedBox(width: 12),

              // Botón Siguiente/Finalizar
              Expanded(
                flex: currentStep == 0 ? 1 : 2,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : onNext,
                  icon: Icon(
                    currentStep < steps.length - 1
                        ? Icons.arrow_forward
                        : Icons.check_circle,
                  ),
                  label: Text(
                    currentStep < steps.length - 1 ? nextButtonText : finalButtonText,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentStep < steps.length - 1
                        ? AppColors.navNext
                        : AppColors.navFinalize,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: onWillPop,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 80,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'CÓDIGO MET: $codMetrica',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            backgroundColor: isDarkMode ? Colors.transparent : Colors.white,
            elevation: 0,
            flexibleSpace: isDarkMode
                ? ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Container(color: Colors.black.withOpacity(0.1)),
                    ),
                  )
                : null,
            centerTitle: true,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
            ),
            actions: [
              if (isSaving && isAutoSavingNotifier == null)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          body: isLoading
              ? Column(
                  children: [
                    _buildProgressBar(context, isDarkMode),
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Cargando datos...',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildProgressBar(context, isDarkMode),
                    Expanded(child: stepContent),
                    _buildNavigationButtons(context, isDarkMode),
                  ],
                ),
          floatingActionButton: const BalanzaSpeedDial(),
          floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        ),
      ),
    );
  }
}
