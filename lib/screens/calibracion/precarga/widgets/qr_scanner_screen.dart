// widgets/qr_scanner_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _hasScanned = false;

  /// Extrae el cod_metrica del contenido del QR.
  /// El QR puede tener múltiples campos separados por ";".
  /// Buscamos el patrón XXXX-XX-XXX (código cliente - planta - correlativo).
  String? _extractCodMetrica(String rawValue) {
    // Patrón: 4 dígitos - 2 dígitos - 3 dígitos (ej: 0032-11-001)
    final regex = RegExp(r'\b(\d{4}-\d{2}-\d{3})\b');

    // Buscar en los campos separados por ";"
    final parts = rawValue.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      final match = regex.firstMatch(trimmed);
      if (match != null) {
        return match.group(1);
      }
    }

    // Si no se encontró con separador, buscar en el texto completo
    final match = regex.firstMatch(rawValue);
    if (match != null) {
      return match.group(1);
    }

    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      final codMetrica = _extractCodMetrica(rawValue);
      if (codMetrica != null) {
        _hasScanned = true;
        Navigator.pop(context, codMetrica);
        return;
      }
    }

    // Si ningún barcode tiene cod_metrica válido, mostrar error
    if (!_hasScanned && barcodes.isNotEmpty) {
      _hasScanned = true; // Evitar múltiples snackbars

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se encontró un código métrica válido en el QR',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 3),
        ),
      );

      // Permitir escanear de nuevo después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _hasScanned = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        foregroundColor: Colors.white,
        title: Text(
          'Escanear QR',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          // Botón de flash
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: state.torchState == TorchState.on
                      ? Colors.amber
                      : Colors.white,
                );
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          // Botón cambiar cámara
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Cámara
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay con guía de escaneo
          _buildScanOverlay(),

          // Instrucciones en la parte inferior
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Apunte la cámara al código QR\ndel instrumento',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Botón cancelar
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, null),
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 20),
                  label: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        final left = (constraints.maxWidth - scanAreaSize) / 2;
        final top = (constraints.maxHeight - scanAreaSize) / 2 - 40;

        return Stack(
          children: [
            // Fondo oscuro con recorte
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.black54,
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.red, // cualquier color, será recortado
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Esquinas del marco de escaneo
            Positioned(
              left: left,
              top: top,
              child: _buildCorner(Alignment.topLeft),
            ),
            Positioned(
              right: left,
              top: top,
              child: _buildCorner(Alignment.topRight),
            ),
            Positioned(
              left: left,
              bottom: constraints.maxHeight - top - scanAreaSize,
              child: _buildCorner(Alignment.bottomLeft),
            ),
            Positioned(
              right: left,
              bottom: constraints.maxHeight - top - scanAreaSize,
              child: _buildCorner(Alignment.bottomRight),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorner(Alignment alignment) {
    const cornerSize = 30.0;
    const cornerWidth = 4.0;
    const color = Color(0xFF667EEA);

    BorderSide top = BorderSide.none;
    BorderSide bottom = BorderSide.none;
    BorderSide left = BorderSide.none;
    BorderSide right = BorderSide.none;

    if (alignment == Alignment.topLeft) {
      top = const BorderSide(color: color, width: cornerWidth);
      left = const BorderSide(color: color, width: cornerWidth);
    } else if (alignment == Alignment.topRight) {
      top = const BorderSide(color: color, width: cornerWidth);
      right = const BorderSide(color: color, width: cornerWidth);
    } else if (alignment == Alignment.bottomLeft) {
      bottom = const BorderSide(color: color, width: cornerWidth);
      left = const BorderSide(color: color, width: cornerWidth);
    } else if (alignment == Alignment.bottomRight) {
      bottom = const BorderSide(color: color, width: cornerWidth);
      right = const BorderSide(color: color, width: cornerWidth);
    }

    return Container(
      width: cornerSize,
      height: cornerSize,
      decoration: BoxDecoration(
        border: Border(top: top, bottom: bottom, left: left, right: right),
      ),
    );
  }
}
