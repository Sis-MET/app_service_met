// Servicio de autenticación de usuarios
// Gestiona login local (SQLite) y remoto (SQL Server),
// validación de credenciales, y persistencia de sesión.

// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:convert';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:mssql_connection/mssql_connection.dart';
import '../models/user_model.dart';
import 'credential_storage.dart';

class AuthService {
  MssqlConnection? _connection;
  final CredentialStorage _credentialStorage = CredentialStorage();

  // ── Helper: Abrir BD de usuarios con migración automática ──
  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'usuarios.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
            CREATE TABLE usuarios (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre1 TEXT,
              apellido1 TEXT,
              apellido2 TEXT,
              pass TEXT,
              usuario TEXT UNIQUE,
              titulo_abr TEXT,
              estado TEXT,
              acceso_app TEXT,
              fecha_guardado TEXT
            )
          ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {},
      onOpen: (db) async {
        try {
          final columns = await db.rawQuery('PRAGMA table_info(usuarios)');
          final hasColumn = columns.any((c) => c['name'] == 'acceso_app');

          if (!hasColumn) {
            print('[AuthService] Recreando tabla usuarios por esquema incorrecto...');
            await db.execute('DROP TABLE IF EXISTS usuarios');
            await db.execute('''
              CREATE TABLE usuarios (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre1 TEXT,
                apellido1 TEXT,
                apellido2 TEXT,
                pass TEXT,
                usuario TEXT UNIQUE,
                titulo_abr TEXT,
                estado TEXT,
                acceso_app TEXT,
                fecha_guardado TEXT
              )
            ''');
            print('[AuthService] Tabla usuarios recreada correctamente');
          }

          await db.execute(
              "UPDATE usuarios SET acceso_app = '0' WHERE acceso_app IS NULL OR acceso_app = ''");
        } catch (e) {
          print('[AuthService] Error en auto-reparación BD: $e');
        }
      },
    );
  }

  // ── Verificar si un usuario existe en BD local ──
  Future<bool> userExists(String usuario) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'usuarios.db');

      final dbExists = await databaseExists(path);
      if (!dbExists) return false;

      final db = await _openDb();
      final results = await db.query(
        'usuarios',
        where: 'usuario = ?',
        whereArgs: [usuario],
        limit: 1,
      );
      await db.close();
      return results.isNotEmpty;
    } catch (e) {
      print('[AuthService] Error verificando usuario: $e');
      return false;
    }
  }

  // ── Obtener credenciales desde secure storage (con fallback) ──
  Future<Map<String, String>?> _getConnectionCredentials() async {
    return await _credentialStorage.getDatabaseCredentials();
  }

  // ── Conectar al SQL Server ──
  Future<bool> _connectToServer() async {
    final credentials = await _getConnectionCredentials();
    if (credentials == null) return false;

    try {
      _connection = MssqlConnection.getInstance();

      final connected = await _connection!
          .connect(
            ip: credentials['ip']!,
            port: credentials['port']!,
            databaseName: credentials['database']!,
            username: credentials['username']!,
            password: credentials['password']!,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => false,
          );

      return connected;
    } catch (e) {
      print('[AuthService] Error conectando al servidor: $e');
      return false;
    }
  }

  // ── Validar usuario en SQL Server (CONSULTA SEGURA parametrizada) ──
  Future<UserValidationResult> _validateUserInServer(
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
      // Construcción segura: escapamos caracteres problematicos manualmente
      // ya que mssql_connection no soporta parámetros nativos.
      // Escapamos comillas simples duplicándolas (SQL standard).
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

      return _processServerUserResult(resultJson);
    } catch (e) {
      return UserValidationResult(
        success: false,
        message: 'Error validando usuario: ${e.toString()}',
      );
    }
  }

  // ── Interpretar respuesta JSON del servidor ──
  UserValidationResult _processServerUserResult(String resultJson) {
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

    final userData = UserModel.fromMap(Map<String, dynamic>.from(result.first));

    // Validar acceso a la app (campo acceso_app debe ser '1')
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
  }

  // ── Guardar usuario en SQLite ──
  Future<bool> saveUserToDatabase(UserModel userData) async {
    try {
      final db = await _openDb();

      await db.insert(
        'usuarios',
        userData.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.close();
      return true;
    } catch (e) {
      print('[AuthService] Error guardando usuario: $e');
      return false;
    }
  }

  // ── Obtener lista de usuarios guardados ──
  Future<List<UserModel>> getSavedUsers() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'usuarios.db');

      final dbExists = await databaseExists(path);
      if (!dbExists) return [];

      final db = await _openDb();
      final results =
          await db.query('usuarios', orderBy: 'fecha_guardado DESC');
      await db.close();

      return results.map((map) => UserModel.fromMap(map)).toList();
    } catch (e) {
      print('[AuthService] Error obteniendo usuarios: $e');
      return [];
    }
  }

  // ── Cargar preferencias de sesión ──
  Future<Map<String, dynamic>> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'savedUser': prefs.getString('logged_user'),
      'savedUserFullName': prefs.getString('logged_user_nombre'),
      'autoLoginEnabled': prefs.getBool('auto_login_enabled') ?? false,
      'isFirstLogin': prefs.getBool('is_first_login') ?? true,
    };
  }

  // ── Obtener usuario guardado ──
  Future<String?> _getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_user');
  }

  // ── Persistir usuario activo ──
  Future<void> _saveLoggedUser(UserModel userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_user', userData.usuario);
    await prefs.setString('logged_user_nombre', userData.fullName);
    await prefs.setString('logged_user_titulo', userData.tituloAbr);
  }

  // ── Login con validación local + remota ──
  Future<LoginResult> login({
    String? usuario,
    required String password,
    bool isChangingUser = false,
  }) async {
    final user = usuario ?? await _getSavedUser();

    if (user == null || user.isEmpty) {
      return LoginResult(success: false, message: 'Usuario no encontrado');
    }

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'usuarios.db');

      final dbExists = await databaseExists(path);
      if (!dbExists) {
        return LoginResult(
          success: false,
          message: 'Base de datos de usuarios no existe',
        );
      }

      final db = await _openDb();

      // Buscar usuario localmente con contraseña
      final results = await db.query(
        'usuarios',
        where: 'usuario = ? AND pass = ?',
        whereArgs: [user, password],
      );

      await db.close();

      if (results.isNotEmpty) {
        final userData = UserModel.fromMap(results.first);

        // Validar acceso local
        if (userData.accesoApp != '1') {
          return LoginResult(
            success: false,
            message:
                '[ACCESO_DENEGADO] Tu usuario no tiene permisos para acceder a la aplicación móvil. Contacta al administrador.',
          );
        }

        if (!userData.isActive) {
          return LoginResult(
            success: false,
            message: 'Usuario inactivo. Contacte al administrador.',
          );
        }

        await _clearDemoMode();
        await _saveLoggedUser(userData);

        return LoginResult(success: true, message: 'Inicio de sesión exitoso');
      }

      if (isChangingUser) {
        return LoginResult(
          success: false,
          message: 'Usuario no encontrado localmente. Use "Agregar Usuario"',
        );
      }

      return LoginResult(success: false, message: 'Credenciales incorrectas');
    } catch (e) {
      return LoginResult(success: false, message: 'Error: ${e.toString()}');
    }
  }

  // ── Login biométrico (sin contraseña, solo validar que existe localmente) ──
  Future<LoginResult> loginWithBiometrics(String usuario) async {
    try {
      final db = await _openDb();

      final results = await db.query(
        'usuarios',
        where: 'usuario = ?',
        whereArgs: [usuario],
        limit: 1,
      );

      await db.close();

      if (results.isEmpty) {
        return LoginResult(
          success: false,
          message: 'Usuario no encontrado localmente',
        );
      }

      final userData = UserModel.fromMap(results.first);

      if (userData.accesoApp != '1') {
        return LoginResult(
          success: false,
          message:
              '[ACCESO_DENEGADO] Tu usuario no tiene permisos para acceder a la aplicación.',
        );
      }

      if (!userData.isActive) {
        return LoginResult(
          success: false,
          message: 'Usuario inactivo. Contacte al administrador.',
        );
      }

      await _clearDemoMode();
      await _saveLoggedUser(userData);

      return LoginResult(success: true, message: 'Inicio de sesión biométrico exitoso');
    } catch (e) {
      return LoginResult(success: false, message: 'Error: ${e.toString()}');
    }
  }

  // ── Agregar nuevo usuario (validando en servidor) ──
  Future<LoginResult> addNewUser({
    required String usuario,
    required String password,
  }) async {
    try {
      final connected = await _connectToServer();
      if (!connected) {
        return LoginResult(
          success: false,
          message: 'No se pudo conectar al servidor',
        );
      }

      final validation = await _validateUserInServer(usuario, password);

      await _connection?.disconnect();

      if (!validation.success || validation.userData == null) {
        return LoginResult(
          success: false,
          message: validation.message,
        );
      }

      final saved = await saveUserToDatabase(validation.userData!);

      if (!saved) {
        return LoginResult(
          success: false,
          message: 'Error guardando usuario localmente',
        );
      }

      await _clearDemoMode();
      await _saveLoggedUser(validation.userData!);

      return LoginResult(
        success: true,
        message: 'Usuario agregado y autenticado exitosamente',
      );
    } catch (e) {
      await _connection?.disconnect();
      return LoginResult(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  // ── Login en modo demo / offline ──
  Future<void> loginDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modoDemo', true);
  }

  // ── Limpiar modo demo ──
  Future<void> _clearDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modoDemo', false);
  }

  // ── Cambiar usuario (deshabilita auto-login) ──
  Future<void> changeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login_enabled', false);
  }

  // ── Reconfigurar aplicación ──
  Future<void> reconfigure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('setup_completed');
    await prefs.remove('setup_date');
    await prefs.remove('auto_login_enabled');
    await prefs.remove('logged_user');
    await prefs.remove('logged_user_nombre');
    await prefs.remove('logged_user_titulo');
    await prefs.remove('is_first_login');

    // Limpiar también secure storage
    await _credentialStorage.clearCredentials();
  }

  // ── Eliminar usuario guardado ──
  Future<bool> deleteUser(String usuario) async {
    try {
      final db = await _openDb();
      await db.delete('usuarios', where: 'usuario = ?', whereArgs: [usuario]);

      final remainingUsers = await db.query('usuarios');
      await db.close();

      if (remainingUsers.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('logged_user');
        await prefs.remove('logged_user_nombre');
        await prefs.setBool('auto_login_enabled', false);
      }

      return true;
    } catch (e) {
      print('[AuthService] Error eliminando usuario: $e');
      return false;
    }
  }

  @visibleForTesting
  UserValidationResult processServerUserResultForTest(String resultJson) {
    return _processServerUserResult(resultJson);
  }
}

// ── Resultados ──

class LoginResult {
  final bool success;
  final String message;

  LoginResult({required this.success, required this.message});
}

class UserValidationResult extends LoginResult {
  final UserModel? userData;

  UserValidationResult({
    required super.success,
    required super.message,
    this.userData,
  });
}
