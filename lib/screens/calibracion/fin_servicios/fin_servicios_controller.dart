// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/app_database.dart';
import 'package:service_met/screens/calibracion/precarga/precarga_screen.dart';
import 'package:service_met/home/screens/home_screen.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class FinServiciosController extends ChangeNotifier {
  final String secaValue;
  final String sessionId;
  final String codMetrica;
  final BuildContext context;

  int _currentStep = 0;
  int get currentStep => _currentStep;

  // Step 1: Condiciones Finales
  final TextEditingController horaController = TextEditingController();
  final TextEditingController hrifinController = TextEditingController();
  final TextEditingController tifinController = TextEditingController();
  final TextEditingController patmifinController = TextEditingController();
  final TextEditingController mantenimientoController = TextEditingController();
  final TextEditingController ventaPesasController = TextEditingController();
  final TextEditingController reemplazoController = TextEditingController();
  final TextEditingController obscomController = TextEditingController();
  final FocusNode obscomFocusNode = FocusNode();

  double? hriInicial;
  double? tiInicial;
  double? patmiInicial;

  final Map<String, List<File>> finalPhotos = {};
  final ImagePicker _imagePicker = ImagePicker();
  bool fotosTomadas = false;
  bool isDataSaved = false;

  // Step 2: Exportación
  String? selectedEmp23001;
  final TextEditingController indicarController = TextEditingController();
  final TextEditingController factorSeguridadController =
      TextEditingController();
  String? selectedReglaAceptacion;
  bool isExporting = false;

  // Sticker Preview (Pasos Finales)
  String stickerCertificado = '';
  String stickerFecha = '';
  String stickerCodMetrica = '';
  String stickerNro = '';

  // Auto-save
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;
  bool get isAutoSaving => _isAutoSaving;
  bool _lastSaveSuccessful = true;
  bool get lastSaveSuccessful => _lastSaveSuccessful;

  FinServiciosController({
    required this.secaValue,
    required this.sessionId,
    required this.codMetrica,
    required this.context,
  }) {
    _loadInitialValues();
    _setupAutoSaveListeners();
  }

  void _setupAutoSaveListeners() {
    final controllers = [
      horaController,
      hrifinController,
      tifinController,
      patmifinController,
      mantenimientoController,
      ventaPesasController,
      reemplazoController,
      obscomController,
    ];
    for (final ctrl in controllers) {
      ctrl.addListener(_scheduleAutoSave);
    }
  }

  void _scheduleAutoSave() {
    // Solo auto-guardar en el paso 1
    if (_currentStep != 0) return;

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () {
      _autoSave();
    });
  }

  Future<void> flushAutoSave() async {
    _autoSaveTimer?.cancel();
    if (_currentStep == 0) {
      await _autoSave();
    }
  }

  Future<void> _autoSave() async {
    if (_isAutoSaving) return;
    _isAutoSaving = true;
    notifyListeners();

    try {
      await _saveStep1DataOnly();
      _lastSaveSuccessful = true;
      debugPrint('💾 Auto-guardado fin de servicios completado');
    } catch (e) {
      _lastSaveSuccessful = false;
      debugPrint('❌ Error en auto-guardado fin servicios: $e');
    } finally {
      _isAutoSaving = false;
      notifyListeners();
    }
  }

  Future<void> _loadInitialValues() async {
    fetchEquipos(); // Cargar pesas disponibles
    try {
      final dbHelper = AppDatabase();
      final registro = await dbHelper.getRegistroBySeca(secaValue, sessionId);

      if (registro != null) {
        hriInicial = double.tryParse(registro['hri']?.toString() ?? '');
        tiInicial = double.tryParse(registro['ti']?.toString() ?? '');
        patmiInicial = double.tryParse(registro['patmi']?.toString() ?? '');

        // --- Cálculo de Datos para el Sticker ---
        final reca = registro['n_reca']?.toString() ?? 'SN';
        final sticker = registro['sticker']?.toString() ?? 'SN';
        final fecha = registro['fecha_servicio']?.toString() ??
            DateFormat('yyyy-MM-dd').format(DateTime.now());

        // Cód Cliente (ej: 0028 de 0028-11-020)
        final codParts = codMetrica.split('-');
        final codCliente = codParts.isNotEmpty ? codParts[0] : 'XXXX';

        // Cotización (ej: C04 de 26-0028-11-C04)
        final secaParts = secaValue.split('-');
        final cotizacion = secaParts.isNotEmpty ? secaParts.last : 'C0X';

        // Gestión (2 dígitos del año actual)
        final gestion = DateTime.now().year.toString().substring(2);

        stickerCertificado = '$codCliente-$cotizacion-$reca-$gestion';
        stickerFecha = fecha;
        stickerCodMetrica = codMetrica;
        stickerNro = sticker;

        // Cargar datos previos si existen
        horaController.text = registro['hora_fin']?.toString() ?? '';
        hrifinController.text = registro['hri_fin']?.toString() ?? '';
        tifinController.text = registro['ti_fin']?.toString() ?? '';
        patmifinController.text = registro['patmi_fin']?.toString() ?? '';
        mantenimientoController.text =
            registro['mant_soporte']?.toString() ?? '';
        ventaPesasController.text = registro['venta_pesas']?.toString() ?? '';
        reemplazoController.text = registro['reemplazo']?.toString() ?? '';

        final existingObs = registro['observaciones']?.toString();
        if (existingObs != null && existingObs.isNotEmpty) {
          obscomController.text = existingObs;
        } else {
          obscomController.text = "Sin Observaciones";
        }

        notifyListeners();
      } else {
        obscomController.text = "Sin Observaciones";
      }
    } catch (e) {
      debugPrint('Error al cargar valores iniciales: $e');
      obscomController.text = "Sin Observaciones";
    }

    // Add Focus listener for target behavior
    obscomFocusNode.addListener(() {
      if (obscomFocusNode.hasFocus) {
        if (obscomController.text == "Sin Observaciones") {
          obscomController.clear();
        }
      } else {
        if (obscomController.text.trim().isEmpty) {
          obscomController.text = "Sin Observaciones";
        }
      }
    });
  }

  void setStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  // --- Logic for Step 1 ---

  void setHora() {
    final now = DateTime.now();
    final formattedTime = DateFormat('HH:mm:ss').format(now);
    horaController.text = formattedTime;
    _scheduleAutoSave();
    notifyListeners();
  }

  Future<void> takePhoto() async {
    final photo = await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      finalPhotos['final'] ??= [];
      if (finalPhotos['final']!.length < 5) {
        finalPhotos['final']!.add(File(photo.path));
        fotosTomadas = true;
        _scheduleAutoSave();
        notifyListeners();
      } else {
        _showSnackBar('Maximo de 5 fotos alcanzado', isError: true);
      }
    }
  }

  void removePhoto(File photo) {
    finalPhotos['final']?.remove(photo);
    if (finalPhotos['final']?.isEmpty ?? true) {
      fotosTomadas = false;
    }
    _scheduleAutoSave();
    notifyListeners();
  }

  bool validateStep1() {
    if (horaController.text.isEmpty ||
        hrifinController.text.isEmpty ||
        tifinController.text.isEmpty ||
        patmifinController.text.isEmpty ||
        mantenimientoController.text.isEmpty ||
        ventaPesasController.text.isEmpty ||
        reemplazoController.text.isEmpty ||
        obscomController.text.isEmpty) {
      _showSnackBar('Debe terminar de llenar todos los campos', isError: true);
      return false;
    }
    return true;
  }

  Future<void> saveStep1() async {
    if (finalPhotos['final']?.isNotEmpty ?? false) {
      await _savePhotosToZip();
    }
    await _saveStep1DataOnly();
  }

  Future<void> _saveStep1DataOnly() async {
    try {
      final dbHelper = AppDatabase();
      final existingRecord =
          await dbHelper.getRegistroBySeca(secaValue, sessionId);

      final Map<String, dynamic> registro = {
        'session_id': sessionId,
        'seca': secaValue,
        'hora_fin': horaController.text,
        'hri_fin': hrifinController.text,
        'ti_fin': tifinController.text,
        'patmi_fin': patmifinController.text,
        'mant_soporte': mantenimientoController.text,
        'venta_pesas': ventaPesasController.text,
        'reemplazo': reemplazoController.text,
        'observaciones': obscomController.text,
        'estado_servicio_bal': 'Balanza Calibrada',
      };

      // Guardar Pesas Patrón seleccionadas (Slots 1-5)
      for (int i = 0; i < _selectedPesas.length; i++) {
        final index = i + 1;
        final pesa = _selectedPesas[i];
        registro['equipo$index'] = pesa['cod_instrumento'];
        registro['certificado$index'] = pesa['cert_fecha'];
        registro['ente_calibrador$index'] = pesa['ente_calibrador'];
        // registro['estado$index'] = 'OK'; // O lo que corresponda
        registro['cantidad$index'] = pesa['cantidad'];
      }
      // Limpiar slots restantes si se deseleccionaron pesas (opcional pero recomendado)
      for (int i = _selectedPesas.length; i < 5; i++) {
        final index = i + 1;
        registro['equipo$index'] = '';
        registro['certificado$index'] = '';
        registro['ente_calibrador$index'] = '';
        registro['cantidad$index'] = '';
      }

      if (existingRecord != null) {
        await dbHelper.upsertRegistroCalibracion(registro);
      } else {
        await dbHelper.insertRegistroCalibracion(registro);
      }

      isDataSaved = true;
    } catch (e) {
      debugPrint('Error interno al guardar: $e');
      rethrow;
    }
  }

  Future<void> _savePhotosToZip() async {
    if (finalPhotos['final']?.isNotEmpty ?? false) {
      final archive = Archive();
      for (var i = 0; i < finalPhotos['final']!.length; i++) {
        final file = finalPhotos['final']![i];
        final fileName = 'final_${i + 1}.jpg';
        archive.addFile(
            ArchiveFile(fileName, file.lengthSync(), file.readAsBytesSync()));
      }

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      final uint8ListData = Uint8List.fromList(zipData);
      final zipFileName = '${secaValue}_${codMetrica}_FotosFinalesBalanza.zip';

      final params = SaveFileDialogParams(
        data: uint8ListData,
        fileName: zipFileName,
        mimeTypesFilter: ['application/zip'],
      );

      try {
        await FlutterFileDialog.saveFile(params: params);
      } catch (e) {
        _showSnackBar('Error al guardar fotos: $e', isError: true);
      }
    }
  }

  // --- Logic for Step 2 --- (Offset will shift down)

  // EQUIPOS (Pesas Patrón) logic
  List<dynamic> _equiposOptions = [];
  final List<Map<String, dynamic>> _selectedPesas = [];
  List<dynamic> get equiposOptions => _equiposOptions;
  List<Map<String, dynamic>> get selectedPesas => _selectedPesas;

  Future<void> fetchEquipos() async {
    try {
      String path = join(await getDatabasesPath(), 'precarga_database.db');
      debugPrint('Cargando equipos de: $path');
      final db = await openDatabase(path);

      final List<Map<String, dynamic>> equiposList = await db.query(
        'equipamientos',
        where: "estado != 'DESACTIVADO'",
      );

      debugPrint('Total equipos cargados: ${equiposList.length}');

      _equiposOptions = equiposList.where((e) {
        final instrumento = e['instrumento']?.toString().toLowerCase() ?? '';
        final tipo = e['tipo_instrumento']?.toString().toLowerCase() ?? '';
        final descripcion = e['descripcion']?.toString().toLowerCase() ?? '';

        final isPesa = instrumento.contains('pesa') ||
            tipo.contains('pesa') ||
            descripcion.contains('pesa');

        final isMasa = instrumento.contains('masa') ||
            tipo.contains('masa') ||
            descripcion.contains('masa');

        return isPesa || isMasa;
      }).toList();

      debugPrint('Pesas filtradas: ${_equiposOptions.length}');

      await db.close();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar equipos: $e');
    }
  }

  void addPesa(Map<String, dynamic> equipo) {
    if (_selectedPesas.length < 5) {
      // Create a copy to modify if needed, add default quantity 1
      final pesa = Map<String, dynamic>.from(equipo);
      pesa['cantidad'] = '1';
      _selectedPesas.add(pesa);
      _scheduleAutoSave();
      notifyListeners();
    } else {
      _showSnackBar('Máximo 5 pesas patrón permitidas', isError: true);
    }
  }

  void removePesa(String codInstrumento) {
    _selectedPesas.removeWhere((p) => p['cod_instrumento'] == codInstrumento);
    _scheduleAutoSave();
    notifyListeners();
  }

  void updatePesaCantidad(String codInstrumento, String nuevaCantidad) {
    final index = _selectedPesas
        .indexWhere((p) => p['cod_instrumento'] == codInstrumento);
    if (index != -1) {
      _selectedPesas[index]['cantidad'] = nuevaCantidad;
      _scheduleAutoSave();
    }
  }

  // --- Logic for Step 2 --- (Existing code follows)

  Future<List<Map<String, dynamic>>> prepareExportData() async {
    try {
      final dbHelper = AppDatabase();
      final db = await dbHelper.database;

      final rows = await db.query(
        'registros_calibracion',
        where: 'seca = ? AND estado_servicio_bal = ?',
        whereArgs: [secaValue, 'Balanza Calibrada'],
      );

      final cantidad = rows.length;

      if (cantidad == 0) {
        _showSnackBar(
            'No hay registros para exportar con este SECA ($secaValue)',
            isError: true);
        return [];
      }

      // 1. Solicitar datos adicionales (Dialog logic should be in UI, but we can handle data here)
      // Assuming the dialog is handled in the UI and sets the values in the controller
      if (selectedEmp23001 == null ||
          indicarController.text.isEmpty ||
          factorSeguridadController.text.isEmpty ||
          selectedReglaAceptacion == null) {
        // This check should ideally happen before calling this method or inside the dialog
        // But if we are calling this from the "Finalizar" button directly after filling fields
        _showSnackBar('Complete todos los campos de exportación',
            isError: true);
        return [];
      }

      // 2. Actualizar registros con datos adicionales
      for (final row in rows) {
        await db.update(
          'registros_calibracion',
          {
            'emp': selectedEmp23001,
            'indicar': indicarController.text,
            'factor': factorSeguridadController.text,
            'regla_aceptacion': selectedReglaAceptacion,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }

      // 3. Obtener rows actualizados
      final updatedRows = await db.query(
        'registros_calibracion',
        where: 'seca = ? AND estado_servicio_bal = ?',
        whereArgs: [secaValue, 'Balanza Calibrada'],
      );

      return updatedRows;
    } catch (e) {
      _showSnackBar('Error en exportación: $e', isError: true);
      return [];
    }
  }

  Future<void> executeExport(List<Map<String, dynamic>> rows) async {
    final success = await _exportToCSV(rows);

    // Solo navegar al inicio si la exportación fue exitosa
    if (success && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<bool> _exportToCSV(List<Map<String, dynamic>> registros) async {
    if (isExporting) return false;
    isExporting = true;
    notifyListeners();

    try {
      final registrosDepurados = await _depurarDatos(registros);
      final csvBytes = await _generateCSVBytes(registrosDepurados);
      final fileName =
          '${secaValue}_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.csv';

      final params = SaveFileDialogParams(
        data: Uint8List.fromList(csvBytes),
        fileName: fileName,
        mimeTypesFilter: ['text/csv'],
      );

      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (savedPath != null) {
        final savedFile = savedPath.split('/').last;
        final savedDir = savedPath.contains('/')
            ? savedPath.substring(0, savedPath.lastIndexOf('/'))
            : savedPath;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1B5E20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'CSV exportado exitosamente',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.insert_drive_file,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        savedFile,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.folder, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        savedDir,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        return true;
      } else {
        _showSnackBar('Exportación cancelada.', isError: true);
        return false;
      }
    } catch (e) {
      _showSnackBar('Error al exportar CSV: $e', isError: true);
      return false;
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> _depurarDatos(
      List<Map<String, dynamic>> registros) async {
    registros.removeWhere((registro) =>
        registro.values.every((value) => value == null || value == ''));

    final Map<String, Map<String, dynamic>> registrosUnicos = {};

    for (var registro in registros) {
      final String claveUnica =
          '${registro['reca']}_${registro['cod_metrica']}_${registro['sticker']}';
      final String horaFinActual = registro['hora_fin']?.toString() ?? '';

      if (!registrosUnicos.containsKey(claveUnica) ||
          (registrosUnicos[claveUnica]?['hora_fin']?.toString() ?? '')
                  .compareTo(horaFinActual) <
              0) {
        registrosUnicos[claveUnica] = registro;
      }
    }

    return registrosUnicos.values.toList();
  }

  Future<List<int>> _generateCSVBytes(
      List<Map<String, dynamic>> registros) async {
    final headers = registros.first.keys.toList();

    final rows = registros.map((registro) {
      return headers.map((header) {
        final value = registro[header];
        if (value is double || value is num) {
          return value.toString();
        } else {
          return value?.toString() ?? '';
        }
      }).toList();
    }).toList();

    rows.insert(0, headers);

    final csv = const ListToCsvConverter(
      fieldDelimiter: ';',
      textDelimiter: '"',
    ).convert(rows);

    return utf8.encode(csv);
  }

  Future<void> confirmarSeleccionOtraBalanza() async {
    try {
      final dbHelper = AppDatabase();
      final db = await dbHelper.database;

      final List<Map<String, dynamic>> rows = await db.query(
        'registros_calibracion',
        where: 'seca = ? AND session_id = ?',
        whereArgs: [secaValue, sessionId],
        orderBy: 'id DESC',
      );

      final nuevoSessionId = await dbHelper.generateSessionId(secaValue);

      final Map<String, dynamic> nuevoRegistro = {
        'seca': secaValue,
        'session_id': nuevoSessionId,
        'fecha_servicio': DateFormat('dd-MM-yyyy').format(DateTime.now()),
      };

      const columnsToCarry = [
        'cliente',
        'razon_social',
        'planta',
        'dir_planta',
        'dep_planta',
        'cod_planta',
        'personal',
        'equipo6',
        'certificado6',
        'ente_calibrador6',
        'estado6',
        'cantidad6',
        'equipo7',
        'certificado7',
        'ente_calibrador7',
        'estado7',
        'cantidad7',
      ];

      for (final col in columnsToCarry) {
        for (final row in rows) {
          final v = row[col];
          if (v != null && (v is! String || v.toString().trim().isNotEmpty)) {
            nuevoRegistro[col] = v;
            break;
          }
        }
      }

      await dbHelper.upsertRegistroCalibracion(nuevoRegistro);

      final userName = nuevoRegistro['personal']?.toString() ?? 'Usuario';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PrecargaScreen(
            userName: userName,
            initialStep: 3,
            sessionId: nuevoSessionId,
            secaValue: secaValue,
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Error al preparar nueva balanza: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    horaController.dispose();
    hrifinController.dispose();
    tifinController.dispose();
    patmifinController.dispose();
    mantenimientoController.dispose();
    ventaPesasController.dispose();
    reemplazoController.dispose();
    obscomController.dispose();
    obscomFocusNode.dispose();
    indicarController.dispose();
    factorSeguridadController.dispose();
    super.dispose();
  }
}
