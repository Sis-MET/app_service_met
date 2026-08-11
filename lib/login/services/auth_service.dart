import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_model.dart';
import 'auth_api_service.dart';
import 'credential_storage.dart';
import 'password_verifier.dart';

class AuthService {
  static const _databaseVersion = 5;
  static const offlineAccessValidity = Duration(days: 30);
  final CredentialStorage _credentialStorage = CredentialStorage();

  Future<Database> _openDb() async {
    final path = join(await getDatabasesPath(), 'usuarios.db');
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, _) => _createUsersTable(db),
      onUpgrade: (db, _, __) => _ensureSchema(db),
      onOpen: (db) async {
        await _ensureSchema(db);
        await _migrateLegacyPasswords(db);
      },
    );
  }

  Future<void> _createUsersTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre1 TEXT,
        apellido1 TEXT,
        apellido2 TEXT,
        pass TEXT DEFAULT '',
        usuario TEXT UNIQUE,
        titulo_abr TEXT,
        estado TEXT,
        acceso_app TEXT,
        password_salt TEXT,
        password_hash TEXT,
        last_verified_at TEXT,
        fecha_guardado TEXT
      )
    ''');
  }

  Future<void> _ensureSchema(Database db) async {
    await _createUsersTable(db);
    final columns = await db.rawQuery('PRAGMA table_info(usuarios)');
    final names = columns.map((column) => column['name']?.toString()).toSet();
    for (final definition in const {
      'pass': "TEXT DEFAULT ''",
      'acceso_app': "TEXT DEFAULT '0'",
      'password_salt': 'TEXT',
      'password_hash': 'TEXT',
      'last_verified_at': 'TEXT',
      'fecha_guardado': 'TEXT',
    }.entries) {
      if (!names.contains(definition.key)) {
        await db.execute(
          'ALTER TABLE usuarios ADD COLUMN ${definition.key} ${definition.value}',
        );
      }
    }
  }

  Future<void> _migrateLegacyPasswords(Database db) async {
    final rows = await db.query(
      'usuarios',
      columns: ['id', 'pass'],
      where: "pass IS NOT NULL AND pass != ''",
    );
    for (final row in rows) {
      final verifier = await PasswordVerifier.create(row['pass'].toString());
      await db.update(
        'usuarios',
        {
          'password_salt': verifier.salt,
          'password_hash': verifier.hash,
          'last_verified_at': DateTime.now().toIso8601String(),
          'pass': '',
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> migrateDatabase() async {
    final db = await _openDb();
    await db.close();
    await _credentialStorage.clearCredentials();
  }

  Future<bool> userExists(String usuario) async {
    if (!await _databaseExists()) return false;
    final db = await _openDb();
    try {
      final rows = await db.query(
        'usuarios',
        columns: ['id'],
        where: 'usuario = ?',
        whereArgs: [usuario],
        limit: 1,
      );
      return rows.isNotEmpty;
    } finally {
      await db.close();
    }
  }

  Future<bool> _databaseExists() async {
    final path = join(await getDatabasesPath(), 'usuarios.db');
    return databaseExists(path);
  }

  Future<bool> saveUserToDatabase(UserModel user) async {
    final db = await _openDb();
    try {
      await db.rawInsert(
        '''
        INSERT INTO usuarios (
          usuario, nombre1, apellido1, apellido2, titulo_abr,
          estado, acceso_app, fecha_guardado
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(usuario) DO UPDATE SET
          nombre1 = excluded.nombre1,
          apellido1 = excluded.apellido1,
          apellido2 = excluded.apellido2,
          titulo_abr = excluded.titulo_abr,
          estado = excluded.estado,
          acceso_app = excluded.acceso_app,
          fecha_guardado = excluded.fecha_guardado
        ''',
        [
          user.usuario,
          user.nombre1,
          user.apellido1,
          user.apellido2,
          user.tituloAbr,
          user.estado,
          user.accesoApp,
          DateTime.now().toIso8601String(),
        ],
      );
      return true;
    } catch (error) {
      debugPrint('[AuthService] Error guardando usuario: $error');
      return false;
    } finally {
      await db.close();
    }
  }

  Future<void> enrollOnlineUser({
    required UserModel user,
    required String password,
  }) async {
    final verifier = await PasswordVerifier.create(password);
    final saved = await saveUserToDatabase(user);
    if (!saved) throw StateError('No se pudo guardar el usuario localmente.');
    final db = await _openDb();
    try {
      await db.update(
        'usuarios',
        {
          'password_salt': verifier.salt,
          'password_hash': verifier.hash,
          'last_verified_at': DateTime.now().toIso8601String(),
          'pass': '',
        },
        where: 'usuario = ?',
        whereArgs: [user.usuario],
      );
    } finally {
      await db.close();
    }
    await _saveLoggedUser(user);
  }

  Future<List<UserModel>> getSavedUsers() async {
    if (!await _databaseExists()) return [];
    final db = await _openDb();
    try {
      final rows = await db.query('usuarios', orderBy: 'fecha_guardado DESC');
      return rows.map(UserModel.fromMap).toList(growable: false);
    } finally {
      await db.close();
    }
  }

  Future<void> selectUser(UserModel user) async {
    if (!user.isSelectable) {
      throw StateError('El usuario no está habilitado para ServiceMET.');
    }
    await _saveLoggedUser(user);
  }

  Future<Map<String, dynamic>> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'savedUser': prefs.getString('logged_user'),
      'savedUserFullName': prefs.getString('logged_user_nombre'),
      'lastUpdate': prefs.getString('lastUpdate'),
    };
  }

  Future<LoginResult> login({
    String? usuario,
    required String password,
    bool isChangingUser = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final user = usuario ?? prefs.getString('logged_user');
    if (user == null || user.isEmpty || !await _databaseExists()) {
      return const LoginResult(
        success: false,
        message: 'Este usuario aún no está disponible sin conexión.',
        code: 'LOCAL_USER_MISSING',
      );
    }

    final db = await _openDb();
    try {
      final rows = await db.query(
        'usuarios',
        where: 'usuario = ?',
        whereArgs: [user],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const LoginResult(
          success: false,
          message: 'Usuario no encontrado en este dispositivo.',
          code: 'LOCAL_USER_MISSING',
        );
      }
      final row = rows.first;
      final validation = _validateLocalUser(row);
      if (validation != null) return validation;
      final validPassword = await PasswordVerifier.verify(
        password: password,
        salt: row['password_salt']?.toString() ?? '',
        expectedHash: row['password_hash']?.toString() ?? '',
      );
      if (!validPassword) {
        return const LoginResult(
          success: false,
          message: 'Contraseña incorrecta.',
          code: 'INVALID_CREDENTIALS',
        );
      }
      await _saveLoggedUser(UserModel.fromMap(row));
      return const LoginResult(
        success: true,
        message: 'Acceso offline autorizado.',
        offline: true,
      );
    } finally {
      await db.close();
    }
  }

  Future<LoginResult> loginWithBiometrics(String usuario) async {
    if (!await _databaseExists()) {
      return const LoginResult(
        success: false,
        message: 'No hay una sesión offline disponible.',
        code: 'LOCAL_USER_MISSING',
      );
    }
    final db = await _openDb();
    try {
      final rows = await db.query(
        'usuarios',
        where: 'usuario = ?',
        whereArgs: [usuario],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const LoginResult(
          success: false,
          message: 'Usuario no encontrado en este dispositivo.',
          code: 'LOCAL_USER_MISSING',
        );
      }
      final validation = _validateLocalUser(rows.first);
      if (validation != null) return validation;
      await _saveLoggedUser(UserModel.fromMap(rows.first));
      return const LoginResult(
        success: true,
        message: 'Dispositivo desbloqueado.',
        offline: true,
      );
    } finally {
      await db.close();
    }
  }

  LoginResult? _validateLocalUser(Map<String, Object?> row) {
    final user = UserModel.fromMap(row);
    if (user.accesoApp != '1' || !user.isActive) {
      return const LoginResult(
        success: false,
        message: 'El usuario no está habilitado para ServiceMET.',
        code: 'ACCESS_DENIED',
      );
    }
    final verifiedAt = DateTime.tryParse(
      row['last_verified_at']?.toString() ?? '',
    );
    if (verifiedAt == null ||
        DateTime.now().difference(verifiedAt) > offlineAccessValidity) {
      return const LoginResult(
        success: false,
        message: 'Conéctate al servidor para renovar el acceso offline.',
        code: 'OFFLINE_ACCESS_EXPIRED',
      );
    }
    return null;
  }

  Future<LoginResult> addNewUser({
    required String apiUrl,
    required String usuario,
    required String password,
  }) async {
    final api = AuthApiService(apiUrl);
    try {
      final result = await api.login(usuario: usuario, password: password);
      await enrollOnlineUser(user: result.user, password: password);
      return const LoginResult(
        success: true,
        message: 'Usuario guardado para trabajar online y offline.',
      );
    } catch (error) {
      return LoginResult(success: false, message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<void> _saveLoggedUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_user', user.usuario);
    await prefs.setString('logged_user_nombre', user.fullName);
    await prefs.setString('logged_user_titulo', user.tituloAbr);
    await prefs.remove('modoDemo');
    await prefs.remove('auto_login_enabled');
    await prefs.remove('is_first_login');
  }

  Future<void> changeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_user');
    await prefs.remove('logged_user_nombre');
    await prefs.remove('logged_user_titulo');
  }

  Future<void> reconfigure() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      'setup_completed',
      'setup_date',
      'logged_user',
      'logged_user_nombre',
      'logged_user_titulo',
      'auto_login_enabled',
      'is_first_login',
      'modoDemo',
    ]) {
      await prefs.remove(key);
    }
    await _credentialStorage.clearCredentials();
  }

  Future<UserModel?> deleteUser(String usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final wasSelected = prefs.getString('logged_user') == usuario;
    final db = await _openDb();
    try {
      await db.delete('usuarios', where: 'usuario = ?', whereArgs: [usuario]);
    } finally {
      await db.close();
    }
    if (!wasSelected) return null;

    final remainingUsers = await getSavedUsers();
    UserModel? fallback;
    for (final user in remainingUsers) {
      if (user.isSelectable) {
        fallback = user;
        break;
      }
    }
    if (fallback == null) {
      await changeUser();
    } else {
      await _saveLoggedUser(fallback);
    }
    return fallback;
  }
}

class LoginResult {
  final bool success;
  final String message;
  final String? code;
  final bool offline;

  const LoginResult({
    required this.success,
    required this.message,
    this.code,
    this.offline = false,
  });
}
