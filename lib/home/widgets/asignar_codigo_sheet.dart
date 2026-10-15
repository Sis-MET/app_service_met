// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../utils/new_scale_code.dart';

/// Busca un código en la precarga del teléfono (balanzas + inf).
typedef BuscarEnCatalogo = Future<Map<String, dynamic>?> Function(
    String codigo);

/// Devuelve el motivo por el que el código no puede usarse (p. ej. otra
/// balanza del mismo servicio ya lo tiene), o null si está libre.
typedef VerificarCodigo = Future<String?> Function(String codigo);

/// Guarda el código; lanza una excepción con el mensaje para el técnico.
typedef GuardarCodigo = Future<void> Function(String codigo);

/// Pide el código métrica que DataMET asignó a una balanza nueva y lo guarda.
/// Devuelve el código guardado, o null si se canceló.
Future<String?> showAsignarCodigoSheet(
  BuildContext context, {
  required Map<String, dynamic> registro,
  required GuardarCodigo guardar,
  BuscarEnCatalogo? buscarEnCatalogo,
  VerificarCodigo? verificar,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AsignarCodigoSheet(
      registro: registro,
      guardar: guardar,
      buscarEnCatalogo: buscarEnCatalogo,
      verificar: verificar,
    ),
  );
}

class AsignarCodigoSheet extends StatefulWidget {
  const AsignarCodigoSheet({
    super.key,
    required this.registro,
    required this.guardar,
    this.buscarEnCatalogo,
    this.verificar,
  });

  final Map<String, dynamic> registro;
  final GuardarCodigo guardar;
  final BuscarEnCatalogo? buscarEnCatalogo;
  final VerificarCodigo? verificar;

  @override
  State<AsignarCodigoSheet> createState() => _AsignarCodigoSheetState();
}

enum _Aviso { error, advertencia, ok, info }

class _AsignarCodigoSheetState extends State<AsignarCodigoSheet> {
  late final TextEditingController _codigo;
  Timer? _espera;
  int _consulta = 0;
  bool _guardando = false;
  String? _error;
  final List<(_Aviso, String)> _avisos = [];

  String get _provisional =>
      widget.registro['cod_metrica']?.toString().trim() ?? '';

  /// `CLIENTE-PLANTA` del código provisional: el definitivo suele empezar
  /// igual, así que se deja escrito para completar solo el número.
  String get _prefijo => NewScaleCode.provisionalPrefix(_provisional) ?? '';

  @override
  void initState() {
    super.initState();
    final inicial = _prefijo.isEmpty ? '' : '$_prefijo-';
    _codigo = TextEditingController(text: inicial);
  }

  @override
  void dispose() {
    _espera?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  /// Error que impide guardar, sin consultar nada.
  String? _errorBasico(String codigo) {
    if (codigo.isEmpty || codigo == '$_prefijo-') {
      return 'Escriba el código que asignó DataMET.';
    }
    if (RegExp(r'\s').hasMatch(codigo)) {
      return 'El código no lleva espacios.';
    }
    if (NewScaleCode.isProvisional(codigo)) {
      return 'Ese código también es provisional. Use el que asignó DataMET.';
    }
    if (codigo.toUpperCase() == _provisional.toUpperCase()) {
      return 'Es el mismo código provisional.';
    }
    return null;
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    setState(() {
      _error = null;
      _avisos.clear();
    });
    _espera = Timer(const Duration(milliseconds: 400), _revisar);
  }

  Future<void> _revisar() async {
    final codigo = _codigo.text.trim();
    final consulta = ++_consulta;
    final basico = _errorBasico(codigo);
    final avisos = <(_Aviso, String)>[];
    String? error = basico;

    if (basico == null) {
      if (_prefijo.isNotEmpty &&
          !codigo.toUpperCase().startsWith('${_prefijo.toUpperCase()}-')) {
        avisos.add((
          _Aviso.advertencia,
          'No empieza con $_prefijo, el cliente y la planta de este '
              'registro. Verifique que sea el código correcto.'
        ));
      }
      try {
        error = await widget.verificar?.call(codigo);
      } catch (_) {
        // Si no se pudo revisar, decide el servidor al validar.
      }
      if (error == null && widget.buscarEnCatalogo != null) {
        Map<String, dynamic>? catalogo;
        try {
          catalogo = await widget.buscarEnCatalogo!(codigo);
        } catch (_) {
          catalogo = null;
        }
        if (catalogo == null) {
          avisos.add((
            _Aviso.info,
            'No figura en la precarga del teléfono. Si la balanza se '
                'registró hace poco es normal; verifique que el código esté '
                'escrito igual que en DataMET.'
          ));
        } else {
          avisos.addAll(_compararConCatalogo(catalogo));
        }
      }
    }
    if (!mounted || consulta != _consulta) return;
    setState(() {
      _error = error;
      _avisos
        ..clear()
        ..addAll(avisos);
    });
  }

  List<(_Aviso, String)> _compararConCatalogo(Map<String, dynamic> c) {
    final descripcion = [c['marca'], c['modelo']]
        .map((v) => v?.toString().trim() ?? '')
        .where((v) => v.isNotEmpty)
        .join(' ');
    final serieCatalogo =
        (c['inf_serie'] ?? c['serie'])?.toString().trim() ?? '';
    final serieRegistro = widget.registro['serie']?.toString().trim() ?? '';
    final avisos = <(_Aviso, String)>[
      (
        _Aviso.ok,
        'En la precarga: ${descripcion.isEmpty ? 'balanza' : descripcion}'
            '${serieCatalogo.isEmpty ? '' : ' · serie $serieCatalogo'}.'
      ),
    ];
    if (serieCatalogo.isNotEmpty &&
        serieRegistro.isNotEmpty &&
        serieCatalogo.toUpperCase() != serieRegistro.toUpperCase()) {
      avisos.add((
        _Aviso.advertencia,
        'La serie del catálogo ($serieCatalogo) no es la registrada en el '
            'servicio ($serieRegistro). Confirme que es la misma balanza.'
      ));
    }
    return avisos;
  }

  Future<void> _guardar() async {
    _espera?.cancel();
    await _revisar();
    if (_error != null || !mounted) return;
    final codigo = _codigo.text.trim();
    setState(() => _guardando = true);
    try {
      await widget.guardar(codigo);
      if (mounted) Navigator.pop(context, codigo);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = widget.registro;
    final descripcion = [r['marca'], r['modelo']]
        .map((v) => v?.toString().trim() ?? '')
        .where((v) => v.isNotEmpty)
        .join(' · ');
    final serie = r['serie']?.toString().trim() ?? '';
    final ubicacion = r['ubicacion']?.toString().trim() ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Código métrica definitivo',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Registre primero la balanza en DataMET y escriba aquí el '
              'código que le asignó. Después podrá subir sus datos.',
              style: GoogleFonts.inter(
                  fontSize: 13, height: 1.4, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(AppIcons.agregarCirculo,
                      color: AppColors.warning, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Balanza nueva · código provisional',
                            style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning)),
                        const SizedBox(height: 2),
                        SelectableText(
                          _provisional,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (descripcion.isNotEmpty ||
                            serie.isNotEmpty ||
                            ubicacion.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (descripcion.isNotEmpty) descripcion,
                              if (serie.isNotEmpty) 'Serie $serie',
                              if (ubicacion.isNotEmpty) ubicacion,
                            ].join('\n'),
                            style: GoogleFonts.inter(
                                fontSize: 12.5,
                                height: 1.4,
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _codigo,
              autofocus: true,
              enabled: !_guardando,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onChanged: _alEscribir,
              onSubmitted: (_) => _guardar(),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: 'Código métrica asignado en DataMET',
                hintText:
                    _prefijo.isEmpty ? 'Ej.: 0032-11-021' : '$_prefijo-021',
                prefixIcon: const Icon(AppIcons.qr),
                errorText: _error,
                errorMaxLines: 3,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            for (final (tipo, texto) in _avisos) ...[
              const SizedBox(height: 10),
              _AvisoCodigo(tipo: tipo, texto: texto),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.historial, size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El cambio queda en el historial del registro con el '
                    'código anterior, su usuario, la fecha y el motivo. Es '
                    'el único dato que se puede corregir.',
                    style: GoogleFonts.inter(
                        fontSize: 12, height: 1.4, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.guardar, size: 18),
                    label: const Text('Guardar código'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisoCodigo extends StatelessWidget {
  const _AvisoCodigo({required this.tipo, required this.texto});

  final _Aviso tipo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (color, icono) = switch (tipo) {
      _Aviso.error => (AppColors.error, AppIcons.error),
      _Aviso.advertencia => (AppColors.warning, AppIcons.advertencia),
      _Aviso.ok => (AppColors.success, AppIcons.completo),
      _Aviso.info => (cs.onSurfaceVariant, AppIcons.info),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: GoogleFonts.inter(
                fontSize: 12.5, height: 1.4, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
