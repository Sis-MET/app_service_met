import 'dart:io';

import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/precarga_bd.dart';
import 'auth_api_service.dart';
import 'auth_service.dart';
import 'database_service.dart';

typedef SetupProgress = void Function(String message, double progress);

class SetupService {
  final AuthService _authService;
  final DatabaseService _databaseService;

  SetupService({
    AuthService? authService,
    DatabaseService? databaseService,
  })  : _authService = authService ?? AuthService(),
        _databaseService = databaseService ?? DatabaseService();

  Future<SetupResult> validateConnection({required String apiUrl}) async {
    final api = AuthApiService(apiUrl);
    try {
      await api.checkHealth();
      return const SetupResult(
        success: true,
        message: 'Servidor disponible.',
      );
    } catch (error) {
      return SetupResult(success: false, message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<SetupResult> configureDevice({
    required String apiUrl,
    required String usuario,
    required String password,
    required SetupProgress onProgress,
  }) async {
    final api = AuthApiService(apiUrl);
    try {
      onProgress('Validando tu acceso...', 0.08);
      final session = await api.login(usuario: usuario, password: password);

      onProgress('Preparando el acceso offline...', 0.18);
      await _authService.enrollOnlineUser(
        user: session.user,
        password: password,
      );

      onProgress('Descargando datos de trabajo...', 0.28);
      final payload = await api.downloadBootstrap(token: session.token);
      await _installBootstrapAtomically(payload, onProgress);
      await saveConfiguration(apiUrl: apiUrl);

      return const SetupResult(
        success: true,
        message: 'El dispositivo está listo para trabajar sin conexión.',
      );
    } catch (error) {
      return SetupResult(success: false, message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<SetupResult> refreshBootstrap({
    required String apiUrl,
    required String usuario,
    required String password,
    required SetupProgress onProgress,
  }) async {
    final api = AuthApiService(apiUrl);
    try {
      onProgress('Renovando sesión...', 0.08);
      final session = await api.login(usuario: usuario, password: password);
      await _authService.enrollOnlineUser(
        user: session.user,
        password: password,
      );
      onProgress('Descargando datos actualizados...', 0.22);
      final payload = await api.downloadBootstrap(token: session.token);
      await _installBootstrapAtomically(payload, onProgress);
      await saveConfiguration(apiUrl: apiUrl);
      return const SetupResult(
        success: true,
        message: 'Datos actualizados correctamente.',
      );
    } catch (error) {
      return SetupResult(success: false, message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<void> _installBootstrapAtomically(
    Map<String, dynamic> payload,
    SetupProgress onProgress,
  ) async {
    final rawTables = payload['tables'];
    if (rawTables is! Map) {
      throw const FormatException(
          'El servidor devolvió una precarga inválida.');
    }
    final tables = Map<String, dynamic>.from(rawTables);
    final dbDirectory = await getDatabasesPath();
    final activePath = join(dbDirectory, 'precarga_database.db');
    final temporaryPath = join(dbDirectory, 'precarga_database.next.db');
    final backupPath = join(dbDirectory, 'precarga_database.previous.db');

    if (await databaseExists(temporaryPath)) {
      await deleteDatabase(temporaryPath);
    }

    Database? database;
    try {
      database = await openDatabase(
        temporaryPath,
        version: 1,
        onCreate: (db, _) => _databaseService.createPrecargaTables(db),
      );
      final entries = tables.entries.toList(growable: false);
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        final rows = (entry.value as List? ?? const [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        onProgress(
          'Guardando ${_tableLabel(entry.key)}...',
          0.32 + (0.5 * (index + 1) / entries.length),
        );
        await database.transaction((transaction) async {
          final batch = transaction.batch();
          for (final row in rows) {
            final prepared = _prepareRow(entry.key, row);
            batch.insert(
              entry.key,
              prepared,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        });
      }

      onProgress('Verificando la descarga...', 0.9);
      for (final entry in entries) {
        final expected = (entry.value as List? ?? const []).length;
        final actual = Sqflite.firstIntValue(
              await database.rawQuery('SELECT COUNT(*) FROM ${entry.key}'),
            ) ??
            0;
        if (actual != expected) {
          throw StateError(
            'La tabla ${entry.key} quedó incompleta ($actual de $expected).',
          );
        }
      }
      await database.close();
      database = null;

      onProgress('Activando los datos offline...', 0.96);
      // Imprescindible antes de renombrar: `DatabaseHelperPrecarga` cachea la
      // conexión en un campo estático. Si queda abierta, sigue apuntando al
      // archivo viejo (ya renombrado o borrado) durante el resto de la sesión,
      // y la app no ve los datos recién descargados —o falla con
      // "no such table: clientes" si ese archivo se quedó sin tablas.
      await DatabaseHelperPrecarga().close();

      final activeFile = File(activePath);
      final temporaryFile = File(temporaryPath);
      final backupFile = File(backupPath);
      if (await backupFile.exists()) await backupFile.delete();
      if (await activeFile.exists()) await activeFile.rename(backupPath);
      try {
        await temporaryFile.rename(activePath);
        if (await backupFile.exists()) await backupFile.delete();
      } catch (_) {
        if (await backupFile.exists() && !await activeFile.exists()) {
          await backupFile.rename(activePath);
        }
        rethrow;
      }
      onProgress('Datos listos para trabajar sin conexión.', 1);
    } catch (_) {
      if (database != null && database.isOpen) await database.close();
      if (await databaseExists(temporaryPath)) {
        await deleteDatabase(temporaryPath);
      }
      rethrow;
    }
  }

  Map<String, dynamic> _prepareRow(
    String table,
    Map<String, dynamic> source,
  ) {
    final normalized = {
      for (final entry in source.entries)
        entry.key.toLowerCase(): entry.value?.toString().trim() ?? '',
    };
    final allowed = <String>{
      ...?_columns[table],
      if (table == 'servicios')
        for (var index = 1; index <= 30; index++) 'rep$index',
      if (table == 'servicios')
        for (var index = 1; index <= 60; index++) 'lin$index',
    };
    if (allowed.isEmpty) {
      throw FormatException('Tabla de precarga desconocida: $table');
    }
    return {
      for (final column in allowed) column: normalized[column] ?? '',
    };
  }

  static const Map<String, Set<String>> _columns = {
    'clientes': {'codigo_cliente', 'cliente_id', 'cliente', 'razonsocial'},
    'plantas': {
      'planta',
      'planta_id',
      'cliente_id',
      'dep_id',
      'codigo_planta',
      'dep',
      'dir',
    },
    'balanzas': {
      'cod_metrica',
      'unidad',
      'n_celdas',
      'cap_max1',
      'd1',
      'e1',
      'dec1',
      'cap_max2',
      'd2',
      'e2',
      'dec2',
      'cap_max3',
      'd3',
      'e3',
      'dec3',
      'categoria',
      'tecnologia',
      'clase',
      'tipo',
      'rango',
    },
    'inf': {
      'cod_interno',
      'cod_metrica',
      'instrumento',
      'tipo_instrumento',
      'marca',
      'modelo',
      'serie',
      'estado',
      'detalles',
      'ubicacion',
    },
    'equipamientos': {
      'cod_instrumento',
      'instrumento',
      'cert_fecha',
      'ente_calibrador',
      'estado',
    },
    'servicios': {
      'cod_metrica',
      'seca',
      'reg_fecha',
      'reg_usuario',
      'exc',
    },
  };

  String _tableLabel(String value) => switch (value) {
        'clientes' => 'clientes',
        'plantas' => 'plantas',
        'balanzas' => 'balanzas',
        'inf' => 'instrumentos',
        'equipamientos' => 'equipamiento patrón',
        'servicios' => 'historial de servicios',
        _ => value,
      };

  Future<void> saveConfiguration({required String apiUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setBool('setup_completed', true);
    await prefs.setString('setup_date', now);
    await prefs.setString('lastUpdate', now);
    await prefs.setString('api_url', apiUrl);
    await prefs.remove('modoDemo');
  }

  Future<void> disconnect() async {}
}

class SetupResult {
  final bool success;
  final String message;

  const SetupResult({required this.success, required this.message});
}
