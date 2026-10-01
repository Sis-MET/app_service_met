import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../login/services/connection_profile_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../widgets/service_ui/input_decoration.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../oportunidades/models/opportunity_draft.dart' show newOpportunityUuid;
import '../oportunidades/models/opportunity_service_context.dart';
import '../oportunidades/widgets/opportunity_password_prompt.dart';
import 'data/rim_catalogo.dart';
import 'models/rim_documento.dart';
import 'services/rim_repository.dart';
import 'widgets/signature_pad.dart';

/// Formulario "Recepción de instrumentos de pesaje" (RIM), para Calibración
/// y Soporte técnico.
///
/// El cliente, la planta y el instrumento vienen del servicio en curso (una
/// foto de solo lectura), así que el técnico llena solo el estado físico y la
/// recepción, y el cliente firma en la pantalla. Se abre encima del servicio:
/// el paso actual sigue montado debajo. Al emitir, el RIM queda guardado en
/// el teléfono y ya no se modifica.
class RimFormScreen extends StatefulWidget {
  final OpportunityServiceContext serviceContext;
  final RimRepository repository;
  final Future<String?> Function() loggedUser;
  final Future<String?> Function() appVersion;

  /// Solo para pruebas: reemplaza la pantalla de firma.
  final Future<Uint8List?> Function(BuildContext context)? signatureCapture;

  const RimFormScreen({
    super.key,
    required this.serviceContext,
    required this.repository,
    required this.loggedUser,
    required this.appVersion,
    this.signatureCapture,
  });

  /// Devuelve el RIM emitido, o null si el técnico cancela.
  static Future<RimRegistro?> open(
    BuildContext context, {
    required OpportunityServiceContext serviceContext,
  }) {
    final profiles = context.read<ConnectionProfileService>();
    return Navigator.of(context).push<RimRegistro>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RimFormScreen(
          serviceContext: serviceContext,
          repository: RimRepository(
            apiUrl: () => profiles.perfilSeleccionado?.apiUrl,
            loggedUser: loggedServiceMetUser,
          ),
          loggedUser: loggedServiceMetUser,
          appVersion: serviceMetAppVersion,
        ),
      ),
    );
  }

  @override
  State<RimFormScreen> createState() => _RimFormScreenState();
}

class _OtroComponente {
  final nombre = TextEditingController();
  RimEstadoComponente estado = RimEstadoComponente.present;
}

class _RimFormScreenState extends State<RimFormScreen> {
  static const _pasos = ['Estado físico', 'Recepción y firma'];

  late final String _uuid = newOpportunityUuid();
  late final String _codigo = rimCodigo(
    plantCode: widget.serviceContext.plantCode,
    clientCode: widget.serviceContext.clientCode,
    year: widget.serviceContext.capturedAt.year,
  );

  final _scroll = [ScrollController(), ScrollController()];
  int _paso = 0;
  bool _busy = false;
  bool _dirty = false;
  Map<String, String> _errores = const {};
  String? _errorGeneral;

  // Paso 1: estado físico.
  final Map<String, RimEstadoComponente> _inventario = {};
  final Map<String, TextEditingController> _cantidades = {
    for (final componente in RimCatalogo.componentes)
      if (componente.conCantidad) componente.key: TextEditingController(),
  };
  final List<_OtroComponente> _otros = [];
  final _obsInventario = TextEditingController();
  String? _estadoGeneral;
  final Map<String, Set<String>> _danos = {};
  final _descripcionDanos = TextEditingController();
  String? _nivelSuciedad;

  // Paso 2: recepción y firma.
  final _motivo = TextEditingController();
  bool? _pruebas;
  final _descripcionPruebas = TextEditingController();
  final _contactoNombre = TextEditingController();
  final _contactoCargo = TextEditingController();
  final _contactoTelefono = TextEditingController();
  late final _lugar = TextEditingController(text: _lugarSugerido());
  final _tecnicoAsignado = TextEditingController();
  Uint8List? _firma;

  OpportunityServiceContext get _service => widget.serviceContext;

  String _lugarSugerido() => [_service.plantName, _service.plantAddress]
      .whereType<String>()
      .join(' - ');

  @override
  void dispose() {
    for (final controller in [
      ..._scroll,
      ..._cantidades.values,
      for (final otro in _otros) otro.nombre,
      _obsInventario,
      _descripcionDanos,
      _motivo,
      _descripcionPruebas,
      _contactoNombre,
      _contactoCargo,
      _contactoTelefono,
      _lugar,
      _tecnicoAsignado,
    ]) {
      controller.dispose();
    }
    widget.repository.close();
    super.dispose();
  }

  void _cambio(VoidCallback change) => setState(() {
        change();
        _dirty = true;
      });

  /// Al escribir en un campo: desde ahí, salir pide confirmación.
  void _tocado(String _) {
    if (!_dirty) setState(() => _dirty = true);
  }

  // ── Validación ─────────────────────────────────────────────────────────

  Map<String, String> _faltantes(int paso) {
    final errores = <String, String>{};
    if (paso == 0) {
      if (_estadoGeneral == null) {
        errores['estadoGeneral'] = 'Seleccione el estado general.';
      }
      if (_nivelSuciedad == null) {
        errores['nivelSuciedad'] = 'Seleccione el nivel de suciedad.';
      }
      return errores;
    }
    if (_motivo.text.trim().length < 5) {
      errores['motivo'] = 'Describa por qué se recibe el instrumento.';
    }
    if (_pruebas == null) {
      errores['pruebas'] = 'Indique si se realizaron pruebas.';
    }
    if (_contactoNombre.text.trim().length < 3) {
      errores['contactoNombre'] = 'Escriba el nombre de quien entrega.';
    }
    if (_lugar.text.trim().isEmpty) {
      errores['lugar'] = 'Indique el lugar de recepción.';
    }
    if (_firma == null) errores['firma'] = 'Falta la firma del cliente.';
    return errores;
  }

  bool _validar(int paso) {
    final errores = _faltantes(paso);
    setState(() {
      _errores = errores;
      _errorGeneral =
          errores.isEmpty ? null : 'Complete lo marcado para continuar.';
    });
    return errores.isEmpty;
  }

  void _irA(int paso) {
    FocusScope.of(context).unfocus();
    if (paso > _paso && !_validar(_paso)) return;
    setState(() {
      _paso = paso;
      _errores = const {};
      _errorGeneral = null;
    });
  }

  // ── Firma y emisión ────────────────────────────────────────────────────

  Future<void> _firmar() async {
    FocusScope.of(context).unfocus();
    final nombre = _contactoNombre.text.trim();
    if (nombre.length < 3) {
      setState(() => _errores = {
            ..._errores,
            'contactoNombre': 'Escriba el nombre de quien va a firmar.',
          });
      return;
    }
    final capture = widget.signatureCapture;
    final firma = capture != null
        ? await capture(context)
        : await SignatureCaptureScreen.open(
            context,
            signerName: nombre,
            documentLabel:
                [_codigo, _service.metricCode].whereType<String>().join(' · '),
          );
    if (firma == null || !mounted) return;
    _cambio(() {
      _firma = firma;
      _errores = {..._errores}..remove('firma');
    });
  }

  Future<RimDocumento> _documento() async {
    final usuario = await widget.loggedUser();
    String? version;
    try {
      version = await widget.appVersion();
    } catch (_) {
      // La versión es un dato de referencia: no impide emitir.
    }
    return RimDocumento(
      uuid: _uuid,
      codigo: _codigo,
      service: _service,
      motivo: _motivo.text.trim(),
      inventario: Map.of(_inventario),
      cantidades: {
        for (final entry in _cantidades.entries)
          if (_inventario[entry.key] == RimEstadoComponente.present &&
              entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
      },
      otrosComponentes: [
        for (final otro in _otros)
          if (otro.nombre.text.trim().isNotEmpty)
            RimComponenteExtra(otro.nombre.text.trim(), otro.estado),
      ],
      observacionesInventario: _obsInventario.text.trim(),
      estadoGeneral: _estadoGeneral!,
      danos: {
        for (final entry in _danos.entries) entry.key: entry.value.toList(),
      },
      descripcionDanos: _descripcionDanos.text.trim(),
      nivelSuciedad: _nivelSuciedad!,
      pruebasFuncionamiento: _pruebas!,
      descripcionPruebas: _pruebas! ? _descripcionPruebas.text.trim() : '',
      contactoNombre: _contactoNombre.text.trim(),
      contactoCargo: _contactoCargo.text.trim(),
      contactoTelefono: _contactoTelefono.text.trim(),
      representanteMetrica: _service.technician ?? usuario ?? '',
      lugarRecepcion: _lugar.text.trim(),
      tecnicoAsignado: _tecnicoAsignado.text.trim(),
      emitidoEn: DateTime.now(),
      creadoPor: usuario,
      appVersion: version,
    );
  }

  Future<void> _emitir() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;
    // Un dato del primer paso pudo quedar sin llenar si se volvió atrás.
    if (!_validar(0)) {
      setState(() => _paso = 0);
      return;
    }
    if (!_validar(1)) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Emitir el RIM?'),
        content: Text(
          'Se emitirá $_codigo del instrumento '
          '${_service.metricCode ?? 'seleccionado'}, firmado por '
          '${_contactoNombre.text.trim()}.\n\n'
          'Una vez emitido no se puede modificar: si tiene un error, se '
          'anula y se emite otro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Emitir RIM'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final registro =
          await widget.repository.emitir(await _documento(), _firma!);
      if (!mounted) return;
      Navigator.of(context).pop(registro);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorGeneral = 'No se pudo guardar el RIM en el teléfono: $error';
      });
    }
  }

  Future<void> _cancelar() async {
    if (_busy) return;
    if (_dirty) {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Descartar el RIM?'),
          content: const Text(
            'Lo que llenó no se guardará y no se emitirá ningún RIM. El '
            'servicio no se modifica.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Seguir llenando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (descartar != true || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _atras() => _paso > 0 ? _irA(_paso - 1) : _cancelar();

  // ── Interfaz ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ultimo = _paso == _pasos.length - 1;

    return PopScope(
      canPop: !_busy && !_dirty && _paso == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras();
      },
      child: Scaffold(
        appBar: ServiceAppBar(
          title: 'Recepción de instrumento',
          subtitle: 'Paso ${_paso + 1} de ${_pasos.length} · ${_pasos[_paso]}',
          leading: Center(
            child: IconButton(
              tooltip: 'Cancelar',
              icon: const Icon(Icons.close_rounded),
              onPressed: _busy ? null : _cancelar,
            ),
          ),
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          // Los dos pasos quedan construidos: al volver atrás, los campos
          // conservan lo escrito y su posición.
          child: IndexedStack(
            index: _paso,
            children: [
              _pagina(0, _pasoEstadoFisico(isDark)),
              _pagina(1, _pasoRecepcion(isDark)),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDesign.pagePadding, 8, AppDesign.pagePadding, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: AppDesign.neutralButtonStyle(context),
                    onPressed: _busy ? null : _atras,
                    child: Text(_paso == 0 ? 'Cancelar' : 'Atrás'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    style: AppDesign.positiveButtonStyle(),
                    onPressed: _busy
                        ? null
                        : ultimo
                            ? _emitir
                            : () => _irA(_paso + 1),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Text(ultimo ? 'Emitir RIM' : 'Siguiente'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pagina(int paso, List<Widget> children) => SingleChildScrollView(
        controller: _scroll[paso],
        padding: const EdgeInsets.fromLTRB(
            AppDesign.pagePadding, 8, AppDesign.pagePadding, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children,
            if (_errorGeneral != null && _paso == paso) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: _errorGeneral!),
            ],
          ],
        ),
      );

  List<Widget> _pasoEstadoFisico(bool isDark) => [
        _ResumenServicio(codigo: _codigo, service: _service),
        const SizedBox(height: 22),
        const ServiceSectionHeader('Inventario de componentes'),
        Text(
          'Marque lo que se recibe con el instrumento. Lo que deje sin marcar '
          'no aparece en el RIM.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        _MarcarTodos(
          onSelected: (estado) => _cambio(() {
            for (final componente in RimCatalogo.componentes) {
              _inventario[componente.key] = estado;
            }
            for (final otro in _otros) {
              otro.estado = estado;
            }
          }),
        ),
        const SizedBox(height: 8),
        AppPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final componente in RimCatalogo.componentes)
                _FilaComponente(
                  key: ValueKey('rim-componente-${componente.key}'),
                  label: componente.label,
                  estado: _inventario[componente.key],
                  cantidad: _cantidades[componente.key],
                  isDark: isDark,
                  onChanged: (estado) => _cambio(() {
                    if (estado == null) {
                      _inventario.remove(componente.key);
                    } else {
                      _inventario[componente.key] = estado;
                    }
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _otros.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppPanel(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _otros[i].nombre,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: _tocado,
                          decoration: serviceInputDeco(
                            'Otro componente',
                            isDark,
                            hintText: 'Ej.: Cable RS232, pesa patrón…',
                          ).copyWith(counterText: ''),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar este componente',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _cambio(() {
                          _otros.removeAt(i).nombre.dispose();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _EstadoSelector(
                    estado: _otros[i].estado,
                    onChanged: (estado) => _cambio(() {
                      if (estado != null) _otros[i].estado = estado;
                    }),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _cambio(() => _otros.add(_OtroComponente())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar otro componente'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _obsInventario,
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _tocado,
          decoration:
              serviceInputDeco('Observaciones de inventario (opcional)', isDark)
                  .copyWith(alignLabelWithHint: true),
        ),
        const SizedBox(height: 14),
        const ServiceSectionHeader('Daños físicos'),
        _OpcionUnica(
          label: 'Estado general del instrumento',
          opciones: RimCatalogo.estadosGenerales,
          seleccion: _estadoGeneral,
          error: _errores['estadoGeneral'],
          prefijo: 'rim-estado',
          onChanged: (key) => _cambio(() {
            _estadoGeneral = key;
            _errores = {..._errores}..remove('estadoGeneral');
          }),
        ),
        const SizedBox(height: 16),
        Text('Tipos de daños detectados',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        for (final tipo in RimCatalogo.tiposDano)
          _FilaDano(
            key: ValueKey('rim-dano-${tipo.key}'),
            tipo: tipo,
            ubicaciones: _danos[tipo.key],
            onToggle: (activo) => _cambio(() {
              if (activo) {
                _danos[tipo.key] = {};
              } else {
                _danos.remove(tipo.key);
              }
            }),
            onUbicacion: (ubicacion, activa) => _cambio(() {
              final ubicaciones = _danos[tipo.key] ??= {};
              activa
                  ? ubicaciones.add(ubicacion)
                  : ubicaciones.remove(ubicacion);
            }),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _descripcionDanos,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _tocado,
          decoration:
              serviceInputDeco('Descripción de daños (opcional)', isDark)
                  .copyWith(alignLabelWithHint: true),
        ),
        const SizedBox(height: 14),
        const ServiceSectionHeader('Nivel de suciedad'),
        _OpcionUnica(
          label: 'Nivel de suciedad',
          opciones: RimCatalogo.nivelesSuciedad,
          seleccion: _nivelSuciedad,
          error: _errores['nivelSuciedad'],
          prefijo: 'rim-suciedad',
          onChanged: (key) => _cambio(() {
            _nivelSuciedad = key;
            _errores = {..._errores}..remove('nivelSuciedad');
          }),
        ),
      ];

  List<Widget> _pasoRecepcion(bool isDark) => [
        const ServiceSectionHeader('Síntomas y evidencias'),
        TextField(
          key: const ValueKey('rim-motivo'),
          controller: _motivo,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _tocado,
          decoration: serviceInputDeco(
            'Motivo de la recepción',
            isDark,
            hintText: 'Ej.: El indicador no enciende; no se pudo concluir la '
                'calibración.',
          ).copyWith(
            errorText: _errores['motivo'],
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 6),
        Text('¿Se realizaron pruebas de funcionamiento?',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Sí')),
            ButtonSegment(value: false, label: Text('No')),
          ],
          selected: {if (_pruebas != null) _pruebas!},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (selection) => _cambio(() {
            _pruebas = selection.isEmpty ? null : selection.first;
            _errores = {..._errores}..remove('pruebas');
          }),
        ),
        if (_errores['pruebas'] != null) _ErrorTexto(_errores['pruebas']!),
        if (_pruebas == true) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _descripcionPruebas,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: _tocado,
            decoration: serviceInputDeco('Descripción de pruebas', isDark)
                .copyWith(alignLabelWithHint: true),
          ),
        ],
        const SizedBox(height: 20),
        const ServiceSectionHeader('Quién entrega el instrumento'),
        TextField(
          key: const ValueKey('rim-contacto'),
          controller: _contactoNombre,
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
          onChanged: _tocado,
          decoration: serviceInputDeco(
            'Nombre del cliente o contacto',
            isDark,
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ).copyWith(
            errorText: _errores['contactoNombre'],
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contactoCargo,
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _tocado,
          decoration: serviceInputDeco('Cargo (opcional)', isDark)
              .copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contactoTelefono,
          maxLength: 30,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
          ],
          onChanged: _tocado,
          decoration: serviceInputDeco('Teléfono (opcional)', isDark)
              .copyWith(counterText: ''),
        ),
        const SizedBox(height: 20),
        const ServiceSectionHeader('Recepción'),
        AppPanel(
          padding: const EdgeInsets.all(16),
          child: _FilaLectura(
            'Representante Métrica',
            _service.technician ?? 'Usuario con sesión iniciada',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lugar,
          maxLength: 255,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _tocado,
          decoration: serviceInputDeco(
            'Lugar de recepción',
            isDark,
            prefixIcon: const Icon(Icons.place_outlined),
          ).copyWith(errorText: _errores['lugar'], counterText: ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tecnicoAsignado,
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
          onChanged: _tocado,
          decoration: serviceInputDeco('Técnico asignado (opcional)', isDark)
              .copyWith(counterText: ''),
        ),
        const SizedBox(height: 20),
        const ServiceSectionHeader('Firma del cliente'),
        _CampoFirma(
          firma: _firma,
          error: _errores['firma'],
          onTap: _firmar,
        ),
      ];
}

class _ResumenServicio extends StatelessWidget {
  final String codigo;
  final OpportunityServiceContext service;

  const _ResumenServicio({required this.codigo, required this.service});

  @override
  Widget build(BuildContext context) {
    final planta = [service.plantName, service.plantDepartment]
        .whereType<String>()
        .join(' - ');
    final equipo = [service.equipmentType, service.brand, service.model]
        .whereType<String>()
        .join(' · ');
    final origen = service.serviceLabel;
    return AppPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppStatusPill(
            icon: Icons.inventory_2_outlined,
            label: codigo,
            color: AppColors.actionPositive,
          ),
          const SizedBox(height: 12),
          _FilaLectura('Servicio', origen),
          _FilaLectura(service.secaLabel, service.seca),
          _FilaLectura('Cliente', service.clientDisplay),
          _FilaLectura('Planta', planta.isEmpty ? null : planta),
          _FilaLectura('Código métrica', service.metricCode),
          _FilaLectura('Instrumento', equipo.isEmpty ? null : equipo),
          _FilaLectura('Serie', service.serial),
          _FilaLectura('Capacidad', service.capacityWithUnit),
          _FilaLectura('Resolución', service.divisionWithUnit),
          _FilaLectura('Ubicación', service.location),
        ],
      ),
    );
  }
}

class _FilaLectura extends StatelessWidget {
  final String label;
  final String? value;

  const _FilaLectura(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: muted),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarcarTodos extends StatelessWidget {
  final ValueChanged<RimEstadoComponente> onSelected;

  const _MarcarTodos({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Marcar todos:', style: Theme.of(context).textTheme.bodySmall),
        for (final estado in RimEstadoComponente.values)
          ActionChip(
            label: Text(estado.label),
            visualDensity: VisualDensity.compact,
            onPressed: () => onSelected(estado),
          ),
      ],
    );
  }
}

/// Presente / Faltante / N/A. Tocar el estado ya elegido lo quita.
class _EstadoSelector extends StatelessWidget {
  final RimEstadoComponente? estado;
  final ValueChanged<RimEstadoComponente?> onChanged;

  const _EstadoSelector({required this.estado, required this.onChanged});

  static Color _color(RimEstadoComponente estado, ColorScheme scheme) =>
      switch (estado) {
        RimEstadoComponente.present => AppColors.success,
        RimEstadoComponente.missing => AppColors.actionNegative,
        RimEstadoComponente.na => scheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      children: [
        for (final opcion in RimEstadoComponente.values)
          ChoiceChip(
            label: Text(opcion.label),
            selected: estado == opcion,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            selectedColor: _color(opcion, scheme).withValues(alpha: 0.16),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: estado == opcion ? FontWeight.w700 : FontWeight.w500,
              color: estado == opcion ? _color(opcion, scheme) : null,
            ),
            side: BorderSide(
              color: estado == opcion
                  ? _color(opcion, scheme).withValues(alpha: 0.5)
                  : scheme.outlineVariant,
            ),
            onSelected: (selected) => onChanged(selected ? opcion : null),
          ),
      ],
    );
  }
}

class _FilaComponente extends StatelessWidget {
  final String label;
  final RimEstadoComponente? estado;
  final TextEditingController? cantidad;
  final bool isDark;
  final ValueChanged<RimEstadoComponente?> onChanged;

  const _FilaComponente({
    super.key,
    required this.label,
    required this.estado,
    required this.cantidad,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final conCantidad =
        cantidad != null && estado == RimEstadoComponente.present;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _EstadoSelector(estado: estado, onChanged: onChanged),
              ),
              if (conCantidad)
                SizedBox(
                  width: 76,
                  child: TextField(
                    controller: cantidad,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 3,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: serviceInputDeco('Cant.', isDark).copyWith(
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una sola opción de una lista corta, como chips.
class _OpcionUnica extends StatelessWidget {
  final String label;
  final List<RimOpcion> opciones;
  final String? seleccion;
  final String? error;
  final String prefijo;
  final ValueChanged<String> onChanged;

  const _OpcionUnica({
    required this.label,
    required this.opciones,
    required this.seleccion,
    required this.error,
    required this.prefijo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: label,
          container: true,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final opcion in opciones)
                ChoiceChip(
                  key: ValueKey('$prefijo-${opcion.key}'),
                  label: Text(opcion.label),
                  selected: seleccion == opcion.key,
                  onSelected: (_) => onChanged(opcion.key),
                ),
            ],
          ),
        ),
        if (error != null) _ErrorTexto(error!),
      ],
    );
  }
}

class _FilaDano extends StatelessWidget {
  final RimOpcion tipo;

  /// Null si el daño no está marcado.
  final Set<String>? ubicaciones;
  final ValueChanged<bool> onToggle;
  final void Function(String ubicacion, bool activa) onUbicacion;

  const _FilaDano({
    super.key,
    required this.tipo,
    required this.ubicaciones,
    required this.onToggle,
    required this.onUbicacion,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activo = ubicaciones != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: AppDesign.smallRadius,
        border: Border.all(
          color: activo ? scheme.outline : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            value: activo,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            shape: RoundedRectangleBorder(borderRadius: AppDesign.smallRadius),
            title: Text(
              tipo.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            onChanged: (value) => onToggle(value ?? false),
          ),
          if (activo)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ubicación del daño:',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final ubicacion in RimCatalogo.ubicacionesDano)
                        FilterChip(
                          label: Text(ubicacion.label),
                          visualDensity: VisualDensity.compact,
                          selected: ubicaciones!.contains(ubicacion.key),
                          onSelected: (value) =>
                              onUbicacion(ubicacion.key, value),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CampoFirma extends StatelessWidget {
  final Uint8List? firma;
  final String? error;
  final VoidCallback onTap;

  const _CampoFirma({
    required this.firma,
    required this.error,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imagen = firma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const ValueKey('rim-firma'),
          onTap: onTap,
          borderRadius: AppDesign.mediumRadius,
          child: Container(
            height: 150,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // Siempre blanco: la firma es tinta negra, también en oscuro.
              color: Colors.white,
              borderRadius: AppDesign.mediumRadius,
              border: Border.all(
                color: error != null
                    ? AppColors.actionNegative
                    : scheme.outlineVariant,
                width: error != null ? 1.4 : 1,
              ),
            ),
            child: imagen == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.draw_outlined,
                          size: 30, color: Colors.black54),
                      SizedBox(height: 6),
                      Text(
                        'Tocar para firmar',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Image.memory(imagen, fit: BoxFit.contain),
          ),
        ),
        if (error != null) _ErrorTexto(error!),
        if (imagen != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Volver a firmar'),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'El cliente firma con el dedo en la pantalla, en horizontal. La '
          'firma queda en el RIM y en su PDF.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ErrorTexto extends StatelessWidget {
  final String message;

  const _ErrorTexto(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(
          message,
          style: const TextStyle(fontSize: 12, color: AppColors.actionNegative),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.actionNegative.withValues(alpha: 0.1),
        borderRadius: AppDesign.mediumRadius,
        border: Border.all(
          color: AppColors.actionNegative.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.actionNegative),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
