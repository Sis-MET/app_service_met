import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import 'data/manual_servicemet.dart';
import 'models/manual.dart';
import 'services/calidad_pdf.dart';
import 'utils/exportar_documento.dart';
import 'widgets/calidad_ui.dart';
import '../../theme/app_icons.dart';

Future<void> _exportarManual(BuildContext context, ManualUso manual) =>
    exportarDocumentoCalidad(
      context,
      titulo: 'manual de uso',
      nombreArchivo: 'Manual_de_uso_ServiceMET',
      generar: (version) => CalidadPdf.manualDeUso(manual, appVersion: version),
    );

/// Índice del manual de uso, con búsqueda y control del documento.
class ManualScreen extends StatefulWidget {
  const ManualScreen({super.key, this.manual = manualServiceMet});

  final ManualUso manual;

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final _busqueda = TextEditingController();
  String _consulta = '';

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _abrir(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualSeccionScreen(
          manual: widget.manual,
          indiceInicial: index,
          resaltar: _consulta,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manual = widget.manual;
    final control = manual.control;
    final secciones = manual.secciones;

    return CalidadPage(
      titulo: 'Manual de uso',
      subtitulo: 'Cómo usar ServiceMET en campo, paso a paso. Disponible sin '
          'conexión.',
      acciones: [
        CalidadAccion(
          icono: AppIcons.documento,
          tooltip: 'Exportar manual',
          onPressed: () => _exportarManual(context, manual),
        ),
      ],
      encabezado: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppStatusPill(
            icon: AppIcons.documento,
            label: 'Rev. ${control.revision}',
            color: AppColors.shimmerGold,
          ),
          AppStatusPill(
            icon: AppIcons.telefono,
            label: 'Aplica a v${control.aplicaA}',
            color: AppColors.actionPositive,
          ),
          if (!control.aprobado)
            const AppStatusPill(
              icon: AppIcons.pendiente,
              label: 'Pendiente de aprobación',
              color: Color(0xFFB07F00),
            ),
        ],
      ),
      children: [
        TextField(
          controller: _busqueda,
          onChanged: (v) => setState(() => _consulta = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar en el manual (p. ej. "SECA", "subir")',
            prefixIcon: const Icon(AppIcons.buscar),
            suffixIcon: _consulta.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(AppIcons.cerrar),
                    onPressed: () => setState(() {
                      _consulta = '';
                      _busqueda.clear();
                    }),
                  ),
            border: OutlineInputBorder(
              borderRadius: AppDesign.mediumRadius,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (_consulta.trim().isNotEmpty)
          ..._resultados(context, secciones)
        else
          ..._indice(context, secciones),
        const SizedBox(height: 10),
        const CalidadSeccion('Control del documento'),
        AppPanel(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CalidadDato('Código', control.codigo),
              CalidadDato('Revisión', control.revision),
              CalidadDato('Emisión', control.fechaEmision),
              CalidadDato('Aplica a', 'ServiceMET ${control.aplicaA}'),
              CalidadDato('Elaboró', control.elaboro),
              CalidadDato('Revisó', control.reviso),
              CalidadDato('Aprobó', control.aprobo),
              const Divider(height: 22),
              for (final r in control.historial)
                CalidadDato('Rev. ${r.revision} · ${r.fecha}', r.descripcion,
                    pendiente: false),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: AppDesign.positiveButtonStyle(),
          onPressed: () => _exportarManual(context, manual),
          icon: const Icon(AppIcons.documento),
          label: const Text('Exportar manual en PDF'),
        ),
      ],
    );
  }

  List<Widget> _indice(BuildContext context, List<SeccionManual> secciones) {
    final widgets = <Widget>[];
    for (final grupo in GrupoManual.values) {
      final items = [
        for (final (i, s) in secciones.indexed)
          if (s.grupo == grupo) (i, s),
      ];
      if (items.isEmpty) continue;
      widgets
        ..add(CalidadSeccion(grupo.etiqueta))
        ..add(AppPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (n, (i, s)) in items.indexed) ...[
                if (n > 0)
                  Divider(
                    height: 1,
                    indent: 66,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                _SeccionTile(
                  numero: i + 1,
                  seccion: s,
                  onTap: () => _abrir(i),
                ),
              ],
            ],
          ),
        ))
        ..add(const SizedBox(height: 22));
    }
    return widgets;
  }

  List<Widget> _resultados(
      BuildContext context, List<SeccionManual> secciones) {
    final encontrados = [
      for (final (i, s) in secciones.indexed)
        if (s.coincide(_consulta)) (i, s),
    ];
    final cs = Theme.of(context).colorScheme;
    if (encontrados.isEmpty) {
      return [
        AppPanel(
          child: Column(
            children: [
              Icon(AppIcons.sinResultados,
                  size: 36, color: cs.onSurfaceVariant),
              const SizedBox(height: 10),
              Text('No encontramos "$_consulta" en el manual.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ];
    }
    return [
      CalidadSeccion('${encontrados.length} resultado(s)'),
      AppPanel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (n, (i, s)) in encontrados.indexed) ...[
              if (n > 0)
                Divider(height: 1, indent: 66, color: cs.outlineVariant),
              _SeccionTile(
                numero: i + 1,
                seccion: s,
                extracto: _extracto(s, _consulta),
                onTap: () => _abrir(i),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 22),
    ];
  }

  /// Fragmento del bloque que contiene la búsqueda, para dar contexto.
  static String? _extracto(SeccionManual seccion, String consulta) {
    final q = consulta.trim().toLowerCase();
    for (final bloque in seccion.bloques) {
      final texto = bloque.texto.replaceAll(RegExp(r'\s+'), ' ').trim();
      final at = texto.toLowerCase().indexOf(q);
      if (at < 0) continue;
      final inicio = (at - 40).clamp(0, texto.length);
      final fin = (at + q.length + 70).clamp(0, texto.length);
      return '${inicio > 0 ? '…' : ''}${texto.substring(inicio, fin)}'
          '${fin < texto.length ? '…' : ''}';
    }
    return null;
  }
}

class _SeccionTile extends StatelessWidget {
  const _SeccionTile({
    required this.numero,
    required this.seccion,
    required this.onTap,
    this.extracto,
  });

  final int numero;
  final SeccionManual seccion;
  final VoidCallback onTap;
  final String? extracto;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: CalidadIcono(seccion.icono),
      title: Text(
        '$numero. ${seccion.titulo}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(extracto ?? seccion.resumen,
          maxLines: extracto == null ? 2 : 3, overflow: TextOverflow.ellipsis),
      trailing: const Icon(AppIcons.siguiente),
      onTap: onTap,
    );
  }
}

/// Una sección del manual, con navegación a la anterior y a la siguiente.
class ManualSeccionScreen extends StatefulWidget {
  const ManualSeccionScreen({
    super.key,
    required this.manual,
    required this.indiceInicial,
    this.resaltar = '',
  });

  final ManualUso manual;
  final int indiceInicial;

  /// Texto buscado en el índice, que se resalta en la sección.
  final String resaltar;

  @override
  State<ManualSeccionScreen> createState() => _ManualSeccionScreenState();
}

class _ManualSeccionScreenState extends State<ManualSeccionScreen> {
  late int _indice = widget.indiceInicial;
  late String _resaltar = widget.resaltar.trim();
  final _scroll = ScrollController();

  /// Pasos marcados como hechos, por "bloque:paso". Solo guía de lectura; no
  /// se guarda.
  final Set<String> _hechos = {};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _ir(int indice) {
    setState(() {
      _indice = indice;
      _hechos.clear();
      _resaltar = '';
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final secciones = widget.manual.secciones;
    final seccion = secciones[_indice];
    final total = secciones.length;

    return CalidadPage(
      controller: _scroll,
      titulo: seccion.titulo,
      subtitulo: seccion.resumen,
      acciones: [
        Center(
          child: CalidadEtiqueta('${_indice + 1} de $total'),
        ),
      ],
      encabezado: Align(
        alignment: Alignment.centerLeft,
        child: AppStatusPill(
          icon: seccion.icono,
          label: seccion.grupo.etiqueta,
          color: AppColors.shimmerGold,
        ),
      ),
      children: [
        for (final (b, bloque) in seccion.bloques.indexed) ...[
          _bloque(context, b, bloque),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        _navegacion(context, secciones),
      ],
    );
  }

  Widget _bloque(BuildContext context, int b, BloqueManual bloque) {
    return switch (bloque) {
      Parrafo(:final contenido) => _Texto(
          contenido,
          resaltar: _resaltar,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
      Lista(:final titulo, :final items) =>
        _ListaWidget(titulo: titulo, items: items, resaltar: _resaltar),
      Pasos(:final titulo, :final pasos) => _PasosWidget(
          titulo: titulo,
          pasos: pasos,
          resaltar: _resaltar,
          hecho: (p) => _hechos.contains('$b:$p'),
          onToggle: (p) => setState(() {
            if (!_hechos.remove('$b:$p')) _hechos.add('$b:$p');
          }),
        ),
      final Nota nota => _NotaWidget(nota, resaltar: _resaltar),
    };
  }

  Widget _navegacion(BuildContext context, List<SeccionManual> secciones) {
    final anterior = _indice > 0 ? secciones[_indice - 1] : null;
    final siguiente =
        _indice < secciones.length - 1 ? secciones[_indice + 1] : null;

    Widget boton(String etiqueta, SeccionManual s, int indice, bool adelante) =>
        Expanded(
          child: OutlinedButton(
            style: AppDesign.neutralButtonStyle(context).copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 64)),
              padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            ),
            onPressed: () => _ir(indice),
            child: Column(
              crossAxisAlignment:
                  adelante ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  etiqueta,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: adelante ? TextAlign.end : TextAlign.start,
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        if (anterior != null)
          boton('← Anterior', anterior, _indice - 1, false)
        else
          const Spacer(),
        const SizedBox(width: 10),
        if (siguiente != null)
          boton('Siguiente →', siguiente, _indice + 1, true)
        else
          Expanded(
            child: FilledButton.icon(
              style: AppDesign.positiveButtonStyle(),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(AppIcons.manual),
              label: const Text('Volver al índice'),
            ),
          ),
      ],
    );
  }
}

/// Texto con la búsqueda resaltada en amarillo de marca.
class _Texto extends StatelessWidget {
  const _Texto(this.texto, {required this.resaltar, this.style});

  final String texto;
  final String resaltar;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final q = resaltar.toLowerCase();
    if (q.isEmpty || !texto.toLowerCase().contains(q)) {
      return Text(texto, style: style);
    }
    final spans = <TextSpan>[];
    final lower = texto.toLowerCase();
    var desde = 0;
    while (true) {
      final at = lower.indexOf(q, desde);
      if (at < 0) {
        spans.add(TextSpan(text: texto.substring(desde)));
        break;
      }
      if (at > desde) spans.add(TextSpan(text: texto.substring(desde, at)));
      spans.add(TextSpan(
        text: texto.substring(at, at + q.length),
        style: TextStyle(
          backgroundColor: AppColors.accentYellow.withOpacity(0.55),
          color: AppDesign.ink,
          fontWeight: FontWeight.w700,
        ),
      ));
      desde = at + q.length;
    }
    return Text.rich(TextSpan(children: spans), style: style);
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto, {this.trailing});

  final String texto;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      CalidadSeccion(texto, trailing: trailing);
}

class _ListaWidget extends StatelessWidget {
  const _ListaWidget({
    required this.titulo,
    required this.items,
    required this.resaltar,
  });

  final String? titulo;
  final List<String> items;
  final String resaltar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titulo != null) _Encabezado(titulo!),
        AppPanel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.shimmerGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Texto(
                          item,
                          resaltar: resaltar,
                          style: const TextStyle(fontSize: 14.5, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasosWidget extends StatelessWidget {
  const _PasosWidget({
    required this.titulo,
    required this.pasos,
    required this.resaltar,
    required this.hecho,
    required this.onToggle,
  });

  final String? titulo;
  final List<Paso> pasos;
  final String resaltar;
  final bool Function(int paso) hecho;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completados =
        List.generate(pasos.length, (i) => i).where(hecho).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Encabezado(
          titulo ?? 'Pasos',
          trailing: Text(
            completados == 0
                ? 'Toca un paso al completarlo'
                : '$completados de ${pasos.length} hechos',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: completados == pasos.length
                  ? AppColors.actionPositive
                  : cs.onSurfaceVariant,
            ),
          ),
        ),
        AppPanel(
          padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
          child: Column(
            children: [
              for (final (i, paso) in pasos.indexed)
                _PasoFila(
                  numero: i + 1,
                  paso: paso,
                  resaltar: resaltar,
                  hecho: hecho(i),
                  ultimo: i == pasos.length - 1,
                  onTap: () => onToggle(i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasoFila extends StatelessWidget {
  const _PasoFila({
    required this.numero,
    required this.paso,
    required this.resaltar,
    required this.hecho,
    required this.ultimo,
    required this.onTap,
  });

  final int numero;
  final Paso paso;
  final String resaltar;
  final bool hecho;
  final bool ultimo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const verde = AppColors.actionPositive;
    return Semantics(
      button: true,
      checked: hecho,
      label: 'Paso $numero',
      child: InkWell(
        borderRadius: AppDesign.smallRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Stack(
            children: [
              // Línea hacia el paso siguiente: ocupa todo el alto de la fila,
              // sea cual sea el largo del texto.
              if (!ultimo)
                Positioned(
                  left: 16,
                  top: 42,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 2,
                    color: hecho ? verde.withOpacity(0.6) : cs.outlineVariant,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 34,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hecho
                                ? verde
                                : AppColors.accentYellow.withOpacity(0.16),
                            border: Border.all(
                              color: hecho
                                  ? verde
                                  : AppColors.shimmerGold.withOpacity(0.45),
                            ),
                          ),
                          child: hecho
                              ? const Icon(AppIcons.listo,
                                  size: 18, color: AppColors.actionPositiveInk)
                              : Text(
                                  '$numero',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: hecho ? 0.55 : 1,
                      child: Padding(
                        padding:
                            EdgeInsets.only(top: 12, bottom: ultimo ? 10 : 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Texto(
                              paso.accion,
                              resaltar: resaltar,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            if (paso.detalle != null) ...[
                              const SizedBox(height: 4),
                              _Texto(
                                paso.detalle!,
                                resaltar: resaltar,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
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
    );
  }
}

class _NotaWidget extends StatelessWidget {
  const _NotaWidget(this.nota, {required this.resaltar});

  final Nota nota;
  final String resaltar;

  @override
  Widget build(BuildContext context) {
    final tipo = nota.tipo;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // En modo claro, el rótulo se oscurece para mantener el contraste.
    final tinta =
        dark ? tipo.color : Color.lerp(tipo.color, Colors.black, 0.35)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tipo.color.withOpacity(dark ? 0.14 : 0.09),
        borderRadius: AppDesign.mediumRadius,
        border: Border.all(color: tipo.color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tipo.icono, color: tipo.color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tipo.etiqueta,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tinta,
                      ),
                    ),
                    if (nota.referencia != null)
                      CalidadEtiqueta(nota.referencia!, color: tinta),
                  ],
                ),
                const SizedBox(height: 6),
                _Texto(
                  nota.contenido,
                  resaltar: resaltar,
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
