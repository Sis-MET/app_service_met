import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_design.dart';
import '../../utils/new_scale_code.dart';
import '../../utils/top_alert.dart';
import '../../widgets/service_ui/input_decoration.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../calibracion/widgets/qr_scanner_screen.dart';
import '../oportunidades/models/opportunity_service_context.dart';
import '../soporte_new/precarga/precarga_controller.dart';
import 'catalogo_servicio.dart';

/// Para qué formulario se elige el cliente: cambia qué es obligatorio.
enum PropositoSeleccion {
  /// El RIM es de un instrumento: cliente, planta e instrumento.
  rim('Nuevo RIM', instrumentoObligatorio: true),

  /// Una oportunidad puede ser de un equipo que el cliente todavía no
  /// tiene: basta el cliente.
  oportunidad('Nueva oportunidad', instrumentoObligatorio: false);

  final String titulo;
  final bool instrumentoObligatorio;

  const PropositoSeleccion(this.titulo, {required this.instrumentoObligatorio});
}

/// Selección rápida de cliente, planta e instrumento para llenar un
/// formulario fuera de un servicio. Una sola pantalla, sin SECA ni OTST: con
/// el código QR del instrumento se completan los tres datos de una vez.
///
/// Devuelve la misma foto del servicio que usan los formularios dentro de
/// una calibración o de un soporte, con el tipo "Registro directo".
class SeleccionRapidaScreen extends StatefulWidget {
  final PropositoSeleccion proposito;

  /// Técnico con sesión iniciada.
  final String userName;
  final CatalogoServicio catalogo;

  /// Solo para pruebas: reemplaza la cámara.
  final Future<String?> Function(BuildContext context)? scanQr;

  const SeleccionRapidaScreen({
    super.key,
    required this.proposito,
    required this.userName,
    required this.catalogo,
    this.scanQr,
  });

  /// Devuelve null si el técnico cancela.
  static Future<OpportunityServiceContext?> open(
    BuildContext context, {
    required PropositoSeleccion proposito,
    required String userName,
    CatalogoServicio? catalogo,
  }) {
    return Navigator.of(context).push<OpportunityServiceContext>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SeleccionRapidaScreen(
          proposito: proposito,
          userName: userName,
          catalogo: catalogo ?? PrecargaCatalogoServicio(),
        ),
      ),
    );
  }

  @override
  State<SeleccionRapidaScreen> createState() => _SeleccionRapidaScreenState();
}

class _SeleccionRapidaScreenState extends State<SeleccionRapidaScreen> {
  Map<String, dynamic>? _cliente;
  Map<String, dynamic>? _planta;
  Map<String, dynamic>? _instrumento;
  List<Map<String, dynamic>> _plantas = const [];
  List<Map<String, dynamic>> _instrumentos = const [];
  bool _cargando = false;
  String? _error;

  bool get _exigeInstrumento => widget.proposito.instrumentoObligatorio;

  static String _texto(Map<String, dynamic>? row, String key) =>
      row?[key]?.toString().trim() ?? '';

  bool get _instrumentoNuevo => _instrumento?['_nuevo'] == true;

  // ── Selección ──────────────────────────────────────────────────────────

  Future<void> _elegirCliente() async {
    final cliente = await _mostrarLista<Map<String, dynamic>>(
      titulo: 'Cliente',
      ayuda: 'Busque por nombre comercial o razón social.',
      buscar: widget.catalogo.buscarClientes,
      tituloDe: (row) => _texto(row, 'cliente'),
      detalleDe: (row) => [
        _texto(row, 'codigo_cliente'),
        _texto(row, 'razonsocial'),
      ].where((part) => part.isNotEmpty).join(' · '),
    );
    if (cliente != null) await _setCliente(cliente);
  }

  Future<void> _setCliente(Map<String, dynamic> cliente) async {
    setState(() {
      _cliente = cliente;
      _planta = null;
      _instrumento = null;
      _plantas = const [];
      _instrumentos = const [];
      _error = null;
      _cargando = true;
    });
    try {
      final plantas = await widget.catalogo.plantasDe(cliente);
      if (!mounted) return;
      setState(() => _plantas = plantas);
      // Con una sola planta no hay nada que elegir.
      if (plantas.length == 1) await _setPlanta(plantas.single);
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudieron leer las plantas.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirPlanta() async {
    final planta = await _mostrarLista<Map<String, dynamic>>(
      titulo: 'Planta',
      items: _plantas,
      tituloDe: (row) => _texto(row, 'planta'),
      detalleDe: (row) => [
        _texto(row, 'codigo_planta'),
        _texto(row, 'dep'),
        _texto(row, 'dir'),
      ].where((part) => part.isNotEmpty).join(' · '),
    );
    if (planta != null) await _setPlanta(planta);
  }

  Future<void> _setPlanta(Map<String, dynamic> planta) async {
    setState(() {
      _planta = planta;
      _instrumento = null;
      _instrumentos = const [];
      _error = null;
      _cargando = true;
    });
    try {
      final instrumentos = await widget.catalogo.instrumentosDe(planta);
      if (mounted) setState(() => _instrumentos = instrumentos);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudieron leer los instrumentos.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  static String _descripcionInstrumento(Map<String, dynamic> row) => [
        [
          _texto(row, 'tipo_instrumento').isEmpty
              ? _texto(row, 'instrumento')
              : _texto(row, 'tipo_instrumento'),
          _texto(row, 'marca'),
          _texto(row, 'modelo'),
        ].where((part) => part.isNotEmpty).join(' '),
        if (_texto(row, 'inf_serie').isNotEmpty ||
            _texto(row, 'serie').isNotEmpty)
          'Serie ${_texto(row, 'inf_serie').isEmpty ? _texto(row, 'serie') : _texto(row, 'inf_serie')}',
        if (_texto(row, 'cap_max1').isNotEmpty)
          '${_texto(row, 'cap_max1')} ${_texto(row, 'unidad')}'.trim(),
        _texto(row, 'ubicacion'),
      ].where((part) => part.isNotEmpty).join(' · ');

  Future<void> _elegirInstrumento() async {
    final instrumento = await _mostrarLista<Map<String, dynamic>>(
      titulo: 'Instrumento',
      items: _instrumentos,
      tituloDe: (row) => _texto(row, 'cod_metrica'),
      detalleDe: _descripcionInstrumento,
      vacio: 'Esta planta no tiene instrumentos en la precarga.',
    );
    if (instrumento != null) setState(() => _instrumento = instrumento);
  }

  /// Instrumento que no está en la precarga: el técnico escribe sus datos y
  /// recibe un código provisional, como una balanza nueva en calibración.
  Future<void> _instrumentoNoRegistrado() async {
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _InstrumentoManualDialog(),
    );
    if (datos == null || !mounted) return;
    setState(() {
      _instrumento = {
        ...datos,
        'cod_metrica': NewScaleCode.generate(
          clientCode: _texto(_cliente, 'codigo_cliente'),
          plantCode: _texto(_planta, 'codigo_planta'),
        ),
        '_nuevo': true,
      };
    });
  }

  /// El código métrica del QR empieza con el código del cliente y el de la
  /// planta ("0032-11-020"): elige los tres de una vez.
  Future<void> _escanearQr() async {
    final raw = widget.scanQr != null
        ? await widget.scanQr!(context)
        : await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const QrScannerScreen()),
          );
    if (raw == null || !mounted) return;
    final metrica = PrecargaController.codMetricaFromQr(raw);
    if (metrica == null) {
      return _avisar('Formato de código QR inválido: $raw');
    }
    final partes = metrica.split('-');
    final codigoCliente = partes[0];
    final codigoPlanta = '${partes[0]}-${partes[1]}';

    final Map<String, dynamic>? cliente;
    try {
      cliente = await widget.catalogo.clientePorCodigo(codigoCliente);
    } catch (error) {
      return _avisar('No se pudo leer la precarga: $error');
    }
    if (!mounted) return;
    if (cliente == null) {
      return _avisar('No se encontró cliente con código: $codigoCliente');
    }
    await _setCliente(cliente);
    if (!mounted) return;

    final planta = _primero(
        _plantas, (row) => _texto(row, 'codigo_planta') == codigoPlanta);
    if (planta == null) {
      return _avisar('No se encontró planta con código: $codigoPlanta');
    }
    if (_planta != planta) await _setPlanta(planta);
    if (!mounted) return;

    final instrumento =
        _primero(_instrumentos, (row) => _texto(row, 'cod_metrica') == metrica);
    if (instrumento == null) {
      return _avisar('El instrumento $metrica no está en la precarga.');
    }
    setState(() => _instrumento = instrumento);
    TopAlert.show(context, 'Instrumento $metrica identificado.');
  }

  static Map<String, dynamic>? _primero(
    List<Map<String, dynamic>> rows,
    bool Function(Map<String, dynamic> row) test,
  ) {
    for (final row in rows) {
      if (test(row)) return row;
    }
    return null;
  }

  void _avisar(String mensaje) {
    if (mounted) TopAlert.show(context, mensaje, isError: true);
  }

  void _continuar() {
    final cliente = _cliente;
    if (cliente == null) {
      return setState(() => _error = 'Seleccione el cliente.');
    }
    if (_exigeInstrumento && _planta == null) {
      return setState(() => _error = 'Seleccione la planta.');
    }
    if (_exigeInstrumento && _instrumento == null) {
      return setState(() => _error = 'Seleccione el instrumento.');
    }
    final instrumento = _instrumento == null
        ? null
        : (Map<String, dynamic>.of(_instrumento!)..remove('_nuevo'));
    Navigator.of(context).pop(OpportunityServiceContext.directo(
      userName: widget.userName,
      cliente: cliente,
      planta: _planta,
      instrumento: instrumento,
    ));
  }

  /// Lista con buscador. Con [buscar] consulta la precarga al escribir; con
  /// [items] filtra lo ya cargado.
  Future<T?> _mostrarLista<T>({
    required String titulo,
    required String Function(T item) tituloDe,
    required String Function(T item) detalleDe,
    Future<List<T>> Function(String texto)? buscar,
    List<T>? items,
    String? ayuda,
    String vacio = 'Sin resultados.',
  }) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ListaConBuscador<T>(
        titulo: titulo,
        ayuda: ayuda,
        vacio: vacio,
        buscar: buscar ??
            (texto) async {
              final filtro = texto.trim().toLowerCase();
              return [
                for (final item in items ?? <T>[])
                  if (filtro.isEmpty ||
                      '${tituloDe(item)} ${detalleDe(item)}'
                          .toLowerCase()
                          .contains(filtro))
                    item,
              ];
            },
        tituloDe: tituloDe,
        detalleDe: detalleDe,
      ),
    );
  }

  // ── Interfaz ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final opcional = _exigeInstrumento ? '' : ' (opcional)';
    final plantaDetalle = [
      _texto(_planta, 'codigo_planta'),
      _texto(_planta, 'dep'),
    ].where((part) => part.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: ServiceAppBar(
        title: widget.proposito.titulo,
        leading: Center(
          child: IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppDesign.pagePadding, 8, AppDesign.pagePadding, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _exigeInstrumento
                  ? 'Elija el cliente, la planta y el instrumento que se '
                      'recibe. Con el código QR del instrumento se completan '
                      'los tres.'
                  : 'Elija el cliente. La planta y el instrumento son '
                      'opcionales: sirven si la oportunidad es sobre un '
                      'equipo que ya tiene.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: AppDesign.neutralButtonStyle(context),
              onPressed: _cargando ? null : _escanearQr,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Escanear QR del instrumento'),
            ),
            const SizedBox(height: 18),
            _CampoSeleccion(
              key: const ValueKey('seleccion-cliente'),
              icon: Icons.business_rounded,
              label: 'Cliente',
              value: _cliente == null ? null : _texto(_cliente, 'cliente'),
              detail: _texto(_cliente, 'razonsocial'),
              onTap: _cargando ? null : _elegirCliente,
            ),
            const SizedBox(height: 12),
            _CampoSeleccion(
              key: const ValueKey('seleccion-planta'),
              icon: Icons.factory_outlined,
              label: 'Planta$opcional',
              value: _planta == null ? null : _texto(_planta, 'planta'),
              detail: plantaDetalle,
              placeholder: _cliente == null
                  ? 'Primero elija el cliente'
                  : _plantas.isEmpty && !_cargando
                      ? 'El cliente no tiene plantas en la precarga'
                      : 'Seleccionar planta',
              onTap: _cliente == null || _plantas.isEmpty || _cargando
                  ? null
                  : _elegirPlanta,
            ),
            const SizedBox(height: 12),
            _CampoSeleccion(
              key: const ValueKey('seleccion-instrumento'),
              icon: Icons.scale_outlined,
              label: 'Instrumento$opcional',
              value: _instrumento == null
                  ? null
                  : _instrumentoNuevo
                      ? 'Instrumento no registrado'
                      : _texto(_instrumento, 'cod_metrica'),
              detail: _instrumento == null
                  ? ''
                  : _descripcionInstrumento(_instrumento!),
              placeholder: _planta == null
                  ? 'Primero elija la planta'
                  : 'Seleccionar instrumento',
              onTap: _planta == null || _cargando ? null : _elegirInstrumento,
            ),
            if (_exigeInstrumento && _planta != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _cargando ? null : _instrumentoNoRegistrado,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('El instrumento no está en la lista'),
                ),
              ),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDesign.pagePadding, 8, AppDesign.pagePadding, 12),
          child: FilledButton(
            style: AppDesign.positiveButtonStyle(),
            onPressed: _cargando ? null : _continuar,
            child: const Text('Continuar'),
          ),
        ),
      ),
    );
  }
}

/// Campo que muestra lo elegido y abre su lista al tocarlo.
class _CampoSeleccion extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String detail;
  final String placeholder;
  final VoidCallback? onTap;

  const _CampoSeleccion({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.detail = '',
    this.placeholder = 'Seleccionar',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final text = value;
    return InkWell(
      onTap: onTap,
      borderRadius: AppDesign.mediumRadius,
      child: InputDecorator(
        decoration: serviceInputDeco(
          label,
          isDark,
          prefixIcon: Icon(icon),
          suffixIcon: Icon(
            Icons.expand_more_rounded,
            color: onTap == null ? muted.withValues(alpha: 0.4) : null,
          ),
        ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.always),
        child: text == null
            ? Text(placeholder, style: TextStyle(color: muted))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  if (detail.isNotEmpty)
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
      ),
    );
  }
}

class _ListaConBuscador<T> extends StatefulWidget {
  final String titulo;
  final String? ayuda;
  final String vacio;
  final Future<List<T>> Function(String texto) buscar;
  final String Function(T item) tituloDe;
  final String Function(T item) detalleDe;

  const _ListaConBuscador({
    required this.titulo,
    required this.ayuda,
    required this.vacio,
    required this.buscar,
    required this.tituloDe,
    required this.detalleDe,
  });

  @override
  State<_ListaConBuscador<T>> createState() => _ListaConBuscadorState<T>();
}

class _ListaConBuscadorState<T> extends State<_ListaConBuscador<T>> {
  final _texto = TextEditingController();
  List<T>? _items;
  String? _error;
  int _secuencia = 0;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  /// Una respuesta vieja no pisa la búsqueda más reciente.
  Future<void> _buscar(String texto) async {
    final secuencia = ++_secuencia;
    try {
      final items = await widget.buscar(texto);
      if (!mounted || secuencia != _secuencia) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (error) {
      if (!mounted || secuencia != _secuencia) return;
      setState(() {
        _items = const [];
        _error = 'No se pudo leer la precarga: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _items;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titulo, style: AppDesign.titleStyle(context)),
              if (widget.ayuda != null) ...[
                const SizedBox(height: 4),
                Text(widget.ayuda!,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _texto,
                textInputAction: TextInputAction.search,
                onChanged: _buscar,
                decoration: serviceInputDeco(
                  'Buscar',
                  isDark,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: items == null
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: Text(
                              _error ?? widget.vacio,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final detalle = widget.detalleDe(item);
                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                title: Text(
                                  widget.tituloDe(item),
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle:
                                    detalle.isEmpty ? null : Text(detalle),
                                onTap: () => Navigator.of(context).pop(item),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Datos de un instrumento que no está en la precarga.
class _InstrumentoManualDialog extends StatefulWidget {
  const _InstrumentoManualDialog();

  @override
  State<_InstrumentoManualDialog> createState() =>
      _InstrumentoManualDialogState();
}

class _InstrumentoManualDialogState extends State<_InstrumentoManualDialog> {
  static const _campos = [
    ('tipo_instrumento', 'Instrumento', 'Ej.: Balanza de plataforma'),
    ('marca', 'Marca', null),
    ('modelo', 'Modelo', null),
    ('serie', 'Número de serie', null),
    ('cap_max1', 'Capacidad máxima', null),
    ('unidad', 'Unidad', 'kg, g…'),
    ('d1', 'Resolución', null),
    ('ubicacion', 'Área de trabajo', null),
  ];

  late final _controllers = {
    for (final (key, _, _) in _campos) key: TextEditingController(),
  };
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _aceptar() {
    final datos = {
      for (final entry in _controllers.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: entry.value.text.trim(),
    };
    if (!datos.containsKey('tipo_instrumento')) {
      return setState(() => _error = 'Escriba qué instrumento es.');
    }
    Navigator.pop(context, <String, dynamic>{
      ...datos,
      'instrumento': datos['tipo_instrumento'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: const Text('Instrumento no registrado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escriba los datos que tenga. Recibirá un código provisional, '
              'como una balanza nueva.',
            ),
            const SizedBox(height: 14),
            for (final (key, label, hint) in _campos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _controllers[key],
                  maxLength: key == 'unidad' ? 20 : 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      serviceInputDeco(label, isDark, hintText: hint).copyWith(
                    counterText: '',
                    errorText: key == 'tipo_instrumento' ? _error : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _aceptar,
          child: const Text('Usar estos datos'),
        ),
      ],
    );
  }
}
