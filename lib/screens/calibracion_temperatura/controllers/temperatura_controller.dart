import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../utils/fecha_iso.dart';
import '../../../utils/new_scale_code.dart';
import '../data/catalogo_temperatura.dart';
import '../data/temperatura_store.dart';
import '../models/temperatura_models.dart';

/// Los pasos de la calibración de temperatura.
abstract final class PasoTemp {
  static const cliente = 0;
  static const planta = 1;
  static const seca = 2;
  static const equipo = 3;
  static const patrones = 4;
  static const puntos = 5;
  static const medicion = 6;
  static const cierre = 7;
  static const resumen = 8;
  static const total = 9;
}

/// Estado de una calibración de temperatura en pantalla, con guardado
/// automático de la cabecera en la base local.
class TemperaturaController extends ChangeNotifier {
  TemperaturaController({
    required this.userName,
    TemperaturaStore? store,
    CatalogoTemperatura? catalogo,
    Future<String?> Function()? appVersion,
    this.autoguardado = const Duration(milliseconds: 600),
    DateTime Function()? reloj,
  })  : store = store ?? TemperaturaStore(),
        catalogo = catalogo ?? PrecargaCatalogoTemperatura(),
        _appVersion = appVersion ?? (() async => null),
        _reloj = reloj ?? DateTime.now;

  /// Técnico con sesión: el responsable del registro.
  final String userName;
  final TemperaturaStore store;
  final CatalogoTemperatura catalogo;
  final Future<String?> Function() _appVersion;
  final Duration autoguardado;
  final DateTime Function() _reloj;

  TempServicio? _servicio;
  List<TempPatron> patrones = const [];
  List<TempCanal> canales = const [];
  List<TempPunto> puntos = const [];
  List<TempLectura> lecturas = const [];
  List<TempCorreccion> correcciones = const [];
  Map<String, Object?>? ubicacion;

  bool cargando = true;
  String? errorCarga;
  bool guardando = false;
  bool pendiente = false;
  String? saveError;
  Timer? _timer;
  bool _disposed = false;

  bool get listo => _servicio != null;
  TempServicio get servicio => _servicio!;
  int get paso => _servicio?.pasoActual ?? 0;
  bool get editable => _servicio?.editable ?? false;

  /// Con lecturas tomadas, los canales ya no cambian.
  bool get canalesFijos => lecturas.isNotEmpty;

  TempPaquete get paquete => TempPaquete(
        servicio: servicio,
        patrones: patrones,
        canales: canales,
        puntos: puntos,
        lecturas: lecturas,
        correcciones: correcciones,
        ubicacion: ubicacion,
      );

  /// Abre el registro [uuid] o crea uno nuevo; con [base], uno nuevo para
  /// otro equipo de la misma SECA.
  Future<void> abrir({String? uuid, TempPaquete? base}) async {
    cargando = true;
    errorCarga = null;
    _notify();
    try {
      final id = uuid ??
          (await store.crear(
            personal: userName,
            appVersion: await _versionSegura(),
            base: base,
            ahora: _reloj(),
          ))
              .uuid;
      await _cargar(id);
    } catch (error) {
      errorCarga = 'No se pudo abrir la calibración: $error';
    } finally {
      cargando = false;
      _notify();
    }
  }

  Future<String?> _versionSegura() async {
    try {
      return await _appVersion();
    } catch (_) {
      return null;
    }
  }

  Future<void> _cargar(String uuid) async {
    final paquete = await store.paquete(uuid);
    if (paquete == null) throw StateError('no existe $uuid');
    _servicio = paquete.servicio;
    patrones = paquete.patrones;
    canales = paquete.canales;
    puntos = paquete.puntos;
    lecturas = paquete.lecturas;
    correcciones = paquete.correcciones;
    ubicacion = paquete.ubicacion;
  }

  /// Vuelve a leer todo de la base (tras una medición, una corrección…).
  Future<void> recargar() async {
    final actual = _servicio;
    if (actual == null) return;
    // Lo que se está escribiendo en pantalla manda sobre la cabecera leída.
    await guardarYa();
    await _cargar(actual.uuid);
    _notify();
  }

  // ── Guardado de la cabecera ───────────────────────────────────────────

  /// Cambia la cabecera y la guarda en unos instantes.
  void actualizar(TempServicio Function(TempServicio actual) cambio) {
    final actual = _servicio;
    if (actual == null || !actual.editable) return;
    _servicio = cambio(actual);
    pendiente = true;
    _timer?.cancel();
    _timer = Timer(autoguardado, () => guardarYa());
    _notify();
  }

  /// Escribe ya lo pendiente. Devuelve false si la base lo rechazó.
  Future<bool> guardarYa() async {
    _timer?.cancel();
    final actual = _servicio;
    if (actual == null || !pendiente || !actual.editable) return true;
    guardando = true;
    _notify();
    try {
      pendiente = false;
      final guardado = await store.guardar(actual, ahora: _reloj());
      // Si mientras tanto cambió algo, no se pisa con lo guardado.
      if (identical(_servicio, actual)) _servicio = guardado;
      saveError = null;
      return true;
    } catch (error) {
      pendiente = true;
      saveError = error is TemperaturaError
          ? error.message
          : 'No se pudo guardar en el teléfono: $error';
      return false;
    } finally {
      guardando = false;
      _notify();
    }
  }

  // ── Pasos ─────────────────────────────────────────────────────────────

  /// Si se puede abrir el paso [n] (sus anteriores lo permiten).
  bool puedeAbrir(int n) {
    final s = _servicio;
    if (s == null) return false;
    if (s.finalizado) return n == PasoTemp.resumen;
    return switch (n) {
      PasoTemp.cliente => true,
      PasoTemp.planta => s.cliente != null,
      PasoTemp.seca => s.planta != null,
      PasoTemp.equipo => s.secaConfirmada,
      PasoTemp.patrones => s.equipoConfirmado,
      PasoTemp.puntos =>
        s.equipoConfirmado && faltantes(PasoTemp.patrones).isEmpty,
      PasoTemp.medicion => puedeAbrir(PasoTemp.puntos) && puntos.isNotEmpty,
      PasoTemp.cierre => puntos.any(_medido),
      PasoTemp.resumen => s.finalizado,
      _ => false,
    };
  }

  static bool _medido(TempPunto p) =>
      p.estado == EstadoPunto.completo || p.estado == EstadoPunto.interrumpido;

  /// Lo que le falta al paso [n] para seguir.
  List<String> faltantes(int n) {
    final s = _servicio;
    if (s == null) return const ['La calibración no está abierta.'];
    final equipo = s.equipo;
    return switch (n) {
      PasoTemp.cliente => [if (s.cliente == null) 'Seleccione el cliente.'],
      PasoTemp.planta => [if (s.planta == null) 'Seleccione la planta.'],
      PasoTemp.seca => [if (!s.secaConfirmada) 'Confirme el código SECA.'],
      PasoTemp.equipo => [
          if (equipo == null) 'Seleccione el equipo o registre uno nuevo.',
          if (equipo != null && (equipo.tipo ?? '').isEmpty)
            'Indique el tipo de equipo.',
          if (equipo != null &&
              (equipo.rangoMin == null || equipo.rangoMax == null))
            'Indique el rango de trabajo del equipo.',
          if (equipo != null &&
              equipo.rangoMin != null &&
              equipo.rangoMax != null &&
              equipo.rangoMin! >= equipo.rangoMax!)
            'El rango mínimo debe ser menor que el máximo.',
          if (equipo != null && (equipo.resolucion ?? 0) <= 0)
            'Indique la resolución del indicador del equipo.',
        ],
      PasoTemp.patrones => [
          if (!patrones.any((p) => p.uso == TempPatron.usoTemperatura))
            'Seleccione al menos un patrón de temperatura.',
          if (!canales.any((c) => c.rol == RolCanal.patron))
            'Agregue los sensores del patrón que van dentro del equipo.',
          if (!canales.any((c) => c.rol == RolCanal.equipo))
            'Falta el indicador del equipo.',
          if (s.ambiente.temperaturaInicio == null ||
              s.ambiente.humedadInicio == null)
            'Registre la temperatura y la humedad ambiente iniciales.',
        ],
      PasoTemp.puntos => [
          if (puntos.isEmpty) 'Agregue al menos un punto de calibración.',
        ],
      PasoTemp.medicion => [
          if (!puntos.any(_medido)) 'Mida al menos un punto.',
          if (puntos.any((p) => p.estado == EstadoPunto.enCurso))
            'Hay un punto en medición: termínelo o deténgalo.',
        ],
      PasoTemp.cierre => [
          if (s.ambiente.temperaturaFin == null ||
              s.ambiente.humedadFin == null)
            'Registre la temperatura y la humedad ambiente finales.',
        ],
      _ => const [],
    };
  }

  Future<void> irA(int n) async {
    if (!puedeAbrir(n) && !(servicio.finalizado && n == PasoTemp.resumen)) {
      return;
    }
    if (servicio.editable) {
      actualizar((s) => s.copyWith(pasoActual: n));
      await guardarYa();
    } else {
      _notify();
    }
  }

  // ── Cliente, planta y SECA ────────────────────────────────────────────

  bool get clienteFijo => _servicio?.secaConfirmada ?? false;

  void elegirCliente(Map<String, dynamic> row) {
    if (clienteFijo) return;
    actualizar((s) => TempServicio(
          uuid: s.uuid,
          sessionId: s.sessionId,
          personal: s.personal,
          appVersion: s.appVersion,
          createdAt: s.createdAt,
          updatedAt: s.updatedAt,
          fechaServicio: s.fechaServicio,
          ambiente: s.ambiente,
          pasoActual: s.pasoActual,
          cliente: TempCliente(
            id: textoDe(row['cliente_id']),
            codigo: textoDe(row['codigo_cliente']),
            nombre: textoDe(row['cliente']) ?? '',
            razonSocial: textoDe(row['razonsocial']),
          ),
        ));
  }

  Future<List<Map<String, dynamic>>> plantas() async {
    final id = _servicio?.cliente?.id;
    if (id == null) return const [];
    return catalogo.plantasDe(id);
  }

  void elegirPlanta(Map<String, dynamic> row) {
    if (clienteFijo) return;
    final codigo = textoDe(row['codigo_planta']);
    if (codigo == null) return;
    actualizar((s) => s.copyWith(
          planta: TempPlanta(
            id: textoDe(row['planta_id']),
            codigo: codigo,
            nombre: textoDe(row['planta']) ?? codigo,
            departamento: textoDe(row['dep']),
            direccion: textoDe(row['dir']),
          ),
          clearEquipo: true,
        ));
  }

  /// "0032-11-C01-26": planta, cotización y gestión, como en balanzas.
  String secaPropuesta(String cotizacion) {
    final planta = _servicio?.planta?.codigo ?? 'NNNN-NN';
    final cot =
        cotizacion.trim().isEmpty ? 'C01' : cotizacion.trim().toUpperCase();
    final gestion = _reloj().year.toString().substring(2);
    return '$planta-$cot-$gestion';
  }

  Future<String?> confirmarSeca(String seca) async {
    final valor = seca.trim().toUpperCase();
    if (_servicio?.planta == null) return 'Seleccione la planta.';
    if (!RegExp(r'^\d{4}-\d{2}-[A-Z0-9]{1,6}-\d{2}$').hasMatch(valor)) {
      return 'El SECA debe tener la forma PLANTA-COTIZACIÓN-AÑO (0032-11-C01-26).';
    }
    final ahora = _reloj();
    actualizar((s) => s.copyWith(
          seca: valor,
          secaConfirmada: true,
          horaInicio: s.horaInicio ?? fechaIsoConDesfase(ahora),
          fechaServicio: fechaIsoConDesfase(ahora).substring(0, 10),
        ));
    if (!await guardarYa()) return saveError;
    // La ubicación nunca hace fallar el paso.
    unawaited(store.registrarUbicacion(servicio.uuid).then((_) async {
      if (_disposed) return;
      final paquete = await store.paquete(servicio.uuid);
      ubicacion = paquete?.ubicacion;
      _notify();
    }).catchError((_) {}));
    return null;
  }

  /// El código del QR del equipo ("0032-11-090 Mufla…"): elige cliente,
  /// planta y, si está en la precarga, el equipo.
  Future<String?> aplicarQr(String raw) async {
    final partes = raw.trim().split(RegExp(r'\s+')).first.split('-');
    if (partes.length < 3) return 'El código QR no es de un equipo: $raw';
    final numero = RegExp(r'^\d+').stringMatch(partes[2]) ?? '';
    if (numero.isEmpty) return 'El código QR no es de un equipo: $raw';
    final codPlanta = '${partes[0]}-${partes[1]}';
    final codMetrica = '$codPlanta-$numero';
    if (clienteFijo && _servicio?.planta?.codigo != codPlanta) {
      return 'El equipo $codMetrica es de otra planta que la de esta SECA.';
    }
    if (!clienteFijo) {
      final cliente = await catalogo.clientePorCodigo(partes[0]);
      if (cliente == null) {
        return 'No se encontró el cliente ${partes[0]} en la precarga.';
      }
      elegirCliente(cliente);
      final planta = (await plantas())
          .where((p) => p['codigo_planta']?.toString().trim() == codPlanta)
          .firstOrNull;
      if (planta == null) {
        return 'No se encontró la planta $codPlanta en la precarga.';
      }
      elegirPlanta(planta);
    }
    final equipo = await catalogo.equipoPorCodigo(codMetrica);
    if (equipo != null && !(servicio.equipoConfirmado)) {
      elegirEquipo(FiltrosTemperatura.equipoDe(equipo));
    }
    await guardarYa();
    return null;
  }

  // ── Equipo ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> equiposPlanta() async {
    final codigo = _servicio?.planta?.codigo;
    if (codigo == null) return const [];
    return catalogo.equiposDe(codigo);
  }

  void elegirEquipo(TempEquipo equipo) {
    if (_servicio?.equipoConfirmado ?? true) return;
    actualizar((s) => s.copyWith(equipo: equipo));
  }

  /// Cambia el tipo de indicador; si el indicador ya existe y todavía no
  /// hay lecturas, ajusta cómo se toma.
  Future<void> elegirIndicador(String indicador) async {
    final equipo = _servicio?.equipo;
    // Es un dato del equipo: queda fijo al confirmarlo.
    if (equipo == null || !editable || servicio.equipoConfirmado) return;
    actualizar(
        (s) => s.copyWith(equipo: equipo.copyWith(indicador: indicador)));
    if (!canalesFijos && canales.any((c) => c.rol == RolCanal.equipo)) {
      await metodoIndicador(metodoDeIndicador(indicador));
    }
  }

  /// Un equipo que todavía no está en DataMET, con código provisional.
  void equipoNuevo() {
    final s = _servicio;
    if (s == null || s.equipoConfirmado) return;
    elegirEquipo(TempEquipo(
      codMetrica: NewScaleCode.generate(
        clientCode: s.cliente?.codigo,
        plantCode: s.planta?.codigo,
        now: _reloj(),
      ),
      nuevo: true,
    ));
  }

  void editarEquipo(TempEquipo Function(TempEquipo actual) cambio) {
    final equipo = _servicio?.equipo;
    if (equipo == null || servicio.equipoConfirmado) return;
    actualizar((s) => s.copyWith(equipo: cambio(equipo)));
  }

  Future<String?> confirmarEquipo() async {
    final faltan = faltantes(PasoTemp.equipo);
    if (faltan.isNotEmpty) return faltan.first;
    final s = servicio;
    if (await store.equipoYaEnSeca(s.seca!, s.equipo!.codMetrica,
        exceptoUuid: s.uuid)) {
      return 'El equipo ${s.equipo!.codMetrica} ya tiene una calibración en '
          'la SECA ${s.seca}.';
    }
    actualizar((s) => s.copyWith(equipoConfirmado: true));
    return await guardarYa() ? null : saveError;
  }

  // ── Patrones, canales y puntos ────────────────────────────────────────

  Future<String?> _escribir(Future<void> Function() escritura) async {
    try {
      await guardarYa();
      await escritura();
      await _cargar(servicio.uuid);
      _notify();
      return null;
    } on TemperaturaError catch (error) {
      return error.message;
    } catch (error) {
      return 'No se pudo guardar en el teléfono: $error';
    }
  }

  Future<String?> guardarPatrones(List<TempPatron> lista) =>
      _escribir(() => store.guardarPatrones(servicio.uuid, lista));

  Future<String?> guardarCanales(List<TempCanal> lista) {
    final numerados = [
      for (var i = 0; i < lista.length; i++) lista[i].copyWith(n: i + 1),
    ];
    return _escribir(() => store.guardarCanales(servicio.uuid, numerados));
  }

  Future<String?> guardarPuntos(List<TempPunto> lista) =>
      _escribir(() => store.guardarPuntos(servicio.uuid, lista));

  /// Los canales que se leen al empezar: el patrón al centro y el
  /// indicador del equipo.
  /// El indicador del equipo: lo único que se registra en la app, con la
  /// cámara si es digital o a mano si es analógico.
  TempCanal indicadorPorDefecto() {
    final equipo = _servicio?.equipo;
    return TempCanal(
      n: 1,
      nombre: 'Indicador del equipo',
      rol: RolCanal.equipo,
      metodo: metodoDeIndicador(equipo?.indicador),
      decimales: _decimales(equipo?.resolucion) ?? 0,
    );
  }

  /// Los canales al entrar a Patrones: el indicador si todavía no está.
  List<TempCanal> canalesPorDefecto() => [
        indicadorPorDefecto(),
        ...canales.where((c) => c.rol == RolCanal.patron),
      ];

  /// Crea el indicador del equipo si falta (al abrir Patrones y sensores).
  Future<void> asegurarIndicador() async {
    if (!editable || canalesFijos) return;
    if (canales.any((c) => c.rol == RolCanal.equipo)) return;
    await guardarCanales(canalesPorDefecto());
  }

  /// Un sensor del patrón nuevo: T1, T2… al centro si es el primero.
  TempCanal sensorNuevo() {
    final sensores = canales.where((c) => c.rol == RolCanal.patron).length;
    final patron =
        patrones.where((p) => p.uso == TempPatron.usoTemperatura).firstOrNull;
    return TempCanal(
      n: canales.length + 1,
      nombre: 'T${sensores + 1}',
      rol: RolCanal.patron,
      codPatron: patron?.codInstrumento,
      posicion: sensores == 0 ? 'Centro' : null,
      metodo: MetodoCanal.externo,
    );
  }

  /// Agrega, cambia o quita un sensor (los sensores no se leen en la app).
  Future<String?> guardarSensor(TempCanal sensor, {bool quitar = false}) {
    final lista = [...canales];
    final indice = lista.indexWhere((c) => c.n == sensor.n);
    if (quitar) {
      if (indice >= 0) lista.removeAt(indice);
    } else {
      final limpio = sensor.copyWith(metodo: MetodoCanal.externo);
      if (indice >= 0) {
        lista[indice] = limpio;
      } else {
        lista.add(limpio);
      }
    }
    // El indicador primero; después los sensores.
    lista.sort((a, b) => a.rol == b.rol
        ? a.n.compareTo(b.n)
        : (a.rol == RolCanal.equipo ? -1 : 1));
    return guardarCanales(lista);
  }

  /// Cambia cómo se toma el indicador (cámara o a mano).
  Future<String?> metodoIndicador(MetodoCanal metodo) {
    final lista = [
      for (final c in canales)
        c.rol == RolCanal.equipo ? c.copyWith(metodo: metodo) : c,
    ];
    return guardarCanales(lista);
  }

  static int? _decimales(double? resolucion) {
    if (resolucion == null || resolucion <= 0) return null;
    final texto = textoNumero(resolucion);
    return texto.contains('.') ? texto.split('.').last.length : 0;
  }

  // ── Medición ──────────────────────────────────────────────────────────

  Future<String?> iniciarPunto(int n) =>
      _escribir(() => store.iniciarPunto(servicio.uuid, n, _reloj()));

  Future<String?> detenerPunto(int n, String motivo) =>
      _escribir(() => store.terminarPunto(servicio.uuid, n,
          estado: EstadoPunto.interrumpido, fin: _reloj(), motivo: motivo));

  Future<String?> completarPunto(int n) =>
      _escribir(() => store.terminarPunto(servicio.uuid, n,
          estado: EstadoPunto.completo, fin: _reloj()));

  Future<String?> corregir(
    TempLectura lectura, {
    required TipoCorreccion tipo,
    double? valorNuevo,
    required String motivo,
  }) =>
      _escribir(() => store.corregir(
            servicio.uuid,
            nPunto: lectura.nPunto,
            nLectura: lectura.nLectura,
            nCanal: lectura.nCanal,
            tipo: tipo,
            valorNuevo: valorNuevo,
            motivo: motivo,
            usuario: userName,
            ahora: _reloj(),
          ));

  // ── Cierre ────────────────────────────────────────────────────────────

  Future<String?> finalizar() async {
    final faltan = [
      ...faltantes(PasoTemp.medicion),
      ...faltantes(PasoTemp.cierre),
    ];
    if (faltan.isNotEmpty) return faltan.first;
    actualizar((s) => s.copyWith(
          horaFin: s.horaFin ?? fechaIsoConDesfase(_reloj()),
          pasoActual: PasoTemp.resumen,
        ));
    if (!await guardarYa()) return saveError;
    return _escribir(() => store.finalizar(servicio.uuid, ahora: _reloj()));
  }

  /// Abre un registro nuevo para otro equipo de la misma SECA.
  Future<String?> otroEquipo() async {
    final base = paquete;
    try {
      await abrir(base: base);
      return errorCarga;
    } catch (error) {
      return 'No se pudo crear el registro: $error';
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    // Lo pendiente se escribe igual al cerrar la pantalla.
    if (pendiente && _servicio != null && _servicio!.editable) {
      unawaited(store.guardar(_servicio!).catchError((_) => _servicio!));
    }
    super.dispose();
  }
}
