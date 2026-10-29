// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/service_session.dart' show EquipoInfo;
import '../../../theme/app_icons.dart';
import '../../../utils/top_alert.dart';
import '../../../widgets/service_ui/calibracion_ui.dart';
import '../../calibracion/widgets/patron_weights_selector.dart';
import '../controllers/temperatura_controller.dart';
import '../data/catalogo_temperatura.dart';
import '../models/temperatura_models.dart';
import '../widgets/temp_ui.dart';

const posicionesSensor = [
  'Centro',
  'Superior',
  'Inferior',
  'Frontal',
  'Posterior',
  'Izquierda',
  'Derecha',
  'Esquina',
];

const _textosPatrones = PatronSelectorTexts(
  title: 'Patrones de temperatura',
  emptyHint: 'Añade el termómetro o los termopares patrón que van en el '
      'equipo.',
  filledHint: 'Revisa la vigencia del certificado de cada patrón.',
  sheetTitle: 'Patrones de temperatura',
  searchHint: 'Buscar código o tipo de patrón',
  chooseLabel: 'Seleccionar patrones',
  loadingLabel: 'Cargando patrones…',
  loadFailed: 'No se pudo cargar el catálogo de patrones.',
  noMatches: 'No hay patrones que coincidan',
  noMatchesHint: 'Prueba con otro código o tipo.',
  emptyCatalog: 'No hay patrones de temperatura en la precarga',
  emptyCatalogHint: 'Las pesas no se muestran aquí. Actualiza la precarga '
      'si falta un termómetro o termopar.',
  defaultType: 'Patrón de temperatura',
  footer: 'Hasta 5 patrones',
);

const _textosAmbiente = PatronSelectorTexts(
  title: 'Termohigrómetro',
  emptyHint: 'Añade el instrumento con que se miden la temperatura y la '
      'humedad del lugar.',
  filledHint: 'Revisa la vigencia de su certificado.',
  sheetTitle: 'Termohigrómetro',
  searchHint: 'Buscar código o tipo',
  chooseLabel: 'Seleccionar termohigrómetro',
  loadingLabel: 'Cargando…',
  loadFailed: 'No se pudo cargar el catálogo.',
  noMatches: 'No hay instrumentos que coincidan',
  noMatchesHint: 'Prueba con otro código o tipo.',
  emptyCatalog: 'No hay termohigrómetros en la precarga',
  emptyCatalogHint: 'Actualiza la precarga para disponer del catálogo.',
  defaultType: 'Termohigrómetro',
  footer: 'Un instrumento para el ambiente',
);

EquipoInfo _info(TempPatron p) => EquipoInfo(
      codInstrumento: p.codInstrumento,
      tipo: p.instrumento,
      certFecha: p.certFecha,
      enteCalibrador: p.enteCalibrador,
      estado: p.estado,
      cantidad: '1',
    );

TempPatron _patron(EquipoInfo e, String uso) => TempPatron(
      codInstrumento: e.codInstrumento ?? '',
      instrumento: e.tipo,
      certFecha: e.certFecha,
      enteCalibrador: e.enteCalibrador,
      estado: e.estado,
      uso: uso,
    );

EquipoInfo _infoDeFila(Map<String, dynamic> row) =>
    _info(FiltrosTemperatura.patronDe(row, uso: TempPatron.usoTemperatura));

class PatronesTempStep extends StatefulWidget {
  const PatronesTempStep({super.key});

  @override
  State<PatronesTempStep> createState() => _PatronesTempStepState();
}

class _PatronesTempStepState extends State<PatronesTempStep> {
  List<Map<String, dynamic>> _catalogo = const [];
  bool _cargando = true;
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TemperaturaController>().asegurarIndicador();
    });
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _fallo = false;
    });
    try {
      final rows =
          await context.read<TemperaturaController>().catalogo.patrones();
      if (mounted) setState(() => _catalogo = rows);
    } catch (_) {
      if (mounted) setState(() => _fallo = true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarPatrones(
    TemperaturaController c,
    List<EquipoInfo> elegidos,
    String uso,
  ) async {
    final otros = c.patrones.where((p) => p.uso != uso);
    final error = await c.guardarPatrones([
      if (uso == TempPatron.usoTemperatura)
        ...elegidos.map((e) => _patron(e, uso)),
      ...otros,
      if (uso == TempPatron.usoAmbiente)
        ...elegidos.map((e) => _patron(e, uso)),
    ]);
    if (!mounted) return;
    if (error != null) {
      TopAlert.show(context, error, isError: true);
      return;
    }
    final vencidos = elegidos
        .where((e) => WeightCertificateStatus(e.certFecha).expired)
        .map((e) => e.codInstrumento);
    if (vencidos.isNotEmpty) {
      TopAlert.show(context, '${vencidos.join(', ')}: certificado vencido.',
          isError: true);
    }
  }

  Future<void> _editarSensor(TemperaturaController c,
      {TempCanal? sensor}) async {
    final patrones =
        c.patrones.where((p) => p.uso == TempPatron.usoTemperatura).toList();
    final base = sensor ?? c.sensorNuevo();
    final resultado = await showModalBottomSheet<(TempCanal?, bool)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SensorSheet(
        sensor: base,
        patrones: patrones,
        puedeQuitar: sensor != null,
      ),
    );
    if (resultado == null || !mounted) return;
    final (editado, quitar) = resultado;
    final error = await c.guardarSensor(editado ?? base, quitar: quitar);
    if (error != null && mounted) TopAlert.show(context, error, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TemperaturaController>();
    final s = c.servicio;
    final isDark = CalUi.dark(context);
    final fijos = c.canalesFijos;
    final indicador =
        c.canales.where((k) => k.rol == RolCanal.equipo).firstOrNull;
    final sensores = c.canales.where((k) => k.rol == RolCanal.patron).toList();
    final temperatura = _catalogo.where(FiltrosTemperatura.esPatronTemperatura);
    final ambiente = _catalogo.where(FiltrosTemperatura.esAmbiente);
    void ambienteInicio({double? t, double? hr, required bool esT}) =>
        c.actualizar((s) => s.copyWith(
              ambiente: TempAmbiente(
                temperaturaInicio: esT ? t : s.ambiente.temperaturaInicio,
                humedadInicio: esT ? s.ambiente.humedadInicio : hr,
                temperaturaFin: s.ambiente.temperaturaFin,
                humedadFin: s.ambiente.humedadFin,
              ),
            ));

    return TempStepPage(
      title: 'Patrones y sensores',
      subtitle: 'Con qué se mide y qué se registra en cada lectura',
      children: [
        PatronWeightsSelector(
          key: const ValueKey('temp-patrones'),
          catalog: [for (final row in temperatura) _infoDeFila(row)],
          selected: [
            for (final p in c.patrones)
              if (p.uso == TempPatron.usoTemperatura) _info(p),
          ],
          onChanged: (lista) =>
              _guardarPatrones(c, lista, TempPatron.usoTemperatura),
          loading: _cargando,
          loadFailed: _fallo,
          onRetry: _cargar,
          texts: _textosPatrones,
          icon: AppIcons.temperatura,
        ),
        const SizedBox(height: 24),
        const CalSectionTitle('Sensores del patrón', AppIcons.sensor),
        CalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Los sensores van dentro del equipo y graban en el software '
                'de su registrador. Aquí solo se anota cuál es cada uno y '
                'dónde quedó.',
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 14),
              if (fijos)
                const TempAviso.bloqueado(
                    'La medición ya empezó: los sensores quedan como están.'),
              for (final sensor in sensores) ...[
                CalListItem(
                  title: sensor.nombre,
                  subtitle: [sensor.codPatron, sensor.posicion]
                      .whereType<String>()
                      .join(' · '),
                  leadingIcon: AppIcons.sensor,
                  selected: false,
                  onTap: fijos ? null : () => _editarSensor(c, sensor: sensor),
                  trailing: Icon(fijos ? AppIcons.bloqueado : AppIcons.editar,
                      size: 16,
                      color: isDark ? Colors.white38 : Colors.black38),
                ),
                const SizedBox(height: 8),
              ],
              if (!fijos)
                OutlinedButton.icon(
                  key: const ValueKey('temp-agregar-sensor'),
                  onPressed: () => _editarSensor(c),
                  icon: const Icon(AppIcons.agregar, size: 18),
                  label: Text(sensores.isEmpty
                      ? 'Agregar sensor'
                      : 'Agregar otro sensor'),
                ),
              const SizedBox(height: 16),
              CalTextField(
                key: const ValueKey('temp-registro-sensores'),
                label: 'Registro de los sensores',
                hint: 'Archivo o referencia en el software',
                icon: AppIcons.archivo,
                value: s.registroSensores,
                onChanged: (v) =>
                    c.actualizar((s) => s.copyWith(registroSensores: v.trim())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const CalSectionTitle('Indicador del equipo', AppIcons.ver),
        CalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CalSummaryRow('Tipo', s.equipo?.indicador),
              const SizedBox(height: 8),
              CalSummaryRow(
                  'Resolución',
                  s.equipo?.resolucion == null
                      ? null
                      : '${textoNumero(s.equipo!.resolucion)} ${s.equipo!.unidad}'),
              const SizedBox(height: 16),
              Text(
                'Es lo que se registra en cada lectura.',
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 10),
              if (indicador != null)
                TempOpciones<MetodoCanal>(
                  opciones: const [MetodoCanal.camara, MetodoCanal.manual],
                  seleccion: indicador.metodo,
                  enabled: !fijos,
                  etiqueta: (m) =>
                      m == MetodoCanal.camara ? 'Con la cámara' : 'A mano',
                  iconos: (m) => m == MetodoCanal.camara
                      ? AppIcons.camara
                      : AppIcons.editar,
                  onChanged: (m) async {
                    final error = await c.metodoIndicador(m);
                    if (error != null && context.mounted) {
                      TopAlert.show(context, error, isError: true);
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PatronWeightsSelector(
          key: const ValueKey('temp-termohigrometro'),
          catalog: [for (final row in ambiente) _infoDeFila(row)],
          selected: [
            for (final p in c.patrones)
              if (p.uso == TempPatron.usoAmbiente) _info(p),
          ],
          onChanged: (lista) =>
              _guardarPatrones(c, lista, TempPatron.usoAmbiente),
          loading: _cargando,
          loadFailed: _fallo,
          onRetry: _cargar,
          texts: _textosAmbiente,
          icon: AppIcons.humedad,
          maxSelection: 1,
        ),
        const SizedBox(height: 16),
        CalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CalGroupTitle(
                  'Condiciones ambientales iniciales', AppIcons.humedad),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TempNumeroField(
                      key: const ValueKey('temp-amb-inicio'),
                      label: 'Temperatura',
                      sufijo: '°C',
                      valor: s.ambiente.temperaturaInicio,
                      onChanged: (v) => ambienteInicio(t: v, esT: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TempNumeroField(
                      key: const ValueKey('temp-hr-inicio'),
                      label: 'Humedad',
                      sufijo: '%HR',
                      negativos: false,
                      valor: s.ambiente.humedadInicio,
                      onChanged: (v) => ambienteInicio(hr: v, esT: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hoja de un sensor del patrón, con la forma de "Buscar Instrumento".
class _SensorSheet extends StatefulWidget {
  const _SensorSheet({
    required this.sensor,
    required this.patrones,
    required this.puedeQuitar,
  });

  final TempCanal sensor;
  final List<TempPatron> patrones;
  final bool puedeQuitar;

  @override
  State<_SensorSheet> createState() => _SensorSheetState();
}

class _SensorSheetState extends State<_SensorSheet> {
  late TempCanal _sensor = widget.sensor;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final valido = _sensor.nombre.trim().isNotEmpty;
    Widget etiqueta(String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(texto,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87)),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Sensor del patrón',
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: CalUi.texto(isDark))),
                const SizedBox(height: 16),
                TempTextoField(
                  label: 'Nombre (como en el software)',
                  valor: _sensor.nombre,
                  maxLength: 60,
                  onChanged: (v) =>
                      setState(() => _sensor = _sensor.copyWith(nombre: v)),
                ),
                if (widget.patrones.length > 1) ...[
                  const SizedBox(height: 8),
                  etiqueta('Patrón'),
                  TempOpciones<String>(
                    opciones: [
                      for (final p in widget.patrones) p.codInstrumento
                    ],
                    seleccion: _sensor.codPatron,
                    etiqueta: (c) => c,
                    onChanged: (c) => setState(
                        () => _sensor = _sensor.copyWith(codPatron: c)),
                  ),
                ],
                const SizedBox(height: 16),
                etiqueta('Posición dentro del equipo'),
                TempOpciones<String>(
                  opciones: posicionesSensor,
                  seleccion: _sensor.posicion,
                  etiqueta: (p) => p,
                  onChanged: (p) =>
                      setState(() => _sensor = _sensor.copyWith(posicion: p)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (widget.puedeQuitar)
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context, (null, true)),
                        icon: const Icon(AppIcons.eliminar, size: 18),
                        label: const Text('Quitar'),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: valido
                          ? () => Navigator.pop(context, (
                                _sensor.copyWith(nombre: _sensor.nombre.trim()),
                                false
                              ))
                          : null,
                      icon: const Icon(AppIcons.listo, size: 18),
                      label: const Text('Guardar sensor'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
