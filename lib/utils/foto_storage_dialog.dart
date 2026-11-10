import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/utils/saf_storage.dart';
import '../theme/app_icons.dart';

/// Pide al técnico la carpeta principal de ServiceMET donde exportar la
/// documentación de los servicios.
///
/// El técnico elige una carpeta del dispositivo. Android conserva un permiso
/// URI e iOS un bookmark de Archivos, sin acceso al resto de sus archivos.
///
/// Las fotografías se guardan siempre en el almacenamiento propio de la app
/// (no requiere permisos ni conexión); esta carpeta es el destino de la
/// exportación.
class FotoStorageDialog {
  static Future<bool> show(BuildContext context,
      {String subDirName = 'calibracion_fotos'}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(AppIcons.carpeta,
                    size: 24, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Carpeta de ServiceMET',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Seleccione la carpeta donde ServiceMET exportará la '
              'documentación. Cada servicio se guarda en su propia carpeta '
              'identificada por código:',
              textAlign: TextAlign.start,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _folderPreview(isDark, subDirName: subDirName),
            const SizedBox(height: 16),
            Text(
              'El teléfono conserva el acceso a esta carpeta; la aplicación '
              'no accede al resto de sus archivos. '
              '${defaultTargetPlatform == TargetPlatform.iOS ? 'Elija una carpeta en «En mi iPhone» o «En mi iPad» para exportar sin conexión.' : 'Sólo se pedirá una vez.'}',
              textAlign: TextAlign.start,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final tree = await SafStorage.chooseTree();
                      if (ctx.mounted) {
                        Navigator.pop(ctx, tree != null);
                      }
                    },
                    icon: const Icon(AppIcons.carpetaAbierta, size: 18),
                    label: const Text('Seleccionar Carpeta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3e7732),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Widget _folderPreview(bool isDark,
      {String subDirName = 'calibracion_fotos'}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _folderRow(AppIcons.carpeta, '${SafStorage.rootFolder}/', isDark,
              bold: true),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: _folderRow(AppIcons.carpeta, '{código de servicio}/', isDark,
                bold: true),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: _folderRow(
                AppIcons.documento, 'resumen.pdf, datos.csv', isDark),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: _folderRow(AppIcons.carpeta, '$subDirName/', isDark,
                bold: true),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 72),
            child: _folderRow(AppIcons.imagen, '001.jpg, 002.jpg...', isDark),
          ),
        ],
      ),
    );
  }

  static Widget _folderRow(IconData icon, String text, bool isDark,
      {bool bold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white60 : Colors.black45),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}
