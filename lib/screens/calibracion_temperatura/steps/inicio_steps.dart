// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_icons.dart';
import '../../../utils/top_alert.dart';
import '../../../widgets/service_ui/calibracion_ui.dart';
import '../../calibracion/widgets/qr_scanner_screen.dart';
import '../controllers/temperatura_controller.dart';
import '../models/temperatura_models.dart';
import '../widgets/temp_ui.dart';

/// Lee el QR del equipo y completa cliente, planta y equipo.
Future<void> escanearQrEquipo(
  BuildContext context,
  TemperaturaController controller,
) async {
  final raw = await QrScannerScreen.escanear(context);
  if (raw == null || !context.mounted) return;
  final error = await controller.aplicarQr(raw);
  if (!context.mounted) return;
  TopAlert.show(
    context,
    error ?? 'Equipo identificado por su código QR.',
    isError: error != null,
  );
}

const _qrAzul = Color(0xFF04376E);

class ClienteTempStep extends StatefulWidget {
  const ClienteTempStep({super.key});

  @override
  State<ClienteTempStep> createState() => _ClienteTempStepState();
}

class _ClienteTempStepState extends State<ClienteTempStep> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _clientes = const [];
  bool _cargando = true;
  bool _mostrarBannerQr = true;
  String? _error;
  Timer? _espera;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _espera?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 250), () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final controller = context.read<TemperaturaController>();
      final clientes = await controller.catalogo.buscarClientes(texto);
      if (!mounted || consulta != _consulta) return;
      setState(() => _clientes = clientes.take(60).toList());
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TemperaturaController>();
    final isDark = CalUi.dark(context);
    final seleccionado = controller.servicio.cliente;
    final fijo = controller.clienteFijo;
    return TempStepPage(
      title: 'Cliente',
      subtitle: 'Selecciona el cliente del servicio',
      children: [
        if (fijo)
          const TempAviso.bloqueado(
              'El cliente quedó fijado al confirmar la SECA.')
        else ...[
          if (_mostrarBannerQr) ...[
            _BannerQr(
              onScan: () => escanearQrEquipo(context, controller),
              onClose: () => setState(() => _mostrarBannerQr = false),
            ),
            const SizedBox(height: 20),
          ],
          _SelectorModo(onQr: () => escanearQrEquipo(context, controller)),
          const SizedBox(height: 20),
          CalSearchField(
            controller: _search,
            hint: 'Buscar por nombre o razón social...',
            onChanged: _alEscribir,
          ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
          const SizedBox(height: 12),
          if (_cargando && _clientes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Cargando clientes...',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: CalUi.secundario(isDark))),
              ]),
            )
          else if (_error != null)
            CalEmptyState(
              icon: AppIcons.error,
              title: 'Error al cargar clientes',
              subtitle: _error,
              action: OutlinedButton.icon(
                onPressed: () => _buscar(_search.text),
                icon: const Icon(AppIcons.actualizar, size: 16),
                label: const Text('Reintentar'),
              ),
            )
          else if (_clientes.isEmpty)
            const CalEmptyState(
              title: 'Sin resultados',
              subtitle: 'Intenta con otro término o actualiza la precarga',
            )
          else ...[
            if (_cargando) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 10),
            ],
            for (final cliente in _clientes) ...[
              CalListItem(
                title: cliente['cliente']?.toString() ?? 'Cliente desconocido',
                subtitle: cliente['razonsocial']?.toString(),
                selected: seleccionado?.id == cliente['cliente_id']?.toString(),
                onTap: () => controller.elegirCliente(cliente),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
        if (seleccionado != null) ...[
          const SizedBox(height: 16),
          CalSelectedCard(
            label: 'Cliente Seleccionado',
            title: seleccionado.nombre,
            subtitle: seleccionado.razonSocial,
          ),
        ],
      ],
    );
  }
}

/// El aviso "¿Tienes el código QR del instrumento?" de Cliente.
class _BannerQr extends StatelessWidget {
  const _BannerQr({required this.onScan, required this.onClose});

  final VoidCallback onScan;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF001B36), const Color(0xFF0A1628)]
              : [const Color(0xFFE3F2FD), const Color(0xFFE8EAF6)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _qrAzul.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _qrAzul.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(AppIcons.escanearQr,
                size: 28, color: isDark ? Colors.white : _qrAzul),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Tienes el código QR del equipo?',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CalUi.texto(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Escanea para auto-completar cliente, planta y equipo',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onScan,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _qrAzul,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Escaneá',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            child: Icon(AppIcons.cerrar,
                size: 20, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2);
  }
}

/// El selector de modo de Cliente: buscar entre los existentes o leer el QR.
class _SelectorModo extends StatelessWidget {
  const _SelectorModo({required this.onQr});

  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: CalUi.accent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: CalUi.accent.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(AppIcons.buscarPersona,
                      size: 18, color: CalUi.ink),
                  const SizedBox(width: 8),
                  Text('Existente',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CalUi.ink)),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onQr,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _qrAzul.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.escanearQr,
                        size: 18, color: isDark ? Colors.white : _qrAzul),
                    const SizedBox(width: 6),
                    Text('QR',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : _qrAzul)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2);
  }
}

class PlantaTempStep extends StatefulWidget {
  const PlantaTempStep({super.key});

  @override
  State<PlantaTempStep> createState() => _PlantaTempStepState();
}

class _PlantaTempStepState extends State<PlantaTempStep> {
  Future<List<Map<String, dynamic>>>? _plantas;
  String? _clienteId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TemperaturaController>();
    final cliente = controller.servicio.cliente;
    if (cliente?.id != _clienteId) {
      _clienteId = cliente?.id;
      _plantas = controller.plantas().then((plantas) {
        // Con una sola planta no hay nada que elegir.
        if (plantas.length == 1 &&
            controller.servicio.planta == null &&
            !controller.clienteFijo) {
          controller.elegirPlanta(plantas.single);
        }
        return plantas;
      });
    }
    final seleccionada = controller.servicio.planta;
    return TempStepPage(
      title: 'Planta',
      subtitle: 'Selecciona la planta del servicio',
      children: [
        if (cliente != null) ...[
          CalContextBanner(
            icon: AppIcons.empresa,
            label: 'Cliente para este servicio',
            value: cliente.nombre,
          ),
          const SizedBox(height: 20),
        ],
        if (controller.clienteFijo)
          const TempAviso.bloqueado(
              'La planta quedó fijada al confirmar la SECA.')
        else
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _plantas,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final plantas = snapshot.data ?? const [];
              if (plantas.isEmpty) {
                return const CalEmptyState(
                  icon: AppIcons.planta,
                  title: 'Sin plantas',
                  subtitle: 'El cliente no tiene plantas en la precarga',
                );
              }
              return Column(
                children: [
                  for (final planta in plantas) ...[
                    CalListItem(
                      title: planta['planta']?.toString() ?? '',
                      subtitle: [
                        planta['codigo_planta'],
                        planta['dep'],
                        planta['dir'],
                      ]
                          .where((v) => (v?.toString().trim() ?? '').isNotEmpty)
                          .join(' · '),
                      leadingIcon: AppIcons.planta,
                      selected: seleccionada?.codigo ==
                          planta['codigo_planta']?.toString().trim(),
                      onTap: () => controller.elegirPlanta(planta),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        if (seleccionada != null) ...[
          const SizedBox(height: 16),
          CalSelectedCard(
            label: 'Planta Seleccionada',
            title: seleccionada.nombre,
            subtitle: 'Código: ${seleccionada.codigo}',
            details: [
              if ((seleccionada.direccion ?? '').isNotEmpty)
                (AppIcons.ubicacion, seleccionada.direccion!),
              if ((seleccionada.departamento ?? '').isNotEmpty)
                (AppIcons.mapa, seleccionada.departamento!),
            ],
          ),
        ],
      ],
    );
  }
}

class SecaTempStep extends StatefulWidget {
  const SecaTempStep({super.key, required this.cotizacion});

  /// La cotización que forma la SECA propuesta (C01, C13…).
  final ValueNotifier<String> cotizacion;

  @override
  State<SecaTempStep> createState() => _SecaTempStepState();
}

class _SecaTempStepState extends State<SecaTempStep> {
  late final _texto = TextEditingController(
      text: widget.cotizacion.value == 'C01' ? '' : widget.cotizacion.value);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TemperaturaController>();
    final s = controller.servicio;
    final isDark = CalUi.dark(context);
    final confirmada = s.secaConfirmada;
    final planta = s.planta?.codigo ?? 'NNNN-NN';
    final gestion = controller.secaPropuesta('C01').split('-').last;
    final ubicacion = controller.ubicacion;
    final inicio = horaLegible(s.horaInicio);
    return TempStepPage(
      title: 'Código SECA',
      subtitle: 'Generación del código único del servicio',
      children: [
        CalInfoSummary(
          title: 'Resumen de la Información',
          rows: [
            ('Cliente', s.cliente?.nombre),
            ('Código Planta', s.planta?.codigo),
            ('Técnico', s.personal),
            ('Fecha', s.fechaServicio),
          ],
        ),
        const SizedBox(height: 24),
        _TarjetaSeca(
          confirmada: confirmada,
          seca: s.seca,
          fija: '$planta-',
          gestion: '-$gestion',
          texto: _texto,
          onChanged: (valor) {
            widget.cotizacion.value =
                valor.trim().isEmpty ? 'C01' : valor.trim().toUpperCase();
            setState(() {});
          },
          sessionId: s.sessionId,
        ),
        const SizedBox(height: 24),
        if (confirmada)
          CalInfoSummary(
            title: 'Registro del servicio',
            icon: AppIcons.hora,
            rows: [
              ('Inicio', inicio),
              (
                'Ubicación',
                ubicacion == null
                    ? 'Se registra al guardar'
                    : '${ubicacion['latitud']}, ${ubicacion['longitud']}',
              ),
            ],
          )
        else
          Text(
            'Al confirmar, el cliente y la planta quedan fijos y se registra '
            'la hora de inicio del servicio.',
            style: GoogleFonts.inter(
                fontSize: 12.5, color: CalUi.secundario(isDark), height: 1.4),
          ),
      ],
    );
  }
}

/// La tarjeta "SECA Sugerido / SECA Confirmado" de Calibración.
class _TarjetaSeca extends StatelessWidget {
  const _TarjetaSeca({
    required this.confirmada,
    required this.seca,
    required this.fija,
    required this.gestion,
    required this.texto,
    required this.onChanged,
    required this.sessionId,
  });

  final bool confirmada;
  final String? seca;
  final String fija;
  final String gestion;
  final TextEditingController texto;
  final ValueChanged<String> onChanged;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    const accent = CalUi.accent;
    final mono = GoogleFonts.robotoMono(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: CalUi.texto(isDark),
      letterSpacing: 1,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: confirmada
            ? (isDark ? accent.withOpacity(0.08) : const Color(0xFFFFFDE6))
            : CalUi.fondo(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: confirmada ? accent.withOpacity(0.5) : CalUi.borde(isDark),
          width: confirmada ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(confirmada ? 0.05 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            confirmada ? 'SECA Confirmado' : 'SECA Sugerido',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: confirmada
                  ? (isDark ? accent : CalUi.accentInk)
                  : (isDark ? Colors.white54 : Colors.black54),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (confirmada)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CalUi.borde(isDark)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  seca ?? '',
                  key: const ValueKey('temp-seca'),
                  style: mono.copyWith(fontSize: 22, letterSpacing: 2),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CalUi.borde(isDark)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(fija, style: mono),
                    Container(
                      width: 70,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        key: const ValueKey('temp-cotizacion'),
                        controller: texto,
                        textCapitalization: TextCapitalization.characters,
                        style: mono.copyWith(
                            color: isDark ? accent : CalUi.accentInk),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: CalUi.borde(isDark)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: CalUi.borde(isDark)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: accent, width: 2),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          hintText: 'C01',
                          hintStyle: mono.copyWith(
                              color: isDark ? Colors.white30 : Colors.black26),
                        ),
                        textAlign: TextAlign.center,
                        maxLength: 3,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null,
                        onChanged: onChanged,
                      ),
                    ),
                    Text(gestion, style: mono),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (confirmada) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.completo, color: CalUi.ink, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Confirmado y Registrado',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: CalUi.ink,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
                .animate(delay: 400.ms)
                .fadeIn()
                .scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CalUi.borde(isDark)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.clave,
                      color: isDark ? Colors.white54 : Colors.black45,
                      size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ID: $sessionId',
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Text(
              'Escriba la cotización (C01, C13…) y confirme con el botón '
              'inferior.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12, color: CalUi.secundario(isDark)),
            ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2);
  }
}

/// Resumen del equipo para el diálogo de confirmación.
List<(String, String?)> datosEquipo(TempEquipo equipo) => [
      ('Código métrica', equipo.codMetrica),
      ('Tipo', equipo.tipo),
      ('Marca', equipo.marca),
      ('Modelo', equipo.modelo),
      ('Serie', equipo.serie),
      (
        'Rango',
        equipo.rangoMin == null || equipo.rangoMax == null
            ? null
            : '${textoNumero(equipo.rangoMin)} a ${textoNumero(equipo.rangoMax)} ${equipo.unidad}',
      ),
      (
        'Resolución',
        equipo.resolucion == null
            ? null
            : '${textoNumero(equipo.resolucion)} ${equipo.unidad}',
      ),
      ('Indicador', equipo.indicador),
    ];
