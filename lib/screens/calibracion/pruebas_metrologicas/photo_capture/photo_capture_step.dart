import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:service_met/screens/calibracion/pruebas_metrologicas/pruebas_metrologicas_controller.dart';

class PhotoCaptureStep extends StatefulWidget {
  final PruebasMetrologicasController controller;

  const PhotoCaptureStep({super.key, required this.controller});

  @override
  State<PhotoCaptureStep> createState() => _PhotoCaptureStepState();
}

class _PhotoCaptureStepState extends State<PhotoCaptureStep> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        widget.controller.setCargaPhoto(File(photo.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al tomar foto: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _viewPhoto(File photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Container(
            color: Colors.black,
            child: PhotoView(
              imageProvider: FileImage(photo),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _savePhoto() async {
    await widget.controller.savePhotoToDevice();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.controller.cargaPhoto;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FOTO DE ÚLTIMA CARGA',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF2C3E50),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Capture una fotografía de la última carga ingresada para finalizar las pruebas.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (photo == null)
            _buildPlaceholder(isDarkMode)
          else
            _buildPhotoPreview(photo, isDarkMode),
          const SizedBox(height: 24),
          if (photo != null)
            ElevatedButton.icon(
              onPressed: _savePhoto,
              icon: const Icon(Icons.save_alt),
              label: const Text('Guardar Foto en Dispositivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDarkMode) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera),
            label: const Text('ABRIR CÁMARA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(File photo, bool isDarkMode) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _viewPhoto(photo),
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? Colors.white24 : Colors.black12,
              ),
              image: DecorationImage(
                image: FileImage(photo),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.zoom_in, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.refresh),
                label: const Text('Tomar otra'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
