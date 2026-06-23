// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:service_met/theme/app_colors.dart';

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

      final params = SaveFileDialogParams(
        data: bytes,
        fileName: fileName,
      );
      final savedPath = await FlutterFileDialog.saveFile(params: params);

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
        final params = SaveFileDialogParams(data: bytes, fileName: fileName);
        final savedPath = await FlutterFileDialog.saveFile(params: params);
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

  Future<void> _deleteFile(FileSystemEntity file) async {
    try {
      await File(file.path).delete();
      setState(() => _loadFiles());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivo eliminado')),
      );
    } catch (e) {
      _showErrorDialog('Error al eliminar', e.toString());
    }
  }

  Future<void> _deleteSelectedFiles() async {
    try {
      for (var file in _selectedFiles) {
        await File(file.path).delete();
      }

      setState(() {
        _loadFiles();
        _selectedFiles.clear();
        _isSelectionMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedFiles.length} archivos eliminados')),
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
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Descargar'),
            onTap: () {
              Navigator.pop(context);
              _downloadFile(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Eliminar'),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(file);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(FileSystemEntity file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content:
            Text('¿Estás seguro de eliminar ${file.uri.pathSegments.last}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(file);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar archivos'),
        content: Text(
            '¿Estás seguro de eliminar ${_selectedFiles.length} archivos seleccionados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSelectedFiles();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
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

  Widget _buildFileList(String title, List<FileSystemEntity> files) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No hay archivos disponibles',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: cs.onSurface.withOpacity(0.38),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.54),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            children: files.asMap().entries.map((entry) {
              final idx = entry.key;
              final file = entry.value;
              return Column(
                children: [
                  _buildFileItem(file),
                  if (idx < files.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      color:
                          isDark ? AppColors.borderDark : AppColors.borderLight,
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
    final accent = cs.primary;
    final fileInfo = File(file.path);
    final stat = fileInfo.statSync();
    final modified = DateTime.fromMillisecondsSinceEpoch(
        stat.modified.millisecondsSinceEpoch);
    final isSelected = _selectedFiles.contains(file);
    final icon = _getFileIcon(file);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _isSelectionMode
          ? Checkbox(
              value: isSelected,
              activeColor: accent,
              onChanged: (_) => _toggleFileSelection(file),
            )
          : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
      title: Text(
        file.uri.pathSegments.last,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: cs.onSurface,
        ),
      ),
      subtitle: Text(
        '${_formatBytes(stat.size)} · ${DateFormat('dd/MM/yyyy HH:mm').format(modified)}',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: cs.onSurface.withOpacity(0.54),
        ),
      ),
      trailing: _isSelectionMode
          ? null
          : IconButton(
              icon: Icon(Icons.download_outlined, color: accent, size: 22),
              onPressed: () => _downloadFile(file),
            ),
      onTap: () => _isSelectionMode
          ? _toggleFileSelection(file)
          : _showFileOptions(file),
      onLongPress: () => _toggleFileSelection(file),
    );
  }

  IconData _getFileIcon(FileSystemEntity file) {
    if (file.path.endsWith('.csv')) return Icons.table_chart;
    if (file.path.endsWith('.db')) return Icons.storage;
    return Icons.insert_drive_file;
  }

  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Widget _buildSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: cs.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar archivos...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.38),
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: cs.onSurface.withOpacity(isDark ? 0.54 : 0.45), size: 20),
          filled: true,
          fillColor: isDark ? AppColors.cardDark : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 20, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _isSelectionMode
            ? '${_selectedFiles.length} seleccionados'
            : 'Respaldo de Datos',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          height: 1.1,
        ),
      ),
      actions: _isSelectionMode
          ? [
              IconButton(
                icon: Icon(Icons.download_outlined, color: accent),
                onPressed: _downloadSelectedFiles,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _confirmDeleteSelected,
              ),
              IconButton(
                icon: Icon(Icons.close,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                onPressed: () => setState(() {
                  _selectedFiles.clear();
                  _isSelectionMode = false;
                }),
              ),
            ]
          : null,
    );
  }

  InputDecoration _buildInputDecoration(String labelText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.54)),
      filled: true,
      fillColor: isDark ? AppColors.cardDark : AppColors.backgroundLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _buildAuthScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    final bgColor =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      appBar: _buildAppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.lock_outline_rounded, color: accent, size: 28),
                ),
                const SizedBox(height: 20),
                Text(
                  'Acceso Restringido',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa la contraseña proporcionada por el área de sistemas para acceder a los respaldos.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(isDark ? 0.60 : 0.54),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _passwordController,
                  decoration: _buildInputDecoration('Contraseña de acceso'),
                  obscureText: false,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Ingresar',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackupScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bgColor =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final accent = cs.primary;
    final filteredDbs = _filterFiles(_databases, _searchController.text);
    final filteredCsvs = _filterFiles(_csvFiles, _searchController.text);
    final filteredBackups =
        _filterFiles(_precargaBackups, _searchController.text);
    final filteredSoporteTec =
        _filterFiles(_soporteTecDbs, _searchController.text);

    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: accent),
            )
          : Column(
              children: [
                _buildSearchField(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFileList(
                            'RESPALDOS DE CALIBRACIÓN', filteredBackups),
                        const SizedBox(height: 24),
                        _buildFileList(
                            'BASES DE DATOS PRINCIPALES', filteredDbs),
                        const SizedBox(height: 24),
                        _buildFileList('SOPORTE TÉCNICO', filteredSoporteTec),
                        const SizedBox(height: 24),
                        _buildFileList('ARCHIVOS CSV', filteredCsvs),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildAuthScreen();
    }

    return _buildBackupScreen();
  }
}
