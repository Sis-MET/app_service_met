import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../../../widgets/service_ui/service_app_bar.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isProcessed = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const ServiceAppBar(title: 'Escanear QR'),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Centra el código QR en el recuadro para escanearlo',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                height: MediaQuery.of(context).size.width * 0.75,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentYellow
                          .withOpacity(isDark ? 0.14 : 0.24),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: MobileScanner(
                        controller: cameraController,
                        onDetect: (capture) {
                          if (_isProcessed) return;
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final barcode = barcodes.first;
                            if (barcode.rawValue != null) {
                              _isProcessed = true;
                              Navigator.pop(context, barcode.rawValue);
                            }
                          }
                        },
                      ),
                    ),
                    // Border overlay
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.accentYellow.withOpacity(0.8),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Icons.flash_on_rounded,
                label: 'Linterna',
                onPressed: () => cameraController.toggleTorch(),
                isDark: isDark,
              ),
              const SizedBox(width: 40),
              _buildControlButton(
                icon: Icons.flip_camera_ios_rounded,
                label: 'Cámara',
                onPressed: () => cameraController.switchCamera(),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: AppDesign.mediumRadius,
              border: Border.all(
                color: isDark
                    ? AppColors.borderDarkSoft
                    : AppColors.accentYellow.withOpacity(0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentYellow.withOpacity(0.09),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 28,
              color: isDark ? Colors.white : AppDesign.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
