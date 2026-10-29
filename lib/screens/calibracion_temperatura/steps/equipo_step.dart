import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_icons.dart';
import '../../../widgets/service_ui/calibracion_ui.dart';
import '../../../widgets/service_ui/editable_suggestion_field.dart';
import '../../../widgets/service_ui/ficha_instrumento.dart';
import '../controllers/temperatura_controller.dart';
import '../data/catalogo_temperatura.dart';
import '../models/temperatura_models.dart';
import '../widgets/temp_ui.dart';
import 'inicio_steps.dart';

const _resoluciones = [1.0, 0.5, 0.1, 0.01];

final _compacto = OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10));

/// La ficha de un equipo de temperatura, como la de Instrumento: código,
/// fabricante, datos y, al pie, rango, resolución e indicador.
class FichaEquipoTemp extends StatelessWidget {
  const FichaEquipoTemp({super.key, required this.equipo});

  final TempEquipo equipo;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final unidad = equipo.unidad;
    final rango = equipo.rangoMin == null || equipo.rangoMax == null
        ? 'Sin rango'
        : '${textoNumero(equipo.rangoMin)} a ${textoNumero(equipo.rangoMax)} $unidad';
    return FichaInstrumentoEncabezado(
      codMetrica: equipo.codMetrica,
      esNueva: equipo.nuevo,
      marca: equipo.marca,
      modelo: equipo.modelo,
      serie: equipo.serie,
      tipo: equipo.tipo,
      unidad: unidad,
      rangos: const [],
      icono: AppIcons.temperatura,
      avisoProvisional: 'Código provisional. Registre el equipo en DataMET; '
          'antes de subir los datos podrá cambiarlo por el código definitivo.',
      pie: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          _DatoPie('Rango de trabajo', rango, isDark),
          _DatoPie(
              'Resolución',
              equipo.resolucion == null
                  ? '—'
                  : '${textoNumero(equipo.resolucion)} $unidad',
              isDark),
          _DatoPie('Indicador', equipo.indicador ?? '—', isDark),
        ],
      ),
    );
  }
}

class _DatoPie extends StatelessWidget {
  const _DatoPie(this.etiqueta, this.valor, this.isDark);

  final String etiqueta;
  final String valor;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiqueta.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 2),
          Text(valor,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: CalUi.texto(isDark))),
        ],
      );
}

class EquipoTempStep extends StatefulWidget {
  const EquipoTempStep({super.key});

  @override
  State<EquipoTempStep> createState() => _EquipoTempStepState();
}

class _EquipoTempStepState extends State<EquipoTempStep> {
  List<Map<String, dynamic>> _equipos = const [];
  bool _cargando = false;
  String? _planta;

  Future<void> _cargar(TemperaturaController controller) async {
    setState(() => _cargando = true);
    try {
      final equipos = await controller.equiposPlanta();
      if (mounted) setState(() => _equipos = equipos);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _buscar(TemperaturaController controller) async {
    final row = await showCalSearchSheet<Map<String, dynamic>>(
      context,
      title: 'Buscar Equipo',
      hint: 'Buscar por código, serie o marca...',
      items: _equipos,
      empty: 'La planta no tiene equipos de temperatura en la precarga',
      matches: (row, q) => [
        row['cod_metrica'],
        row['serie'],
        row['marca'],
        row['cod_interno'],
        row['instrumento'],
      ].any((v) => (v?.toString().toLowerCase() ?? '').contains(q)),
      itemBuilder: (context, row, select) => CalListItem(
        title: row['cod_metrica']?.toString() ?? 'Sin código',
        subtitle: [
          row['instrumento'],
          row['marca'],
          row['modelo'],
          if ((row['serie']?.toString() ?? '').isNotEmpty)
            'Serie ${row['serie']}',
        ].where((v) => (v?.toString().trim() ?? '').isNotEmpty).join(' · '),
        leadingIcon: AppIcons.temperatura,
        selected: false,
        onTap: select,
      ),
    );
    if (row != null) controller.elegirEquipo(FiltrosTemperatura.equipoDe(row));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TemperaturaController>();
    final s = controller.servicio;
    if (s.planta?.codigo != _planta) {
      _planta = s.planta?.codigo;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargar(controller);
      });
    }
    final equipo = s.equipo;
    return TempStepPage(
      title: 'Equipo',
      subtitle: 'Selecciona o registra el equipo a calibrar',
      children: [
        if (s.equipoConfirmado) ...[
          const TempAviso.bloqueado(
              'Equipo confirmado: sus datos quedan fijos en el registro.'),
          FichaEquipoTemp(equipo: equipo!),
          const SizedBox(height: 16),
          CalInfoSummary(
            title: 'Datos del equipo',
            icon: AppIcons.temperatura,
            rows: [
              ('Descripción', equipo.instrumento),
              ('Código interno', equipo.codInterno),
              ('Ubicación', equipo.ubicacion),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  style: _compacto,
                  onPressed: _cargando ? null : () => _buscar(controller),
                  icon: _cargando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(AppIcons.buscar, size: 18),
                  label: const Text('Buscar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  key: const ValueKey('temp-equipo-nuevo'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: controller.equipoNuevo,
                  icon: const Icon(AppIcons.agregar, size: 18),
                  label: const Text('Nuevo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: _compacto,
                  onPressed: () => escanearQrEquipo(context, controller),
                  icon: const Icon(AppIcons.escanearQr, size: 18),
                  label: const Text('QR', softWrap: false),
                ),
              ),
            ],
          ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
          const SizedBox(height: 24),
          if (equipo == null)
            CalEmptyState(
              icon: AppIcons.temperatura,
              title: _equipos.isEmpty
                  ? 'Sin equipos de temperatura en la precarga'
                  : '${_equipos.length} equipos en la planta',
              subtitle: _equipos.isEmpty
                  ? 'Registre uno con "Nuevo": se sube con su código '
                      'definitivo cuando DataMET lo asigne.'
                  : 'Use "Buscar" para elegir el equipo o "Nuevo" para '
                      'registrarlo.',
            )
          else
            _Formulario(
              key: ValueKey(equipo.codMetrica),
              equipo: equipo,
              controller: controller,
            ),
        ],
      ],
    );
  }
}

class _Formulario extends StatefulWidget {
  const _Formulario(
      {super.key, required this.equipo, required this.controller});

  final TempEquipo equipo;
  final TemperaturaController controller;

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  late final _tipo = TextEditingController(text: widget.equipo.tipo ?? '');

  TempEquipo get equipo => widget.equipo;

  void _editar(TempEquipo Function(TempEquipo e) cambio) =>
      widget.controller.editarEquipo(cambio);

  @override
  void dispose() {
    _tipo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final unidad = equipo.unidad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FichaEquipoTemp(equipo: equipo),
        const SizedBox(height: 16),
        CalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CalGroupTitle('Identificación', AppIcons.etiqueta),
              CalTextField(
                label: 'Código Métrica',
                value: equipo.codMetrica,
                icon: AppIcons.qr,
                readOnly: true,
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              CalTextField(
                label: 'Código Interno',
                value: equipo.codInterno,
                icon: AppIcons.numero,
                onChanged: (v) => _editar((e) => e.copyWith(codInterno: v)),
              ),
              const SizedBox(height: 12),
              EditableSuggestionField(
                controller: _tipo,
                label: 'Tipo de Equipo',
                icon: AppIcons.temperatura,
                options: tiposEquipoTemperatura,
                onChanged: (v) => _editar((e) => e.copyWith(tipo: v.trim())),
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              CalTextField(
                label: 'Descripción',
                value: equipo.instrumento,
                onChanged: (v) => _editar((e) => e.copyWith(instrumento: v)),
              ),
              const SizedBox(height: 22),
              const CalGroupTitle('Fabricante', AppIcons.empresa),
              CalTextField(
                label: 'Marca',
                value: equipo.marca,
                icon: AppIcons.empresa,
                onChanged: (v) => _editar((e) => e.copyWith(marca: v)),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CalTextField(
                      label: 'Modelo',
                      value: equipo.modelo,
                      onChanged: (v) => _editar((e) => e.copyWith(modelo: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CalTextField(
                      label: 'Serie',
                      value: equipo.serie,
                      onChanged: (v) => _editar((e) => e.copyWith(serie: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const CalGroupTitle('Características', AppIcons.chip),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CalDropdown<String>(
                      key: const ValueKey('temp-indicador'),
                      label: 'Indicador',
                      value: equipo.indicador,
                      items: tiposIndicador,
                      onChanged: (v) {
                        if (v != null) widget.controller.elegirIndicador(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CalDropdown<String>(
                      label: 'Unidad',
                      value: unidad,
                      items: const ['°C', '°F'],
                      onChanged: (v) =>
                          _editar((e) => e.copyWith(unidad: v ?? '°C')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CalDropdown<double>(
                label: 'Resolución del indicador',
                value: equipo.resolucion,
                items: _resoluciones,
                itemLabel: (r) => '${textoNumero(r)} $unidad',
                onChanged: (v) => _editar((e) => e.copyWith(resolucion: v)),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CalNumberField(
                      label: 'Rango mínimo',
                      suffix: unidad,
                      value: equipo.rangoMin,
                      onChanged: (v) =>
                          _editar((e) => e.conRango(v, e.rangoMax)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CalNumberField(
                      label: 'Rango máximo',
                      suffix: unidad,
                      value: equipo.rangoMax,
                      onChanged: (v) =>
                          _editar((e) => e.conRango(e.rangoMin, v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CalTextField(
                label: 'Ubicación',
                value: equipo.ubicacion,
                icon: AppIcons.ubicacion,
                onChanged: (v) => _editar((e) => e.copyWith(ubicacion: v)),
              ),
            ],
          ),
        ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
        if (!equipo.nuevo) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => widget.controller
                  .actualizar((s) => s.copyWith(clearEquipo: true)),
              icon: const Icon(AppIcons.cambiar, size: 16),
              label: const Text('Elegir otro equipo'),
            ),
          ),
        ],
      ],
    );
  }
}
