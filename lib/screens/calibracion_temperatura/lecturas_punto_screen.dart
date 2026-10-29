import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import 'models/temperatura_models.dart';
import 'widgets/temp_grafico.dart';
import 'widgets/temp_ui.dart';

/// Cambia una lectura (corrección, exclusión o restitución) con su motivo.
/// Devuelve el mensaje de error, o null si se guardó.
typedef CorregirLectura = Future<String?> Function(
  TempLectura lectura, {
  required TipoCorreccion tipo,
  double? valorNuevo,
  required String motivo,
});

/// Las lecturas de un punto, una fila por hora programada. Ver no modifica
/// nada; con [onCorregir] (registro en curso) cada lectura se puede corregir
/// o excluir con motivo, conservando su valor original.
class LecturasPuntoScreen extends StatefulWidget {
  const LecturasPuntoScreen({
    super.key,
    required this.punto,
    required this.canales,
    required this.lecturas,
    required this.correcciones,
    required this.unidad,
    this.onCorregir,
    this.recargar,
  });

  final TempPunto punto;
  final List<TempCanal> canales;
  final List<TempLectura> lecturas;
  final List<TempCorreccion> correcciones;
  final String unidad;
  final CorregirLectura? onCorregir;

  /// Las lecturas y correcciones actualizadas tras un cambio.
  final Future<(List<TempLectura>, List<TempCorreccion>)> Function()? recargar;

  @override
  State<LecturasPuntoScreen> createState() => _LecturasPuntoScreenState();
}

class _LecturasPuntoScreenState extends State<LecturasPuntoScreen> {
  late List<TempLectura> _lecturas = widget.lecturas;
  late List<TempCorreccion> _correcciones = widget.correcciones;

  List<TempLectura> get _delPunto =>
      _lecturas.where((l) => l.nPunto == widget.punto.n).toList();

  Future<void> _abrir(TempLectura lectura) async {
    final canal = widget.canales.firstWhere((c) => c.n == lectura.nCanal);
    final historial = _correcciones
        .where((c) =>
            c.nPunto == lectura.nPunto &&
            c.nLectura == lectura.nLectura &&
            c.nCanal == lectura.nCanal)
        .toList();
    final cambio = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _LecturaSheet(
        lectura: lectura,
        canal: canal,
        unidad: widget.unidad,
        historial: historial,
        onCorregir: widget.onCorregir,
      ),
    );
    if (cambio == true && widget.recargar != null) {
      final (lecturas, correcciones) = await widget.recargar!();
      if (mounted) {
        setState(() {
          _lecturas = lecturas;
          _correcciones = correcciones;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lecturas = _delPunto;
    final porNumero = <int, Map<int, TempLectura>>{};
    for (final l in lecturas) {
      porNumero.putIfAbsent(l.nLectura, () => {})[l.nCanal] = l;
    }
    final numeros = porNumero.keys.toList()..sort();
    return Scaffold(
      appBar: ServiceAppBar(
        title: 'Lecturas del punto ${widget.punto.n}',
        subtitle:
            '${textoNumero(widget.punto.temperaturaNominal)} ${widget.unidad} · ${numeros.length} de ${widget.punto.lecturas}',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TempGrafico(
            canales: widget.canales,
            lecturas: lecturas,
            nominal: widget.punto.temperaturaNominal,
          ),
          const SizedBox(height: 12),
          if (widget.onCorregir == null)
            const TempAviso.bloqueado('Solo lectura: el registro está cerrado.')
          else
            const TempAviso(
              texto: 'Toque una lectura para ver su imagen o corregirla. La '
                  'lectura original se conserva junto con el motivo.',
            ),
          for (final n in numeros)
            _FilaLectura(
              numero: n,
              tiempo: porNumero[n]!.values.first.tiempoProgramadoS,
              canales: widget.canales,
              lecturas: porNumero[n]!,
              corregidas: {
                for (final c in _correcciones)
                  if (c.nPunto == widget.punto.n && c.nLectura == n) c.nCanal,
              },
              onTap: _abrir,
            ),
        ],
      ),
    );
  }
}

class _FilaLectura extends StatelessWidget {
  const _FilaLectura({
    required this.numero,
    required this.tiempo,
    required this.canales,
    required this.lecturas,
    required this.corregidas,
    required this.onTap,
  });

  final int numero;
  final int tiempo;
  final List<TempCanal> canales;
  final Map<int, TempLectura> lecturas;
  final Set<int> corregidas;
  final ValueChanged<TempLectura> onTap;

  @override
  Widget build(BuildContext context) {
    final m = tiempo ~/ 60, s = tiempo % 60;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#$numero',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                Text('$m:${s.toString().padLeft(2, '0')}',
                    style: GoogleFonts.robotoMono(fontSize: 11.5)),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final canal in canales)
                  if (lecturas[canal.n] != null)
                    _Celda(
                      lectura: lecturas[canal.n]!,
                      canal: canal,
                      color: colorCanal(canal, canales),
                      corregida: corregidas.contains(canal.n),
                      onTap: () => onTap(lecturas[canal.n]!),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({
    required this.lectura,
    required this.canal,
    required this.color,
    required this.corregida,
    required this.onTap,
  });

  final TempLectura lectura;
  final TempCanal canal;
  final Color color;
  final bool corregida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = switch (lectura.estado) {
      EstadoLectura.sinLectura => 'sin lectura',
      _ => textoNumero(lectura.valor, decimales: canal.decimales),
    };
    final tachada = lectura.estado == EstadoLectura.excluida;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: lectura.alerta != null
                ? AppColors.actionNegative
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto,
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: tachada ? TextDecoration.lineThrough : null,
                color: lectura.estado == EstadoLectura.sinLectura
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
              ),
            ),
            if (lectura.origen == OrigenLectura.manual) ...[
              const SizedBox(width: 4),
              const Icon(AppIcons.editar, size: 12),
            ],
            if (corregida) ...[
              const SizedBox(width: 4),
              const Icon(AppIcons.historial, size: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _LecturaSheet extends StatefulWidget {
  const _LecturaSheet({
    required this.lectura,
    required this.canal,
    required this.unidad,
    required this.historial,
    required this.onCorregir,
  });

  final TempLectura lectura;
  final TempCanal canal;
  final String unidad;
  final List<TempCorreccion> historial;
  final CorregirLectura? onCorregir;

  @override
  State<_LecturaSheet> createState() => _LecturaSheetState();
}

class _LecturaSheetState extends State<_LecturaSheet> {
  bool _guardando = false;

  TempLectura get l => widget.lectura;

  Future<void> _corregir() async {
    final nuevo = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        final texto = TextEditingController();
        return AlertDialog(
          title: const Text('Valor correcto'),
          content: TextField(
            controller: texto,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: 'Lo que muestra la imagen del display',
              suffixText: widget.unidad,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext,
                  double.tryParse(texto.text.trim().replaceAll(',', '.'))),
              child: const Text('Siguiente'),
            ),
          ],
        );
      },
    );
    if (nuevo == null || !mounted) return;
    await _aplicar(TipoCorreccion.correccion, valor: nuevo);
  }

  Future<void> _aplicar(TipoCorreccion tipo, {double? valor}) async {
    final motivo = await pedirMotivo(
      context,
      titulo: switch (tipo) {
        TipoCorreccion.correccion => 'Corregir la lectura',
        TipoCorreccion.exclusion => 'Excluir de los resultados',
        TipoCorreccion.restitucion => 'Volver a contar la lectura',
      },
      mensaje: 'El valor original se conserva. Explique por qué.',
    );
    if (motivo == null || !mounted) return;
    setState(() => _guardando = true);
    final error = await widget.onCorregir!(l,
        tipo: tipo, valorNuevo: valor, motivo: motivo);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final imagen = l.imagenPath;
    final hayImagen = imagen != null && File(imagen).existsSync();
    final editable = widget.onCorregir != null && !_guardando;
    // Una lectura sin valor solo se corrige mirando su imagen.
    final puedeCorregir = editable && (l.valorOriginal != null || hayImagen);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.canal.nombre} · lectura #${l.nLectura}',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (hayImagen)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(imagen), fit: BoxFit.contain),
            )
          else
            const TempAviso(texto: 'Esta lectura no tiene imagen del display.'),
          const SizedBox(height: 12),
          TempDato(
              'Valor',
              l.valor == null
                  ? 'Sin valor'
                  : '${textoNumero(l.valor)} ${widget.unidad}',
              destacado: true),
          TempDato(
              'Valor original',
              l.valorOriginal == null
                  ? '—'
                  : '${textoNumero(l.valorOriginal)} ${widget.unidad}'),
          TempDato('Leído', l.textoLeido),
          TempDato('Origen', l.origen.etiqueta),
          TempDato(
              'Estado',
              switch (l.estado) {
                EstadoLectura.valida => 'Válida',
                EstadoLectura.sinLectura => 'Sin lectura',
                EstadoLectura.excluida => 'Excluida de los resultados',
              }),
          if (l.motivo != null) TempDato('Motivo', l.motivo),
          if (l.coincidencia != null)
            TempDato('Coincidencia',
                '${(l.coincidencia! * 100).round()} % de ${l.cuadros ?? '—'} cuadros'),
          if (l.alerta != null) TempDato('Avisos', l.alerta),
          TempDato(
              'Hora',
              l.capturadaEn.length >= 23
                  ? l.capturadaEn.substring(0, 23).replaceFirst('T', ' ')
                  : l.capturadaEn),
          if (widget.historial.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Historial de cambios',
                style: Theme.of(context).textTheme.titleSmall),
            for (final c in widget.historial)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.historial, size: 18),
                title: Text('${c.tipo.etiqueta}: '
                    '${textoNumero(c.valorAnterior)} → ${textoNumero(c.valorNuevo)}'),
                subtitle:
                    Text('${c.motivo}\n${c.usuario} · ${horaLegible(c.fecha)}'),
                isThreeLine: true,
              ),
          ],
          if (widget.onCorregir != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (puedeCorregir)
                  FilledButton.icon(
                    onPressed: _corregir,
                    icon: const Icon(AppIcons.editar, size: 18),
                    label: const Text('Corregir'),
                  ),
                if (editable && l.estado == EstadoLectura.valida)
                  OutlinedButton.icon(
                    onPressed: () => _aplicar(TipoCorreccion.exclusion),
                    icon: const Icon(AppIcons.noAplica, size: 18),
                    label: const Text('Excluir'),
                  ),
                if (editable && l.estado == EstadoLectura.excluida)
                  OutlinedButton.icon(
                    onPressed: () => _aplicar(TipoCorreccion.restitucion),
                    icon: const Icon(AppIcons.deshacer, size: 18),
                    label: const Text('Volver a contar'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
