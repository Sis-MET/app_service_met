import 'dart:io';
import 'package:flutter/material.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';

class FotoCargaStep extends StatefulWidget {
  const FotoCargaStep({super.key});

  @override
  State<FotoCargaStep> createState() => _FotoCargaStepState();
}

class _FotoCargaStepState extends State<FotoCargaStep> {
  final ImagePicker _picker = ImagePicker();
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ServiceSessionProvider>();
      final cf = provider.session?.condicionesFinales;
      if (cf != null && cf.fotosPaths != null && cf.fotosPaths!.isNotEmpty) {
        // Assume first photo is carga photo if any exist, or search for a specific marker.
        // For simplicity we just use the first photo in the list for this step if it exists.
        // If there are multiple, it's better to store it properly.
        setState(() {
          _photoPath = cf.fotosPaths!.first;
        });
      }
    });
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() => _photoPath = photo.path);
        _saveToProvider(photo.path);
      }
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'Error al tomar foto: $e', isError: true);
      }
    }
  }

  void _saveToProvider(String path) {
    final provider = context.read<ServiceSessionProvider>();
    final cf = provider.session?.condicionesFinales ?? CondicionesFinales();
    List<String> fotos = List.from(cf.fotosPaths ?? []);
    if (fotos.isEmpty) {
      fotos.add(path);
    } else {
      fotos[0] = path;
    }
    provider.updateCondicionesFinales(cf.copyWith(fotosPaths: fotos));
  }

  void _viewPhoto(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: Container(
            color: Colors.black,
            child: PhotoView(imageProvider: FileImage(File(path))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FOTO DE ÚLTIMA CARGA',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.indigo[800]),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 12),
          Text(
            'Capture una fotografía de la última carga ingresada para finalizar las pruebas.',
            style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[700]),
            textAlign: TextAlign.center,
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 30),

          if (_photoPath == null)
            _buildPlaceholder(isDark).animate(delay: 400.ms).scale()
          else
            _buildPreview(_photoPath!, isDark).animate(delay: 400.ms).fadeIn(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 2, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 80, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera),
            label: const Text('ABRIR CÁMARA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(String path, bool isDark) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _viewPhoto(path),
          child: Container(
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 2),
              image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 12, top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.zoom_in, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.refresh),
            label: const Text('Tomar otra fotografía'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Color(0xFF667EEA)),
              foregroundColor: const Color(0xFF667EEA),
            ),
          ),
        ),
      ],
    );
  }
}
