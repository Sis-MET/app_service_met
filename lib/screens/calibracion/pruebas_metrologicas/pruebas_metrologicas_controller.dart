// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:service_met/screens/calibracion/pruebas_metrologicas/excentricidad/excentricidad_controller.dart';
import 'package:service_met/screens/calibracion/pruebas_metrologicas/linealidad/linealidad_controller.dart';
import 'package:service_met/screens/calibracion/pruebas_metrologicas/repetibilidad/repetibilidad_controller.dart';
import 'package:service_met/providers/calibration_provider.dart';
import 'package:provider/provider.dart';

class PruebasMetrologicasController extends ChangeNotifier {
  final String codMetrica;
  final String secaValue;
  final String sessionId;
  final BuildContext context;

  int _currentStep = 0;
  int get currentStep => _currentStep;

  late ExcentricidadController excentricidadController;
  late RepetibilidadController repetibilidadController;
  late LinealidadController linealidadController;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  PruebasMetrologicasController({
    required this.codMetrica,
    required this.secaValue,
    required this.sessionId,
    required this.context,
  }) {
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    _isLoading = true;
    notifyListeners();

    // Initialize ExcentricidadController
    excentricidadController = ExcentricidadController(
      codMetrica: codMetrica,
      secaValue: secaValue,
      sessionId: sessionId,
      onUpdate: notifyListeners,
    );
    await excentricidadController.initialize();

    // Initialize RepetibilidadController
    final calibrationProvider =
        Provider.of<CalibrationProvider>(context, listen: false);
    repetibilidadController = RepetibilidadController(
      provider: calibrationProvider,
      codMetrica: codMetrica,
      secaValue: secaValue,
      sessionId: sessionId,
      context: context,
      onUpdate: notifyListeners,
    );

    await repetibilidadController.initialize();

    // Initialize LinealidadController
    linealidadController = LinealidadController(
      context: context,
      provider: calibrationProvider,
      codMetrica: codMetrica,
      secaValue: secaValue,
      sessionId: sessionId,
      onUpdate: notifyListeners,
    );

    await linealidadController.loadLinFromPrecargaOrDatabase();

    _isLoading = false;
    notifyListeners();
  }

  File? _cargaPhoto;
  File? get cargaPhoto => _cargaPhoto;

  void setCargaPhoto(File photo) {
    _cargaPhoto = photo;
    notifyListeners();
  }

  Future<void> savePhotoToDevice() async {
    if (_cargaPhoto == null) return;

    try {
      // Solicitar permiso de almacenamiento (Android < 10 o MANAGE_EXTERNAL_STORAGE)
      // O simplemente usar file_picker que maneja permisos en algunos casos o usar SAF.
      // ESTRATEGIA: Usar FilePicker.platform.saveFile si es posible, o getApplicationDocumentsDirectory y luego mostrar dialogo.
      // Dado el requerimiento "abrir el explorador de archivos ... guardarla en una carpeta que el usuario seleccione"
      // file_picker saveFile es lo más cercano a "Guardar como".

      // Leer los bytes de la imagen
      final Uint8List fileBytes = await _cargaPhoto!.readAsBytes();

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Foto de Carga',
        fileName: '${secaValue}_$codMetrica.jpg',
        type: FileType.image,
        bytes: fileBytes, // Pasamos los bytes requeridos en Android/iOS
      );

      if (outputFile != null) {
        // En Android/iOS, si se pasan 'bytes', el FilePicker se encarga de guardar el archivo.
        // El path devuelto puede ser un URI del sistema que File.copy no puede manejar directamente.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Foto guardada correctamente'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error saving photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void setStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    // Ahora tenemos 4 pasos (indices 0, 1, 2, 3)
    // 0: Excentricidad
    // 1: Repetibilidad
    // 2: Linealidad
    // 3: Foto
    if (_currentStep < 3) {
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

  @override
  void dispose() {
    excentricidadController.dispose();
    repetibilidadController.dispose();
    linealidadController.dispose();
    super.dispose();
  }
}
