import 'dart:convert';
import 'dart:typed_data';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../oportunidades/models/opportunity_draft.dart' show newOpportunityUuid;
import '../models/rim_documento.dart';
import '../models/rim_numeracion.dart';

/// Momento en que se instaló la app en este teléfono; null si no se sabe.
typedef RimInstallTime = Future<DateTime?> Function();

/// RIM emitidos en este teléfono (`servicios_extras.db` › `form_rim`), con el
/// mismo nombre de base y de tabla que en el servidor, y los talonarios con
/// los que se numeran.
///
/// Un RIM es un registro firmado por el cliente y por el representante de
/// Métrica: se inserta una sola vez y su contenido no se vuelve a escribir.
/// Después solo cambian el estado de la subida y, si corresponde, la
/// anulación (con quién, cuándo y por qué). No hay borrado. El respaldo de la
/// app incluye esta base porque copia todas las `.db`.
///
/// Los talonarios pertenecen a la **instalación** de la app, identificada
/// por un UUID atado al momento en que se instaló (`installTime`). Si esta
/// base se copia a otro teléfono (respaldo de la app o copia de Android) o
/// se reinstala la app, la instalación cambia y los talonarios copiados no se
/// usan: así dos teléfonos nunca emiten con el mismo número, ni una
/// reinstalación reutiliza números de RIM perdidos sin subir.
class RimStore {
  static const databaseName = 'servicios_extras.db';
  static const table = 'form_rim';
  static const talonariosTable = 'rim_talonarios';
  static const solicitudesTable = 'rim_talonario_solicitudes';
  static const instalacionTable = 'rim_instalacion';

  static Future<Database>? _shared;

  final Database? _injected;
  final RimInstallTime _installTime;

  /// [database] e [installTime] solo para pruebas; la app comparte una única
  /// conexión y toma la fecha de instalación de Android.
  RimStore({Database? database, RimInstallTime? installTime})
      : _injected = database,
        _installTime = installTime ?? _packageInstallTime;

  static Future<DateTime?> _packageInstallTime() async {
    try {
      return (await PackageInfo.fromPlatform()).installTime;
    } catch (_) {
      return null;
    }
  }

  Future<Database> get _db async {
    final injected = _injected;
    if (injected != null) {
      await createTable(injected);
      return injected;
    }
    final current = await (_shared ??= _open());
    if (current.isOpen) return current;
    return _shared = _open();
  }

  static Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), databaseName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => createTable(db),
      onOpen: createTable,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        codigo_rim TEXT NOT NULL,
        service_type TEXT NOT NULL,
        service_name TEXT,
        service_session_id TEXT,
        seca TEXT,
        cod_metrica TEXT,
        cliente TEXT,
        planta TEXT,
        contacto_nombre TEXT,
        payload TEXT NOT NULL,
        firma_cliente BLOB NOT NULL,
        firma_representante BLOB,
        created_by TEXT,
        emitido_en TEXT NOT NULL,
        app_version TEXT,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        server_n INTEGER,
        sent_at TEXT,
        anulado INTEGER NOT NULL DEFAULT 0,
        anulado_por TEXT,
        anulado_en TEXT,
        motivo_anulacion TEXT,
        gestion INTEGER,
        numero INTEGER,
        talonario_id INTEGER,
        instalacion TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${table}_status ON $table (status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${table}_session '
      'ON $table (service_session_id)',
    );
    // Tablas creadas antes de la segunda firma o de la numeración.
    final columnas = {
      for (final columna in await db.rawQuery('PRAGMA table_info($table)'))
        columna['name'],
    };
    for (final (nombre, tipo) in const [
      ('firma_representante', 'BLOB'),
      ('gestion', 'INTEGER'),
      ('numero', 'INTEGER'),
      ('talonario_id', 'INTEGER'),
      ('instalacion', 'TEXT'),
    ]) {
      if (!columnas.contains(nombre)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $nombre $tipo');
      }
    }
    // Dos RIM nunca comparten número en la gestión (los de código anterior
    // no tienen número).
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_${table}_numero '
      'ON $table (gestion, numero) WHERE numero IS NOT NULL',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $instalacionTable (
        id TEXT PRIMARY KEY,
        instalado_en TEXT NOT NULL UNIQUE,
        creada_en TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $talonariosTable (
        id INTEGER PRIMARY KEY,
        instalacion TEXT NOT NULL,
        gestion INTEGER NOT NULL,
        desde INTEGER NOT NULL,
        hasta INTEGER NOT NULL,
        recibido_en TEXT NOT NULL,
        cierre_reportado_en TEXT
      )
    ''');
    // Pedido de talonario en curso: si la respuesta se pierde, se repite
    // con el mismo identificador y el servidor devuelve el mismo talonario.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $solicitudesTable (
        solicitud TEXT PRIMARY KEY,
        instalacion TEXT NOT NULL,
        gestion INTEGER NOT NULL,
        creada_en TEXT NOT NULL,
        UNIQUE (instalacion, gestion)
      )
    ''');
  }

  // ── Instalación y talonarios ───────────────────────────────────────────

  /// UUID de esta instalación de la app. Se crea la primera vez y se
  /// reconoce por el momento de la instalación: en una base copiada de otro
  /// teléfono (o de una instalación anterior) se crea otro.
  Future<String> instalacion([DatabaseExecutor? executor]) async {
    final db = executor ?? await _db;
    final instalado =
        (await _installTime())?.toUtc().toIso8601String() ?? 'desconocido';
    Future<String?> leer() async {
      final rows = await db.query(
        instalacionTable,
        columns: ['id'],
        where: 'instalado_en = ?',
        whereArgs: [instalado],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first['id'].toString();
    }

    final actual = await leer();
    if (actual != null) return actual;
    await db.insert(
      instalacionTable,
      {
        'id': newOpportunityUuid(),
        'instalado_en': instalado,
        'creada_en': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return (await leer())!;
  }

  /// Talonarios de esta instalación, del más antiguo al más reciente.
  Future<List<RimTalonario>> talonarios({int? gestion}) async {
    final db = await _db;
    final instalacion = await this.instalacion(db);
    final rows = await db.query(
      talonariosTable,
      where: 'instalacion = ?${gestion == null ? '' : ' AND gestion = ?'}',
      whereArgs: [instalacion, if (gestion != null) gestion],
      orderBy: 'gestion ASC, desde ASC',
    );
    return rows.map(RimTalonario.fromRow).toList(growable: false);
  }

  /// Último número usado en el talonario [id]; null si no se usó ninguno.
  Future<int?> ultimoUsado(int id, [DatabaseExecutor? executor]) async {
    final db = executor ?? await _db;
    final rows = await db.rawQuery(
      'SELECT MAX(numero) AS ultimo FROM $table WHERE talonario_id = ?',
      [id],
    );
    return rows.first['ultimo'] as int?;
  }

  /// Siguiente número libre de esta instalación en la [gestion], con los
  /// que le quedan; null si no tiene talonario o los agotó.
  Future<RimNumero?> proximoNumero({
    required int gestion,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    final instalacion = await this.instalacion(db);
    final rows = await db.query(
      talonariosTable,
      where: 'instalacion = ? AND gestion = ?',
      whereArgs: [instalacion, gestion],
      orderBy: 'desde ASC',
    );
    RimTalonario? talonario;
    int? numero;
    var restantes = 0;
    for (final row in rows) {
      final actual = RimTalonario.fromRow(row);
      final usado = await ultimoUsado(actual.id, db);
      final primero = usado == null ? actual.desde : usado + 1;
      if (primero > actual.hasta) continue;
      restantes += actual.hasta - primero + 1;
      if (numero == null) {
        talonario = actual;
        numero = primero;
      }
    }
    if (talonario == null || numero == null) return null;
    return RimNumero(
      talonarioId: talonario.id,
      instalacion: instalacion,
      gestion: gestion,
      numero: numero,
      restantes: restantes,
    );
  }

  /// Identificador del pedido de talonario de la [gestion]: el pendiente, si
  /// lo hay, o uno nuevo.
  Future<String> solicitudTalonario(int gestion) async {
    final db = await _db;
    final instalacion = await this.instalacion(db);
    await db.insert(
      solicitudesTable,
      {
        'solicitud': newOpportunityUuid(),
        'instalacion': instalacion,
        'gestion': gestion,
        'creada_en': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final rows = await db.query(
      solicitudesTable,
      columns: ['solicitud'],
      where: 'instalacion = ? AND gestion = ?',
      whereArgs: [instalacion, gestion],
      limit: 1,
    );
    return rows.first['solicitud'].toString();
  }

  /// Guarda el talonario que entregó el servidor y da por cumplido su
  /// pedido. Recibirlo dos veces no lo duplica.
  Future<void> guardarTalonario(
    RimTalonario talonario, {
    required String solicitud,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        talonariosTable,
        {
          'id': talonario.id,
          'instalacion': talonario.instalacion,
          'gestion': talonario.gestion,
          'desde': talonario.desde,
          'hasta': talonario.hasta,
          'recibido_en': talonario.recibidoEn.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.delete(
        solicitudesTable,
        where: 'solicitud = ?',
        whereArgs: [solicitud],
      );
    });
  }

  /// Talonarios de esta instalación de gestiones anteriores a [gestion] cuyo
  /// cierre todavía no se informó al servidor, con su último número usado.
  Future<List<({RimTalonario talonario, int? ultimoUsado})>> talonariosPorCerrar(
    int gestion,
  ) async {
    final db = await _db;
    final instalacion = await this.instalacion(db);
    final rows = await db.query(
      talonariosTable,
      where: 'instalacion = ? AND gestion < ? AND cierre_reportado_en IS NULL',
      whereArgs: [instalacion, gestion],
      orderBy: 'desde ASC',
    );
    return [
      for (final row in rows)
        (
          talonario: RimTalonario.fromRow(row),
          ultimoUsado: await ultimoUsado(row['id'] as int, db),
        ),
    ];
  }

  Future<void> marcarCierreReportado(int id) async {
    final db = await _db;
    await db.update(
      talonariosTable,
      {'cierre_reportado_en': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ? AND cierre_reportado_en IS NULL',
      whereArgs: [id],
    );
  }

  // ── RIM ────────────────────────────────────────────────────────────────

  /// Guarda un RIM recién emitido, con las dos firmas. Falla si el UUID ya
  /// existe (un RIM emitido nunca se reemplaza) o si su número ya no es el
  /// siguiente libre del talonario de esta instalación.
  Future<RimRegistro> insert(
    RimDocumento documento,
    Uint8List firmaCliente,
    Uint8List firmaRepresentante,
  ) async {
    final numeracion = documento.numeracion;
    if (numeracion == null) {
      throw RimNumeroNoDisponible(
        'El código ${documento.codigo} no tiene el formato RIM-AA-NNNN.',
      );
    }
    final db = await _db;
    await db.transaction((txn) async {
      final siguiente =
          await proximoNumero(gestion: numeracion.gestion, executor: txn);
      if (siguiente == null ||
          siguiente.numero != numeracion.numero ||
          siguiente.instalacion != documento.instalacion) {
        throw RimNumeroNoDisponible(
          siguiente == null
              ? 'Este teléfono ya no tiene números de RIM disponibles.'
              : 'El número ${documento.codigo} ya no está disponible; el '
                  'siguiente es ${siguiente.codigo}.',
        );
      }
      await txn.insert(
        table,
        {
          'uuid': documento.uuid,
          'codigo_rim': documento.codigo,
          'service_type': documento.service.serviceType.name,
          'service_name': documento.service.serviceName,
          'service_session_id': documento.service.sessionId,
          'seca': documento.service.seca,
          'cod_metrica': documento.service.metricCode,
          'cliente': documento.service.clientDisplay,
          'planta': documento.service.plantName,
          'contacto_nombre': documento.contactoNombre,
          'payload': jsonEncode(documento.toJson()),
          'firma_cliente': firmaCliente,
          'firma_representante': firmaRepresentante,
          'created_by': documento.creadoPor,
          'emitido_en': documento.emitidoEn.toUtc().toIso8601String(),
          'app_version': documento.appVersion,
          'status': RimEstadoSubida.pending.name,
          'gestion': numeracion.gestion,
          'numero': numeracion.numero,
          'talonario_id': siguiente.talonarioId,
          'instalacion': siguiente.instalacion,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
    return (await byUuid(documento.uuid))!;
  }

  Future<RimRegistro?> byUuid(String uuid) async {
    final db = await _db;
    final rows = await db.query(table, where: 'uuid = ?', whereArgs: [uuid]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Por subir primero, también los anulados (los más antiguos arriba);
  /// luego los subidos más recientes, hasta [historyLimit].
  Future<List<RimRegistro>> list({int historyLimit = 50}) async {
    final db = await _db;
    final unsent = await db.query(
      table,
      where: 'status <> ?',
      whereArgs: [RimEstadoSubida.sent.name],
      orderBy: 'emitido_en ASC',
    );
    final history = await db.query(
      table,
      where: 'status = ?',
      whereArgs: [RimEstadoSubida.sent.name],
      orderBy: 'emitido_en DESC',
      limit: historyLimit,
    );
    return [...unsent, ...history].map(_fromRow).toList(growable: false);
  }

  /// RIM por subir, anulados incluidos.
  Future<int> countUnsent() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $table WHERE status <> ?',
      [RimEstadoSubida.sent.name],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Si el servicio [sessionId] ya tiene un RIM vigente del instrumento
  /// [codMetrica], para no volver a sugerirlo.
  Future<bool> existsForService({
    required String? sessionId,
    required String? codMetrica,
  }) async {
    if (sessionId == null || sessionId.isEmpty) return false;
    final db = await _db;
    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'service_session_id = ? AND anulado = 0'
          '${codMetrica == null ? '' : ' AND cod_metrica = ?'}',
      whereArgs: [sessionId, if (codMetrica != null) codMetrica],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Marca que empezó un intento de subida. No toca lo ya subido.
  Future<void> markSending(String uuid) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE $table SET status = ?, retry_count = retry_count + 1 '
      'WHERE uuid = ? AND status <> ?',
      [RimEstadoSubida.sending.name, uuid, RimEstadoSubida.sent.name],
    );
  }

  Future<RimRegistro> markSent(String uuid, int serverN) async {
    final db = await _db;
    await db.update(
      table,
      {
        'status': RimEstadoSubida.sent.name,
        'server_n': serverN,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
        'last_error': null,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return (await byUuid(uuid))!;
  }

  Future<RimRegistro> markFailed(
    String uuid, {
    required RimEstadoSubida estado,
    required String error,
  }) async {
    assert(estado != RimEstadoSubida.sent);
    final db = await _db;
    await db.update(
      table,
      {'status': estado.name, 'last_error': error},
      where: 'uuid = ? AND status <> ?',
      whereArgs: [uuid, RimEstadoSubida.sent.name],
    );
    return (await byUuid(uuid))!;
  }

  /// Anula un RIM que todavía no se subió: queda en el teléfono, marcado,
  /// con quién lo anuló, cuándo y por qué, y se sube así. Devuelve false si
  /// ya estaba subido o anulado.
  Future<bool> anular(
    String uuid, {
    required String usuario,
    required String motivo,
  }) async {
    final db = await _db;
    final updated = await db.update(
      table,
      {
        'anulado': 1,
        'anulado_por': usuario,
        'anulado_en': DateTime.now().toUtc().toIso8601String(),
        'motivo_anulacion': motivo,
      },
      where: 'uuid = ? AND anulado = 0 AND status <> ?',
      whereArgs: [uuid, RimEstadoSubida.sent.name],
    );
    return updated > 0;
  }

  static RimRegistro _fromRow(Map<String, Object?> row) {
    DateTime? date(String column) =>
        DateTime.tryParse(row[column]?.toString() ?? '')?.toLocal();
    final payload = jsonDecode(row['payload'].toString());
    final firmaRepresentante = row['firma_representante'] as List<int>?;
    return RimRegistro(
      id: row['id'] as int,
      documento:
          RimDocumento.fromJson(Map<String, dynamic>.from(payload as Map)),
      firmaCliente: Uint8List.fromList(row['firma_cliente'] as List<int>),
      firmaRepresentante: firmaRepresentante == null
          ? null
          : Uint8List.fromList(firmaRepresentante),
      estado: RimEstadoSubida.fromName(row['status']?.toString()),
      retryCount: row['retry_count'] as int? ?? 0,
      lastError: row['last_error']?.toString(),
      serverN: row['server_n'] as int?,
      sentAt: date('sent_at'),
      anulado: (row['anulado'] as int? ?? 0) == 1,
      anuladoPor: row['anulado_por']?.toString(),
      anuladoEn: date('anulado_en'),
      motivoAnulacion: row['motivo_anulacion']?.toString(),
    );
  }
}
