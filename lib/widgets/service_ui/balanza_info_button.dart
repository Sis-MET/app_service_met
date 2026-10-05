// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_colors.dart';
import '../../theme/app_icons.dart';

/// Datos mínimos del instrumento para la ficha de información.
/// Modelo neutro compartido por Calibración y Soporte.
class ServiceBalanzaInfo {
  final String? codMetrica;
  final String? tipo;
  final String? categoria;
  final String? marca;
  final String? modelo;
  final String? serie;
  final String? tecnologia;
  final String? clase;
  final String? codInterno;
  final String? unidad;
  final String? ubicacion;
  final String? rango;
  final String? nCeldas;
  final String? capMax1, d1, e1, dec1;
  final String? capMax2, d2, e2, dec2;
  final String? capMax3, d3, e3, dec3;

  /// Equipamiento: líneas ya formateadas (ej. "PES-001 x1").
  final List<String> pesasPatron;
  final List<String> ambiente;

  const ServiceBalanzaInfo({
    this.codMetrica,
    this.tipo,
    this.categoria,
    this.marca,
    this.modelo,
    this.serie,
    this.tecnologia,
    this.clase,
    this.codInterno,
    this.unidad,
    this.ubicacion,
    this.rango,
    this.nCeldas,
    this.capMax1,
    this.d1,
    this.e1,
    this.dec1,
    this.capMax2,
    this.d2,
    this.e2,
    this.dec2,
    this.capMax3,
    this.d3,
    this.e3,
    this.dec3,
    this.pesasPatron = const [],
    this.ambiente = const [],
  });
}

/// Botón flotante ámbar (44x44) que abre la ficha de información
/// del instrumento en un bottom sheet, idéntico al de Calibración.
class BalanzaInfoButton extends StatelessWidget {
  final ServiceBalanzaInfo info;

  const BalanzaInfoButton({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.amber,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(AppIcons.info, color: Colors.black87, size: 22),
        onPressed: () => showBalanzaInfoSheet(context, info, isDark),
      ),
    );
  }
}

/// Bottom sheet con la ficha completa del instrumento.
void showBalanzaInfoSheet(
    BuildContext context, ServiceBalanzaInfo b, bool isDark) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Información del Instrumento',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _infoSectionHeader(ctx, 'Identificación', isDark),
                  _infoRow('Código Métrica', b.codMetrica ?? '-', isDark),
                  _infoRow('Tipo', b.tipo ?? '-', isDark),
                  _infoRow('Categoría', b.categoria ?? '-', isDark),
                  const Divider(height: 24),
                  _infoSectionHeader(ctx, 'Fabricante', isDark),
                  _infoRow('Marca', b.marca ?? '-', isDark),
                  _infoRow('Modelo', b.modelo ?? '-', isDark),
                  _infoRow('Serie', b.serie ?? '-', isDark),
                  const Divider(height: 24),
                  _infoSectionHeader(ctx, 'Características', isDark),
                  _infoRow('Tecnología', b.tecnologia ?? '-', isDark),
                  _infoRow('Clase', b.clase ?? '-', isDark),
                  _infoRow('Código Interno', b.codInterno ?? '-', isDark),
                  _infoRow('Unidad', b.unidad ?? '-', isDark),
                  _infoRow('Ubicación', b.ubicacion ?? '-', isDark),
                  _infoRow('Rango', b.rango ?? '-', isDark),
                  _infoRow('N° Celdas', b.nCeldas ?? '-', isDark),
                  const Divider(height: 24),
                  _infoSectionHeader(ctx, 'Rangos de Intervalo', isDark),
                  _infoRow(
                      'Rango 1',
                      'Cap.Max: ${b.capMax1 ?? '-'} | d: ${b.d1 ?? '-'} | e: ${b.e1 ?? '-'} | Dec: ${b.dec1 ?? '-'}',
                      isDark),
                  _infoRow(
                      'Rango 2',
                      'Cap.Max: ${b.capMax2 ?? '-'} | d: ${b.d2 ?? '-'} | e: ${b.e2 ?? '-'} | Dec: ${b.dec2 ?? '-'}',
                      isDark),
                  _infoRow(
                      'Rango 3',
                      'Cap.Max: ${b.capMax3 ?? '-'} | d: ${b.d3 ?? '-'} | e: ${b.e3 ?? '-'} | Dec: ${b.dec3 ?? '-'}',
                      isDark),
                  const Divider(height: 24),
                  _infoSectionHeader(ctx, 'Equipamiento del Servicio', isDark),
                  if (b.pesasPatron.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Sin pesas patrón seleccionadas',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38)),
                    )
                  else ...[
                    Text('Pesas Patrón (${b.pesasPatron.length})',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 4),
                    ...b.pesasPatron.map((e) => Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 4),
                          child: Text(e,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight)),
                        )),
                  ],
                  const SizedBox(height: 8),
                  if (b.ambiente.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Sin instrumentos de ambiente seleccionados',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38)),
                    )
                  else ...[
                    Text('Ambiente (${b.ambiente.length})',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 4),
                    ...b.ambiente.map((e) => Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 4),
                          child: Text(e,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight)),
                        )),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _infoSectionHeader(BuildContext context, String label, bool isDark) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

Widget _infoRow(String label, String value, bool isDark) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    ),
  );
}
