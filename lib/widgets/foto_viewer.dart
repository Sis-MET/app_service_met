import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../database/calibration_data_normalizer.dart';
import '../models/service_session.dart';
import '../theme/app_colors.dart';
import '../utils/top_alert.dart';
import '../theme/app_icons.dart';

/// Una foto del servicio con la etiqueta de dónde se tomó.
class FotoItem {
  final String path;
  final String grupo;

  const FotoItem({required this.path, required this.grupo});

  bool get existe => File(path).existsSync();
}

/// Fotos de un registro (una balanza), en el orden de sus columnas. Las
/// columnas `foto_balanza` y `*_foto` guardan rutas del teléfono, sueltas o
/// en una lista JSON; lo mismo en calibración y en soporte técnico.
List<FotoItem> fotosDelRegistro(Map<String, dynamic> registro) => [
      for (final entry in registro.entries)
        if (CalibrationDataNormalizer.isLocalFileField(entry.key))
          for (final path in ServiceSession.fotosFromColumn(entry.value))
            FotoItem(path: path, grupo: grupoDeFoto(entry.key)),
    ];

/// Sección donde se tomó la foto, a partir de su columna
/// ("conector_cables_foto" → "Conector Cables").
String grupoDeFoto(String columna) => switch (columna) {
      'foto_balanza' => 'Balanza',
      'linealidad_foto' => 'Linealidad',
      'condiciones_finales_foto' => 'Condiciones finales',
      _ => columna
          .replaceAll(RegExp(r'_?foto'), '')
          .split('_')
          .where((palabra) => palabra.isNotEmpty)
          .map((palabra) =>
              palabra[0].toUpperCase() + palabra.substring(1).toLowerCase())
          .join(' '),
    };

/// Abre [fotos] a pantalla completa, en la foto [index].
Future<void> abrirVisorFotos(
  BuildContext context, {
  required List<FotoItem> fotos,
  required int index,
  required String nombreBase,
}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FotoViewerScreen(
          fotos: fotos,
          initialIndex: index,
          nombreBase: nombreBase,
        ),
      ),
    );

/// Miniaturas agrupadas (Balanza, Linealidad...) que abren el visor.
///
/// Las fotos viven en el almacenamiento propio de la app, que ningún
/// administrador de archivos puede abrir desde Android 11: este visor es la
/// forma de verlas, compartirlas o guardar una copia en el teléfono.
class FotoGallerySection extends StatelessWidget {
  final List<FotoItem> fotos;

  /// Prefijo para el nombre al guardar o compartir, p. ej. el código métrica.
  final String nombreBase;

  const FotoGallerySection({
    super.key,
    required this.fotos,
    required this.nombreBase,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grupos = <String, List<int>>{};
    for (var i = 0; i < fotos.length; i++) {
      grupos.putIfAbsent(fotos[i].grupo, () => []).add(i);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.fotos, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fotografías (${fotos.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Compartir todas',
                visualDensity: VisualDensity.compact,
                onPressed: () => compartirFotos(
                  context,
                  fotos.where((f) => f.existe).toList(),
                  nombreBase,
                ),
                icon: const Icon(AppIcons.compartir, size: 20),
              ),
            ],
          ),
          for (final grupo in grupos.entries) ...[
            const SizedBox(height: 10),
            Text(
              grupo.key,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: grupo.value.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final index = grupo.value[i];
                  return FotoMiniatura(
                    foto: fotos[index],
                    size: 84,
                    onTap: () => abrirVisorFotos(
                      context,
                      fotos: fotos,
                      index: index,
                      nombreBase: nombreBase,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Miniatura de una foto. Si el archivo ya no está en el teléfono muestra el
/// ícono de imagen no disponible en lugar de fallar. Sin [size] ocupa todo el
/// espacio que le den (por ejemplo, una celda de una grilla).
class FotoMiniatura extends StatelessWidget {
  final FotoItem foto;
  final double? size;
  final double radius;
  final VoidCallback? onTap;

  /// Encima de la foto (p. ej., "+3").
  final Widget? overlay;

  const FotoMiniatura({
    super.key,
    required this.foto,
    this.size,
    this.radius = 10,
    this.onTap,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borde = BorderRadius.circular(radius);
    final imagen = foto.existe
        ? Image.file(
            File(foto.path),
            fit: BoxFit.cover,
            // Miniatura: no decodificar la foto de la cámara completa.
            cacheWidth: 240,
            errorBuilder: (_, __, ___) => _FotoNoDisponible(cs: cs),
          )
        : _FotoNoDisponible(cs: cs);
    return Semantics(
      button: onTap != null,
      label: 'Ver foto de ${foto.grupo}',
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: borde,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imagen,
              if (overlay != null) overlay!,
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, borderRadius: borde),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vista previa de las fotos de una balanza en una tarjeta: tantas
/// miniaturas como quepan en una línea y, si hay más, "+N" sobre la última.
/// Tocar una foto la abre en grande; "+N" abre todas.
class FotoTiraMiniaturas extends StatelessWidget {
  final List<FotoItem> fotos;
  final void Function(int index) onFoto;
  final VoidCallback onVerTodas;
  final double size;

  const FotoTiraMiniaturas({
    super.key,
    required this.fotos,
    required this.onFoto,
    required this.onVerTodas,
    this.size = 56,
  });

  static const _espacio = 6.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final caben = ((constraints.maxWidth + _espacio) / (size + _espacio))
            .floor()
            .clamp(1, fotos.length);
        final resto = fotos.length - caben;
        return Row(
          children: [
            for (var i = 0; i < caben; i++) ...[
              if (i > 0) const SizedBox(width: _espacio),
              if (i == caben - 1 && resto > 0)
                Semantics(
                  button: true,
                  label: 'Ver las ${fotos.length} fotos',
                  excludeSemantics: true,
                  child: FotoMiniatura(
                    foto: fotos[i],
                    size: size,
                    onTap: onVerTodas,
                    overlay: ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          '+${resto + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                FotoMiniatura(
                  foto: fotos[i],
                  size: size,
                  onTap: () => onFoto(i),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _FotoNoDisponible extends StatelessWidget {
  final ColorScheme cs;
  final bool grande;

  const _FotoNoDisponible({required this.cs, this.grande = false});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: grande ? Colors.black : cs.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.imagenNoDisponible,
              size: grande ? 48 : 22,
              color: grande ? Colors.white54 : cs.onSurfaceVariant,
            ),
            if (grande) ...[
              const SizedBox(height: 8),
              const Text(
                'Foto no disponible en este teléfono',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Visor a pantalla completa: zoom, deslizar entre fotos, compartir y
/// guardar una copia donde elija el técnico. Abajo, una tira con todas las
/// fotos para saltar a cualquiera; tocar la foto oculta o muestra los
/// controles. Solo muestra: no cambia el registro.
class FotoViewerScreen extends StatefulWidget {
  final List<FotoItem> fotos;
  final int initialIndex;
  final String nombreBase;

  const FotoViewerScreen({
    super.key,
    required this.fotos,
    required this.initialIndex,
    required this.nombreBase,
  });

  /// Etiqueta Hero de la foto [index], para que crezca desde su miniatura.
  static String heroTag(int index) => 'foto-$index';

  @override
  State<FotoViewerScreen> createState() => _FotoViewerScreenState();
}

class _FotoViewerScreenState extends State<FotoViewerScreen> {
  static const _tiraAlto = 64.0;
  static const _tiraFoto = 52.0;
  static const _tiraEspacio = 6.0;

  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late final ScrollController _tira = ScrollController(
    initialScrollOffset: _offsetTira(widget.initialIndex),
  );
  late int _index = widget.initialIndex;
  bool _controles = true;

  FotoItem get _actual => widget.fotos[_index];

  @override
  void dispose() {
    _pages.dispose();
    _tira.dispose();
    super.dispose();
  }

  /// Desplazamiento de la tira que deja la foto [index] cerca del centro.
  double _offsetTira(int index) =>
      (index * (_tiraFoto + _tiraEspacio) - 120).clamp(0, double.infinity);

  void _alCambiarDePagina(int index) {
    setState(() => _index = index);
    if (!_tira.hasClients) return;
    _tira.animateTo(
      _offsetTira(index).clamp(0, _tira.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _alternarControles() => setState(() => _controles = !_controles);

  Future<void> _guardar() async {
    final foto = _actual;
    try {
      final bytes = await File(foto.path).readAsBytes();
      final nombre = nombreArchivo(widget.nombreBase, foto);
      // Selector del sistema: el técnico elige la carpeta (Imágenes,
      // Descargas...). No necesita permisos de almacenamiento.
      final guardado = await FilePicker.saveFile(
        dialogTitle: 'Guardar foto',
        fileName: nombre,
        type: FileType.image,
        bytes: bytes,
      );
      if (!mounted || guardado == null) return;
      TopAlert.show(context, 'Foto guardada: $nombre');
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'No se pudo guardar la foto: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.fotos.length;
    final disponible = _actual.existe;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duracion =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 200);

    Widget desvanecible(Widget child) => IgnorePointer(
          ignoring: !_controles,
          child: AnimatedOpacity(
            opacity: _controles ? 1 : 0,
            duration: duracion,
            child: child,
          ),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: PhotoViewGallery.builder(
                pageController: _pages,
                itemCount: total,
                onPageChanged: _alCambiarDePagina,
                builder: (context, i) {
                  final foto = widget.fotos[i];
                  if (!foto.existe) {
                    return PhotoViewGalleryPageOptions.customChild(
                      child: GestureDetector(
                        onTap: _alternarControles,
                        child: _FotoNoDisponible(
                          cs: Theme.of(context).colorScheme,
                          grande: true,
                        ),
                      ),
                      disableGestures: true,
                    );
                  }
                  return PhotoViewGalleryPageOptions(
                    imageProvider: FileImage(File(foto.path)),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 4,
                    heroAttributes: PhotoViewHeroAttributes(
                      tag: FotoViewerScreen.heroTag(i),
                    ),
                    onTapUp: (_, __, ___) => _alternarControles(),
                    errorBuilder: (context, _, __) => _FotoNoDisponible(
                      cs: Theme.of(context).colorScheme,
                      grande: true,
                    ),
                  );
                },
                loadingBuilder: (_, __) => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.accentYellow),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: desvanecible(
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    systemOverlayStyle: SystemUiOverlayStyle.light,
                    title: Text(
                      '${_actual.grupo} · ${_index + 1} de $total',
                      style: const TextStyle(fontSize: 16),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Compartir',
                        onPressed: disponible
                            ? () => compartirFotos(
                                context, [_actual], widget.nombreBase)
                            : null,
                        icon: const Icon(AppIcons.compartir),
                      ),
                      IconButton(
                        tooltip: 'Guardar en el teléfono',
                        onPressed: disponible ? _guardar : null,
                        icon: const Icon(AppIcons.descargar),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (total > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: desvanecible(
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: _tiraAlto + 16,
                        child: ListView.separated(
                          controller: _tira,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          itemCount: total,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: _tiraEspacio),
                          itemBuilder: (context, i) => _FotoDeLaTira(
                            foto: widget.fotos[i],
                            size: _tiraFoto,
                            actual: i == _index,
                            onTap: () => _pages.jumpToPage(i),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Foto de la tira inferior del visor; la que se está viendo, resaltada.
class _FotoDeLaTira extends StatelessWidget {
  final FotoItem foto;
  final double size;
  final bool actual;
  final VoidCallback onTap;

  const _FotoDeLaTira({
    required this.foto,
    required this.size,
    required this.actual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: actual ? AppColors.accentYellow : Colors.transparent,
            width: 2,
          ),
        ),
        child: Opacity(
          opacity: actual ? 1 : 0.6,
          child: FotoMiniatura(
            foto: foto,
            size: size - 8,
            radius: 7,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// `<nombreBase>_<grupo>_<archivo>.jpg`, sin espacios ni tildes para que
/// WhatsApp o el correo no lo alteren.
String nombreArchivo(String nombreBase, FotoItem foto) {
  String limpio(String texto) => texto
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final partes = [
    if (limpio(nombreBase).isNotEmpty) limpio(nombreBase),
    limpio(foto.grupo),
    p.basenameWithoutExtension(foto.path),
  ];
  final extension = p.extension(foto.path).isEmpty
      ? '.jpg'
      : p.extension(foto.path).toLowerCase();
  return '${partes.join('_')}$extension';
}

/// Abre la hoja de compartir de Android (WhatsApp, correo, Drive, "Guardar
/// en Archivos"...).
Future<void> compartirFotos(
  BuildContext context,
  List<FotoItem> fotos,
  String nombreBase,
) async {
  if (fotos.isEmpty) {
    TopAlert.show(context, 'No hay fotos disponibles para compartir.',
        isError: true);
    return;
  }
  try {
    await SharePlus.instance.share(ShareParams(
      files: [
        for (final foto in fotos)
          XFile(
            foto.path,
            name: nombreArchivo(nombreBase, foto),
            mimeType: 'image/jpeg',
          ),
      ],
      subject: nombreBase.isEmpty ? 'Fotos del servicio' : 'Fotos $nombreBase',
    ));
  } catch (e) {
    if (context.mounted) {
      TopAlert.show(context, 'No se pudo compartir: $e', isError: true);
    }
  }
}
