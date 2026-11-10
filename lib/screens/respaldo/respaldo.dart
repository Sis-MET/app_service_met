// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:service_met/screens/respaldo/services/database_import_service.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import '../../theme/app_icons.dart';

class BackupService {
  static Future<List<FileSystemEntity>> getDatabaseFiles() async {
    final databasesDir = await getDatabasesPath();
    final dbDir = Directory(databasesDir);
    return dbDir.existsSync()
        ? dbDir.listSync().cast<FileSystemEntity>()
        : <FileSystemEntity>[];
  }

  static Future<List<FileSystemEntity>> getSoporteTecnicoDatabases() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final soporteTecDir = Directory('${appDir.path}/.soporte_tec');

      if (!soporteTecDir.existsSync()) return [];

      return soporteTecDir
          .listSync()
          .where((file) => file is File && file.path.endsWith('.db'))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener bases de soporte técnico: $e');
      return [];
    }
  }

  static Future<List<FileSystemEntity>> getPrecargaBackups() async {
    try {
      final databasesPath = await getDatabasesPath();
      final backupDir = Directory('$databasesPath/backups');

      if (!backupDir.existsSync()) return [];

      return backupDir
          .listSync()
          .where((file) =>
              file is File &&
              (file.path.endsWith('.db') ||
                  file.path.endsWith('.bak') ||
                  file.path.endsWith('.sqlite')))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener backups: $e');
      return [];
    }
  }

  static Future<List<FileSystemEntity>> getCsvFiles() async {
    final appDir = await getApplicationDocumentsDirectory();
    return appDir
        .listSync(recursive: true)
        .where((file) => file.path.endsWith('.csv'))
        .toList();
  }

  static Future<bool> copyFileToDirectory(
      String sourcePath, String destinationDir) async {
    try {
      final fileName = sourcePath.split('/').last;
      final destinationPath = '$destinationDir/$fileName';
      await File(sourcePath).copy(destinationPath);
      return true;
    } catch (e) {
      throw Exception('Failed to copy file: $e');
    }
  }
}

class DateTimeAuthService {
  static String generateCurrentPassword() {
    final now = DateTime.now();

    // Formato: DDMMYY-HHMM (ej. 040825-1118 para 04/08/2025 11:18)
    final datePart = '${now.day.toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.year.toString().substring(2)}';

    final timePart = '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';

    return '$datePart-$timePart';
  }

  static bool authenticate(String enteredPassword) {
    final currentPassword = generateCurrentPassword();

    // Aceptar contraseña actual o del minuto anterior por sincronización
    final previousMinute = DateTime.now().subtract(const Duration(minutes: 1));
    final previousPassword = _generatePasswordForDateTime(previousMinute);

    return enteredPassword == currentPassword ||
        enteredPassword == previousPassword;
  }

  static String _generatePasswordForDateTime(DateTime dateTime) {
    final datePart = '${dateTime.day.toString().padLeft(2, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.year.toString().substring(2)}';

    final timePart = '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}';

    return '$datePart-$timePart';
  }
}

class RespaldoScreen extends StatefulWidget {
  const RespaldoScreen({super.key});

  @override
  _RespaldoScreenState createState() => _RespaldoScreenState();
}

class _RespaldoScreenState extends State<RespaldoScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  bool _isImporting = false;

  List<FileSystemEntity> _databases = [];
  List<FileSystemEntity> _csvFiles = [];
  List<FileSystemEntity> _precargaBackups = [];
  List<FileSystemEntity> _soporteTecDbs = [];

  final Set<FileSystemEntity> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    if (_isAuthenticated) {
      _loadFiles();
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final databases = await BackupService.getDatabaseFiles();
      final csvFiles = await BackupService.getCsvFiles();
      final precargaBackups = await BackupService.getPrecargaBackups();
      final soporteTecDbs = await BackupService.getSoporteTecnicoDatabases();

      setState(() {
        _databases = databases;
        _csvFiles = csvFiles;
        _precargaBackups = precargaBackups;
        _soporteTecDbs = soporteTecDbs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Error al cargar archivos', e.toString());
    }
  }

  void _authenticate() {
    if (DateTimeAuthService.authenticate(_passwordController.text)) {
      setState(() => _isAuthenticated = true);
      _loadFiles();
    } else {
      _showErrorDialog('Error de autenticación',
          'Ingreso incorrecto. Por favor, verifica la contraseña ingresada.');
    }
  }

  Future<void> _downloadFile(FileSystemEntity file) async {
    try {
      final fileName = file.uri.pathSegments.last;
      final Uint8List bytes = await File(file.path).readAsBytes();

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Guardar respaldo',
        bytes: bytes,
        fileName: fileName,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo guardado: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('Error al descargar', e.toString());
    }
  }

  Future<void> _downloadSelectedFiles() async {
    int successCount = 0;
    final List<String> errors = [];

    for (final file in _selectedFiles) {
      try {
        final fileName = file.uri.pathSegments.last;
        final Uint8List bytes = await File(file.path).readAsBytes();
        final savedPath = await FilePicker.saveFile(
          dialogTitle: 'Guardar respaldo',
          bytes: bytes,
          fileName: fileName,
        );
        if (savedPath != null) successCount++;
      } catch (e) {
        errors.add(file.uri.pathSegments.last);
        debugPrint('Error al copiar ${file.path}: $e');
      }
    }

    setState(() {
      _selectedFiles.clear();
      _isSelectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errors.isEmpty
                ? '$successCount archivo(s) descargado(s) correctamente'
                : '$successCount descargados, ${errors.length} con errores',
          ),
          backgroundColor: errors.isEmpty ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  // ── Importación de bases externas ──────────────────────────────────
  //
  // Política: solo fusiona. Nunca reemplaza ni borra la base local; si un
  // registro ya existe (misma clave natural), gana el del teléfono.

  Future<void> _importarBaseDeDatos() async {
    if (_isImporting) return;

    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: 'Selecciona un respaldo .db',
        type: FileType.any,
      );
    } catch (e) {
      _showErrorDialog(
          'No se pudo abrir el selector de archivos', e.toString());
      return;
    }

    final path = picked?.path;
    if (path == null || !mounted) return;

    setState(() => _isImporting = true);
    ImportPreview preview;
    try {
      preview = await DatabaseImportService.analyze(path, picked!.name);
    } on ImportUnsupportedFile catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      _showErrorDialog('Archivo no compatible', e.message);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      _showErrorDialog('No se pudo leer el respaldo', e.toString());
      return;
    }

    if (!mounted) return;
    setState(() => _isImporting = false);

    final confirmar = await _mostrarResumenImportacion(preview);
    if (confirmar != true || !mounted) return;

    setState(() => _isImporting = true);
    final result = await DatabaseImportService.apply(preview);
    if (!mounted) return;
    setState(() => _isImporting = false);

    await _loadFiles();
    if (!mounted) return;
    _mostrarResultadoImportacion(result);
  }

  Future<bool?> _mostrarResumenImportacion(ImportPreview preview) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = cs.primary;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, 28 + MediaQuery.paddingOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revisar importación',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                preview.fileName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.54),
                ),
              ),
              const SizedBox(height: 20),
              _buildImportStat(
                icon: AppIcons.datos,
                color: accent,
                label: 'Contenido detectado',
                value: preview.descripcion,
              ),
              const SizedBox(height: 12),
              _buildImportStat(
                icon: AppIcons.agregarCirculo,
                color: AppColors.success,
                label: 'Registros nuevos a importar',
                value: '${preview.totalNuevas}',
              ),
              const SizedBox(height: 12),
              _buildImportStat(
                icon: AppIcons.quitarCirculo,
                color: cs.onSurface.withOpacity(0.45),
                label: 'Ya existen en el teléfono (se omiten)',
                value: '${preview.totalExistentes}',
              ),
              const SizedBox(height: 12),
              _buildImportStat(
                icon: AppIcons.documento,
                color: cs.onSurface.withOpacity(0.45),
                label: 'Registros leídos del archivo',
                value: '${preview.totalLeidas}',
              ),
              if (preview.columnasIgnoradas.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildImportNotice(
                  icon: AppIcons.advertencia,
                  color: AppColors.warning,
                  text:
                      'El respaldo trae columnas que esta versión no reconoce y '
                      'no se copiarán: ${preview.columnasIgnoradas.join(', ')}.',
                ),
              ],
              const SizedBox(height: 16),
              _buildImportNotice(
                icon: AppIcons.seguridad,
                color: AppColors.success,
                text: 'No se borrará nada de lo que ya está en el teléfono. '
                    'Solo se agregan los registros que faltan.',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: preview.hayAlgoQueImportar
                          ? () => Navigator.pop(ctx, true)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        preview.hayAlgoQueImportar
                            ? 'Importar ${preview.totalNuevas} registro(s)'
                            : 'Nada nuevo que importar',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.70),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportNotice({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: cs.onSurface.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarResultadoImportacion(ImportResult result) {
    if (result.errores.isNotEmpty) {
      _showErrorDialog(
        'Importación con errores',
        'Se importaron ${result.insertadas} registro(s).\n\n'
            'Fallaron:\n${result.errores.join('\n')}',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.insertadas} registro(s) importado(s)'
          '${result.omitidas > 0 ? ' · ${result.omitidas} ya existían' : ''}',
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    try {
      await File(file.path).delete();
      await _loadFiles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo eliminado')),
      );
    } catch (e) {
      _showErrorDialog('Error al eliminar', e.toString());
    }
  }

  Future<void> _deleteSelectedFiles() async {
    // El total se calcula antes de limpiar la selección: antes se leía después
    // del clear() y el mensaje siempre decía "0 archivos eliminados".
    final total = _selectedFiles.length;
    try {
      for (final file in _selectedFiles) {
        await File(file.path).delete();
      }

      setState(() {
        _selectedFiles.clear();
        _isSelectionMode = false;
      });
      await _loadFiles();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$total archivo(s) eliminado(s)')),
      );
    } catch (e) {
      _showErrorDialog('Error al eliminar', e.toString());
    }
  }

  void _toggleFileSelection(FileSystemEntity file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
        if (_selectedFiles.isEmpty) _isSelectionMode = false;
      } else {
        _selectedFiles.add(file);
        _isSelectionMode = true;
      }
    });
  }

  void _showFileOptions(FileSystemEntity file) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.descargar),
              title: const Text('Descargar'),
              subtitle: const Text('Guardar una copia fuera de la app'),
              onTap: () {
                Navigator.pop(sheetContext);
                _downloadFile(file);
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.eliminar,
                  color: AppColors.actionNegative),
              title: const Text('Eliminar'),
              subtitle: Text(
                _esBaseCritica(file)
                    ? 'Contiene datos maestros de la app'
                    : 'Borrar del dispositivo',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(FileSystemEntity file) {
    final critica = _esBaseCritica(file);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          critica ? AppIcons.advertencia : AppIcons.eliminar,
          color: critica ? AppColors.warning : AppColors.actionNegative,
        ),
        title: Text(critica ? 'Base crítica' : 'Eliminar archivo'),
        content: Text(
          critica
              ? 'Vas a borrar "${file.uri.pathSegments.last}", que contiene '
                  'datos maestros de la app. Sin este archivo no aparecerán '
                  'clientes, plantas ni balanzas, y tendrás que volver a '
                  'descargar la precarga. ¿Continuar?'
              : '¿Eliminar ${file.uri.pathSegments.last}? '
                  'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.actionNegative,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteFile(file);
            },
            child: Text(critica ? 'Borrar de todas formas' : 'Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected() {
    final criticas = _selectedFiles.where(_esBaseCritica).toList();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          criticas.isEmpty ? AppIcons.eliminar : AppIcons.advertencia,
          color:
              criticas.isEmpty ? AppColors.actionNegative : AppColors.warning,
        ),
        title: const Text('Eliminar archivos'),
        content: Text(
          criticas.isEmpty
              ? '¿Eliminar ${_selectedFiles.length} archivo(s)? '
                  'Esta acción no se puede deshacer.'
              : 'La selección incluye ${criticas.length} base(s) con datos '
                  'maestros (${criticas.map((f) => f.uri.pathSegments.last).join(', ')}). '
                  'Si las borras tendrás que volver a descargar la precarga. '
                  '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.actionNegative,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteSelectedFiles();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  List<FileSystemEntity> _filterFiles(
      List<FileSystemEntity> files, String query) {
    if (query.isEmpty) return files;
    return files
        .where((file) => file.path.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Bases que contienen datos maestros o de servicio y cuya eliminación deja
  /// la app inutilizable hasta volver a descargar la precarga. Se avisa antes
  /// de borrarlas.
  static const Set<String> _basesCriticas = {
    'precarga_database.db',
    'calibracion.db',
    'service_met.db',
  };

  bool _esBaseCritica(FileSystemEntity file) =>
      _basesCriticas.contains(file.uri.pathSegments.last);

  Widget _buildFileList(String title, List<FileSystemEntity> files) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Expanded(
                  child: Text(title, style: AppDesign.titleStyle(context))),
              if (files.isNotEmpty)
                Text(
                  '${files.length}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (files.isEmpty)
          AppPanel(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(AppIcons.bandeja, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No hay archivos en esta categoría',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          )
        else
          AppPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: files.asMap().entries.map((entry) {
                final idx = entry.key;
                return Column(
                  children: [
                    _buildFileItem(entry.value),
                    if (idx < files.length - 1)
                      Divider(
                        height: 1,
                        indent: 64,
                        endIndent: 12,
                        color: cs.outlineVariant.withOpacity(0.7),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFileItem(FileSystemEntity file) {
    final cs = Theme.of(context).colorScheme;
    final stat = File(file.path).statSync();
    final isSelected = _selectedFiles.contains(file);
    final critica = _esBaseCritica(file);
    final accent = critica ? AppColors.shimmerGold : AppColors.actionPositive;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _isSelectionMode
          ? Checkbox(
              value: isSelected,
              activeColor: AppColors.actionPositive,
              onChanged: (_) => _toggleFileSelection(file),
            )
          : Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: AppDesign.smallRadius,
              ),
              child: Icon(_getFileIcon(file), color: accent, size: 20),
            ),
      title: Text(
        file.uri.pathSegments.last,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Flexible(
              child: Text(
                '${_formatBytes(stat.size)} · '
                '${DateFormat('dd/MM/yyyy HH:mm').format(stat.modified)}',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (critica) ...[
              const SizedBox(width: 8),
              const Icon(AppIcons.seguridad,
                  size: 13, color: AppColors.shimmerGold),
            ],
          ],
        ),
      ),
      trailing: _isSelectionMode
          ? null
          : IconButton.filledTonal(
              tooltip: 'Descargar',
              onPressed: () => _downloadFile(file),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accentYellow.withOpacity(0.12),
                foregroundColor: cs.onSurface,
              ),
              icon: const Icon(AppIcons.descargar, size: 19),
            ),
      onTap: () => _isSelectionMode
          ? _toggleFileSelection(file)
          : _showFileOptions(file),
      onLongPress: () => _toggleFileSelection(file),
    );
  }

  IconData _getFileIcon(FileSystemEntity file) {
    if (file.path.endsWith('.csv')) return AppIcons.tabla;
    if (file.path.endsWith('.db')) return AppIcons.datos;
    return AppIcons.archivo;
  }

  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Buscar archivos…',
        prefixIcon: const Icon(AppIcons.buscar, size: 20),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(AppIcons.cerrar, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
        isDense: true,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: AppDesign.mediumRadius,
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isAuthenticated ? _buildBackupScreen() : _buildAuthScreen();
  }

  Widget _buildAuthScreen() {
    return Scaffold(
      appBar: const ServiceAppBar(title: 'Respaldo de datos'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesign.pagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.actionPositive.withOpacity(0.13),
                      borderRadius: AppDesign.mediumRadius,
                    ),
                    child: const Icon(AppIcons.bloqueado,
                        color: AppColors.actionPositive, size: 24),
                  ),
                  const SizedBox(height: 20),
                  Text('Acceso restringido',
                      style: AppDesign.displayStyle(context)),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa la contraseña proporcionada por el área de '
                    'sistemas para administrar los respaldos.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _authenticate(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña de acceso',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: AppDesign.mediumRadius,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _authenticate,
                    style: AppDesign.positiveButtonStyle(),
                    icon: const Icon(AppIcons.ingresar),
                    label: const Text('Ingresar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackupScreen() {
    final query = _searchController.text;
    final filteredBackups = _filterFiles(_precargaBackups, query);
    final filteredDbs = _filterFiles(_databases, query);
    final filteredSoporteTec = _filterFiles(_soporteTecDbs, query);
    final filteredCsvs = _filterFiles(_csvFiles, query);

    return Scaffold(
      appBar: ServiceAppBar(
        title: _isSelectionMode
            ? '${_selectedFiles.length} seleccionados'
            : 'Respaldo de datos',
        actions: _isSelectionMode
            ? [
                IconButton(
                  tooltip: 'Descargar selección',
                  icon: const Icon(AppIcons.descargar),
                  onPressed: _downloadSelectedFiles,
                ),
                IconButton(
                  tooltip: 'Eliminar selección',
                  icon: const Icon(AppIcons.eliminar,
                      color: AppColors.actionNegative),
                  onPressed: _confirmDeleteSelected,
                ),
                IconButton(
                  tooltip: 'Cancelar',
                  icon: const Icon(AppIcons.cerrar),
                  onPressed: () => setState(() {
                    _selectedFiles.clear();
                    _isSelectionMode = false;
                  }),
                ),
              ]
            : null,
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              heroTag: 'importar_respaldo',
              onPressed: _isImporting ? null : _importarBaseDeDatos,
              backgroundColor: AppColors.actionPositive,
              foregroundColor: AppColors.actionPositiveInk,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.subirArchivo),
              label: Text(
                _isImporting ? 'Importando…' : 'Importar base',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.actionPositive,
              onRefresh: _loadFiles,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppDesign.pagePadding,
                  14,
                  AppDesign.pagePadding,
                  112,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Archivos del dispositivo',
                            style: AppDesign.displayStyle(context)),
                        const SizedBox(height: 6),
                        Text(
                          'Descarga una copia, elimina lo que ya no uses o '
                          'importa un respaldo para recuperar registros.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        _buildSearchField(),
                        const SizedBox(height: 26),
                        _buildFileList(
                            'Respaldos de calibración', filteredBackups),
                        const SizedBox(height: 26),
                        _buildFileList('Bases principales', filteredDbs),
                        const SizedBox(height: 26),
                        _buildFileList('Soporte técnico', filteredSoporteTec),
                        const SizedBox(height: 26),
                        _buildFileList('Archivos CSV', filteredCsvs),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
