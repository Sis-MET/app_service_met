// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/servicio_detalles_screen.dart';
import '../models/servicio_model.dart';

class ServiceCard extends StatelessWidget {
  final ServicioResumen servicio;

  const ServiceCard({super.key, required this.servicio});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool isCalibracion = servicio.tipo == TipoServicio.calibracion;
    final List<Color> gradientColors = isCalibracion
        ? const [Color(0xFF667EEA), Color(0xFF764BA2)]
        : const [Color(0xFF4CAF50), Color(0xFF45a049)];
    final Color primaryColor = isCalibracion ? const Color(0xFF667EEA) : const Color(0xFF4CAF50);
    final icon = isCalibracion ? FontAwesomeIcons.scaleBalanced : FontAwesomeIcons.screwdriverWrench;
    final String labelSuffix = isCalibracion ? 'calibrada' : 'técnico';
    final String pluralSuffixItem = servicio.cantidad != 1 ? 's' : '';
    final String pluralSuffixLabel = servicio.cantidad != 1 ? 's' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C3E50) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServicioDetallesScreen(servicio: servicio),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FaIcon(icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${servicio.prefijo} ${servicio.codigo}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF2C3E50),
                              ),
                            ),
                            Text(
                              '${servicio.cantidad} ${servicio.nombreItem}$pluralSuffixItem $labelSuffix$pluralSuffixLabel',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          servicio.cantidad.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServicioDetallesScreen(servicio: servicio),
                              ),
                            );
                          },
                          icon: const FaIcon(FontAwesomeIcons.eye, size: 16),
                          label: const Text('Ver detalles'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
