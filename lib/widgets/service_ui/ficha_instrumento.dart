// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../theme/app_icons.dart';
import '../../utils/new_scale_code.dart';
import '../../utils/scale_range_validator.dart';

/// Un rango de pesaje tal como se muestra: ya ordenado de menor a mayor
/// capacidad, con su número en pantalla ([numero]) y el que tiene guardado
/// ([guardado], 1 a 3, el de `cap_max1..3`).
class RangoInstrumento {
  const RangoInstrumento({
    required this.numero,
    required this.guardado,
    required this.capacidad,
    this.d,
    this.e,
    this.decimales,
  });

  final int numero;
  final int guardado;
  final double capacidad;
  final String? d;
  final String? e;
  final String? decimales;

  /// Ordena los rangos con capacidad de menor a mayor (solo visual: no
  /// cambia `cap_max1..3`). Cada lista trae los tres valores guardados.
  static List<RangoInstrumento> ordenados({
    required List<Object?> capacidades,
    List<Object?> d = const [],
    List<Object?> e = const [],
    List<Object?> decimales = const [],
  }) {
    String? valor(List<Object?> lista, int i) {
      if (i >= lista.length) return null;
      final texto = formatoMedida(lista[i]);
      return texto.isEmpty ? null : texto;
    }

    final rangos = <RangoInstrumento>[];
    for (final i in ScaleRangeOrder.displayOrder(capacidades)) {
      final capacidad = _numero(capacidades[i]);
      if (capacidad == null || capacidad <= 0) continue;
      rangos.add(RangoInstrumento(
        numero: rangos.length + 1,
        guardado: i + 1,
        capacidad: capacidad,
        d: valor(d, i),
        e: valor(e, i),
        decimales: valor(decimales, i),
      ));
    }
    return rangos;
  }
}

/// "300" para 300.0, "0.05" para 0.050; vacío si no hay valor o es 0.
String formatoMedida(Object? valor) {
  final numero = _numero(valor);
  if (numero == null) return valor?.toString().trim() ?? '';
  if (numero == 0) return '';
  var texto = numero.toStringAsFixed(6);
  texto = texto.replaceFirst(RegExp(r'0+$'), '');
  return texto.endsWith('.') ? texto.substring(0, texto.length - 1) : texto;
}

double? _numero(Object? valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  final texto = valor.toString().trim().replaceAll(',', '.');
  if (texto.isEmpty) return null;
  return double.tryParse(texto);
}

String _conUnidad(String valor, String? unidad) {
  final u = unidad?.trim() ?? '';
  return u.isEmpty ? valor : '$valor $u';
}

const _cifrasTabulares = [FontFeature.tabularFigures()];

bool _oscuro(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Superficie de las tarjetas de la ficha: la misma de las tarjetas de la app
/// (blanca con borde suave; gris de tarjeta en tema oscuro).
BoxDecoration decoracionFicha(BuildContext context, {double radio = 18}) {
  final oscuro = _oscuro(context);
  return BoxDecoration(
    color: oscuro ? AppColors.cardDark : Colors.white,
    borderRadius: BorderRadius.circular(radio),
    border: Border.all(
        color: oscuro ? AppColors.borderDark : AppColors.borderLight),
  );
}

/// Colores de un rango (insignia, tramo de la escala) con la identidad de
/// Métrica: amarillo, dorado y tinta, más oscuro cuanto mayor es la
/// capacidad. [tinta] es el color del número encima.
({Color fondo, Color tinta}) estiloRango(
    BuildContext context, int numero, int total) {
  final oscuro = _oscuro(context);
  // La tinta es el color de texto de la app: casi negro en claro, blanco en
  // oscuro, para que el rango mayor siempre contraste con el fondo.
  final tinta = oscuro ? Colors.white : AppColors.primary;
  final escala = switch (total) {
    <= 1 => [AppColors.accentYellow],
    2 => [AppColors.accentYellow, tinta],
    _ => [AppColors.accentYellow, AppColors.shimmerGold, tinta],
  };
  final fondo = escala[(numero - 1).clamp(0, escala.length - 1)];
  final sobreTinta = fondo == tinta;
  return (
    fondo: fondo,
    tinta: sobreTinta
        ? (oscuro ? AppColors.primary : AppColors.accentYellow)
        : AppColors.primary,
  );
}

/// Encabezado de la ficha: código, estado, fabricante, datos clave y escala
/// de capacidades. Se usa en el paso Instrumento y en la ficha completa.
class FichaInstrumentoEncabezado extends StatelessWidget {
  const FichaInstrumentoEncabezado({
    super.key,
    required this.codMetrica,
    required this.rangos,
    this.marca,
    this.modelo,
    this.serie,
    this.tipo,
    this.categoria,
    this.unidad,
    this.clase,
    this.nCeldas,
    this.esNueva,
    this.acento = AppColors.actionPositive,
    this.icono = AppIcons.balanza,
    this.avisoProvisional = 'Código provisional. Registre la balanza en '
        'DataMET; antes de subir los datos podrá cambiarlo por el código '
        'definitivo.',
    this.pie,
  });

  final String? codMetrica;
  final List<RangoInstrumento> rangos;

  /// El ícono del instrumento (balanza; termómetro en temperatura).
  final IconData icono;
  final String avisoProvisional;

  /// Lo que va al pie en lugar de los rangos de pesaje.
  final Widget? pie;
  final String? marca;
  final String? modelo;
  final String? serie;
  final String? tipo;
  final String? categoria;
  final String? unidad;
  final String? clase;
  final String? nCeldas;

  /// Si no se indica, se deduce del código (provisional = nueva).
  final bool? esNueva;

  /// Color del servicio, como en las tarjetas de Inicio: verde en
  /// calibración, dorado en soporte.
  final Color acento;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final oscuro = _oscuro(context);
    final divisor = oscuro ? AppColors.borderDark : AppColors.borderLight;
    final codigo = codMetrica?.trim() ?? '';
    final provisional = NewScaleCode.isProvisional(codigo);
    final nueva = esNueva ?? provisional;
    final fabricante = [marca, modelo]
        .map((v) => v?.trim() ?? '')
        .where((v) => v.isNotEmpty)
        .join(' · ');
    final datos = <(String, String)>[
      ('Serie', serie?.trim() ?? ''),
      ('Tipo', tipo?.trim() ?? ''),
      ('Categoría', categoria?.trim() ?? ''),
      ('Clase', clase?.trim() ?? ''),
      ('Unidad', unidad?.trim() ?? ''),
      ('Celdas', formatoMedida(nCeldas)),
    ].where((d) => d.$2.isNotEmpty).toList();

    return Container(
      decoration: decoracionFicha(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: acento.withOpacity(0.13),
                    borderRadius: AppDesign.smallRadius,
                  ),
                  child: Icon(icono, color: acento, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CÓDIGO MÉTRICA',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          codigo.isEmpty ? 'Sin código' : codigo,
                          maxLines: 1,
                          style: GoogleFonts.poppins(
                            fontSize: 19,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            fontFeatures: _cifrasTabulares,
                          ),
                        ),
                      ),
                      if (fabricante.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          fabricante,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _EstadoInstrumento(nueva: nueva, acento: acento),
              ],
            ),
          ),
          if (provisional)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: AppColors.accentYellow.withOpacity(oscuro ? 0.10 : 0.16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(AppIcons.advertencia,
                      size: 16, color: AppColors.shimmerGold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      avisoProvisional,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.35,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (datos.isNotEmpty) ...[
            Divider(height: 1, color: divisor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const columnas = 3;
                  const separacion = 12.0;
                  final ancho =
                      (constraints.maxWidth - separacion * (columnas - 1)) /
                          columnas;
                  return Wrap(
                    spacing: separacion,
                    runSpacing: 10,
                    children: [
                      for (final (etiqueta, valor) in datos)
                        SizedBox(
                          width: ancho,
                          child:
                              _DatoCompacto(etiqueta: etiqueta, valor: valor),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
          Divider(height: 1, color: divisor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: pie ??
                (rangos.isEmpty
                    ? Text(
                        'Sin capacidades registradas',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: cs.onSurfaceVariant),
                      )
                    : EscalaRangos(rangos: rangos, unidad: unidad)),
          ),
        ],
      ),
    );
  }
}

class _EstadoInstrumento extends StatelessWidget {
  const _EstadoInstrumento({required this.nueva, required this.acento});

  final bool nueva;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Como en Inicio: lo pendiente en amarillo Métrica, lo registrado con el
    // color del servicio.
    final fondo = nueva
        ? AppColors.accentYellow.withOpacity(_oscuro(context) ? 0.16 : 0.28)
        : acento.withOpacity(0.13);
    final icono = nueva ? AppColors.shimmerGold : acento;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(nueva ? AppIcons.agregarCirculo : AppIcons.verificado,
              size: 13, color: icono),
          const SizedBox(width: 5),
          Text(
            nueva ? 'Nueva' : 'Catálogo',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatoCompacto extends StatelessWidget {
  const _DatoCompacto({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Escala de capacidades: una barra de 0 a la capacidad mayor, partida en
/// los rangos de la balanza (de menor a mayor), con la leyenda debajo.
class EscalaRangos extends StatelessWidget {
  const EscalaRangos({super.key, required this.rangos, this.unidad});

  final List<RangoInstrumento> rangos;
  final String? unidad;

  /// Ningún tramo baja de este ancho, para que un rango chico se vea.
  static const _tramoMinimo = 0.16;

  List<double> _proporciones() {
    final maximo = rangos.last.capacidad;
    var anterior = 0.0;
    final crudas = <double>[];
    for (final rango in rangos) {
      crudas.add(((rango.capacidad - anterior) / maximo)
          .clamp(_tramoMinimo, 1.0)
          .toDouble());
      anterior = rango.capacidad;
    }
    final total = crudas.fold<double>(0, (a, b) => a + b);
    return crudas.map((p) => p / total).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final proporciones = _proporciones();
    final total = rangos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Capacidad',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                total == 1 ? 'Un rango' : '$total rangos, de menor a mayor',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              // Sin estirar, los tramos (sin hijo) quedan con alto 0.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: (proporciones[i] * 1000).round().clamp(1, 1000),
                    child: ColoredBox(
                        color: estiloRango(context, i + 1, total).fondo),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final rango in rangos)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NumeroRango(numero: rango.numero, total: total, tamano: 18),
                  const SizedBox(width: 6),
                  Text(
                    _conUnidad(formatoMedida(rango.capacidad), unidad),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      fontFeatures: _cifrasTabulares,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Tabla de solo lectura con los rangos de pesaje, de menor a mayor
/// capacidad: una fila por rango con su capacidad máxima, d, e y decimales,
/// alineados para compararlos de un vistazo.
class TablaRangos extends StatelessWidget {
  const TablaRangos({super.key, required this.rangos, this.unidad});

  final List<RangoInstrumento> rangos;
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final oscuro = _oscuro(context);
    final u = unidad?.trim() ?? '';
    final enUnidad = u.isEmpty ? '' : ' ($u)';
    final total = rangos.length;
    final divisor = oscuro ? AppColors.borderDark : AppColors.borderLight;

    TextStyle encabezado() => GoogleFonts.inter(
          fontSize: 10.5,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
        );
    TextStyle valor({bool fuerte = false}) => GoogleFonts.inter(
          fontSize: fuerte ? 15 : 13.5,
          fontWeight: fuerte ? FontWeight.w700 : FontWeight.w600,
          color: cs.onSurface,
          fontFeatures: _cifrasTabulares,
        );
    Widget fila(List<Widget> celdas, {Color? fondo}) => Container(
          color: fondo,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: celdas),
        );

    return Container(
      decoration: decoracionFicha(context, radio: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fila(
            fondo: cs.onSurface.withOpacity(oscuro ? 0.05 : 0.035),
            [
              SizedBox(width: 38, child: Text('N°', style: encabezado())),
              Expanded(
                  flex: 3,
                  child: Text('CAP. MÁX$enUnidad', style: encabezado())),
              Expanded(flex: 2, child: Text('d$enUnidad', style: encabezado())),
              Expanded(flex: 2, child: Text('e$enUnidad', style: encabezado())),
              SizedBox(
                width: 34,
                child:
                    Text('DEC.', textAlign: TextAlign.end, style: encabezado()),
              ),
            ],
          ),
          for (final rango in rangos) ...[
            Divider(height: 1, color: divisor),
            Semantics(
              label: 'Rango ${rango.numero}: '
                  '${_conUnidad(formatoMedida(rango.capacidad), u)}, '
                  'd ${rango.d ?? 'sin dato'}, e ${rango.e ?? 'sin dato'}, '
                  '${rango.decimales ?? '0'} decimales',
              excludeSemantics: true,
              child: fila([
                SizedBox(
                  width: 38,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: NumeroRango(numero: rango.numero, total: total),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(formatoMedida(rango.capacidad),
                      style: valor(fuerte: true)),
                ),
                Expanded(flex: 2, child: Text(rango.d ?? '—', style: valor())),
                Expanded(flex: 2, child: Text(rango.e ?? '—', style: valor())),
                SizedBox(
                  width: 34,
                  child: Text(rango.decimales ?? '0',
                      textAlign: TextAlign.end, style: valor()),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Insignia con el número del rango, en el color de su lugar en la escala.
class NumeroRango extends StatelessWidget {
  const NumeroRango({
    super.key,
    required this.numero,
    required this.total,
    this.tamano = 24,
  });

  final int numero;
  final int total;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final estilo = estiloRango(context, numero, total);
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: estilo.fondo,
        borderRadius: BorderRadius.circular(tamano * 0.3),
      ),
      child: Text(
        '$numero',
        style: GoogleFonts.inter(
          fontSize: tamano * 0.5,
          fontWeight: FontWeight.w800,
          color: estilo.tinta,
        ),
      ),
    );
  }
}

/// Grupo de datos de la ficha completa, en dos columnas.
class GrupoDatosInstrumento extends StatelessWidget {
  const GrupoDatosInstrumento({
    super.key,
    required this.titulo,
    required this.icono,
    required this.datos,
  });

  final String titulo;
  final IconData icono;
  final List<(String, String?)> datos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icono, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const separacion = 12.0;
            final ancho = (constraints.maxWidth - separacion) / 2;
            return Wrap(
              spacing: separacion,
              runSpacing: 12,
              children: [
                for (final (etiqueta, valor) in datos)
                  SizedBox(
                    width: ancho,
                    child: _DatoCompacto(
                      etiqueta: etiqueta,
                      valor: (valor?.trim().isEmpty ?? true) ? '—' : valor!,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
