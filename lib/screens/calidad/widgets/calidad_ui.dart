import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../models/cumplimiento.dart';

/// Estructura de las pantallas de Calidad: la misma de Ajustes (botón de
/// regreso, título grande y contenido centrado hasta 720 px), con acciones a
/// la derecha de la barra superior.
class CalidadPage extends StatelessWidget {
  const CalidadPage({
    super.key,
    required this.titulo,
    required this.children,
    this.subtitulo,
    this.acciones = const [],
    this.encabezado,
    this.controller,
  });

  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  /// Contenido entre el título y el cuerpo (píldoras de estado, etc.).
  final Widget? encabezado;
  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            AppDesign.pagePadding,
            14,
            AppDesign.pagePadding,
            36 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const AppBackButton(),
                        const Spacer(),
                        for (final (i, accion) in acciones.indexed) ...[
                          if (i > 0) const SizedBox(width: 8),
                          accion,
                        ],
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(titulo, style: AppDesign.displayStyle(context)),
                    if (subtitulo != null) ...[
                      const SizedBox(height: 8),
                      Text(subtitulo!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (encabezado != null) ...[
                      const SizedBox(height: 16),
                      encabezado!,
                    ],
                    const SizedBox(height: 26),
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de la barra superior con el tratamiento del engranaje de Inicio.
class CalidadAccion extends StatelessWidget {
  const CalidadAccion({
    super.key,
    required this.icono,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icono, size: 20),
      style: IconButton.styleFrom(
        foregroundColor: dark ? Colors.white : AppDesign.ink,
        backgroundColor: AppColors.accentYellow.withOpacity(0.07),
        side: BorderSide(color: AppColors.accentYellow.withOpacity(0.32)),
      ),
    );
  }
}

/// Ícono en recuadro suave, como los de Ajustes.
class CalidadIcono extends StatelessWidget {
  const CalidadIcono(this.icono, {super.key, this.color, this.size = 38});

  final IconData icono;

  /// Sin color usa el dorado de marca de Ajustes.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tono = color ?? AppColors.accentYellow;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tono.withOpacity(color == null ? 0.11 : 0.13),
        borderRadius: AppDesign.smallRadius,
      ),
      child:
          Icon(icono, size: size * 0.52, color: color ?? AppColors.shimmerGold),
    );
  }
}

/// Título de sección en versalitas, igual al de Ajustes.
class CalidadSeccion extends StatelessWidget {
  const CalidadSeccion(this.titulo, {super.key, this.trailing});

  final String titulo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EstadoPill extends StatelessWidget {
  const EstadoPill(this.estado, {super.key});

  final EstadoCumplimiento estado;

  @override
  Widget build(BuildContext context) => AppStatusPill(
        icon: estado.icono,
        label: estado.etiqueta,
        color: estado.color,
      );
}

/// Etiqueta pequeña y neutra (ID de requisito, clase de cambio, etc.).
class CalidadEtiqueta extends StatelessWidget {
  const CalidadEtiqueta(this.texto, {super.key, this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tono = color ?? cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tono.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: tono,
        ),
      ),
    );
  }
}

/// Anillo de cumplimiento: un arco por estado, en el orden de
/// [EstadoCumplimiento], con el avance ponderado al centro.
class DonutCumplimiento extends StatelessWidget {
  const DonutCumplimiento({
    super.key,
    required this.resumen,
    this.size = 132,
    this.grosor = 14,
    this.mostrarTexto = true,
  });

  final ResumenCumplimiento resumen;
  final double size;
  final double grosor;
  final bool mostrarTexto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final porcentaje = (resumen.avance * 100).round();
    return Semantics(
      label: 'Avance de cumplimiento $porcentaje por ciento',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _DonutPainter(
              resumen: resumen,
              progreso: t,
              grosor: grosor,
              pista: cs.outlineVariant.withOpacity(0.45),
            ),
            child: mostrarTexto
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(porcentaje * t).round()}%',
                          style: GoogleFonts.poppins(
                            fontSize: size * 0.2,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        if (size >= 100) ...[
                          const SizedBox(height: 4),
                          Text(
                            'avance',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.resumen,
    required this.progreso,
    required this.grosor,
    required this.pista,
  });

  final ResumenCumplimiento resumen;
  final double progreso;
  final double grosor;
  final Color pista;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      grosor / 2,
      grosor / 2,
      size.width - grosor,
      size.height - grosor,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = pista;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (resumen.total == 0) return;

    final activos =
        EstadoCumplimiento.values.where((e) => resumen[e] > 0).toList();
    // Separación visible entre arcos solo si hay más de uno.
    final gap = activos.length > 1 ? 0.07 : 0.0;
    var inicio = -math.pi / 2;
    final totalBarrido = math.pi * 2 * progreso;
    for (final estado in activos) {
      final barrido = totalBarrido * resumen[estado] / resumen.total;
      final visible = math.max(0.0, barrido - gap);
      if (visible > 0) {
        canvas.drawArc(
          rect,
          inicio + gap / 2,
          visible,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = grosor
            ..strokeCap = StrokeCap.round
            ..color = estado.color,
        );
      }
      inicio += barrido;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progreso != progreso ||
      old.resumen != resumen ||
      old.pista != pista ||
      old.grosor != grosor;
}

/// Barra horizontal apilada por estado.
class BarraCumplimiento extends StatelessWidget {
  const BarraCumplimiento({super.key, required this.resumen, this.alto = 8});

  final ResumenCumplimiento resumen;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(alto),
      child: SizedBox(
        height: alto,
        child: resumen.total == 0
            ? ColoredBox(color: cs.outlineVariant.withOpacity(0.45))
            : Row(
                children: [
                  for (final estado in EstadoCumplimiento.values)
                    if (resumen[estado] > 0)
                      Expanded(
                        flex: resumen[estado],
                        child: Container(
                          margin: const EdgeInsets.only(right: 2),
                          color: estado.color,
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

/// Fila "clave: valor" para bloques de control de documento.
class CalidadDato extends StatelessWidget {
  const CalidadDato(this.clave, this.valor, {super.key, this.pendiente});

  final String clave;
  final String valor;

  /// Marca el valor como pendiente (se muestra en ámbar). Por defecto, todo
  /// valor que empiece por "PENDIENTE".
  final bool? pendiente;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esPendiente = pendiente ?? valor.startsWith('PENDIENTE');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              clave,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: esPendiente ? const Color(0xFFB07F00) : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
