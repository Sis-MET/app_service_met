import 'dart:ui' show Rect;

import 'package:sqflite/sqflite.dart';

import '../../../database/app_database.dart';
import '../../../database/auditoria_registros.dart';
import '../../../services/ubicacion_servicio.dart';
import '../../../utils/fecha_iso.dart';
import '../../../utils/new_scale_code.dart';
import '../../calibracion/utils/reading_profile.dart';
import '../../oportunidades/models/opportunity_draft.dart'
    show newOpportunityUuid;
import '../models/temperatura_models.dart';

/// Un cambio que el registro ya no admite, con el motivo para el técnico.
class TemperaturaError implements Exception {
  const TemperaturaError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Las calibraciones de temperatura en el teléfono, dentro de
/// `calibracion.db` (la misma base de calibración: el respaldo la copia
/// entera).
///
/// Reglas de los registros técnicos (NB/ISO/IEC 17025 7.5):
/// * Cada lectura se inserta al tomarla y nunca se reemplaza; su valor
///   original no cambia. Una corrección o exclusión deja su fila en
///   `temp_correcciones` con el valor anterior, el nuevo, quién, cuándo y
///   por qué.
/// * Los canales y los puntos que ya tienen lecturas no se cambian.
/// * Un registro finalizado no se modifica; uno descartado tampoco. Nada se
///   borra.
class TemperaturaStore {
  TemperaturaStore({Future<Database> Function()? open})
      : _open = open ?? (() => AppDatabase().database);

  final Future<Database> Function() _open;

  static const servicios = 'temp_servicios';
  static const patrones = 'temp_patrones';
  static const canales = 'temp_canales';
  static const puntos = 'temp_puntos';
  static const lecturas = 'temp_lecturas';
  static const correcciones = 'temp_correcciones';

  static final Expando<Future<void>> _listas = Expando();

  /// Crea las tablas si faltan. Lo llama `AppDatabase` al abrir la base.
  static Future<void> crearTablas(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $servicios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        session_id TEXT NOT NULL,
        seca TEXT,
        codigo_registro TEXT,
        estado TEXT NOT NULL DEFAULT 'en_curso',
        paso_actual INTEGER NOT NULL DEFAULT 0,
        personal TEXT,
        cliente_id TEXT,
        codigo_cliente TEXT,
        cliente TEXT,
        razon_social TEXT,
        planta_id TEXT,
        cod_planta TEXT,
        planta TEXT,
        dep TEXT,
        dir TEXT,
        seca_confirmada INTEGER NOT NULL DEFAULT 0,
        cod_metrica TEXT,
        equipo_nuevo INTEGER NOT NULL DEFAULT 0,
        tipo_equipo TEXT,
        instrumento TEXT,
        marca TEXT,
        modelo TEXT,
        serie TEXT,
        cod_interno TEXT,
        ubicacion TEXT,
        rango_min REAL,
        rango_max REAL,
        unidad TEXT DEFAULT '°C',
        resolucion REAL,
        indicador TEXT,
        equipo_confirmado INTEGER NOT NULL DEFAULT 0,
        temp_amb_inicio REAL,
        hr_inicio REAL,
        temp_amb_fin REAL,
        hr_fin REAL,
        fecha_servicio TEXT,
        hora_inicio TEXT,
        hora_fin TEXT,
        observaciones TEXT,
        registro_sensores TEXT,
        app_version TEXT,
        created_at TEXT,
        updated_at TEXT,
        finalizado_en TEXT,
        subida_estado TEXT NOT NULL DEFAULT 'pendiente',
        subida_error TEXT,
        server_n INTEGER,
        subido_en TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $patrones (
        servicio_uuid TEXT NOT NULL,
        n INTEGER NOT NULL,
        cod_instrumento TEXT NOT NULL,
        instrumento TEXT,
        cert_fecha TEXT,
        ente_calibrador TEXT,
        estado TEXT,
        uso TEXT NOT NULL DEFAULT 'temperatura',
        PRIMARY KEY (servicio_uuid, n)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $canales (
        servicio_uuid TEXT NOT NULL,
        n_canal INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        rol TEXT NOT NULL,
        cod_patron TEXT,
        posicion TEXT,
        metodo TEXT NOT NULL DEFAULT 'camara',
        decimales INTEGER NOT NULL DEFAULT 1,
        region TEXT,
        perfil TEXT,
        PRIMARY KEY (servicio_uuid, n_canal)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $puntos (
        servicio_uuid TEXT NOT NULL,
        n_punto INTEGER NOT NULL,
        temperatura_nominal REAL NOT NULL,
        estabilizacion_min REAL,
        duracion_min REAL NOT NULL,
        intervalo_s INTEGER NOT NULL,
        lecturas_programadas INTEGER NOT NULL,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        inicio_medicion TEXT,
        fin_medicion TEXT,
        motivo_interrupcion TEXT,
        observaciones TEXT,
        PRIMARY KEY (servicio_uuid, n_punto)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $lecturas (
        servicio_uuid TEXT NOT NULL,
        n_punto INTEGER NOT NULL,
        n_lectura INTEGER NOT NULL,
        n_canal INTEGER NOT NULL,
        tiempo_programado_s INTEGER NOT NULL,
        capturada_en TEXT NOT NULL,
        valor REAL,
        valor_original REAL,
        texto_leido TEXT,
        origen TEXT NOT NULL,
        coincidencia REAL,
        cuadros INTEGER,
        alerta TEXT,
        estado TEXT NOT NULL DEFAULT 'valida',
        motivo TEXT,
        imagen_path TEXT,
        PRIMARY KEY (servicio_uuid, n_punto, n_lectura, n_canal)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $correcciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        servicio_uuid TEXT NOT NULL,
        n_punto INTEGER NOT NULL,
        n_lectura INTEGER NOT NULL,
        n_canal INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        valor_anterior REAL,
        valor_nuevo REAL,
        motivo TEXT NOT NULL,
        usuario TEXT NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');
    // Columnas agregadas después de crear la tabla en algunos teléfonos.
    final columnas = (await db.rawQuery('PRAGMA table_info($servicios)'))
        .map((c) => c['name']?.toString())
        .toSet();
    if (!columnas.contains('registro_sensores')) {
      await db
          .execute('ALTER TABLE $servicios ADD COLUMN registro_sensores TEXT');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_temp_servicios_estado '
        'ON $servicios (estado, personal)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_temp_servicios_seca '
        'ON $servicios (seca)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_temp_correcciones '
        'ON $correcciones (servicio_uuid)');
  }

  Future<Database> get _db async {
    final db = await _open();
    await (_listas[db] ??= () async {
      await crearTablas(db);
      await RegistroUbicacion.asegurarColumnas(db, servicios);
    }());
    return db;
  }

  // ── Servicios ─────────────────────────────────────────────────────────

  /// Una calibración nueva. Con [base] (otro equipo de la misma SECA) se
  /// copian el cliente, la planta, la SECA, los patrones, los canales y los
  /// puntos (sin medir).
  Future<TempServicio> crear({
    required String personal,
    String? appVersion,
    TempPaquete? base,
    DateTime? ahora,
  }) async {
    final now = ahora ?? DateTime.now();
    final iso = fechaIsoConDesfase(now);
    final servicio = TempServicio(
      uuid: newOpportunityUuid(),
      sessionId: _sessionId(now),
      personal: personal,
      appVersion: appVersion,
      createdAt: iso,
      updatedAt: iso,
      fechaServicio: iso.substring(0, 10),
      seca: base?.servicio.seca,
      secaConfirmada: base?.servicio.secaConfirmada ?? false,
      cliente: base?.servicio.cliente,
      planta: base?.servicio.planta,
      ambiente: TempAmbiente(
        temperaturaInicio: base?.servicio.ambiente.temperaturaInicio,
        humedadInicio: base?.servicio.ambiente.humedadInicio,
      ),
      pasoActual: base == null ? 0 : 3,
    );
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(servicios, servicio.toRow());
      if (base == null) return;
      for (var i = 0; i < base.patrones.length; i++) {
        await txn.insert(
            patrones, base.patrones[i].toRow(servicio.uuid, i + 1));
      }
      for (final canal in base.canales) {
        await txn.insert(canales, canal.toRow(servicio.uuid));
      }
      for (final punto in base.puntos) {
        await txn.insert(
          puntos,
          TempPunto(
            n: punto.n,
            temperaturaNominal: punto.temperaturaNominal,
            estabilizacionMin: punto.estabilizacionMin,
            duracionMin: punto.duracionMin,
            intervaloS: punto.intervaloS,
          ).toRow(servicio.uuid),
        );
      }
    });
    return servicio;
  }

  static String _sessionId(DateTime now) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return 'TE${now.year}${dos(now.month)}${dos(now.day)}'
        '${dos(now.hour)}${dos(now.minute)}${dos(now.second)}';
  }

  /// Guarda la cabecera de un registro en curso.
  Future<TempServicio> guardar(TempServicio servicio, {DateTime? ahora}) async {
    final db = await _db;
    final actualizado = servicio.copyWith(
      updatedAt: fechaIsoConDesfase(ahora ?? DateTime.now()),
    );
    final row = actualizado.toRow()
      ..remove('uuid')
      ..remove('created_at')
      // La subida y el cierre tienen sus propios métodos.
      ..remove('estado')
      ..remove('subida_estado')
      ..remove('subida_error')
      ..remove('server_n')
      ..remove('subido_en')
      ..remove('finalizado_en');
    final escritas = await db.update(
      servicios,
      row,
      where: 'uuid = ? AND estado = ?',
      whereArgs: [servicio.uuid, EstadoServicioTemp.enCurso.valor],
    );
    if (escritas == 0) {
      throw const TemperaturaError(
          'El registro ya está cerrado: no se puede modificar.');
    }
    return actualizado;
  }

  Future<TempServicio?> servicio(String uuid) async {
    final db = await _db;
    final rows =
        await db.query(servicios, where: 'uuid = ?', whereArgs: [uuid]);
    return rows.isEmpty ? null : TempServicio.fromRow(rows.first);
  }

  /// Los registros en curso de [personal], el último primero.
  Future<List<TempServicio>> pendientes(String personal) async {
    final db = await _db;
    final rows = await db.query(
      servicios,
      where: 'estado = ? AND personal = ?',
      whereArgs: [EstadoServicioTemp.enCurso.valor, personal],
      orderBy: 'updated_at DESC, id DESC',
    );
    return rows.map(TempServicio.fromRow).toList();
  }

  /// Todos los registros, el último primero.
  Future<List<TempServicio>> lista() async {
    final db = await _db;
    final rows = await db.query(servicios, orderBy: 'updated_at DESC, id DESC');
    return rows.map(TempServicio.fromRow).toList();
  }

  /// Si el equipo [codMetrica] ya tiene otro registro (no descartado) en la
  /// SECA [seca]: el código de registro sería el mismo.
  Future<bool> equipoYaEnSeca(
    String seca,
    String codMetrica, {
    required String exceptoUuid,
  }) async {
    final db = await _db;
    final rows = await db.query(
      servicios,
      columns: ['uuid'],
      where: 'TRIM(seca) = TRIM(?) COLLATE NOCASE '
          'AND TRIM(cod_metrica) = TRIM(?) COLLATE NOCASE '
          'AND uuid <> ? AND estado <> ?',
      whereArgs: [
        seca,
        codMetrica,
        exceptoUuid,
        EstadoServicioTemp.abandonado.valor,
      ],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Finalizados que todavía no llegaron a DataMET.
  Future<int> contarSinSubir() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $servicios WHERE estado = ? AND subida_estado <> ?',
      [EstadoServicioTemp.finalizado.valor, EstadoSubidaTemp.subido.valor],
    );
    return (result.first['n'] as num?)?.toInt() ?? 0;
  }

  /// Descarta un registro en curso para empezar otro. Queda en el teléfono.
  Future<void> abandonar(String uuid, {DateTime? ahora}) async {
    final db = await _db;
    await db.update(
      servicios,
      {
        'estado': EstadoServicioTemp.abandonado.valor,
        'updated_at': fechaIsoConDesfase(ahora ?? DateTime.now()),
      },
      where: 'uuid = ? AND estado = ?',
      whereArgs: [uuid, EstadoServicioTemp.enCurso.valor],
    );
  }

  /// Cierra el registro: desde aquí no se corrige nada. Exige un punto
  /// medido y ninguno en medición.
  Future<TempServicio> finalizar(String uuid, {DateTime? ahora}) async {
    final db = await _db;
    final now = fechaIsoConDesfase(ahora ?? DateTime.now());
    await db.transaction((txn) async {
      final estados = await txn.query(puntos,
          columns: ['estado'], where: 'servicio_uuid = ?', whereArgs: [uuid]);
      final medidos = estados.where((row) =>
          row['estado'] == EstadoPunto.completo.valor ||
          row['estado'] == EstadoPunto.interrumpido.valor);
      if (medidos.isEmpty) {
        throw const TemperaturaError('Falta medir al menos un punto.');
      }
      if (estados.any((row) => row['estado'] == EstadoPunto.enCurso.valor)) {
        throw const TemperaturaError(
            'Hay un punto en medición: termínelo o deténgalo primero.');
      }
      final escritas = await txn.rawUpdate(
        'UPDATE $servicios SET estado = ?, finalizado_en = ?, updated_at = ?, '
        'hora_fin = COALESCE(NULLIF(hora_fin, \'\'), ?) '
        'WHERE uuid = ? AND estado = ?',
        [
          EstadoServicioTemp.finalizado.valor,
          now,
          now,
          now,
          uuid,
          EstadoServicioTemp.enCurso.valor,
        ],
      );
      if (escritas == 0) {
        throw const TemperaturaError('El registro ya estaba cerrado.');
      }
    });
    return (await servicio(uuid))!;
  }

  Future<void> _exigirEnCurso(DatabaseExecutor db, String uuid) async {
    final rows = await db.query(servicios,
        columns: ['estado'], where: 'uuid = ?', whereArgs: [uuid]);
    if (rows.isEmpty) {
      throw const TemperaturaError('No se encontró el registro.');
    }
    if (rows.first['estado'] != EstadoServicioTemp.enCurso.valor) {
      throw const TemperaturaError(
          'El registro ya está cerrado: no se puede modificar.');
    }
  }

  // ── Patrones ──────────────────────────────────────────────────────────

  Future<List<TempPatron>> patronesDe(String uuid) async {
    final db = await _db;
    final rows = await db.query(patrones,
        where: 'servicio_uuid = ?', whereArgs: [uuid], orderBy: 'n');
    return rows.map(TempPatron.fromRow).toList();
  }

  /// Reemplaza los patrones del registro en curso (son parte de su
  /// configuración, como elegirlos en el formulario).
  Future<void> guardarPatrones(String uuid, List<TempPatron> lista) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _exigirEnCurso(txn, uuid);
      await txn.delete(patrones, where: 'servicio_uuid = ?', whereArgs: [uuid]);
      for (var i = 0; i < lista.length; i++) {
        await txn.insert(patrones, lista[i].toRow(uuid, i + 1));
      }
    });
  }

  // ── Canales ───────────────────────────────────────────────────────────

  Future<List<TempCanal>> canalesDe(String uuid) async {
    final db = await _db;
    final rows = await db.query(canales,
        where: 'servicio_uuid = ?', whereArgs: [uuid], orderBy: 'n_canal');
    return rows.map(TempCanal.fromRow).toList();
  }

  Future<bool> tieneLecturas(String uuid, {int? nPunto}) async {
    final db = await _db;
    final rows = await db.query(
      lecturas,
      columns: ['n_lectura'],
      where: nPunto == null
          ? 'servicio_uuid = ?'
          : 'servicio_uuid = ? AND n_punto = ?',
      whereArgs: nPunto == null ? [uuid] : [uuid, nPunto],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Reemplaza los canales. Con lecturas ya tomadas solo se aceptan los
  /// mismos canales (pueden cambiar su recuadro y su perfil del lector).
  Future<void> guardarCanales(String uuid, List<TempCanal> lista) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _exigirEnCurso(txn, uuid);
      final medidos = await txn.query(lecturas,
          columns: ['n_lectura'],
          where: 'servicio_uuid = ?',
          whereArgs: [uuid],
          limit: 1);
      if (medidos.isNotEmpty) {
        final actuales = (await txn.query(canales,
                where: 'servicio_uuid = ?',
                whereArgs: [uuid],
                orderBy: 'n_canal'))
            .map(TempCanal.fromRow)
            .toList();
        final iguales = actuales.length == lista.length &&
            [
              for (var i = 0; i < lista.length; i++)
                actuales[i].mismaConfiguracion(lista[i])
            ].every((same) => same);
        if (!iguales) {
          throw const TemperaturaError(
              'Ya hay lecturas tomadas: los canales no se pueden cambiar.');
        }
      }
      await txn.delete(canales, where: 'servicio_uuid = ?', whereArgs: [uuid]);
      for (final canal in lista) {
        await txn.insert(canales, canal.toRow(uuid));
      }
    });
  }

  /// El recuadro y el perfil con que la cámara lee un canal. Son solo del
  /// teléfono y no forman parte del registro: se guardan aunque el canal ya
  /// tenga lecturas.
  Future<void> guardarLectorCanal(
    String uuid,
    int nCanal, {
    Rect? region,
    ReadingProfile? perfil,
  }) async {
    final db = await _db;
    final canal = TempCanal(
      n: nCanal,
      nombre: '',
      rol: RolCanal.patron,
      region: region,
      perfil: perfil,
    ).toRow(uuid);
    await db.update(
      canales,
      {
        if (region != null) 'region': canal['region'],
        if (perfil != null) 'perfil': canal['perfil'],
      },
      where: 'servicio_uuid = ? AND n_canal = ?',
      whereArgs: [uuid, nCanal],
    );
  }

  // ── Puntos ────────────────────────────────────────────────────────────

  Future<List<TempPunto>> puntosDe(String uuid) async {
    final db = await _db;
    final rows = await db.query(puntos,
        where: 'servicio_uuid = ?', whereArgs: [uuid], orderBy: 'n_punto');
    return rows.map(TempPunto.fromRow).toList();
  }

  /// Reemplaza los puntos pendientes. Los que ya empezaron a medirse deben
  /// seguir en [lista] con la misma configuración.
  Future<void> guardarPuntos(String uuid, List<TempPunto> lista) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _exigirEnCurso(txn, uuid);
      final actuales = (await txn
              .query(puntos, where: 'servicio_uuid = ?', whereArgs: [uuid]))
          .map(TempPunto.fromRow)
          .toList();
      final fijos = actuales.where((p) => p.estado != EstadoPunto.pendiente);
      for (final fijo in fijos) {
        final nuevo = lista.where((p) => p.n == fijo.n).firstOrNull;
        if (nuevo == null || !nuevo.mismaConfiguracion(fijo)) {
          throw TemperaturaError(
              'El punto ${fijo.n} ya se midió: no se puede cambiar ni quitar.');
        }
      }
      await txn.delete(puntos,
          where: 'servicio_uuid = ? AND estado = ?',
          whereArgs: [uuid, EstadoPunto.pendiente.valor]);
      final numerosFijos = fijos.map((p) => p.n).toSet();
      for (final punto in lista) {
        if (numerosFijos.contains(punto.n)) continue;
        await txn.insert(
          puntos,
          punto.copyWith(estado: EstadoPunto.pendiente).toRow(uuid),
        );
      }
    });
  }

  /// Empieza la medición de un punto pendiente: [inicio] es la hora de la
  /// lectura 0.
  Future<TempPunto> iniciarPunto(
      String uuid, int nPunto, DateTime inicio) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _exigirEnCurso(txn, uuid);
      final escritas = await txn.update(
        puntos,
        {
          'estado': EstadoPunto.enCurso.valor,
          'inicio_medicion': fechaIsoConMilisegundos(inicio),
        },
        where: 'servicio_uuid = ? AND n_punto = ? AND estado = ?',
        whereArgs: [uuid, nPunto, EstadoPunto.pendiente.valor],
      );
      if (escritas == 0) {
        throw TemperaturaError('El punto $nPunto ya se empezó a medir.');
      }
    });
    return (await puntosDe(uuid)).firstWhere((p) => p.n == nPunto);
  }

  /// Termina la medición en curso: completa o interrumpida (con motivo).
  Future<void> terminarPunto(
    String uuid,
    int nPunto, {
    required EstadoPunto estado,
    required DateTime fin,
    String? motivo,
  }) async {
    assert(
        estado == EstadoPunto.completo || estado == EstadoPunto.interrumpido);
    if (estado == EstadoPunto.interrumpido &&
        (motivo == null || motivo.trim().length < 5)) {
      throw const TemperaturaError('Indique por qué se detuvo la medición.');
    }
    final db = await _db;
    await db.update(
      puntos,
      {
        'estado': estado.valor,
        'fin_medicion': fechaIsoConMilisegundos(fin),
        'motivo_interrupcion': motivo?.trim(),
      },
      where: 'servicio_uuid = ? AND n_punto = ? AND estado = ?',
      whereArgs: [uuid, nPunto, EstadoPunto.enCurso.valor],
    );
  }

  // ── Lecturas ──────────────────────────────────────────────────────────

  /// Inserta una lectura tomada ahora. Si ya había una para esa hora y ese
  /// canal no la reemplaza: devuelve false.
  Future<bool> registrarLectura(String uuid, TempLectura lectura) async {
    final db = await _db;
    return db.transaction((txn) async {
      await _exigirEnCurso(txn, uuid);
      final punto = await txn.query(puntos,
          columns: ['estado'],
          where: 'servicio_uuid = ? AND n_punto = ?',
          whereArgs: [uuid, lectura.nPunto]);
      if (punto.isEmpty || punto.first['estado'] != EstadoPunto.enCurso.valor) {
        throw TemperaturaError(
            'El punto ${lectura.nPunto} no está en medición.');
      }
      final id = await txn.insert(
        lecturas,
        lectura.toRow(uuid),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return id != 0;
    });
  }

  Future<List<TempLectura>> lecturasDe(String uuid, {int? nPunto}) async {
    final db = await _db;
    final rows = await db.query(
      lecturas,
      where: nPunto == null
          ? 'servicio_uuid = ?'
          : 'servicio_uuid = ? AND n_punto = ?',
      whereArgs: nPunto == null ? [uuid] : [uuid, nPunto],
      orderBy: 'n_punto, n_lectura, n_canal',
    );
    return rows.map(TempLectura.fromRow).toList();
  }

  /// Corrige, excluye o vuelve a contar una lectura de un registro en
  /// curso. La lectura conserva `valor_original`; el cambio queda en
  /// `temp_correcciones`.
  Future<TempLectura> corregir(
    String uuid, {
    required int nPunto,
    required int nLectura,
    required int nCanal,
    required TipoCorreccion tipo,
    double? valorNuevo,
    required String motivo,
    required String usuario,
    DateTime? ahora,
  }) async {
    final motivoLimpio = motivo.trim();
    if (motivoLimpio.length < 5) {
      throw const TemperaturaError('Escriba el motivo del cambio.');
    }
    if (usuario.trim().isEmpty) {
      throw const TemperaturaError('No hay un técnico con sesión.');
    }
    final db = await _db;
    return db.transaction((txn) async {
      await _exigirEnCurso(txn, uuid);
      const where =
          'servicio_uuid = ? AND n_punto = ? AND n_lectura = ? AND n_canal = ?';
      final args = [uuid, nPunto, nLectura, nCanal];
      final rows = await txn.query(lecturas, where: where, whereArgs: args);
      if (rows.isEmpty) {
        throw const TemperaturaError('No se encontró la lectura.');
      }
      final actual = TempLectura.fromRow(rows.first);
      final TempLectura nueva;
      switch (tipo) {
        case TipoCorreccion.correccion:
          if (valorNuevo == null) {
            throw const TemperaturaError('Escriba el valor correcto.');
          }
          if (valorNuevo == actual.valor) {
            throw const TemperaturaError('El valor es el mismo.');
          }
          nueva = actual.copyWith(
            valor: valorNuevo,
            estado: actual.estado == EstadoLectura.excluida
                ? EstadoLectura.excluida
                : EstadoLectura.valida,
          );
        case TipoCorreccion.exclusion:
          if (actual.estado != EstadoLectura.valida) {
            throw const TemperaturaError(
                'La lectura no cuenta en los resultados.');
          }
          nueva = actual.copyWith(estado: EstadoLectura.excluida);
        case TipoCorreccion.restitucion:
          if (actual.estado != EstadoLectura.excluida) {
            throw const TemperaturaError('La lectura no estaba excluida.');
          }
          nueva = actual.copyWith(estado: EstadoLectura.valida);
      }
      await txn.insert(
        correcciones,
        TempCorreccion(
          nPunto: nPunto,
          nLectura: nLectura,
          nCanal: nCanal,
          tipo: tipo,
          valorAnterior: actual.valor,
          valorNuevo:
              tipo == TipoCorreccion.correccion ? valorNuevo : actual.valor,
          motivo: motivoLimpio,
          usuario: usuario.trim(),
          fecha: fechaIsoConDesfase(ahora ?? DateTime.now()),
        ).toRow(uuid),
      );
      await txn.update(
        lecturas,
        {'valor': nueva.valor, 'estado': nueva.estado.valor},
        where: where,
        whereArgs: args,
      );
      return nueva;
    });
  }

  Future<List<TempCorreccion>> correccionesDe(String uuid) async {
    final db = await _db;
    final rows = await db.query(correcciones,
        where: 'servicio_uuid = ?', whereArgs: [uuid], orderBy: 'id');
    return rows.map(TempCorreccion.fromRow).toList();
  }

  // ── Subida y código ───────────────────────────────────────────────────

  Future<void> marcarSubida(
    String uuid,
    EstadoSubidaTemp estado, {
    String? error,
    int? serverN,
    DateTime? ahora,
  }) async {
    final db = await _db;
    await db.update(
      servicios,
      {
        'subida_estado': estado.valor,
        'subida_error': error,
        if (serverN != null) 'server_n': serverN,
        if (estado == EstadoSubidaTemp.subido)
          'subido_en': fechaIsoConDesfase(ahora ?? DateTime.now()),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// El código métrica que DataMET asignó a un equipo nuevo. Es la única
  /// corrección de un registro finalizado, y queda en el historial de
  /// cambios.
  Future<TempServicio> asignarCodigo(
    String uuid, {
    required String codigo,
    required String usuario,
    required String appVersion,
  }) async {
    final nuevo = codigo.trim().toUpperCase();
    if (nuevo.isEmpty || NewScaleCode.isProvisional(nuevo)) {
      throw const TemperaturaError('Escriba el código métrica asignado.');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final rows =
          await txn.query(servicios, where: 'uuid = ?', whereArgs: [uuid]);
      if (rows.isEmpty) {
        throw const TemperaturaError('No se encontró el registro.');
      }
      final actual = TempServicio.fromRow(rows.first);
      if (actual.subido) {
        throw const TemperaturaError('El registro ya está en DataMET.');
      }
      final anterior = actual.equipo?.codMetrica;
      if (!NewScaleCode.isProvisional(anterior)) {
        throw const TemperaturaError(
            'Solo se asigna el código de un equipo nuevo.');
      }
      final seca = actual.seca ?? '';
      await txn.update(
        servicios,
        {
          'cod_metrica': nuevo,
          'codigo_registro': seca.isEmpty ? null : '$seca-$nuevo',
          'equipo_nuevo': 0,
          'updated_at': AuditoriaRegistros.ahora(),
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      await AuditoriaRegistros.asegurarTabla(txn);
      await AuditoriaRegistros.registrar(
        txn,
        EntradaAuditoria(
          fechaHora: AuditoriaRegistros.ahora(),
          usuario: usuario,
          accion: 'MODIFICAR',
          tabla: servicios,
          registroClave: 'uuid=$uuid',
          campo: 'cod_metrica',
          valorAnterior: anterior,
          valorNuevo: nuevo,
          motivo: 'Código métrica asignado por DataMET a un equipo nuevo',
          appVersion: appVersion,
        ),
      );
    });
    return (await servicio(uuid))!;
  }

  /// Guarda la ubicación del teléfono en el registro, si todavía no tiene.
  Future<void> registrarUbicacion(String uuid) =>
      RegistroUbicacion.instance.registrar(
        abrir: () => _db,
        tabla: servicios,
        where: 'uuid = ?',
        whereArgs: [uuid],
      );

  /// Todo el registro.
  Future<TempPaquete?> paquete(String uuid) async {
    final db = await _db;
    final rows =
        await db.query(servicios, where: 'uuid = ?', whereArgs: [uuid]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return TempPaquete(
      servicio: TempServicio.fromRow(row),
      patrones: await patronesDe(uuid),
      canales: await canalesDe(uuid),
      puntos: await puntosDe(uuid),
      lecturas: await lecturasDe(uuid),
      correcciones: await correccionesDe(uuid),
      ubicacion: UbicacionServicio.deRegistro(row)?.toJson(),
    );
  }
}
