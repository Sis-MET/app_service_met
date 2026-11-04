import 'dart:convert';
import 'dart:ui' show Rect;

import '../../calibracion/utils/reading_profile.dart';

/// Código del servicio en `DATA_SERVICIOS_DATOS.tipo_servicio`.
const codigoServicioTemperatura = 'CAL.TE';

/// Estado de una calibración de temperatura en el teléfono.
enum EstadoServicioTemp {
  enCurso('en_curso'),

  /// El técnico la cerró: ya no se corrige nada y se puede subir.
  finalizado('finalizado'),

  /// Se descartó para empezar otra. No se borra ni se sube.
  abandonado('abandonado');

  const EstadoServicioTemp(this.valor);

  final String valor;

  static EstadoServicioTemp from(Object? valor) => values.firstWhere(
        (estado) => estado.valor == valor,
        orElse: () => enCurso,
      );
}

/// Qué mide un canal.
enum RolCanal {
  /// Un sensor del patrón del laboratorio: la temperatura de referencia.
  patron('patron', 'Patrón'),

  /// El indicador o controlador del equipo que se calibra.
  equipo('equipo', 'Equipo');

  const RolCanal(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static RolCanal from(Object? valor) =>
      values.firstWhere((rol) => rol.valor == valor, orElse: () => patron);
}

/// Cómo se toma la lectura de un canal.
enum MetodoCanal {
  /// La lee la cámara en cada hora programada.
  camara('camara', 'Cámara'),

  /// El técnico la escribe en cada hora programada.
  manual('manual', 'Manual'),

  /// Un sensor del patrón que va dentro del equipo y graba en el software
  /// de su registrador: la app no lo lee, solo deja anotado cuál es y dónde
  /// estaba.
  externo('externo', 'Su software');

  const MetodoCanal(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static MetodoCanal from(Object? valor) =>
      values.firstWhere((m) => m.valor == valor, orElse: () => camara);

  /// Se registra en la app (cámara o a mano).
  bool get seLee => this != externo;
}

/// Tipos de indicador del equipo; casi siempre es uno digital.
const tiposIndicador = [
  indicadorDigital,
  'Controlador digital (PID)',
  indicadorAnalogico,
];

/// El indicador por defecto.
const indicadorDigital = 'Digital';

/// Un indicador de aguja (dial): la cámara lo lee con la escala que marca el
/// técnico.
const indicadorAnalogico = 'Analógico';

bool esIndicadorAnalogico(String? indicador) =>
    indicador == indicadorAnalogico;

enum EstadoPunto {
  pendiente('pendiente', 'Pendiente'),
  enCurso('en_curso', 'En medición'),
  completo('completo', 'Completo'),

  /// Se detuvo antes de la última lectura (con motivo).
  interrumpido('interrumpido', 'Interrumpido');

  const EstadoPunto(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoPunto from(Object? valor) =>
      values.firstWhere((e) => e.valor == valor, orElse: () => pendiente);
}

/// De dónde salió el valor de una lectura.
enum OrigenLectura {
  ocrSegmentos('ocr_segmentos', 'Cámara (7 segmentos)'),
  ocrTexto('ocr_texto', 'Cámara (texto)'),

  /// La aguja de un indicador analógico, convertida con la escala que marcó
  /// el técnico.
  ocrAguja('ocr_aguja', 'Cámara (aguja)'),
  manual('manual', 'Manual'),
  sinLectura('sin_lectura', 'Sin lectura');

  const OrigenLectura(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static OrigenLectura from(Object? valor) =>
      values.firstWhere((o) => o.valor == valor, orElse: () => sinLectura);
}

enum EstadoLectura {
  valida('valida'),

  /// No hubo valor a esa hora: el motivo dice por qué.
  sinLectura('sin_lectura'),

  /// El técnico la sacó de los resultados (con motivo); el valor se
  /// conserva.
  excluida('excluida');

  const EstadoLectura(this.valor);

  final String valor;

  static EstadoLectura from(Object? valor) =>
      values.firstWhere((e) => e.valor == valor, orElse: () => valida);
}

/// Motivos de una lectura sin valor. Se guardan tal cual.
abstract final class MotivoSinLectura {
  static const noLegible = 'No se pudo leer el display';
  static const sinValor = 'El display no mostraba un valor';
  static const fueraDeEscala = 'La aguja estaba fuera de la escala marcada';
  static const segundoPlano =
      'La aplicación estaba en segundo plano o la cámara detenida';
  static const appCerrada = 'La aplicación se cerró durante la medición';
  static const manualSinIngresar = 'No se ingresó la lectura manual';
}

/// Tipos de equipo de temperatura que se calibran.
const tiposEquipoTemperatura = [
  'Mufla',
  'Horno',
  'Estufa',
  'Incubadora',
  'Baño termostático',
  'Autoclave',
  'Cámara climática',
  'Refrigerador',
  'Congelador',
  'Otro',
];

/// Cantidad de lecturas de un punto: en t = 0, i, 2i… hasta la duración.
int lecturasProgramadas(
    {required double duracionMin, required int intervaloS}) {
  if (intervaloS <= 0 || duracionMin <= 0) return 0;
  // El mismo margen que el backend: 0,7 min / 7 s son 6 intervalos aunque
  // el punto flotante dé 5,9999…
  return (duracionMin * 60 / intervaloS + 1e-9).floor() + 1;
}

/// Texto de un número sin ceros de más: 25.0 → "25", 0.10 → "0.1".
String textoNumero(double? valor, {int? decimales}) {
  if (valor == null) return '';
  if (decimales != null) return valor.toStringAsFixed(decimales);
  if (valor == valor.roundToDouble()) return valor.toInt().toString();
  return valor
      .toStringAsFixed(4)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// "2026-10-29T08:50:00-04:00" → "2026-10-29 08:50" (la hora de la planta).
String? horaLegible(String? iso) {
  final texto = iso?.trim() ?? '';
  if (texto.length < 16) return texto.isEmpty ? null : texto;
  return texto.substring(0, 16).replaceFirst('T', ' ');
}

double? numeroDe(Object? valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString().trim().replaceAll(',', '.'));
}

String? textoDe(Object? valor) {
  final texto = valor?.toString().trim() ?? '';
  return texto.isEmpty ? null : texto;
}

class TempCliente {
  const TempCliente({
    this.id,
    this.codigo,
    required this.nombre,
    this.razonSocial,
  });

  final String? id;
  final String? codigo;
  final String nombre;
  final String? razonSocial;
}

class TempPlanta {
  const TempPlanta({
    this.id,
    required this.codigo,
    required this.nombre,
    this.departamento,
    this.direccion,
  });

  final String? id;

  /// "0032-11": es el comienzo del código métrica de sus equipos.
  final String codigo;
  final String nombre;
  final String? departamento;
  final String? direccion;
}

/// El equipo que se calibra.
class TempEquipo {
  const TempEquipo({
    required this.codMetrica,
    this.nuevo = false,
    this.tipo,
    this.instrumento,
    this.marca,
    this.modelo,
    this.serie,
    this.codInterno,
    this.ubicacion,
    this.rangoMin,
    this.rangoMax,
    this.unidad = '°C',
    this.resolucion,
    this.indicador = indicadorDigital,
  });

  final String codMetrica;

  /// No está en DataMET: [codMetrica] es provisional.
  final bool nuevo;
  final String? tipo;
  final String? instrumento;
  final String? marca;
  final String? modelo;
  final String? serie;
  final String? codInterno;
  final String? ubicacion;
  final double? rangoMin;
  final double? rangoMax;
  final String unidad;

  /// Resolución del indicador del equipo: 1, 0.1…
  final double? resolucion;

  /// Digital, analógico, controlador…
  final String? indicador;

  /// El mismo equipo con el rango [min]–[max] (cualquiera puede quedar
  /// vacío).
  TempEquipo conRango(double? min, double? max) => TempEquipo(
        codMetrica: codMetrica,
        nuevo: nuevo,
        tipo: tipo,
        instrumento: instrumento,
        marca: marca,
        modelo: modelo,
        serie: serie,
        codInterno: codInterno,
        ubicacion: ubicacion,
        rangoMin: min,
        rangoMax: max,
        unidad: unidad,
        resolucion: resolucion,
        indicador: indicador,
      );

  TempEquipo copyWith({
    String? codMetrica,
    bool? nuevo,
    String? tipo,
    String? instrumento,
    String? marca,
    String? modelo,
    String? serie,
    String? codInterno,
    String? ubicacion,
    double? rangoMin,
    double? rangoMax,
    String? unidad,
    double? resolucion,
    String? indicador,
  }) =>
      TempEquipo(
        codMetrica: codMetrica ?? this.codMetrica,
        nuevo: nuevo ?? this.nuevo,
        tipo: tipo ?? this.tipo,
        instrumento: instrumento ?? this.instrumento,
        marca: marca ?? this.marca,
        modelo: modelo ?? this.modelo,
        serie: serie ?? this.serie,
        codInterno: codInterno ?? this.codInterno,
        ubicacion: ubicacion ?? this.ubicacion,
        rangoMin: rangoMin ?? this.rangoMin,
        rangoMax: rangoMax ?? this.rangoMax,
        unidad: unidad ?? this.unidad,
        resolucion: resolucion ?? this.resolucion,
        indicador: indicador ?? this.indicador,
      );
}

/// Condiciones ambientales del lugar, al empezar y al terminar.
class TempAmbiente {
  const TempAmbiente({
    this.temperaturaInicio,
    this.humedadInicio,
    this.temperaturaFin,
    this.humedadFin,
  });

  final double? temperaturaInicio;
  final double? humedadInicio;
  final double? temperaturaFin;
  final double? humedadFin;
}

/// Estado de la subida a DataMET.
enum EstadoSubidaTemp {
  pendiente('pendiente'),
  enviando('enviando'),
  subido('subido'),
  error('error');

  const EstadoSubidaTemp(this.valor);

  final String valor;

  static EstadoSubidaTemp from(Object? valor) =>
      values.firstWhere((e) => e.valor == valor, orElse: () => pendiente);
}

/// Una calibración de temperatura: un equipo dentro de una SECA.
class TempServicio {
  const TempServicio({
    required this.uuid,
    required this.sessionId,
    this.seca,
    this.estado = EstadoServicioTemp.enCurso,
    this.pasoActual = 0,
    this.personal,
    this.cliente,
    this.planta,
    this.secaConfirmada = false,
    this.equipo,
    this.equipoConfirmado = false,
    this.ambiente = const TempAmbiente(),
    this.fechaServicio,
    this.horaInicio,
    this.horaFin,
    this.observaciones,
    this.registroSensores,
    this.appVersion,
    this.createdAt,
    this.updatedAt,
    this.finalizadoEn,
    this.subida = EstadoSubidaTemp.pendiente,
    this.subidaError,
    this.serverN,
    this.subidoEn,
  });

  final String uuid;
  final String sessionId;
  final String? seca;
  final EstadoServicioTemp estado;
  final int pasoActual;

  /// Técnico de la sesión: el responsable del registro.
  final String? personal;
  final TempCliente? cliente;
  final TempPlanta? planta;
  final bool secaConfirmada;
  final TempEquipo? equipo;
  final bool equipoConfirmado;
  final TempAmbiente ambiente;

  /// AAAA-MM-DD.
  final String? fechaServicio;

  /// ISO con desfase.
  final String? horaInicio;
  final String? horaFin;
  final String? observaciones;

  /// Dónde quedaron las lecturas de los sensores del patrón: el archivo o la
  /// referencia del software del registrador.
  final String? registroSensores;
  final String? appVersion;
  final String? createdAt;
  final String? updatedAt;
  final String? finalizadoEn;
  final EstadoSubidaTemp subida;
  final String? subidaError;
  final int? serverN;
  final String? subidoEn;

  /// SECA-COD_METRICA: único en DataMET.
  String? get codigoRegistro {
    final seca = this.seca?.trim() ?? '';
    final cod = equipo?.codMetrica.trim() ?? '';
    return seca.isEmpty || cod.isEmpty ? null : '$seca-$cod';
  }

  bool get editable => estado == EstadoServicioTemp.enCurso;
  bool get finalizado => estado == EstadoServicioTemp.finalizado;
  bool get subido => subida == EstadoSubidaTemp.subido;

  TempServicio copyWith({
    String? seca,
    EstadoServicioTemp? estado,
    int? pasoActual,
    String? personal,
    TempCliente? cliente,
    bool clearCliente = false,
    TempPlanta? planta,
    bool clearPlanta = false,
    bool? secaConfirmada,
    TempEquipo? equipo,
    bool clearEquipo = false,
    bool? equipoConfirmado,
    TempAmbiente? ambiente,
    String? fechaServicio,
    String? horaInicio,
    String? horaFin,
    String? observaciones,
    String? registroSensores,
    String? appVersion,
    String? updatedAt,
    String? finalizadoEn,
    EstadoSubidaTemp? subida,
    String? subidaError,
    bool clearSubidaError = false,
    int? serverN,
    String? subidoEn,
  }) =>
      TempServicio(
        uuid: uuid,
        sessionId: sessionId,
        seca: seca ?? this.seca,
        estado: estado ?? this.estado,
        pasoActual: pasoActual ?? this.pasoActual,
        personal: personal ?? this.personal,
        cliente: clearCliente ? null : (cliente ?? this.cliente),
        planta: clearPlanta ? null : (planta ?? this.planta),
        secaConfirmada: secaConfirmada ?? this.secaConfirmada,
        equipo: clearEquipo ? null : (equipo ?? this.equipo),
        equipoConfirmado: equipoConfirmado ?? this.equipoConfirmado,
        ambiente: ambiente ?? this.ambiente,
        fechaServicio: fechaServicio ?? this.fechaServicio,
        horaInicio: horaInicio ?? this.horaInicio,
        horaFin: horaFin ?? this.horaFin,
        observaciones: observaciones ?? this.observaciones,
        registroSensores: registroSensores ?? this.registroSensores,
        appVersion: appVersion ?? this.appVersion,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        finalizadoEn: finalizadoEn ?? this.finalizadoEn,
        subida: subida ?? this.subida,
        subidaError:
            clearSubidaError ? null : (subidaError ?? this.subidaError),
        serverN: serverN ?? this.serverN,
        subidoEn: subidoEn ?? this.subidoEn,
      );

  /// Fila de `temp_servicios`.
  Map<String, Object?> toRow() => {
        'uuid': uuid,
        'session_id': sessionId,
        'seca': seca,
        'codigo_registro': codigoRegistro,
        'estado': estado.valor,
        'paso_actual': pasoActual,
        'personal': personal,
        'cliente_id': cliente?.id,
        'codigo_cliente': cliente?.codigo,
        'cliente': cliente?.nombre,
        'razon_social': cliente?.razonSocial,
        'planta_id': planta?.id,
        'cod_planta': planta?.codigo,
        'planta': planta?.nombre,
        'dep': planta?.departamento,
        'dir': planta?.direccion,
        'seca_confirmada': secaConfirmada ? 1 : 0,
        'cod_metrica': equipo?.codMetrica,
        'equipo_nuevo': (equipo?.nuevo ?? false) ? 1 : 0,
        'tipo_equipo': equipo?.tipo,
        'instrumento': equipo?.instrumento,
        'marca': equipo?.marca,
        'modelo': equipo?.modelo,
        'serie': equipo?.serie,
        'cod_interno': equipo?.codInterno,
        'ubicacion': equipo?.ubicacion,
        'rango_min': equipo?.rangoMin,
        'rango_max': equipo?.rangoMax,
        'unidad': equipo?.unidad ?? '°C',
        'resolucion': equipo?.resolucion,
        'indicador': equipo?.indicador,
        'equipo_confirmado': equipoConfirmado ? 1 : 0,
        'temp_amb_inicio': ambiente.temperaturaInicio,
        'hr_inicio': ambiente.humedadInicio,
        'temp_amb_fin': ambiente.temperaturaFin,
        'hr_fin': ambiente.humedadFin,
        'fecha_servicio': fechaServicio,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'observaciones': observaciones,
        'registro_sensores': registroSensores,
        'app_version': appVersion,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'finalizado_en': finalizadoEn,
        'subida_estado': subida.valor,
        'subida_error': subidaError,
        'server_n': serverN,
        'subido_en': subidoEn,
      };

  factory TempServicio.fromRow(Map<String, Object?> row) {
    final cliente = textoDe(row['cliente']);
    final codPlanta = textoDe(row['cod_planta']);
    final codMetrica = textoDe(row['cod_metrica']);
    return TempServicio(
      uuid: row['uuid'].toString(),
      sessionId: row['session_id']?.toString() ?? '',
      seca: textoDe(row['seca']),
      estado: EstadoServicioTemp.from(row['estado']),
      pasoActual: (row['paso_actual'] as num?)?.toInt() ?? 0,
      personal: textoDe(row['personal']),
      cliente: cliente == null
          ? null
          : TempCliente(
              id: textoDe(row['cliente_id']),
              codigo: textoDe(row['codigo_cliente']),
              nombre: cliente,
              razonSocial: textoDe(row['razon_social']),
            ),
      planta: codPlanta == null
          ? null
          : TempPlanta(
              id: textoDe(row['planta_id']),
              codigo: codPlanta,
              nombre: textoDe(row['planta']) ?? codPlanta,
              departamento: textoDe(row['dep']),
              direccion: textoDe(row['dir']),
            ),
      secaConfirmada: row['seca_confirmada'] == 1,
      equipo: codMetrica == null
          ? null
          : TempEquipo(
              codMetrica: codMetrica,
              nuevo: row['equipo_nuevo'] == 1,
              tipo: textoDe(row['tipo_equipo']),
              instrumento: textoDe(row['instrumento']),
              marca: textoDe(row['marca']),
              modelo: textoDe(row['modelo']),
              serie: textoDe(row['serie']),
              codInterno: textoDe(row['cod_interno']),
              ubicacion: textoDe(row['ubicacion']),
              rangoMin: numeroDe(row['rango_min']),
              rangoMax: numeroDe(row['rango_max']),
              unidad: textoDe(row['unidad']) ?? '°C',
              resolucion: numeroDe(row['resolucion']),
              indicador: textoDe(row['indicador']) ?? indicadorDigital,
            ),
      equipoConfirmado: row['equipo_confirmado'] == 1,
      ambiente: TempAmbiente(
        temperaturaInicio: numeroDe(row['temp_amb_inicio']),
        humedadInicio: numeroDe(row['hr_inicio']),
        temperaturaFin: numeroDe(row['temp_amb_fin']),
        humedadFin: numeroDe(row['hr_fin']),
      ),
      fechaServicio: textoDe(row['fecha_servicio']),
      horaInicio: textoDe(row['hora_inicio']),
      horaFin: textoDe(row['hora_fin']),
      observaciones: textoDe(row['observaciones']),
      registroSensores: textoDe(row['registro_sensores']),
      appVersion: textoDe(row['app_version']),
      createdAt: textoDe(row['created_at']),
      updatedAt: textoDe(row['updated_at']),
      finalizadoEn: textoDe(row['finalizado_en']),
      subida: EstadoSubidaTemp.from(row['subida_estado']),
      subidaError: textoDe(row['subida_error']),
      serverN: (row['server_n'] as num?)?.toInt(),
      subidoEn: textoDe(row['subido_en']),
    );
  }
}

/// Patrón o termohigrómetro usado en el servicio.
class TempPatron {
  const TempPatron({
    required this.codInstrumento,
    this.instrumento,
    this.certFecha,
    this.enteCalibrador,
    this.estado,
    this.uso = usoTemperatura,
  });

  static const usoTemperatura = 'temperatura';
  static const usoAmbiente = 'ambiente';

  final String codInstrumento;
  final String? instrumento;
  final String? certFecha;
  final String? enteCalibrador;
  final String? estado;
  final String uso;

  Map<String, Object?> toRow(String servicioUuid, int n) => {
        'servicio_uuid': servicioUuid,
        'n': n,
        'cod_instrumento': codInstrumento,
        'instrumento': instrumento,
        'cert_fecha': certFecha,
        'ente_calibrador': enteCalibrador,
        'estado': estado,
        'uso': uso,
      };

  factory TempPatron.fromRow(Map<String, Object?> row) => TempPatron(
        codInstrumento: row['cod_instrumento']?.toString() ?? '',
        instrumento: textoDe(row['instrumento']),
        certFecha: textoDe(row['cert_fecha']),
        enteCalibrador: textoDe(row['ente_calibrador']),
        estado: textoDe(row['estado']),
        uso: textoDe(row['uso']) ?? usoTemperatura,
      );
}

/// Un display (o un sensor) que se lee en cada hora programada.
class TempCanal {
  const TempCanal({
    required this.n,
    required this.nombre,
    required this.rol,
    this.codPatron,
    this.posicion,
    this.metodo = MetodoCanal.camara,
    this.decimales = 1,
    this.region,
    this.perfil,
  });

  /// 1, 2, 3…
  final int n;
  final String nombre;
  final RolCanal rol;

  /// Patrón al que pertenece el sensor (canales de rol patrón).
  final String? codPatron;

  /// Dónde está el sensor dentro del equipo: centro, esquina…
  final String? posicion;
  final MetodoCanal metodo;

  /// Decimales que muestra el display.
  final int decimales;

  /// Solo en el teléfono: el recuadro de la cámara y la manera de leerlo.
  final Rect? region;
  final ReadingProfile? perfil;

  TempCanal copyWith({
    int? n,
    String? nombre,
    RolCanal? rol,
    String? codPatron,
    bool clearPatron = false,
    String? posicion,
    MetodoCanal? metodo,
    int? decimales,
    Rect? region,
    ReadingProfile? perfil,
    bool clearPerfil = false,
  }) =>
      TempCanal(
        n: n ?? this.n,
        nombre: nombre ?? this.nombre,
        rol: rol ?? this.rol,
        codPatron: clearPatron ? null : (codPatron ?? this.codPatron),
        posicion: posicion ?? this.posicion,
        metodo: metodo ?? this.metodo,
        decimales: decimales ?? this.decimales,
        region: region ?? this.region,
        perfil: clearPerfil ? null : (perfil ?? this.perfil),
      );

  /// Lo que se registra del canal (sin lo que es solo de la cámara).
  bool mismaConfiguracion(TempCanal other) =>
      other.n == n &&
      other.nombre == nombre &&
      other.rol == rol &&
      other.codPatron == codPatron &&
      other.posicion == posicion &&
      other.metodo == metodo &&
      other.decimales == decimales;

  Map<String, Object?> toRow(String servicioUuid) => {
        'servicio_uuid': servicioUuid,
        'n_canal': n,
        'nombre': nombre,
        'rol': rol.valor,
        'cod_patron': codPatron,
        'posicion': posicion,
        'metodo': metodo.valor,
        'decimales': decimales,
        'region': region == null
            ? null
            : jsonEncode(
                [region!.left, region!.top, region!.right, region!.bottom]),
        'perfil': perfil == null ? null : jsonEncode(perfil!.toJson()),
      };

  factory TempCanal.fromRow(Map<String, Object?> row) {
    Rect? region;
    try {
      final values = jsonDecode(row['region']?.toString() ?? '');
      if (values is List && values.length == 4) {
        region = Rect.fromLTRB(
          (values[0] as num).toDouble(),
          (values[1] as num).toDouble(),
          (values[2] as num).toDouble(),
          (values[3] as num).toDouble(),
        );
      }
    } catch (_) {}
    ReadingProfile? perfil;
    try {
      final json = jsonDecode(row['perfil']?.toString() ?? '');
      if (json is Map) perfil = ReadingProfile.fromJson(json.cast());
    } catch (_) {}
    return TempCanal(
      n: (row['n_canal'] as num).toInt(),
      nombre: row['nombre']?.toString() ?? '',
      rol: RolCanal.from(row['rol']),
      codPatron: textoDe(row['cod_patron']),
      posicion: textoDe(row['posicion']),
      metodo: MetodoCanal.from(row['metodo']),
      decimales: (row['decimales'] as num?)?.toInt() ?? 1,
      region: region,
      perfil: perfil,
    );
  }
}

/// Un punto de calibración: una temperatura que se mantiene durante la
/// medición.
class TempPunto {
  const TempPunto({
    required this.n,
    required this.temperaturaNominal,
    this.estabilizacionMin,
    required this.duracionMin,
    required this.intervaloS,
    this.estado = EstadoPunto.pendiente,
    this.inicioMedicion,
    this.finMedicion,
    this.motivoInterrupcion,
    this.observaciones,
  });

  final int n;
  final double temperaturaNominal;

  /// Tiempo de estabilización que declaró el técnico antes de medir.
  final double? estabilizacionMin;
  final double duracionMin;
  final int intervaloS;
  final EstadoPunto estado;

  /// ISO con desfase y milisegundos: la hora de la lectura 0.
  final String? inicioMedicion;
  final String? finMedicion;
  final String? motivoInterrupcion;
  final String? observaciones;

  int get lecturas =>
      lecturasProgramadas(duracionMin: duracionMin, intervaloS: intervaloS);

  DateTime? get inicio =>
      inicioMedicion == null ? null : DateTime.tryParse(inicioMedicion!);

  TempPunto copyWith({
    int? n,
    double? temperaturaNominal,
    double? estabilizacionMin,
    double? duracionMin,
    int? intervaloS,
    EstadoPunto? estado,
    String? inicioMedicion,
    String? finMedicion,
    String? motivoInterrupcion,
    String? observaciones,
  }) =>
      TempPunto(
        n: n ?? this.n,
        temperaturaNominal: temperaturaNominal ?? this.temperaturaNominal,
        estabilizacionMin: estabilizacionMin ?? this.estabilizacionMin,
        duracionMin: duracionMin ?? this.duracionMin,
        intervaloS: intervaloS ?? this.intervaloS,
        estado: estado ?? this.estado,
        inicioMedicion: inicioMedicion ?? this.inicioMedicion,
        finMedicion: finMedicion ?? this.finMedicion,
        motivoInterrupcion: motivoInterrupcion ?? this.motivoInterrupcion,
        observaciones: observaciones ?? this.observaciones,
      );

  bool mismaConfiguracion(TempPunto other) =>
      other.n == n &&
      other.temperaturaNominal == temperaturaNominal &&
      other.estabilizacionMin == estabilizacionMin &&
      other.duracionMin == duracionMin &&
      other.intervaloS == intervaloS;

  Map<String, Object?> toRow(String servicioUuid) => {
        'servicio_uuid': servicioUuid,
        'n_punto': n,
        'temperatura_nominal': temperaturaNominal,
        'estabilizacion_min': estabilizacionMin,
        'duracion_min': duracionMin,
        'intervalo_s': intervaloS,
        'lecturas_programadas': lecturas,
        'estado': estado.valor,
        'inicio_medicion': inicioMedicion,
        'fin_medicion': finMedicion,
        'motivo_interrupcion': motivoInterrupcion,
        'observaciones': observaciones,
      };

  factory TempPunto.fromRow(Map<String, Object?> row) => TempPunto(
        n: (row['n_punto'] as num).toInt(),
        temperaturaNominal: numeroDe(row['temperatura_nominal']) ?? 0,
        estabilizacionMin: numeroDe(row['estabilizacion_min']),
        duracionMin: numeroDe(row['duracion_min']) ?? 0,
        intervaloS: (row['intervalo_s'] as num?)?.toInt() ?? 0,
        estado: EstadoPunto.from(row['estado']),
        inicioMedicion: textoDe(row['inicio_medicion']),
        finMedicion: textoDe(row['fin_medicion']),
        motivoInterrupcion: textoDe(row['motivo_interrupcion']),
        observaciones: textoDe(row['observaciones']),
      );
}

/// Una lectura de un canal en una hora programada: la observación original.
class TempLectura {
  const TempLectura({
    required this.nPunto,
    required this.nLectura,
    required this.nCanal,
    required this.tiempoProgramadoS,
    required this.capturadaEn,
    this.valor,
    this.valorOriginal,
    this.textoLeido,
    required this.origen,
    this.coincidencia,
    this.cuadros,
    this.alerta,
    this.estado = EstadoLectura.valida,
    this.motivo,
    this.imagenPath,
  });

  final int nPunto;

  /// 0 es la lectura al empezar.
  final int nLectura;
  final int nCanal;
  final int tiempoProgramadoS;

  /// Hora del teléfono al tomarla, ISO con desfase y milisegundos.
  final String capturadaEn;

  /// El valor vigente (puede venir de una corrección).
  final double? valor;

  /// El valor tal como se tomó. Nunca cambia.
  final double? valorOriginal;

  /// Lo que leyó el lector, tal cual.
  final String? textoLeido;
  final OrigenLectura origen;

  /// Parte de los cuadros de la ráfaga que coincidió (0 a 1).
  final double? coincidencia;
  final int? cuadros;

  /// Códigos de los avisos del lector, separados por coma.
  final String? alerta;
  final EstadoLectura estado;
  final String? motivo;

  /// Solo en el teléfono: la imagen del display en esa lectura.
  final String? imagenPath;

  bool get cuenta => estado == EstadoLectura.valida && valor != null;

  String get clave => '$nPunto/$nLectura/$nCanal';

  TempLectura copyWith({
    double? valor,
    bool clearValor = false,
    EstadoLectura? estado,
  }) =>
      TempLectura(
        nPunto: nPunto,
        nLectura: nLectura,
        nCanal: nCanal,
        tiempoProgramadoS: tiempoProgramadoS,
        capturadaEn: capturadaEn,
        valor: clearValor ? null : (valor ?? this.valor),
        valorOriginal: valorOriginal,
        textoLeido: textoLeido,
        origen: origen,
        coincidencia: coincidencia,
        cuadros: cuadros,
        alerta: alerta,
        estado: estado ?? this.estado,
        motivo: motivo,
        imagenPath: imagenPath,
      );

  Map<String, Object?> toRow(String servicioUuid) => {
        'servicio_uuid': servicioUuid,
        'n_punto': nPunto,
        'n_lectura': nLectura,
        'n_canal': nCanal,
        'tiempo_programado_s': tiempoProgramadoS,
        'capturada_en': capturadaEn,
        'valor': valor,
        'valor_original': valorOriginal,
        'texto_leido': textoLeido,
        'origen': origen.valor,
        'coincidencia': coincidencia,
        'cuadros': cuadros,
        'alerta': alerta,
        'estado': estado.valor,
        'motivo': motivo,
        'imagen_path': imagenPath,
      };

  factory TempLectura.fromRow(Map<String, Object?> row) => TempLectura(
        nPunto: (row['n_punto'] as num).toInt(),
        nLectura: (row['n_lectura'] as num).toInt(),
        nCanal: (row['n_canal'] as num).toInt(),
        tiempoProgramadoS: (row['tiempo_programado_s'] as num?)?.toInt() ?? 0,
        capturadaEn: row['capturada_en']?.toString() ?? '',
        valor: numeroDe(row['valor']),
        valorOriginal: numeroDe(row['valor_original']),
        textoLeido: textoDe(row['texto_leido']),
        origen: OrigenLectura.from(row['origen']),
        coincidencia: numeroDe(row['coincidencia']),
        cuadros: (row['cuadros'] as num?)?.toInt(),
        alerta: textoDe(row['alerta']),
        estado: EstadoLectura.from(row['estado']),
        motivo: textoDe(row['motivo']),
        imagenPath: textoDe(row['imagen_path']),
      );
}

enum TipoCorreccion {
  /// El valor leído estaba mal: se cambia por el que muestra la evidencia.
  correccion('correccion', 'Corrección'),

  /// La lectura no debe contar en los resultados (puerta abierta, sensor
  /// movido); su valor se conserva.
  exclusion('exclusion', 'Exclusión'),

  /// Vuelve a contar una lectura excluida.
  restitucion('restitucion', 'Restitución');

  const TipoCorreccion(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static TipoCorreccion from(Object? valor) =>
      values.firstWhere((t) => t.valor == valor, orElse: () => correccion);
}

/// Un cambio en una lectura: solo se agregan. La lectura conserva su valor
/// original y aquí queda quién la cambió, cuándo, de qué a qué y por qué.
class TempCorreccion {
  const TempCorreccion({
    required this.nPunto,
    required this.nLectura,
    required this.nCanal,
    required this.tipo,
    this.valorAnterior,
    this.valorNuevo,
    required this.motivo,
    required this.usuario,
    required this.fecha,
  });

  final int nPunto;
  final int nLectura;
  final int nCanal;
  final TipoCorreccion tipo;
  final double? valorAnterior;
  final double? valorNuevo;
  final String motivo;
  final String usuario;
  final String fecha;

  Map<String, Object?> toRow(String servicioUuid) => {
        'servicio_uuid': servicioUuid,
        'n_punto': nPunto,
        'n_lectura': nLectura,
        'n_canal': nCanal,
        'tipo': tipo.valor,
        'valor_anterior': valorAnterior,
        'valor_nuevo': valorNuevo,
        'motivo': motivo,
        'usuario': usuario,
        'fecha': fecha,
      };

  factory TempCorreccion.fromRow(Map<String, Object?> row) => TempCorreccion(
        nPunto: (row['n_punto'] as num).toInt(),
        nLectura: (row['n_lectura'] as num).toInt(),
        nCanal: (row['n_canal'] as num).toInt(),
        tipo: TipoCorreccion.from(row['tipo']),
        valorAnterior: numeroDe(row['valor_anterior']),
        valorNuevo: numeroDe(row['valor_nuevo']),
        motivo: row['motivo']?.toString() ?? '',
        usuario: row['usuario']?.toString() ?? '',
        fecha: row['fecha']?.toString() ?? '',
      );
}

/// Todo lo de una calibración: lo que se muestra, se exporta y se sube.
class TempPaquete {
  const TempPaquete({
    required this.servicio,
    this.patrones = const [],
    this.canales = const [],
    this.puntos = const [],
    this.lecturas = const [],
    this.correcciones = const [],
    this.ubicacion,
  });

  final TempServicio servicio;
  final List<TempPatron> patrones;
  final List<TempCanal> canales;
  final List<TempPunto> puntos;
  final List<TempLectura> lecturas;
  final List<TempCorreccion> correcciones;

  /// Columnas de ubicación de la fila (latitud, longitud…), si las tiene.
  final Map<String, Object?>? ubicacion;

  List<TempLectura> lecturasDe(int nPunto) =>
      lecturas.where((l) => l.nPunto == nPunto).toList();

  /// Los canales que se registran en la app (el indicador del equipo).
  List<TempCanal> get canalesLeidos =>
      canales.where((c) => c.metodo.seLee).toList();

  /// Los sensores del patrón, que graban en su propio software.
  List<TempCanal> get sensores =>
      canales.where((c) => c.rol == RolCanal.patron).toList();
}
