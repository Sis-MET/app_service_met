import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../utils/top_alert.dart';

/// Una foto del servicio con la etiqueta de dónde se tomó.
class FotoItem {
  final String path;
  final String grupo;

  const FotoItem({required this.path, required this.grupo});

  bool get existe => File(path).existsSync();
}

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
              const Icon(Icons.photo_library_outlined, size: 20),
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
              TextButton.icon(
                onPressed: () => compartirFotos(
                  context,
                  fotos.where((f) => f.existe).toList(),
                  nombreBase,
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Compartir todas'),
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
                  return _Miniatura(
                    foto: fotos[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FotoViewerScreen(
                          fotos: fotos,
                          initialIndex: index,
                          nombreBase: nombreBase,
                        ),
                      ),
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

class _Miniatura extends StatelessWidget {
  final FotoItem foto;
  final VoidCallback onTap;

  const _Miniatura({required this.foto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Ver foto de ${foto.grupo}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 84,
            height: 84,
            child: foto.existe
                ? Image.file(
                    File(foto.path),
                    fit: BoxFit.cover,
                    // Miniatura: no decodificar la foto de la cámara completa.
                    cacheWidth: 240,
                    errorBuilder: (_, __, ___) => _FotoNoDisponible(cs: cs),
                  )
                : _FotoNoDisponible(cs: cs),
          ),
        ),
      ),
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
              Icons.image_not_supported_outlined,
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
/// guardar una copia donde elija el técnico.
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

  @override
  State<FotoViewerScreen> createState() => _FotoViewerScreenState();
}

class _FotoViewerScreenState extends State<FotoViewerScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  FotoItem get _actual => widget.fotos[_index];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_actual.grupo} · ${_index + 1} de $total',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            onPressed: disponible
                ? () => compartirFotos(context, [_actual], widget.nombreBase)
                : null,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Guardar en el teléfono',
            onPressed: disponible ? _guardar : null,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _pages,
        itemCount: total,
        onPageChanged: (i) => setState(() => _index = i),
        builder: (context, i) {
          final foto = widget.fotos[i];
          if (!foto.existe) {
            return PhotoViewGalleryPageOptions.customChild(
              child: _FotoNoDisponible(
                cs: Theme.of(context).colorScheme,
                grande: true,
              ),
              disableGestures: true,
            );
          }
          return PhotoViewGalleryPageOptions(
            imageProvider: FileImage(File(foto.path)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            heroAttributes: PhotoViewHeroAttributes(tag: foto.path),
          );
        },
        loadingBuilder: (_, __) => const Center(
          child: CircularProgressIndicator(color: AppColors.accentYellow),
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
