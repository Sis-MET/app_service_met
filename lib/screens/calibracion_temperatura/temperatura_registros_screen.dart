import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../theme/app_icons.dart';
import '../../utils/new_scale_code.dart';
import '../../widgets/requiere_ubicacion.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import 'data/temperatura_store.dart';
import 'lecturas_punto_screen.dart';
import 'models/temperatura_models.dart';
import 'services/temperatura_repository.dart';
import 'temperatura_workspace_screen.dart';
import 'widgets/acciones_registro.dart';
import 'widgets/resumen_punto_card.dart';
import 'widgets/temp_ui.dart';

(String, Color, IconData) estadoRegistro(TempServicio s) {
  if (s.estado == EstadoServicioTemp.abandonado) {
    return ('Descartada', AppColors.textSecondaryLight, AppIcons.cancelar);
  }
  if (s.estado == EstadoServicioTemp.enCurso) {
    return ('En curso', AppColors.shimmerGold, AppIcons.hora);
  }
  return switch (s.subida) {
    EstadoSubidaTemp.subido => (
        'En DataMET',
        AppColors.actionPositive,
        AppIcons.nubeLista
      ),
    EstadoSubidaTemp.error => (
        'Rechazada',
        AppColors.actionNegative,
        AppIcons.error
      ),
    _ => ('Por subir', AppColors.warning, AppIcons.subir),
  };
}

/// Las calibraciones de temperatura del teléfono: en curso, finalizadas,
/// subidas y descartadas. Se consultan sin entrar a editarlas.
class TemperaturaRegistrosScreen extends StatefulWidget {
  const TemperaturaRegistrosScreen(
      {super.key, required this.userName, this.store});

  final String userName;
  final TemperaturaStore? store;

  @override
  State<TemperaturaRegistrosScreen> createState() =>
      _TemperaturaRegistrosScreenState();
}

class _TemperaturaRegistrosScreenState
    extends State<TemperaturaRegistrosScreen> {
  late final TemperaturaStore _store = widget.store ?? TemperaturaStore();
  late Future<List<TempServicio>> _lista = _store.lista();

  void _recargar() => setState(() => _lista = _store.lista());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ServiceAppBar(
        title: 'Registros de temperatura',
        subtitle: 'Calibraciones en este teléfono',
      ),
      body: FutureBuilder<List<TempServicio>>(
        future: _lista,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data ?? const [];
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay calibraciones de temperatura.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final s = lista[index];
                final (texto, color, icono) = estadoRegistro(s);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppPanel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                      leading: const Icon(AppIcons.temperatura,
                          color: AppColors.actionPositive),
                      title: Text(
                        s.codigoRegistro ?? s.seca ?? 'Sin SECA',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text([
                              s.equipo?.tipo,
                              s.cliente?.nombre,
                              s.fechaServicio,
                            ].whereType<String>().join(' · ')),
                            const SizedBox(height: 6),
                            TempEstado(texto, color: color, icon: icono),
                          ],
                        ),
                      ),
                      trailing: const Icon(AppIcons.siguiente),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TemperaturaDetalleScreen(
                              uuid: s.uuid,
                              userName: widget.userName,
                              store: _store,
                            ),
                          ),
                        );
                        _recargar();
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// La ficha de una calibración de temperatura, de solo lectura.
class TemperaturaDetalleScreen extends StatefulWidget {
  const TemperaturaDetalleScreen({
    super.key,
    required this.uuid,
    required this.userName,
    this.store,
  });

  final String uuid;
  final String userName;
  final TemperaturaStore? store;

  @override
  State<TemperaturaDetalleScreen> createState() =>
      _TemperaturaDetalleScreenState();
}

class _TemperaturaDetalleScreenState extends State<TemperaturaDetalleScreen> {
  late final TemperaturaStore _store = widget.store ?? TemperaturaStore();
  late Future<TempPaquete?> _paquete = _store.paquete(widget.uuid);
  bool _subiendo = false;

  void _recargar() => setState(() => _paquete = _store.paquete(widget.uuid));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ServiceAppBar(title: 'Calibración de temperatura'),
      body: FutureBuilder<TempPaquete?>(
        future: _paquete,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final paquete = snapshot.data;
          if (paquete == null) {
            return const Center(child: Text('No se encontró el registro.'));
          }
          final s = paquete.servicio;
          final equipo = s.equipo;
          final unidad = equipo?.unidad ?? '°C';
          final (texto, color, icono) = estadoRegistro(s);
          final impedimento = TemperaturaRepository.impedimento(s);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              TempSection(
                title: 'Registro',
                icon: AppIcons.temperatura,
                trailing: TempEstado(texto, color: color, icon: icono),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TempDato('Código', s.codigoRegistro),
                    TempDato('Cliente', s.cliente?.nombre),
                    TempDato('Planta', s.planta?.nombre),
                    TempDato('SECA', s.seca),
                    TempDato('Técnico', s.personal),
                    TempDato('Inicio', horaLegible(s.horaInicio)),
                    TempDato('Fin', horaLegible(s.horaFin)),
                    TempDato('Versión de la app', s.appVersion),
                    TempDato(
                      'Ubicación',
                      paquete.ubicacion == null
                          ? 'Sin ubicación'
                          : '${paquete.ubicacion!['latitud']}, ${paquete.ubicacion!['longitud']}',
                    ),
                    if (s.subidaError != null && !s.subido)
                      TempAviso.error(s.subidaError!),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (s.estado == EstadoServicioTemp.enCurso)
                          FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                RequiereUbicacion.ruta(
                                    TemperaturaWorkspaceScreen(
                                  userName: widget.userName,
                                  uuid: s.uuid,
                                )),
                              );
                              _recargar();
                            },
                            icon: const Icon(AppIcons.adelante, size: 18),
                            label: const Text('Continuar'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              exportarCsvTemperatura(context, paquete),
                          icon: const Icon(AppIcons.exportarArchivo, size: 18),
                          label: const Text('Exportar CSV'),
                        ),
                        if (s.finalizado &&
                            !s.subido &&
                            NewScaleCode.isProvisional(equipo?.codMetrica))
                          OutlinedButton.icon(
                            onPressed: () async {
                              await asignarCodigoTemperatura(context, s,
                                  store: _store);
                              _recargar();
                            },
                            icon: const Icon(AppIcons.etiqueta, size: 18),
                            label: const Text('Asignar código'),
                          ),
                        if (s.finalizado && !s.subido)
                          FilledButton.icon(
                            onPressed: _subiendo || impedimento != null
                                ? null
                                : () async {
                                    setState(() => _subiendo = true);
                                    await subirRegistroTemperatura(
                                        context, s.uuid,
                                        store: _store);
                                    if (!mounted) return;
                                    setState(() => _subiendo = false);
                                    _recargar();
                                  },
                            icon: const Icon(AppIcons.subir, size: 18),
                            label: const Text('Subir a DataMET'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              TempSection(
                title: 'Equipo',
                icon: AppIcons.equipo,
                child: Column(children: [
                  TempDato('Código métrica', equipo?.codMetrica),
                  TempDato('Tipo', equipo?.tipo),
                  TempDato(
                      'Marca / modelo',
                      [equipo?.marca, equipo?.modelo]
                          .whereType<String>()
                          .join(' · ')),
                  TempDato('Serie', equipo?.serie),
                  TempDato('Ubicación', equipo?.ubicacion),
                  TempDato(
                      'Rango',
                      equipo?.rangoMin == null
                          ? null
                          : '${textoNumero(equipo!.rangoMin)} a ${textoNumero(equipo.rangoMax)} $unidad'),
                  TempDato(
                      'Resolución',
                      equipo?.resolucion == null
                          ? null
                          : '${textoNumero(equipo!.resolucion)} $unidad'),
                  TempDato('Indicador', equipo?.indicador),
                ]),
              ),
              TempSection(
                title: 'Patrones y ambiente',
                icon: AppIcons.laboratorio,
                child: Column(children: [
                  for (final p in paquete.patrones)
                    TempDato(
                        p.uso == TempPatron.usoAmbiente ? 'Ambiente' : 'Patrón',
                        [
                          p.codInstrumento,
                          p.instrumento,
                          if (p.certFecha != null) 'cert. ${p.certFecha}'
                        ].whereType<String>().join(' · ')),
                  TempDato('Ambiente inicio',
                      '${textoNumero(s.ambiente.temperaturaInicio)} °C · ${textoNumero(s.ambiente.humedadInicio)} %HR'),
                  TempDato('Ambiente fin',
                      '${textoNumero(s.ambiente.temperaturaFin)} °C · ${textoNumero(s.ambiente.humedadFin)} %HR'),
                ]),
              ),
              TempSection(
                title: 'Canales',
                icon: AppIcons.sensor,
                child: Column(children: [
                  for (final c in paquete.canales)
                    TempDato(
                        '${c.n}. ${c.nombre}',
                        [
                          c.rol.etiqueta,
                          c.codPatron,
                          c.posicion,
                          c.metodo.etiqueta,
                        ].whereType<String>().join(' · ')),
                ]),
              ),
              for (final punto in paquete.puntos)
                ResumenPuntoCard(
                  punto: punto,
                  canales: paquete.canales,
                  lecturas: paquete.lecturas,
                  unidad: unidad,
                  acciones: [
                    if (punto.estado != EstadoPunto.pendiente)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LecturasPuntoScreen(
                              punto: punto,
                              canales: paquete.canales,
                              lecturas: paquete.lecturas,
                              correcciones: paquete.correcciones,
                              unidad: unidad,
                            ),
                          ),
                        ),
                        icon: const Icon(AppIcons.tabla, size: 18),
                        label: const Text('Ver lecturas'),
                      ),
                  ],
                ),
              if ((s.observaciones ?? '').isNotEmpty)
                TempSection(
                  title: 'Observaciones',
                  icon: AppIcons.nota,
                  child: Text(s.observaciones!),
                ),
              Text(
                '${paquete.lecturas.length} lecturas · '
                '${paquete.correcciones.length} correcciones',
                textAlign: TextAlign.center,
                style: AppDesign.titleStyle(context).copyWith(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}
