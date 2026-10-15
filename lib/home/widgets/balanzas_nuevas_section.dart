// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../utils/new_scale_code.dart';

/// Si el registro es de una balanza nueva, todavía con el código métrica
/// provisional que generó la app.
bool esBalanzaNueva(Map<String, dynamic> record) =>
    NewScaleCode.isProvisional(record['cod_metrica']?.toString());

/// Balanzas nuevas de un servicio pendiente de subir: explica qué hacer y
/// ofrece asignar el código métrica que dio DataMET a cada una.
///
/// No bloquea al resto: las balanzas ya registradas se pueden subir en ese
/// momento y las nuevas, cuando tengan su código.
class BalanzasNuevasSection extends StatelessWidget {
  const BalanzasNuevasSection({
    super.key,
    required this.registros,
    required this.hayRegistradas,
    required this.onAsignar,
    this.etiqueta,
  });

  final List<Map<String, dynamic>> registros;

  /// Si además hay registros ya registrados que pueden subirse ahora.
  final bool hayRegistradas;
  final void Function(Map<String, dynamic> registro)? onAsignar;

  /// Texto extra por registro (en soporte, el módulo).
  final String? Function(Map<String, dynamic> registro)? etiqueta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = registros.length;
    final plural = n == 1 ? 'balanza nueva' : 'balanzas nuevas';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(AppIcons.agregarCirculo,
                        color: AppColors.warning, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$n $plural sin código definitivo',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Paso(
                    numero: 1,
                    texto: n == 1
                        ? 'Registre la balanza en DataMET.'
                        : 'Registre cada balanza en DataMET.'),
                const SizedBox(height: 6),
                const _Paso(
                    numero: 2,
                    texto: 'Toque "Asignar código" y escriba el código '
                        'métrica que le dio DataMET.'),
                const SizedBox(height: 6),
                const _Paso(
                    numero: 3,
                    texto: 'Valide los datos y súbala como las demás.'),
                if (hayRegistradas) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Mientras tanto puede subir las balanzas ya registradas; '
                    '${n == 1 ? 'la nueva queda' : 'las nuevas quedan'} '
                    'pendiente${n == 1 ? '' : 's'} aquí para cuando tenga'
                    '${n == 1 ? '' : 'n'} su código.',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, height: 1.4, color: cs.onSurface),
                  ),
                ],
              ],
            ),
          ),
          for (final registro in registros)
            _BalanzaNuevaTile(
              registro: registro,
              detalle: etiqueta?.call(registro),
              onAsignar: onAsignar == null ? null : () => onAsignar!(registro),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero, required this.texto});

  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: GoogleFonts.inter(
                fontSize: 13, height: 1.35, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}

class _BalanzaNuevaTile extends StatelessWidget {
  const _BalanzaNuevaTile({
    required this.registro,
    required this.onAsignar,
    this.detalle,
  });

  final Map<String, dynamic> registro;
  final VoidCallback? onAsignar;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final codigo = registro['cod_metrica']?.toString() ?? '';
    final descripcion = [
      detalle,
      registro['marca'],
      registro['modelo'],
      if ((registro['serie']?.toString().trim() ?? '').isNotEmpty)
        'Serie ${registro['serie']}',
    ]
        .map((v) => v?.toString().trim() ?? '')
        .where((v) => v.isNotEmpty)
        .join(' · ');
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    codigo,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onAsignar,
            icon: const Icon(AppIcons.editar, size: 16),
            label: const Text('Asignar código'),
          ),
        ],
      ),
    );
  }
}
