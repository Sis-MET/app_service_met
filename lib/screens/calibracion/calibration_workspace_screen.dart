import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/screens/calibracion/widgets/step_indicator.dart';

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
  State<CalibrationWorkspaceScreen> createState() =>
      _CalibrationWorkspaceScreenState();
}

class _CalibrationWorkspaceScreenState
    extends State<CalibrationWorkspaceScreen> {
  final PageController _pageController = PageController();
  bool _infoButtonVisible = true;
  Timer? _showButtonTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ServiceSessionProvider>()
          .initialize(
            userName: widget.userName,
            secaValue: widget.secaValue,
            sessionId: widget.sessionId,
          )
          .then((_) {
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
    _showButtonTimer?.cancel();
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
      return const Scaffold(
          body: Center(child: Text("Error al cargar la sesión")));
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

    // Validate accessibility for steps
    bool hasSeca = session.metadata.secaConfirmed;

    final steps = [
      StepData(
          title: 'Cliente',
          subtitle: session.cliente?.nombreComercial ?? 'Seleccione cliente',
          icon: Icons.business),
      StepData(
          title: 'Planta',
          subtitle: session.planta?.nombre ?? 'Seleccione planta',
          icon: Icons.factory),
      StepData(
          title: 'SECA',
          subtitle: session.sessionInfo.seca ?? 'Ingresar SECA',
          icon: Icons.qr_code),
      StepData(
          title: 'Instrumento',
          subtitle: session.balanza?.codMetrica ?? 'Seleccionar balanza',
          icon: Icons.scale,
          isAccessible: hasSeca),
      StepData(
          title: 'Inspección',
          subtitle: 'Visual',
          icon: Icons.visibility,
          isAccessible: hasSeca),
      StepData(
          title: 'Precarga/Ajuste',
          subtitle: 'Datos',
          icon: Icons.settings,
          isAccessible: hasSeca),
      StepData(
          title: 'Excentricidad',
          subtitle: 'Prueba',
          icon: Icons.center_focus_strong,
          isAccessible: hasSeca),
      StepData(
          title: 'Repetibilidad',
          subtitle: 'Prueba',
          icon: Icons.repeat,
          isAccessible: hasSeca),
      StepData(
          title: 'Linealidad',
          subtitle: 'Prueba',
          icon: Icons.show_chart,
          isAccessible: hasSeca),
      StepData(
          title: 'Foto Carga',
          subtitle: 'Evidencia',
          icon: Icons.camera_alt,
          isAccessible: hasSeca),
      StepData(
          title: 'Final',
          subtitle: 'Condiciones',
          icon: Icons.check_circle,
          isAccessible: hasSeca),
      StepData(
          title: 'Exportar',
          subtitle: 'Reporte',
          icon: Icons.download,
          isAccessible: hasSeca),
    ];

    // Sync page controller if provider step changed externally
    if (_pageController.hasClients &&
        _pageController.page?.round() != provider.currentStep) {
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
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
            child: Stack(
              children: [
                PageView(
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
                    _scrollHide(const FotoCargaStep()),
                    _scrollHide(const CondicionesFinalesStep()),
                    _scrollHide(const ExportacionStep()),
                  ],
                ),

                // Info button — visible on technical steps, hides on scroll
                if (session.balanza != null && provider.currentStep >= 5)
                  Positioned(
                    bottom: 88,
                    right: 20,
                    child: AnimatedOpacity(
                      opacity: _infoButtonVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: AnimatedSlide(
                        offset: _infoButtonVisible
                            ? Offset.zero
                            : const Offset(0, 0.3),
                        duration: const Duration(milliseconds: 200),
                        child: _buildBalanzaInfoButton(provider, isDark),
                      ),
                    ),
                  ),

                // Floating nav buttons — bottom-right, pill grouped
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Builder(
                    builder: (ctx) {
                      final step = provider.currentStep;
                      final meta = provider.session?.metadata;

                      String label = 'Siguiente';
                      Color actionColor = const Color(0xFF498054);
                      VoidCallback? onNext;

                      if (step == 2 && meta != null && !meta.secaConfirmed) {
                        label = 'Confirmar SECA';
                        actionColor = Colors.blue[700]!;
                        onNext = () async {
                          await provider.confirmSeca();
                        };
                      } else if (step == 2 &&
                          meta != null &&
                          meta.secaConfirmed) {
                        label = 'Siguiente';
                        actionColor = const Color(0xFF498054);
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
                        actionColor = const Color(0xFF3e7732);
                        onNext = () async {
                          final error = provider.validateBalanza();
                          if (error != null) {
                            if (ctx.mounted) {
                              TopAlert.show(ctx, error, isError: true);
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
                              final isDark =
                                  Theme.of(ctx2).brightness == Brightness.dark;
                              return AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: isDark
                                            ? Colors.amber[300]
                                            : Colors.amber[800],
                                        size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text('Verificar datos',
                                            style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(
                                                        0xFF1A1A1A)))),
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
                                          session?.sessionInfo.nReca ?? '-',
                                          isDark),
                                      _summaryRow(
                                          'Sticker',
                                          session?.sessionInfo.sticker ?? '-',
                                          isDark),
                                      const Divider(height: 16),
                                      _summaryRow('Cód. Métrica',
                                          b?.codMetrica ?? '-', isDark),
                                      _summaryRow(
                                          'Tipo', b?.tipo ?? '-', isDark),
                                      _summaryRow(
                                          'Marca', b?.marca ?? '-', isDark),
                                      _summaryRow(
                                          'Modelo', b?.modelo ?? '-', isDark),
                                      _summaryRow(
                                          'Serie', b?.serie ?? '-', isDark),
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
                                    onPressed: () => Navigator.pop(ctx2, false),
                                    child: Text('Cancelar',
                                        style: TextStyle(
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx2, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3e7732),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Confirmar y Guardar'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirm == true) {
                            await provider.confirmBalanza();
                          }
                        };
                      } else if (step == 4) {
                        onNext = () {
                          final error = provider.validateInspeccionVisual();
                          if (error != null) {
                            if (ctx.mounted) {
                              TopAlert.show(ctx, error, isError: true);
                            }
                            return;
                          }
                          provider.nextStep();
                        };
                      } else if (step == 5) {
                        onNext = () {
                          final error = provider.validatePrecargasAjuste();
                          if (error != null) {
                            if (ctx.mounted) {
                              TopAlert.show(ctx, error, isError: true);
                            }
                            return;
                          }
                          provider.nextStep();
                        };
                      } else if (step == 6) {
                        onNext = () {
                          final error = provider.validateExcentricidad();
                          if (error != null) {
                            if (ctx.mounted) {
                              TopAlert.show(ctx, error, isError: true);
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

                      final canGoBack = provider.currentStep > 0;
                      final isDarkMode =
                          Theme.of(ctx).brightness == Brightness.dark;
                      final pillBg =
                          isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
                      final backColor =
                          isDarkMode ? Colors.white24 : Colors.black12;

                      return Container(
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Back button
                            Tooltip(
                              message: 'Anterior',
                              child: InkWell(
                                onTap: canGoBack
                                    ? () => provider.previousStep()
                                    : null,
                                borderRadius: BorderRadius.circular(50),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: canGoBack
                                        ? backColor
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: canGoBack
                                        ? (isDarkMode
                                            ? Colors.white70
                                            : Colors.black54)
                                        : (isDarkMode
                                            ? Colors.white24
                                            : Colors.black26),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Dynamic action button
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                    scale: animation, child: child),
                              ),
                              child: Material(
                                key: ValueKey<String>(label),
                                color: onNext != null
                                    ? actionColor
                                    : Colors.grey[400],
                                borderRadius: BorderRadius.circular(50),
                                child: InkWell(
                                  onTap: onNext,
                                  borderRadius: BorderRadius.circular(50),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 11),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          label,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (label == 'Siguiente') ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 14,
                                              color: Colors.white),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: const Color(0xFF04376E),
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
        icon: const Icon(Icons.info_outline, color: Colors.white, size: 22),
        onPressed: () {
          final b = provider.session?.balanza;
          final eq = provider.session?.equipos ?? [];
          if (b != null) _showBalanzaInfo(context, b, eq, isDark);
        },
      ),
    );
  }

  void _showBalanzaInfo(
      BuildContext context, BalanzaInfo b, List<EquipoInfo> equipos, bool isDark) {
    final pesas = equipos.where((e) {
      final t = e.tipo?.toLowerCase() ?? '';
      return t.contains('pesa') || t.contains('masa') || t.contains('patron') || t.contains('patr');
    }).toList();
    final otros = equipos.where((e) {
      final t = e.tipo?.toLowerCase() ?? '';
      return !(t.contains('pesa') || t.contains('masa') || t.contains('patron') || t.contains('patr'));
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.scale, size: 22, color: isDark ? Colors.white : const Color(0xFF04376E)),
                  const SizedBox(width: 10),
                  Text('Información del Instrumento',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _infoSectionHeader('Identificación', isDark),
                    _infoRow('Código Métrica', b.codMetrica ?? '-', isDark),
                    _infoRow('Tipo', b.tipo ?? '-', isDark),
                    _infoRow('Categoría', b.categoria ?? '-', isDark),
                    const Divider(height: 24),

                    _infoSectionHeader('Fabricante', isDark),
                    _infoRow('Marca', b.marca ?? '-', isDark),
                    _infoRow('Modelo', b.modelo ?? '-', isDark),
                    _infoRow('Serie', b.serie ?? '-', isDark),
                    const Divider(height: 24),

                    _infoSectionHeader('Características', isDark),
                    _infoRow('Tecnología', b.tecnologia ?? '-', isDark),
                    _infoRow('Clase', b.clase ?? '-', isDark),
                    _infoRow('Código Interno', b.codInterno ?? '-', isDark),
                    _infoRow('Unidad', b.unidad ?? '-', isDark),
                    _infoRow('Ubicación', b.ubicacion ?? '-', isDark),
                    _infoRow('Rango', b.rango ?? '-', isDark),
                    _infoRow('N° Celdas', b.nCeldas ?? '-', isDark),
                    const Divider(height: 24),

                    _infoSectionHeader('Rangos de Intervalo', isDark),
                    _infoRow(
                        'Rango 1',
                        'Cap.Max: ${b.capMax1 ?? '-'} | d: ${b.d1 ?? '-'} | e: ${b.e1 ?? '-'} | Dec: ${b.dec1 ?? '-'}',
                        isDark),
                    _infoRow(
                        'Rango 2',
                        'Cap.Max: ${b.capMax2 ?? '-'} | d: ${b.d2 ?? '-'} | e: ${b.e2 ?? '-'} | Dec: ${b.dec2 ?? '-'}',
                        isDark),
                    _infoRow(
                        'Rango 3',
                        'Cap.Max: ${b.capMax3 ?? '-'} | d: ${b.d3 ?? '-'} | e: ${b.e3 ?? '-'} | Dec: ${b.dec3 ?? '-'}',
                        isDark),
                    const Divider(height: 24),

                    _infoSectionHeader('Equipamiento del Servicio', isDark),
                    if (pesas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Sin pesas patrón seleccionadas',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38)),
                      )
                    else ...[
                      Text('Pesas Patrón (${pesas.length})',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 4),
                      ...pesas.map((e) => Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Text('${e.codInstrumento ?? '-'} x${e.cantidad ?? '1'}',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                      )),
                    ],
                    const SizedBox(height: 8),
                    if (otros.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Sin instrumentos de ambiente seleccionados',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black38)),
                      )
                    else ...[
                      Text('Ambiente (${otros.length})',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 4),
                      ...otros.map((e) => Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Text('${e.codInstrumento ?? '-'} x${e.cantidad ?? '1'}',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                      )),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoSectionHeader(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF04376E),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
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
