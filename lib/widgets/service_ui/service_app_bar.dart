import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../theme/app_icons.dart';

/// Estado del guardado automático para el indicador del AppBar.
enum SaveStatus { idle, pending, saving, local, success, error }

/// Indicador discreto del guardado automático para el AppBar.
///
/// Solo aparece mientras hay algo que contar: un punto que late con cambios
/// pendientes, un anillo fino mientras guarda y un check que se dibuja al
/// terminar y luego se retira. Un error queda visible hasta resolverse.
/// Sin nada que contar no ocupa lugar: al aparecer se abre paso y las
/// acciones de su izquierda se deslizan para hacerle lugar; al retirarse
/// vuelven a su sitio.
class SaveStatusIndicator extends StatefulWidget {
  final SaveStatus status;

  const SaveStatusIndicator({super.key, required this.status});

  /// Cuánto se muestra el check antes de retirarse.
  static const savedHold = Duration(milliseconds: 1100);

  /// Ancho con un estado a la vista (28 del glifo + 12 de margen) y en
  /// reposo (un respiro para la acción que queda junto al borde).
  static const expandedWidth = 40.0;
  static const collapsedWidth = 4.0;

  /// Lo que tarda en abrirse o cerrarse el hueco.
  static const resize = Duration(milliseconds: 260);

  @override
  State<SaveStatusIndicator> createState() => _SaveStatusIndicatorState();
}

enum _SaveGlyph { pending, saving, saved, error }

class _SaveStatusIndicatorState extends State<SaveStatusIndicator> {
  _SaveGlyph? _glyph;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Al abrir la pantalla no se anuncia lo que ya estaba guardado.
    _glyph = _activeGlyph(widget.status);
  }

  @override
  void didUpdateWidget(covariant SaveStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status == widget.status) return;
    _hideTimer?.cancel();
    final active = _activeGlyph(widget.status);
    if (active != null) {
      _glyph = active;
      return;
    }
    final finishedSaving = widget.status == SaveStatus.local ||
        widget.status == SaveStatus.success;
    if (finishedSaving && _glyph != null && _glyph != _SaveGlyph.saved) {
      _glyph = _SaveGlyph.saved;
      _hideTimer = Timer(SaveStatusIndicator.savedHold, () {
        if (mounted) setState(() => _glyph = null);
      });
    } else if (!finishedSaving) {
      _glyph = null;
    }
  }

  static _SaveGlyph? _activeGlyph(SaveStatus status) => switch (status) {
        SaveStatus.pending => _SaveGlyph.pending,
        SaveStatus.saving => _SaveGlyph.saving,
        SaveStatus.error => _SaveGlyph.error,
        _ => null,
      };

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final glyph = _glyph;
    final description = switch (glyph) {
      _SaveGlyph.pending => 'Cambios pendientes de guardar en este dispositivo',
      _SaveGlyph.saving => 'Guardando en este dispositivo',
      _SaveGlyph.saved => 'Guardado en este dispositivo',
      _SaveGlyph.error => 'Error al guardar en este dispositivo',
      null => null,
    };

    final Widget child = switch (glyph) {
      null => const SizedBox.shrink(key: ValueKey('hidden')),
      _SaveGlyph.pending => const _PulsingDot(key: ValueKey('pending')),
      _SaveGlyph.saving => const _SavingRing(key: ValueKey('saving')),
      _SaveGlyph.saved => const _DrawnCheck(key: ValueKey('saved')),
      _SaveGlyph.error => const Icon(
          AppIcons.error,
          key: ValueKey('error'),
          size: 17,
          color: AppColors.actionNegative,
        ),
    };

    final indicator = SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: AnimatedSwitcher(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
          reverseDuration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: child,
        ),
      ),
    );

    final content = Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: description == null
            ? ExcludeSemantics(child: indicator)
            : Tooltip(
                message: description,
                child: Semantics(
                  label: description,
                  liveRegion: true,
                  child: indicator,
                ),
              ),
      ),
    );

    // El glifo queda anclado al borde derecho: al abrirse el hueco aparece
    // desde el borde y empuja a las acciones vecinas; al cerrarse, se va.
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : SaveStatusIndicator.resize,
      curve: Curves.easeOutCubic,
      width: glyph == null
          ? SaveStatusIndicator.collapsedWidth
          : SaveStatusIndicator.expandedWidth,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerRight,
          minWidth: SaveStatusIndicator.expandedWidth,
          maxWidth: SaveStatusIndicator.expandedWidth,
          child: content,
        ),
      ),
    );
  }
}

/// Cambios sin guardar: un punto ámbar que late suave.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({super.key});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0)
          .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.warning,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Guardando: un anillo fino y neutro.
class _SavingRing extends StatelessWidget {
  const _SavingRing({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 1.8,
        strokeCap: StrokeCap.round,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Guardado: un check que se dibuja de izquierda a derecha.
class _DrawnCheck extends StatefulWidget {
  const _DrawnCheck({super.key});

  @override
  State<_DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<_DrawnCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(16),
      painter: _CheckPainter(
        CurvedAnimation(parent: _draw, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final Animation<double> progress;

  _CheckPainter(this.progress) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.76)
      ..lineTo(size.width * 0.84, size.height * 0.28);
    final paint = Paint()
      ..color = AppColors.actionPositive
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.value),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// AppBar plano estilo Calibración: elevation 0, fondo = scaffold,
/// título Poppins 17 w600 en una línea, iconTheme según brillo.
class ServiceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Segunda línea, más chica (p. ej., "Paso 3 de 11 · SECA").
  final String? subtitle;

  /// Título centrado, entre ≡ y las acciones, en los servicios.
  final bool centerTitle;

  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const ServiceAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.centerTitle = false,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canGoBack = ModalRoute.of(context)?.canPop ?? false;
    final effectiveLeading = leading ??
        (automaticallyImplyLeading && canGoBack
            ? const Center(child: AppBackButton())
            : null);

    // Una sola línea y del mismo tamaño en todas las pantallas: un título
    // largo ("Mnt Preventivo Avanzado") se corta con "…" en vez de partirse
    // en dos renglones o empujar las acciones.
    final titleText = Text(
      title,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: isDark ? Colors.white : AppDesign.ink,
        height: 1.2,
      ),
    );

    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: effectiveLeading,
      // El leading se resuelve arriba para usar siempre el botón compartido.
      automaticallyImplyLeading: false,
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : AppDesign.ink,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemStatusBarContrastEnforced: false,
      ),
      centerTitle: centerTitle,
      title: subtitle == null
          ? titleText
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                titleText,
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : AppDesign.muted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
      actions: actions,
    );
  }
}
