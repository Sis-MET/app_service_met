import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../../../utils/foto_storage_dialog.dart';
import '../../../utils/saf_storage.dart';
import '../../../utils/service_exporter.dart';
import '../../../utils/top_alert.dart';
import '../data/historial_versiones.dart';
import '../widgets/calidad_ui.dart';
import '../../../theme/app_icons.dart';

/// Carpeta, dentro de ServiceMET, donde se guardan los documentos de calidad.
const carpetaCalidad = 'Calidad';

/// Versión instalada con su build ("6.3.3+15"); si la plataforma no la
/// informa, la última registrada en el historial.
Future<String> versionInstalada() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isEmpty) return historialVersiones.first.version;
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  } catch (_) {
    return historialVersiones.first.version;
  }
}

enum _Destino { guardar, compartir, imprimir }

/// Pregunta qué hacer con el documento de calidad, lo genera y lo guarda,
/// comparte o envía a imprimir.
Future<void> exportarDocumentoCalidad(
  BuildContext context, {
  required String titulo,
  required String nombreArchivo,
  required Future<Uint8List> Function(String appVersion) generar,
}) =>
    exportarPdf(
      context,
      titulo: titulo,
      carpeta: carpetaCalidad,
      fileName: '${nombreArchivo}_'
          '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      generar: () async => generar(await versionInstalada()),
    );

/// Pregunta qué hacer con un PDF generado en el teléfono, lo genera y lo
/// guarda en `ServiceMET/{carpeta}`, lo comparte o lo envía a imprimir.
Future<void> exportarPdf(
  BuildContext context, {
  required String titulo,
  required String carpeta,
  required String fileName,
  required Future<Uint8List> Function() generar,
}) async {
  final destino = await showModalBottomSheet<_Destino>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDesign.radiusLarge),
      ),
    ),
    builder: (sheetContext) => _HojaExportar(titulo: titulo, carpeta: carpeta),
  );
  if (destino == null || !context.mounted) return;

  final Uint8List bytes;
  try {
    bytes = await _conProgreso(context, generar);
  } catch (e) {
    if (context.mounted) {
      TopAlert.show(context, 'No se pudo generar el PDF: $e', isError: true);
    }
    return;
  }
  if (!context.mounted) return;

  try {
    switch (destino) {
      case _Destino.guardar:
        await _guardar(context, carpeta, fileName, bytes);
      case _Destino.compartir:
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(ShareParams(
          files: [
            XFile.fromData(bytes,
                name: fileName, mimeType: ServiceExporter.pdfMime),
          ],
          fileNameOverrides: [fileName],
          subject: titulo,
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ));
      case _Destino.imprimir:
        await Printing.layoutPdf(
          name: fileName,
          onLayout: (_) async => bytes,
        );
    }
  } catch (e) {
    if (context.mounted) {
      TopAlert.show(context, 'No se pudo exportar: $e', isError: true);
    }
  }
}

Future<void> _guardar(
  BuildContext context,
  String carpeta,
  String fileName,
  Uint8List bytes,
) async {
  // Igual que la exportación de servicios: si aún no hay carpeta ServiceMET,
  // se ofrece elegirla; si el técnico no la elige, se usa el selector del
  // sistema para guardar el archivo suelto.
  if (SafStorage.isSupported && !await SafStorage.isConfigured()) {
    if (!context.mounted) return;
    await FotoStorageDialog.show(context);
    if (!context.mounted) return;
  }

  final result = await ServiceExporter.exportDocument(
    codigoServicio: carpeta,
    fileName: fileName,
    mimeType: ServiceExporter.pdfMime,
    bytes: bytes,
  );
  if (!result.saved || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Guardado en: ${result.destination}'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      action: result.canOpen
          ? SnackBarAction(
              label: 'Abrir',
              textColor: Colors.white,
              onPressed: () => SafStorage.openDocument(
                result.uri!,
                mimeType: ServiceExporter.pdfMime,
              ),
            )
          : null,
    ),
  );
}

/// Muestra un indicador mientras se genera el documento.
Future<T> _conProgreso<T>(
  BuildContext context,
  Future<T> Function() tarea,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    return await tarea();
  } finally {
    navigator.pop();
  }
}

class _HojaExportar extends StatelessWidget {
  const _HojaExportar({required this.titulo, required this.carpeta});

  final String titulo;
  final String carpeta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Exportar $titulo', style: AppDesign.titleStyle(context)),
            const SizedBox(height: 4),
            Text(
              'Documento PDF generado en el teléfono, sin conexión.',
              style:
                  GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            _opcion(
              context,
              icono: AppIcons.descargar,
              titulo: 'Guardar PDF',
              detalle: 'En la carpeta ServiceMET/$carpeta',
              destino: _Destino.guardar,
            ),
            _opcion(
              context,
              icono: AppIcons.compartir,
              titulo: 'Compartir',
              detalle: 'Correo, WhatsApp, Drive u otra app',
              destino: _Destino.compartir,
            ),
            _opcion(
              context,
              icono: AppIcons.imprimir,
              titulo: 'Imprimir',
              detalle: 'Vista previa, impresora o guardar como PDF',
              destino: _Destino.imprimir,
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcion(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String detalle,
    required _Destino destino,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: AppDesign.mediumRadius),
      leading: CalidadIcono(icono),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(detalle),
      trailing: const Icon(AppIcons.siguiente),
      onTap: () => Navigator.pop(context, destino),
    );
  }
}
