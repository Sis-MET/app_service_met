import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_design.dart';
import 'nav_icons.dart';

/// Colores de la barra inferior según el tema de la app.
class NavBarPaleta {
  /// La cápsula.
  final Color fondo;
  final Color borde;
  final Color sombra;

  /// La píldora del destino abierto.
  final Color pildora;

  /// Ícono y nombre del destino abierto.
  final Color activo;

  /// Íconos de los destinos cerrados.
  final Color inactivo;

  const NavBarPaleta._({
    required this.fondo,
    required this.borde,
    required this.sombra,
    required this.pildora,
    required this.activo,
    required this.inactivo,
  });

  /// Claro: cápsula blanca, píldora gris clara y tinta oscura.
  static const claro = NavBarPaleta._(
    fondo: Colors.white,
    borde: Color(0x0F171714),
    sombra: Color(0x1F000000),
    pildora: Color(0x14171714),
    activo: AppDesign.ink,
    inactivo: Color(0xFF8E8E93),
  );

  /// Oscuro: cápsula gris oscuro, un poco más clara que el fondo para que se
  /// distinga, con píldora gris y tinta blanca.
  static const oscuro = NavBarPaleta._(
    fondo: Color(0xFF2E2E32),
    borde: Color(0x14FFFFFF),
    sombra: Color(0x73000000),
    pildora: Color(0x26FFFFFF),
    activo: Colors.white,
    inactivo: Color(0xFF9C9CA3),
  );

  static NavBarPaleta of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? oscuro : claro;
}

/// Barra de navegación inferior: una cápsula centrada que flota sobre el
/// contenido, blanca en el tema claro y oscura en el oscuro. El destino
/// abierto se vuelve una píldora gris con su ícono y su nombre; los demás
/// muestran solo el ícono. Al cambiar de destino la píldora se abre en el
/// nuevo y los demás se reacomodan.
///
/// El ancho es el justo para el nombre más largo, así la cápsula no cambia de
/// tamaño al pasar de un destino a otro.
class HomeBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const HomeBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// Clave de la cápsula, para las pruebas.
  static const capsulaKey = ValueKey('home-bottom-bar');

  static const destinos = [
    _Destino(icono: NavIcono.inicio, label: 'Inicio'),
    _Destino(icono: NavIcono.servicios, label: 'Servicios'),
    _Destino(icono: NavIcono.precarga, label: 'Precarga'),
    _Destino(icono: NavIcono.otros, label: 'Otros'),
  ];

  static const _alto = 68.0;
  static const _margen = 6.0;

  /// Aire mínimo entre destinos.
  static const _separacion = 4.0;

  @override
  Widget build(BuildContext context) {
    final paleta = NavBarPaleta.of(context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duracion =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 320);
    final escala = MediaQuery.textScalerOf(context);
    final etiquetaMasLarga = destinos
        .map((destino) => _anchoEtiqueta(destino.label, escala))
        .reduce(math.max);
    final fijo = _margen * 2 +
        (destinos.length - 1) * (_BotonDestino.anchoCerrado + _separacion) +
        _BotonDestino.extraPildora;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ancho =
                math.min(fijo + etiquetaMasLarga, constraints.maxWidth);
            // En un teléfono angosto o con letra grande, el nombre se recorta
            // en vez de desbordar.
            final maxEtiqueta = math.max(0.0, ancho - fijo);
            return Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              // Animada: al cambiar el tema de la app, la cápsula pasa de un
              // color al otro en lugar de saltar.
              child: AnimatedContainer(
                key: capsulaKey,
                duration: duracion,
                curve: Curves.easeOutCubic,
                width: ancho,
                height: _alto,
                padding: const EdgeInsets.all(_margen),
                decoration: BoxDecoration(
                  color: paleta.fondo,
                  borderRadius: BorderRadius.circular(_alto / 2),
                  border: Border.all(color: paleta.borde),
                  boxShadow: [
                    BoxShadow(
                      color: paleta.sombra,
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < destinos.length; i++)
                      _BotonDestino(
                        destino: destinos[i],
                        paleta: paleta,
                        seleccionado: i == currentIndex,
                        maxEtiqueta: maxEtiqueta,
                        duracion: duracion,
                        onTap: () {
                          if (i == currentIndex) return;
                          HapticFeedback.selectionClick();
                          onTap(i);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static double _anchoEtiqueta(String texto, TextScaler escala) {
    final painter = TextPainter(
      text: TextSpan(text: texto, style: _BotonDestino.estiloEtiqueta),
      textScaler: escala,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final ancho = painter.width;
    painter.dispose();
    return ancho.ceilToDouble();
  }
}

class _Destino {
  final NavIcono icono;
  final String label;

  const _Destino({required this.icono, required this.label});
}

class _BotonDestino extends StatelessWidget {
  final _Destino destino;
  final NavBarPaleta paleta;
  final bool seleccionado;
  final double maxEtiqueta;
  final Duration duracion;
  final VoidCallback onTap;

  const _BotonDestino({
    required this.destino,
    required this.paleta,
    required this.seleccionado,
    required this.maxEtiqueta,
    required this.duracion,
    required this.onTap,
  });

  static const _icono = 22.0;
  static const _espacio = 8.0;
  static const _relleno = 16.0;

  /// Ancho de un destino cerrado: el ícono con aire alrededor.
  static const anchoCerrado = 48.0;

  /// Lo que la píldora abierta suma al nombre: márgenes, ícono y espacio.
  static const extraPildora = _relleno * 2 + _icono + _espacio;

  /// Sin color: lo pone la paleta del tema.
  static final estiloEtiqueta = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  @override
  Widget build(BuildContext context) {
    const curva = Curves.easeOutCubic;
    return Semantics(
      button: true,
      selected: seleccionado,
      label: destino.label,
      // Excluye el ícono y el texto; la acción de tocar se declara aquí.
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: destino.label,
        // El nombre ya se lee en la píldora abierta.
        triggerMode: seleccionado ? TooltipTriggerMode.manual : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: duracion,
            curve: curva,
            height: double.infinity,
            constraints: const BoxConstraints(minWidth: anchoCerrado),
            padding: EdgeInsets.symmetric(
              horizontal: seleccionado ? _relleno : (anchoCerrado - _icono) / 2,
            ),
            decoration: BoxDecoration(
              color: seleccionado
                  ? paleta.pildora
                  : paleta.pildora.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<Color?>(
                  duration: duracion,
                  curve: curva,
                  tween: ColorTween(
                    end: seleccionado ? paleta.activo : paleta.inactivo,
                  ),
                  builder: (context, color, _) => NavIcon(
                    destino.icono,
                    size: _icono,
                    color: color ?? paleta.inactivo,
                  ),
                ),
                AnimatedSize(
                  duration: duracion,
                  curve: curva,
                  alignment: Alignment.centerLeft,
                  child: seleccionado
                      ? Padding(
                          padding: const EdgeInsets.only(left: _espacio),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxEtiqueta),
                            child: AnimatedDefaultTextStyle(
                              duration: duracion,
                              style: estiloEtiqueta.copyWith(
                                color: paleta.activo,
                              ),
                              child: Text(
                                destino.label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
