// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../theme/app_icons.dart';
import 'ficha_instrumento.dart';

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
        onPressed: () => showBalanzaInfoSheet(context, info, isDark,
            acento: AppColors.shimmerGold),
      ),
    );
  }
}

/// Bottom sheet con la ficha completa del instrumento. [acento] es el color
/// del servicio: verde en calibración, dorado en soporte.
void showBalanzaInfoSheet(
  BuildContext context,
  ServiceBalanzaInfo b,
  bool isDark, {
  Color acento = AppColors.actionPositive,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => FichaInstrumentoSheet(info: b, acento: acento),
  );
}

/// Ficha completa del instrumento: encabezado, rangos de menor a mayor
/// capacidad, otros datos y el equipamiento elegido para el servicio.
class FichaInstrumentoSheet extends StatelessWidget {
  const FichaInstrumentoSheet({
    super.key,
    required this.info,
    this.acento = AppColors.actionPositive,
  });

  final ServiceBalanzaInfo info;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    final b = info;
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final rangos = RangoInstrumento.ordenados(
      capacidades: [b.capMax1, b.capMax2, b.capMax3],
      d: [b.d1, b.d2, b.d3],
      e: [b.e1, b.e2, b.e3],
      decimales: [b.dec1, b.dec2, b.dec3],
    );

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: BoxDecoration(
        // El fondo de las pantallas de la app, para que las tarjetas resalten.
        color: isDark ? AppDesign.canvasDark : AppDesign.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Información del instrumento',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                FichaInstrumentoEncabezado(
                  codMetrica: b.codMetrica,
                  rangos: rangos,
                  marca: b.marca,
                  modelo: b.modelo,
                  serie: b.serie,
                  tipo: b.tipo,
                  categoria: b.categoria,
                  clase: b.clase,
                  unidad: b.unidad,
                  nCeldas: b.nCeldas,
                  acento: acento,
                ),
                if (rangos.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _Titulo(
                    'Rangos de pesaje',
                    detalle:
                        rangos.length > 1 ? 'De menor a mayor capacidad' : null,
                  ),
                  TablaRangos(rangos: rangos, unidad: b.unidad),
                ],
                const SizedBox(height: 10),
                const SizedBox(height: 14),
                GrupoDatosInstrumento(
                  titulo: 'Otros datos',
                  icono: AppIcons.etiqueta,
                  datos: [
                    ('Código interno', b.codInterno),
                    ('Tecnología', b.tecnologia),
                    ('Ubicación', b.ubicacion),
                    ('Tipo de rango', b.rango),
                  ],
                ),
                const SizedBox(height: 24),
                const _Titulo('Equipamiento del servicio'),
                _Equipos(
                  titulo: 'Pesas patrón',
                  vacio: 'Sin pesas patrón seleccionadas',
                  items: b.pesasPatron,
                ),
                const SizedBox(height: 12),
                _Equipos(
                  titulo: 'Ambiente',
                  vacio: 'Sin instrumentos de ambiente seleccionados',
                  items: b.ambiente,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, {this.detalle});

  final String texto;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              texto,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          if (detalle != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                detalle!,
                style:
                    GoogleFonts.inter(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Equipos extends StatelessWidget {
  const _Equipos({
    required this.titulo,
    required this.vacio,
    required this.items,
  });

  final String titulo;
  final String vacio;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          items.isEmpty ? titulo : '$titulo (${items.length})',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(vacio,
              style: GoogleFonts.inter(
                  fontSize: 12, color: cs.onSurface.withOpacity(0.45)))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
