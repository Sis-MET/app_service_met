import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/fecha_iso.dart';

/// Lugar donde se realizó un servicio, tal como lo informó el GPS del
/// teléfono.
///
/// Se guarda en la fila del registro (calibración o soporte), en las columnas
/// [columnas], y al subir viaja aparte del registro técnico hacia el resumen
/// `DATA_SERVICIOS_DATOS` del servidor (ver `backend/src/location.js`).
class UbicacionServicio {
  const UbicacionServicio({
    required this.latitud,
    required this.longitud,
    this.precision,
    this.fecha,
  });

  final double latitud;
  final double longitud;

  /// Radio de precisión en metros, si el GPS lo informó.
  final double? precision;

  /// Instante del fijado GPS (no el del guardado).
  final DateTime? fecha;

  static const columnas = [
    'latitud',
    'longitud',
    'precision_gps',
    'fecha_gps',
  ];

  /// Lee la ubicación guardada en una fila, o null si no tiene una válida.
  static UbicacionServicio? deRegistro(Map<String, dynamic> fila) {
    final latitud = _numero(fila['latitud']);
    final longitud = _numero(fila['longitud']);
    if (latitud == null || longitud == null) return null;
    if (latitud < -90 || latitud > 90 || longitud < -180 || longitud > 180) {
      return null;
    }
    if (latitud == 0 && longitud == 0) return null;
    return UbicacionServicio(
      latitud: latitud,
      longitud: longitud,
      precision: _numero(fila['precision_gps']),
      fecha: DateTime.tryParse(fila['fecha_gps']?.toString() ?? ''),
    );
  }

  /// Columnas para guardar en la fila local.
  Map<String, Object?> aFila() => {
        'latitud': latitud,
        'longitud': longitud,
        'precision_gps': precision,
        'fecha_gps': fecha == null ? null : fechaIsoConDesfase(fecha!),
      };

  /// Lo que recibe el servidor junto al registro.
  Map<String, Object?> toJson() => aFila();

  /// "-16.500012, -68.150099".
  String get coordenadas =>
      '${latitud.toStringAsFixed(6)}, ${longitud.toStringAsFixed(6)}';

  static double? _numero(Object? valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString().trim().replaceAll(',', '.'));
  }
}

typedef LectorUbicacion = Future<UbicacionServicio?> Function();

/// Toma la ubicación del teléfono y la deja en la fila del servicio.
///
/// * Nunca hace fallar un guardado: sin señal (o si se revocó el permiso a
///   mitad del servicio), el servicio queda sin coordenadas.
/// * La primera ubicación guardada no se reemplaza: si el servicio se continúa
///   después en otro lugar, sigue valiendo donde empezó.
/// * No pide permisos: el servicio solo se abre con la ubicación concedida
///   (ver `RequiereUbicacion`).
class RegistroUbicacion {
  RegistroUbicacion._();

  static final RegistroUbicacion instance = RegistroUbicacion._();

  /// Las pruebas lo reemplazan; en el teléfono se usa el GPS.
  @visibleForTesting
  static LectorUbicacion? lectorOverride;

  /// Una lectura sirve para los guardados de los próximos minutos: en la
  /// misma planta no hace falta encender el GPS por cada balanza.
  static const _vigencia = Duration(minutes: 2);
  static const _esperaTrasFallo = Duration(minutes: 1);
  static const _limiteLectura = Duration(seconds: 20);

  /// Por base y tabla, la creación de columnas en curso o terminada: dos
  /// guardados seguidos comparten la misma en vez de repetir el ALTER.
  static final Expando<Map<String, Future<void>>> _columnasPorBase = Expando();

  final Set<String> _filasConUbicacion = {};
  Future<UbicacionServicio?>? _enCurso;
  UbicacionServicio? _ultima;
  DateTime? _ultimaEn;
  DateTime? _falloEn;

  /// Agrega las columnas de ubicación a [tabla] si todavía no las tiene. Si
  /// la tabla aún no existe no hace nada (se reintenta la próxima vez).
  static Future<void> asegurarColumnas(Database db, String tabla) {
    final porTabla = _columnasPorBase[db] ??= <String, Future<void>>{};
    return porTabla[tabla] ??= () async {
      try {
        if (!await _crearColumnas(db, tabla)) porTabla.remove(tabla);
      } catch (_) {
        porTabla.remove(tabla);
        rethrow;
      }
    }();
  }

  /// Devuelve false si la tabla todavía no existe.
  static Future<bool> _crearColumnas(Database db, String tabla) async {
    final info = await db.rawQuery('PRAGMA table_info($tabla)');
    if (info.isEmpty) return false;
    final existentes = info.map((c) => c['name']?.toString()).toSet();
    const tipos = {
      'latitud': 'REAL',
      'longitud': 'REAL',
      'precision_gps': 'REAL',
      'fecha_gps': 'TEXT',
    };
    for (final columna in UbicacionServicio.columnas) {
      if (existentes.contains(columna)) continue;
      try {
        await db.execute(
            'ALTER TABLE $tabla ADD COLUMN $columna ${tipos[columna]}');
      } on DatabaseException catch (error) {
        // Otra conexión al mismo archivo pudo agregarla primero.
        if (!error.isDuplicateColumnError(columna)) rethrow;
      }
    }
    return true;
  }

  /// Guarda la ubicación actual en la fila de [tabla] que cumple [where], si
  /// esa fila todavía no tiene una. Devuelve true si escribió.
  ///
  /// La base se abre con [abrir] solo si hay una ubicación que guardar.
  Future<bool> registrar({
    required Future<Database> Function() abrir,
    required String tabla,
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final clave = '$tabla|${whereArgs.join('|')}';
    if (_filasConUbicacion.contains(clave)) return false;
    try {
      final ubicacion = await leer();
      if (ubicacion == null) return false;
      final db = await abrir();
      await asegurarColumnas(db, tabla);
      final sinUbicacion = "$where AND (latitud IS NULL OR latitud = '')";
      final escritas = await db.update(
        tabla,
        ubicacion.aFila(),
        where: sinUbicacion,
        whereArgs: whereArgs,
      );
      if (escritas > 0) {
        _filasConUbicacion.add(clave);
        return true;
      }
      // Ya tenía ubicación (o la fila no existe todavía): solo se marca en el
      // primer caso, para volver a intentarlo cuando la fila exista.
      final existe = await db.query(
        tabla,
        columns: ['latitud'],
        where: where,
        whereArgs: whereArgs,
        limit: 1,
      );
      if (existe.isNotEmpty) _filasConUbicacion.add(clave);
      return false;
    } catch (error) {
      debugPrint('No se pudo registrar la ubicación en $tabla: $error');
      return false;
    }
  }

  /// La ubicación actual, o null si no se pudo obtener.
  Future<UbicacionServicio?> leer() {
    final ultima = _ultima;
    final ultimaEn = _ultimaEn;
    if (ultima != null &&
        ultimaEn != null &&
        DateTime.now().difference(ultimaEn) < _vigencia) {
      return Future.value(ultima);
    }
    final falloEn = _falloEn;
    if (falloEn != null &&
        DateTime.now().difference(falloEn) < _esperaTrasFallo) {
      return Future.value(null);
    }
    return _enCurso ??= _leerUnaVez().whenComplete(() => _enCurso = null);
  }

  Future<UbicacionServicio?> _leerUnaVez() async {
    UbicacionServicio? ubicacion;
    try {
      ubicacion = await (lectorOverride ?? _leerGps)();
    } catch (error) {
      debugPrint('Ubicación no disponible: $error');
    }
    if (ubicacion == null) {
      _falloEn = DateTime.now();
    } else {
      _ultima = ubicacion;
      _ultimaEn = DateTime.now();
      _falloEn = null;
    }
    return ubicacion;
  }

  Future<UbicacionServicio?> _leerGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    // Aquí nunca se pide el permiso: lo pide RequiereUbicacion al abrir el
    // servicio, con el aviso de la app antes de la solicitud del sistema.
    final permiso = await Geolocator.checkPermission();
    if (permiso != LocationPermission.always &&
        permiso != LocationPermission.whileInUse) {
      return null;
    }
    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _limiteLectura,
        ),
      );
      return _dePosicion(posicion);
    } on TimeoutException {
      // Bajo techo el GPS puede no fijar a tiempo: vale la última posición
      // conocida si es reciente.
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima == null ||
          DateTime.now().difference(ultima.timestamp).abs() >
              const Duration(minutes: 10)) {
        return null;
      }
      return _dePosicion(ultima);
    }
  }

  static UbicacionServicio _dePosicion(Position posicion) => UbicacionServicio(
        latitud: posicion.latitude,
        longitud: posicion.longitude,
        precision: posicion.accuracy,
        fecha: posicion.timestamp,
      );

  /// Olvida lecturas y filas recordadas (para las pruebas).
  @visibleForTesting
  void reiniciar() {
    _filasConUbicacion.clear();
    _enCurso = null;
    _ultima = null;
    _ultimaEn = null;
    _falloEn = null;
  }
}
