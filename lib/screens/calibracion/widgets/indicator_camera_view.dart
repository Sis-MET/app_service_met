import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';

/// Un recuadro que se dibuja sobre la cámara.
class CameraRegion {
  const CameraRegion({
    required this.region,
    required this.label,
    this.color = Colors.white,
    this.value,
    this.editable = true,
    this.highlighted = false,
  });

  /// En fracciones de la imagen derecha, como lo lee el lector.
  final Rect region;
  final String label;
  final Color color;

  /// La lectura en vivo, para que el técnico la compare con el display.
  final String? value;
  final bool editable;

  /// Lectura estable: el borde se pinta en verde.
  final bool highlighted;
}

/// La cámara a todo el espacio, recortando lo que sobre, con los recuadros
/// que se leen. Los recuadros están en fracciones de la imagen: se llevan a
/// la pantalla con la misma escala y el mismo recorte que la vista previa,
/// así coinciden con lo que analiza el lector. Los editables se mueven
/// arrastrándolos y se agrandan o achican desde sus esquinas; tocar fuera de
/// ellos enfoca ahí.
class IndicatorCameraView extends StatelessWidget {
  const IndicatorCameraView({
    super.key,
    required this.camera,
    required this.regions,
    required this.onTapFocus,
    this.onRegionChanged,
    this.hint,
  });

  final CameraController camera;
  final List<CameraRegion> regions;
  final ValueChanged<Offset> onTapFocus;
  final void Function(int index, Rect region)? onRegionChanged;
  final String? hint;

  /// Tamaño mínimo de un recuadro, en fracciones de la imagen.
  static const minWidth = 0.12;
  static const minHeight = 0.05;

  /// Lo mueve dentro de la imagen sin cambiar su tamaño.
  static Rect move(Rect region, Offset delta) {
    final dx =
        (region.left + delta.dx).clamp(0.0, 1.0 - region.width) - region.left;
    final dy =
        (region.top + delta.dy).clamp(0.0, 1.0 - region.height) - region.top;
    return region.shift(Offset(dx, dy));
  }

  /// Corre la esquina [corner] (0 arriba a la izquierda, 1 arriba a la
  /// derecha, 2 abajo a la derecha, 3 abajo a la izquierda) sin achicarlo
  /// por debajo del mínimo ni salir de la imagen.
  static Rect resize(Rect region, int corner, Offset delta) {
    var left = region.left, top = region.top;
    var right = region.right, bottom = region.bottom;
    if (corner == 0 || corner == 3) {
      left = (left + delta.dx).clamp(0.0, right - minWidth);
    } else {
      right = (right + delta.dx).clamp(left + minWidth, 1.0);
    }
    if (corner == 0 || corner == 1) {
      top = (top + delta.dy).clamp(0.0, bottom - minHeight);
    } else {
      bottom = (bottom + delta.dy).clamp(top + minHeight, 1.0);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Widget build(BuildContext context) {
    // previewSize viene acostado; la app va en vertical.
    final preview = camera.value.previewSize!;
    final image = Size(preview.height, preview.width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final space = constraints.biggest;
        final scale = space.width / image.width > space.height / image.height
            ? space.width / image.width
            : space.height / image.height;
        final shown = image * scale;
        final origin = Offset(
          (space.width - shown.width) / 2,
          (space.height - shown.height) / 2,
        );
        Rect toScreen(Rect region) => Rect.fromLTRB(
              origin.dx + region.left * shown.width,
              origin.dy + region.top * shown.height,
              origin.dx + region.right * shown.width,
              origin.dy + region.bottom * shown.height,
            );
        Offset toImage(Offset delta) =>
            Offset(delta.dx / shown.width, delta.dy / shown.height);
        final boxes = [for (final region in regions) toScreen(region.region)];
        final topmost = boxes.isEmpty
            ? space.height / 2
            : boxes.map((box) => box.top).reduce((a, b) => a < b ? a : b);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => onTapFocus(Offset(
            (details.localPosition.dx - origin.dx) / shown.width,
            (details.localPosition.dy - origin.dy) / shown.height,
          )),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: OverflowBox(
                  maxWidth: shown.width,
                  maxHeight: shown.height,
                  child: SizedBox.fromSize(
                    size: shown,
                    child: CameraPreview(camera),
                  ),
                ),
              ),
              CustomPaint(
                painter: _RegionsPainter(
                  boxes: boxes,
                  colors: [
                    for (final region in regions)
                      region.highlighted
                          ? AppColors.actionPositive
                          : region.color,
                  ],
                ),
              ),
              if (hint != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: space.height - topmost + 34,
                  child: Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: const [Shadow(blurRadius: 4)],
                    ),
                  ),
                ),
              for (var i = 0; i < regions.length; i++) ...[
                _Label(box: boxes[i], region: regions[i]),
                if (regions[i].editable && onRegionChanged != null) ...[
                  Positioned.fromRect(
                    rect: boxes[i].deflate(14),
                    child: GestureDetector(
                      key: ValueKey('region-move-$i'),
                      behavior: HitTestBehavior.translucent,
                      onPanUpdate: (details) => onRegionChanged!(
                        i,
                        move(regions[i].region, toImage(details.delta)),
                      ),
                    ),
                  ),
                  for (var corner = 0; corner < 4; corner++)
                    _Handle(
                      key: ValueKey('region-corner-$i-$corner'),
                      at: switch (corner) {
                        0 => boxes[i].topLeft,
                        1 => boxes[i].topRight,
                        2 => boxes[i].bottomRight,
                        _ => boxes[i].bottomLeft,
                      },
                      color: regions[i].color,
                      onDrag: (delta) => onRegionChanged!(
                        i,
                        resize(regions[i].region, corner, toImage(delta)),
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Oscurece todo menos los recuadros y les pinta el borde.
class _RegionsPainter extends CustomPainter {
  const _RegionsPainter({required this.boxes, required this.colors});

  final List<Rect> boxes;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final box in boxes) {
      path.addRRect(RRect.fromRectAndRadius(box, const Radius.circular(12)));
    }
    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.55));
    for (var i = 0; i < boxes.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxes[i], const Radius.circular(12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(_RegionsPainter oldDelegate) =>
      oldDelegate.boxes.length != boxes.length ||
      !_same(oldDelegate.boxes, boxes) ||
      !_same(oldDelegate.colors, colors);

  static bool _same<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// El nombre del recuadro y su lectura en vivo, sobre su borde.
class _Label extends StatelessWidget {
  const _Label({required this.box, required this.region});

  final Rect box;
  final CameraRegion region;

  @override
  Widget build(BuildContext context) {
    final color = region.highlighted ? AppColors.actionPositive : region.color;
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : AppColors.primary;
    return Positioned(
      left: box.left,
      top: box.top - 26,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            region.value == null
                ? region.label
                : '${region.label} · ${region.value}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Esquina para agrandar o achicar un recuadro: un círculo de 28 px, más
/// fácil de tocar que el borde.
class _Handle extends StatelessWidget {
  const _Handle({
    super.key,
    required this.at,
    required this.color,
    required this.onDrag,
  });

  final Offset at;
  final Color color;
  final ValueChanged<Offset> onDrag;

  static const _size = 28.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: at.dx - _size / 2,
      top: at.dy - _size / 2,
      width: _size,
      height: _size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black54, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zoom, exposición y bloqueo de la cámara. Para leer de lejos (el equipo
/// caliente) se acerca la imagen; con los LED muy brillantes se baja la
/// exposición para que los segmentos no se empasten; en una sesión larga en
/// trípode se bloquean el enfoque y la exposición para que la cámara no los
/// busque a cada rato.
class CameraTuning extends ChangeNotifier {
  CameraTuning(this.camera);

  final CameraController camera;

  double minZoom = 1, maxZoom = 1, zoom = 1;
  double minExposure = 0, maxExposure = 0, exposure = 0;
  bool locked = false;
  bool ready = false;

  Future<void> load() async {
    try {
      minZoom = await camera.getMinZoomLevel();
      maxZoom = await camera.getMaxZoomLevel();
      zoom = minZoom;
    } on CameraException catch (_) {
      // Sin zoom en esta cámara.
    }
    try {
      minExposure = await camera.getMinExposureOffset();
      maxExposure = await camera.getMaxExposureOffset();
    } on CameraException catch (_) {
      // Sin compensación de exposición.
    }
    ready = true;
    notifyListeners();
  }

  bool get canZoom => maxZoom > minZoom;
  bool get canExpose => maxExposure > minExposure;

  Future<void> setZoom(double value) async {
    zoom = value.clamp(minZoom, maxZoom);
    notifyListeners();
    try {
      await camera.setZoomLevel(zoom);
    } on CameraException catch (_) {}
  }

  Future<void> setExposure(double value) async {
    exposure = value.clamp(minExposure, maxExposure);
    notifyListeners();
    try {
      await camera.setExposureOffset(exposure);
    } on CameraException catch (_) {}
  }

  Future<void> setLocked(bool value) async {
    locked = value;
    notifyListeners();
    try {
      await camera.setFocusMode(value ? FocusMode.locked : FocusMode.auto);
    } on CameraException catch (_) {}
    try {
      await camera
          .setExposureMode(value ? ExposureMode.locked : ExposureMode.auto);
    } on CameraException catch (_) {}
  }

  /// Hoja con los controles.
  static Future<void> showSheet(BuildContext context, CameraTuning tuning) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      showDragHandle: true,
      builder: (_) => ListenableBuilder(
        listenable: tuning,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ajustes de cámara',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _SliderRow(
                  icon: AppIcons.buscar,
                  label: 'Zoom ${tuning.zoom.toStringAsFixed(1)}×',
                  enabled: tuning.canZoom,
                  value: tuning.zoom,
                  min: tuning.minZoom,
                  max: tuning.canZoom ? tuning.maxZoom : tuning.minZoom + 1,
                  onChanged: tuning.setZoom,
                ),
                _SliderRow(
                  icon: AppIcons.claro,
                  label: 'Exposición ${tuning.exposure >= 0 ? '+' : ''}'
                      '${tuning.exposure.toStringAsFixed(1)}',
                  enabled: tuning.canExpose,
                  value: tuning.exposure,
                  min: tuning.minExposure,
                  max: tuning.canExpose
                      ? tuning.maxExposure
                      : tuning.minExposure + 1,
                  onChanged: tuning.setExposure,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.actionPositive,
                  title: Text(
                    'Bloquear enfoque y exposición',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Para mediciones largas con el teléfono fijo. '
                    'Toque el display antes de bloquear.',
                    style: GoogleFonts.inter(
                        color: Colors.white60, fontSize: 12.5),
                  ),
                  value: tuning.locked,
                  onChanged: tuning.setLocked,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 10),
        SizedBox(
          width: 118,
          child: Text(
            enabled ? label : '${label.split(' ').first}: no disponible',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          ),
        ),
        Expanded(
          child: Slider(
            activeColor: AppColors.actionPositive,
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
