// Servicio de configuración inicial (setup) de la aplicación
// Gestiona la conexión al SQL Server, validación de credenciales,
// descarga de datos de precarga y persistencia de configuración.

// ignore_for_file: unused_local_variable, avoid_print

import 'dart:convert';
import 'package:mssql_connection/mssql_connection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'credential_storage.dart';

class SetupService {
  MssqlConnection? _connection;
  final DatabaseService _dbService = DatabaseService();
  final CredentialStorage _credentialStorage = CredentialStorage();

  // ── Validar conexión al servidor ──
  Future<SetupResult> validateConnection({
    required String ip,
    required String port,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      _connection = MssqlConnection.getInstance();

      final connected = await _connection!
          .connect(
            ip: ip,
            port: port,
            databaseName: database,
            username: username,
            password: password,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => false,
          );

      if (!connected) {
        return SetupResult(
          success: false,
          message: 'No se pudo conectar al servidor. Verifique los datos.',
        );
      }

      return SetupResult(
        success: true,
        message: 'Conexión validada correctamente',
      );
    } catch (e) {
      return SetupResult(
        success: false,
        message: 'Error al conectar: ${e.toString()}',
      );
    }
  }

  // ── Conectar usando configuración guardada ──
  Future<SetupResult> connectFromSavedConfiguration() async {
    try {
      final credentials = await _credentialStorage.getDatabaseCredentials();

      if (credentials == null) {
        return SetupResult(
          success: false,
          message:
              'No hay configuración guardada. Por favor reconfigure la aplicación.',
        );
      }

      return await validateConnection(
        ip: credentials['ip']!,
        port: credentials['port']!,
        database: credentials['database']!,
        username: credentials['username']!,
        password: credentials['password']!,
      );
    } catch (e) {
      return SetupResult(
        success: false,
        message: 'Error al leer configuración: ${e.toString()}',
      );
    }
  }

  // ── Validar usuario en SQL Server (CONSULTA SEGURA) ──
  Future<UserValidationResult> validateUserInServer(
    String usuario,
    String pass,
  ) async {
    if (_connection == null) {
      return UserValidationResult(
        success: false,
        message: 'No hay conexión al servidor',
      );
    }

    try {
      // Escapamos comillas simples para prevenir SQL Injection
      final safeUsuario = usuario.replaceAll("'", "''");
      final safePass = pass.replaceAll("'", "''");

      final query = '''
        SELECT nombre1, apellido1, apellido2, pass, usuario, titulo_abr, estado, acceso_app 
        FROM data_users 
        WHERE usuario = '$safeUsuario' AND pass = '$safePass'
      ''';

      final resultJson = await _connection!.getData(query).timeout(
            const Duration(seconds: 15),
          );

      if (resultJson.isEmpty || resultJson == '[]') {
        return UserValidationResult(
          success: false,
          message: 'Usuario o contraseña incorrecta',
        );
      }

      final List<dynamic> result = jsonDecode(resultJson);

      if (result.isEmpty) {
        return UserValidationResult(
          success: false,
          message: 'Usuario o contraseña incorrecta',
        );
      }

      final userData =
          UserModel.fromMap(Map<String, dynamic>.from(result.first));

      if (userData.accesoApp != '1') {
        return UserValidationResult(
          success: false,
          message:
              '[ACCESO_DENEGADO] Tu usuario no tiene permisos para acceder a la aplicación móvil. Contacta al administrador.',
        );
      }

      if (!userData.isActive) {
        return UserValidationResult(
          success: false,
          message: 'Usuario inactivo. Contacte al administrador.',
        );
      }

      return UserValidationResult(
        success: true,
        message: 'Usuario validado correctamente',
        userData: userData,
      );
    } catch (e) {
      return UserValidationResult(
        success: false,
        message: 'Error validando usuario: ${e.toString()}',
      );
    }
  }

  // ── Guardar usuario autenticado en SQLite ──
  Future<SetupResult> saveAuthenticatedUser(UserModel userData) async {
    try {
      final db = await _dbService.createUsersDatabase();

      await db.delete('usuarios');
      await db.insert('usuarios', userData.toMap());
      await db.close();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_user', userData.usuario);
      await prefs.setString('logged_user_nombre', userData.fullName);
      await prefs.setString('logged_user_titulo', userData.tituloAbr);
      await prefs.setBool('auto_login_enabled', true);

      return SetupResult(
        success: true,
        message: 'Usuario guardado exitosamente',
      );
    } catch (e) {
      return SetupResult(
        success: false,
        message: 'Error guardando usuario: ${e.toString()}',
      );
    }
  }

  // ── Descargar datos de precarga ──
  Future<SetupResult> downloadPrecargaData(
    Function(String message, double progress) onProgress,
  ) async {
    if (_connection == null) {
      return SetupResult(
        success: false,
        message: 'No hay conexión al servidor',
      );
    }

    Database? db;

    try {
      final queries = {
        'clientes':
            'SELECT codigo_cliente, cliente, cliente_id, razonsocial FROM DATA_CLIENTES',
        'plantas':
            'SELECT cliente_id, codigo_planta, planta_id, dep, dep_id, planta, dir FROM DATA_PLANTAS',
        'balanzas': 'SELECT * FROM DATA_EQUIPOS_BALANZAS',
        'inf': 'SELECT * FROM DATA_EQUIPOS',
        'equipamientos': 'SELECT * FROM DATA_EQUIPOS_CAL',
        'servicios': 'SELECT * FROM DATA_SERVICIOS_LEC',
      };

      onProgress('Preparando base de datos local...', 0.05);

      final dbPath = await getDatabasesPath();
      final precargaDbPath = join(dbPath, 'precarga_database.db');

      if (await databaseExists(precargaDbPath)) {
        await deleteDatabase(precargaDbPath);
      }

      db = await openDatabase(
        precargaDbPath,
        version: 1,
        onCreate: (db, version) async {
          await _dbService.createPrecargaTables(db);
        },
      );

      int tableIndex = 0;
      final totalTables = queries.length;
      int totalInserted = 0;
      int totalSkipped = 0;

      for (final entry in queries.entries) {
        final tableName = entry.key;
        final query = entry.value;

        onProgress('Descargando tabla: $tableName...',
            0.1 + (0.4 * tableIndex / totalTables));

        final resultJson = await _connection!.getData(query).timeout(
              const Duration(seconds: 90),
            );

        if (resultJson.isEmpty || resultJson == '[]') {
          print('[SetupService] Tabla $tableName sin datos');
          tableIndex++;
          continue;
        }

        final List<dynamic> result = jsonDecode(resultJson);
        print('[SetupService] Tabla $tableName: ${result.length} registros');

        if (result.isEmpty) {
          tableIndex++;
          continue;
        }

        onProgress('Guardando $tableName (${result.length} registros)...',
            0.5 + (0.4 * tableIndex / totalTables));

        await db.transaction((txn) async {
          final batch = txn.batch();
          int batchInserted = 0;
          int batchSkipped = 0;

          for (final item in result) {
            try {
              final itemMap = Map<String, dynamic>.from(item);
              final rowData = _prepareRowData(tableName, itemMap);

              if (rowData != null && rowData.isNotEmpty) {
                batch.insert(tableName, rowData,
                    conflictAlgorithm: ConflictAlgorithm.ignore);
                batchInserted++;
              } else {
                batchSkipped++;
              }
            } catch (e) {
              batchSkipped++;
            }
          }

          try {
            await batch.commit(noResult: true);
            totalInserted += batchInserted;
            totalSkipped += batchSkipped;
            print(
                '[SetupService] $tableName: $batchInserted insertados, $batchSkipped saltados');
          } catch (e) {
            print('[SetupService] Error en batch commit para $tableName: $e');
            rethrow;
          }
        });

        tableIndex++;
      }

      onProgress('Verificando datos guardados...', 0.95);
      await _verifyDownloadedData(db);

      await db.close();

      print('[SetupService] Total insertados: $totalInserted');
      print('[SetupService] Total saltados: $totalSkipped');

      return SetupResult(
        success: true,
        message: 'Datos de precarga descargados: $totalInserted registros',
      );
    } catch (e) {
      print('[SetupService] Error en downloadPrecargaData: $e');
      if (db != null && db.isOpen) {
        await db.close();
      }
      return SetupResult(
        success: false,
        message: 'Error descargando datos: ${e.toString()}',
      );
    }
  }

  // ── Preparar datos para inserción según la tabla ──
  Map<String, dynamic>? _prepareRowData(
      String table, Map<String, dynamic> data) {
    try {
      switch (table) {
        case 'clientes':
          return {
            'codigo_cliente': data['codigo_cliente']?.toString().trim() ?? '',
            'cliente_id': data['cliente_id']?.toString().trim() ?? '',
            'cliente': data['cliente']?.toString().trim() ?? '',
            'razonsocial': data['razonsocial']?.toString().trim() ?? '',
          };

        case 'plantas':
          return {
            'planta': data['planta']?.toString().trim() ?? '',
            'planta_id': data['planta_id']?.toString().trim() ?? '',
            'cliente_id': data['cliente_id']?.toString().trim() ?? '',
            'dep_id': data['dep_id']?.toString().trim() ?? '',
            'codigo_planta': data['codigo_planta']?.toString().trim() ?? '',
            'dep': data['dep']?.toString().trim() ?? '',
            'dir': data['dir']?.toString().trim() ?? '',
          };

        case 'balanzas':
          return {
            'cod_metrica': data['cod_metrica']?.toString().trim() ?? '',
            'unidad': data['unidad']?.toString().trim() ?? '',
            'n_celdas': data['n_celdas']?.toString().trim() ?? '',
            'cap_max1': data['cap_max1']?.toString().trim() ?? '',
            'd1': data['d1']?.toString().trim() ?? '',
            'e1': data['e1']?.toString().trim() ?? '',
            'dec1': data['dec1']?.toString().trim() ?? '',
            'cap_max2': data['cap_max2']?.toString().trim() ?? '',
            'd2': data['d2']?.toString().trim() ?? '',
            'e2': data['e2']?.toString().trim() ?? '',
            'dec2': data['dec2']?.toString().trim() ?? '',
            'cap_max3': data['cap_max3']?.toString().trim() ?? '',
            'd3': data['d3']?.toString().trim() ?? '',
            'e3': data['e3']?.toString().trim() ?? '',
            'dec3': data['dec3']?.toString().trim() ?? '',
            'categoria': data['categoria']?.toString().trim() ?? '',
            'tecnologia': data['tecnologia']?.toString().trim() ?? '',
            'clase': data['clase']?.toString().trim() ?? '',
            'tipo': data['tipo']?.toString().trim() ?? '',
            'rango': data['rango']?.toString().trim() ?? '',
          };

        case 'inf':
          return {
            'cod_interno': data['cod_interno']?.toString().trim() ?? '',
            'cod_metrica': data['cod_metrica']?.toString().trim() ?? '',
            'instrumento': data['instrumento']?.toString().trim() ?? '',
            'tipo_instrumento':
                data['tipo_instrumento']?.toString().trim() ?? '',
            'marca': data['marca']?.toString().trim() ?? '',
            'modelo': data['modelo']?.toString().trim() ?? '',
            'serie': data['serie']?.toString().trim() ?? '',
            'estado': data['estado']?.toString().trim() ?? '',
            'detalles': data['detalles']?.toString().trim() ?? '',
            'ubicacion': data['ubicacion']?.toString().trim() ?? '',
          };

        case 'equipamientos':
          return {
            'cod_instrumento': data['cod_instrumento']?.toString().trim() ?? '',
            'instrumento': data['instrumento']?.toString().trim() ?? '',
            'cert_fecha': data['cert_fecha']?.toString().trim() ?? '',
            'ente_calibrador': data['ente_calibrador']?.toString().trim() ?? '',
            'estado': data['estado']?.toString().trim() ?? '',
          };

        case 'servicios':
          final servicioData = <String, dynamic>{
            'cod_metrica': data['cod_metrica']?.toString().trim() ?? '',
            'seca': data['seca']?.toString().trim() ?? '',
            'reg_fecha': data['reg_fecha']?.toString().trim() ?? '',
            'reg_usuario': data['reg_usuario']?.toString().trim() ?? '',
            'exc': data['exc']?.toString().trim() ?? '',
          };

          for (int i = 1; i <= 30; i++) {
            final key = 'rep$i';
            servicioData[key] = data[key]?.toString().trim() ?? '';
          }
          for (int i = 1; i <= 60; i++) {
            final key = 'lin$i';
            servicioData[key] = data[key]?.toString().trim() ?? '';
          }

          return servicioData;

        default:
          return null;
      }
    } catch (e) {
      print('[SetupService] Error preparando datos para $table: $e');
      return null;
    }
  }

  // ── Verificar datos descargados ──
  Future<Map<String, int>> _verifyDownloadedData(Database db) async {
    final tables = [
      'clientes',
      'plantas',
      'balanzas',
      'inf',
      'equipamientos',
      'servicios'
    ];
    final counts = <String, int>{};

    for (final table in tables) {
      try {
        final count = Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM $table')) ??
            0;
        counts[table] = count;
      } catch (e) {
        counts[table] = 0;
      }
    }

    return counts;
  }

  // ── Guardar configuración en secure storage ──
  Future<void> saveConfiguration({
    required String ip,
    required String port,
    required String database,
    required String dbUser,
    required String dbPass,
  }) async {
    // Guardar credenciales en secure storage
    await _credentialStorage.saveDatabaseCredentials(
      ip: ip,
      port: port,
      database: database,
      dbUser: dbUser,
      dbPass: dbPass,
    );

    // Guardar metadatos en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_completed', true);
    await prefs.setString('setup_date', DateTime.now().toIso8601String());
    await prefs.setString('lastUpdate', DateTime.now().toIso8601String());
  }

  // ── Desconectar del servidor ──
  Future<void> disconnect() async {
    await _connection?.disconnect();
  }
}

// ── Resultados ──

class SetupResult {
  final bool success;
  final String message;

  SetupResult({required this.success, required this.message});
}

class UserValidationResult extends SetupResult {
  final UserModel? userData;

  UserValidationResult({
    required super.success,
    required super.message,
    this.userData,
  });
}
