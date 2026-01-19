import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/soporte_tecnico/database_helper_relevamiento.dart';
import '../database/soporte_tecnico/database_helper_ajustes.dart';
import '../database/soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import '../database/soporte_tecnico/database_helper_instalacion.dart';
import '../database/soporte_tecnico/database_helper_mnt_prv_avanzado_stac.dart';
import '../database/soporte_tecnico/database_helper_mnt_prv_regular_stil.dart';
import '../database/soporte_tecnico/database_helper_verificaciones.dart';

import '../login/services/auth_service.dart';

class DatabaseMaintenanceService {
  /// Ejecuta el proceso de migración para todas las bases de datos registradas.
  ///
  /// El proceso consiste en:
  /// 1. Leer todos los registros existentes en memoria.
  /// 2. Cerrar la conexión a la base de datos.
  /// 3. Eliminar el archivo físico de la base de datos (.db).
  /// 4. Re-inicializar la base de datos (lo que activará _onCreate con el nuevo esquema).
  /// 5. Insertar los registros guardados.
  static Future<void> migrateAllDatabases() async {
    debugPrint('Iniciando mantenimiento de bases de datos...');

    // 0. Usuarios (AuthService) - IMPORTANTE: Recrear estructura nueva
    await _migrateUsuarios();

    // 1. AppDatabase (Calibración)
    await _migrateAppDatabase();

    // 2. Relevamiento de Datos
    await _migrateRelevamiento();

    // 3. Ajustes Metrológicos
    await _migrateAjustes();

    // 4. Diagnóstico y Correctivo
    await _migrateDiagnosticoCorrectivo();

    // 5. Instalación
    await _migrateInstalacion();

    // 6. Mantenimiento Preventivo Avanzado STAC
    await _migrateMntPrvAvanzadoStac();

    // 7. Mantenimiento Preventivo Regular STIL
    await _migrateMntPrvRegularStil();

    // 8. Verificaciones
    await _migrateVerificaciones();

    debugPrint('Mantenimiento de bases de datos completado.');
  }

  static Future<void> _migrateAppDatabase() async {
    try {
      final db = AppDatabase();
      debugPrint('Migrando AppDatabase...');

      // 1. Backup
      final data = await db.getAllRegistrosCalibracion();
      debugPrint('Registros respaldados: ${data.length}');

      // 2. Close
      await db.close();

      // 3. Delete
      final path = join(await getDatabasesPath(), 'calibracion.db');
      await _deleteDbFile(path);

      // Re-instanciar (Singleton puede mantener estado, forzamos cierre)
      // En este diseño, AppDatabase maneja su propia instancia interna,
      // al haber cerrado y nullificado _database en close(), la siguiente llamada abrirá una nueva.

      // 4 & 5. Restore (Insert one by one to handle potential errors in individual rows)
      int restored = 0;
      for (var row in data) {
        // Remover el ID para que se autogenere o respetarlo si es necesario.
        // Generalmente es mejor respetar el ID si hay relaciones, pero aquí son tablas planas.
        // Si removemos el ID, se crean nuevos IDs. Intentemos mantener el ID si 'insert' lo permite.
        // sqflite insert permite insertar ID si está en el mapa.
        await db.insertRegistroCalibracion(row);
        restored++;
      }
      debugPrint('Registros restaurados: $restored');
    } catch (e) {
      debugPrint('Error migrando AppDatabase: $e');
    }
  }

  static Future<void> _migrateRelevamiento() async {
    try {
      final db = DatabaseHelperRelevamiento();
      debugPrint('Migrando Relevamiento...');
      final data = await db.getAllRegistrosRelevamiento();
      await db.close();
      final path = join(await getDatabasesPath(), 'relevamiento_de_datos.db');
      await _deleteDbFile(path);

      for (var row in data) {
        await db.insertRegistroRelevamiento(row);
      }
      debugPrint('Registros restaurados: ${data.length}');
    } catch (e) {
      debugPrint('Error migrando Relevamiento: $e');
    }
  }

  static Future<void> _migrateAjustes() async {
    try {
      final db = DatabaseHelperAjustes();
      debugPrint('Migrando Ajustes...');
      final data = await db
          .getAllRegistrosRelevamiento(); // Nombre del método puede variar
      await db.close();
      final path = join(await getDatabasesPath(), 'ajustes_metrologicos.db');
      await _deleteDbFile(path);

      for (var row in data) {
        await db.insertRegistroRelevamiento(row);
      }
      debugPrint('Registros restaurados: ${data.length}');
    } catch (e) {
      debugPrint('Error migrando Ajustes: $e');
    }
  }

  static Future<void> _migrateDiagnosticoCorrectivo() async {
    try {
      final db = DatabaseHelperDiagnosticoCorrectivo();
      debugPrint('Migrando Diagnóstico Correctivo...');
      final data = await db.getAllRegistrosRelevamiento();
      await db.close();
      final path = join(await getDatabasesPath(), 'diagnostico_correctivo.db');
      await _deleteDbFile(path);

      for (var row in data) {
        await db.insertRegistroRelevamiento(row);
      }
      debugPrint('Registros restaurados: ${data.length}');
    } catch (e) {
      debugPrint('Error migrando Diagnóstico Correctivo: $e');
    }
  }

  static Future<void> _migrateInstalacion() async {
    try {
      final db = DatabaseHelperInstalacion();
      debugPrint('Migrando Instalación...');
      final data = await db.getAllRegistrosRelevamiento();
      await db.close();
      final path = join(await getDatabasesPath(), 'instalacion.db');
      await _deleteDbFile(path);

      for (var row in data) {
        await db.insertRegistroRelevamiento(row);
      }
      debugPrint('Registros restaurados: ${data.length}');
    } catch (e) {
      debugPrint('Error migrando Instalación: $e');
    }
  }

  static Future<void> _migrateMntPrvAvanzadoStac() async {
    try {
      final db = DatabaseHelperMntPrvAvanzadoStac();
      debugPrint('Migrando Mnt Prv Avanzado STAC...');
      final data = await db.getAllRegistrosRelevamiento();
      await db.close();
      final path = join(await getDatabasesPath(), 'mnt_prv_avanzado_stac.db');
      await _deleteDbFile(path);

      for (var row in data) {
        await db.insertRegistroRelevamiento(row);
      }
      debugPrint('Registros restaurados: ${data.length}');
    } catch (e) {
      debugPrint('Error migrando Mnt Prv Avanzado STAC: $e');
    }
  }

  static Future<void> _migrateMntPrvRegularStil() async {
    try {
      final db = DatabaseHelperMntPrvRegularStil();
      debugPrint('Migrando Mnt Prv Regular STIL...');
      final data = await db.getAllRegistrosRelevamiento();
      await db.close();
      final path = join(await getDatabasesPath(), 'mnt_prv_regular_stil.db');
      await _deleteDbFile(path);

      for (var row in data) {
        await db.insertRegistroRelevamiento(row);
      }
      debugPrint('Registros restaurados: ${data.length}');
    } catch (e) {
      debugPrint('Error migrando Mnt Prv Regular STIL: $e');
    }
  }

  static Future<void> _migrateVerificaciones() async {
    try {
      final db = DatabaseHelperVerificaciones();
      debugPrint('Migrando Verificaciones...');
      final data = await db.getAllRegistrosRelevamiento();
      await db.close();
      final path = join(await getDatabasesPath(), 'verificaciones.db');
      await _deleteDbFile(path);

      for (var row in data) {
        await db.insertRegistroRelevamiento(row);
      }
      debugPrint('Registros restaurados: ${data.length}');
    } catch (e) {
      debugPrint('Error migrando Verificaciones: $e');
    }
  }

  static Future<void> _migrateUsuarios() async {
    try {
      final authService = AuthService();
      debugPrint('Migrando Usuarios...');

      // 1. Backup
      final users = await authService.getSavedUsers();
      debugPrint('Usuarios respaldados: ${users.length}');

      // 2. Delete
      // Nota: AuthService cierra la conexión en cada operación, así que no es necesario un close() explicito aquí
      // si usamos getSavedUsers(). Pero para borrar el archivo sí necesitamos asegurar que nadie lo tenga tomado,
      // aunque sqflite maneja pool. De todas formas, lo borraremos.
      final path = join(await getDatabasesPath(), 'usuarios.db');
      await _deleteDbFile(path);

      // 3. Restore
      // Al llamar a saveUserToDatabase, el AuthService automáticamente ejecutará _openDb(),
      // lo cual creará la tabla con la NUEVA estructura definida en AuthService (versión actualizada).
      int restored = 0;
      for (var user in users) {
        await authService.saveUserToDatabase(user);
        restored++;
      }
      debugPrint('Usuarios restaurados: $restored');
    } catch (e) {
      debugPrint('Error migrando Usuarios: $e');
    }
  }

  static Future<void> _deleteDbFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    // También borrar archivos temporales de SQLite
    final fileShm = File('$path-shm');
    if (await fileShm.exists()) await fileShm.delete();

    final fileWal = File('$path-wal');
    if (await fileWal.exists()) await fileWal.delete();

    final fileJournal = File('$path-journal');
    if (await fileJournal.exists()) await fileJournal.delete();
  }
}
