import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelperDiagnosticoCorrectivo {
  static final DatabaseHelperDiagnosticoCorrectivo _instance =
      DatabaseHelperDiagnosticoCorrectivo._internal();
  factory DatabaseHelperDiagnosticoCorrectivo() => _instance;
  static Database? _database;
  static bool _isInitializing = false;
  String get tableName => 'diagnostico_correctivo';

  DatabaseHelperDiagnosticoCorrectivo._internal();

  Future<bool> metricaExists(String otst) async {
    return await secaExists(otst);
  }

  Future<Map<String, dynamic>?> getUltimoRegistroPorMetrica(String otst) async {
    return await getUltimoRegistroPorSeca(otst);
  }

  Future<void> upsertRegistro(Map<String, dynamic> registro) async {
    await upsertRegistroRelevamiento(registro);
  }

  Future<Map<String, dynamic>?> getRegistroByCodMetrica(
      String codMetrica) async {
    try {
      final db = await database;

      final List<Map<String, dynamic>> result = await db.query(
        tableName,
        where: 'cod_metrica = ?',
        whereArgs: [codMetrica],
        orderBy: 'id DESC',
        limit: 1,
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('Error al buscar registro por codMetrica: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUltimoRegistroPorSeca(String otst) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        where: 'otst = ?',
        whereArgs: [otst],
        orderBy: 'id DESC',
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('Error al obtener último registro por OTST: $e');
      return null;
    }
  }

  Future<String> generateSessionId(String otst) async {
    try {
      final db = await database;

      // Buscar el último session_id para este SECA
      final result = await db.rawQuery('''
      SELECT session_id 
      FROM $tableName 
      WHERE otst = ? 
      ORDER BY session_id DESC 
      LIMIT 1
    ''', [otst]);

      if (result.isEmpty) {
        // Primera sesión para este SECA
        return '0001';
      }

      // Extraer el número del último session_id
      final lastSessionId = result.first['session_id'] as String;
      final lastNumber = int.tryParse(lastSessionId) ?? 0;

      // Generar el siguiente número
      final nextNumber = lastNumber + 1;

      // Formatear con ceros a la izquierda (0001, 0002, etc.)
      return nextNumber.toString().padLeft(4, '0');
    } catch (e) {
      debugPrint('Error generando sessionId: $e');
      // En caso de error, generar uno basado en timestamp
      return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    }
  }

  Future<List<Map<String, dynamic>>> getAllRegistrosRelevamiento() async {
    try {
      final db = await database;
      return await db.query(tableName, orderBy: 'fecha_servicio DESC');
    } catch (e) {
      debugPrint('Error al obtener todos los registros: $e');
      return [];
    }
  }

  Future<bool> secaExists(String seca) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        where: 'otst = ?',
        whereArgs: [seca],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error verificando si OTST existe: $e');
      return false;
    }
  }

  Future<bool> doesTableExist(String tableName) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName]);
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error verificando si tabla existe: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getRegistroBySeca(
      String otst, String sessionId) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        where: 'otst = ? AND session_id = ?',
        whereArgs: [otst, sessionId],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('Error al obtener registro por OTST y sessionId: $e');
      return null;
    }
  }

  Future<void> upsertRegistroRelevamiento(Map<String, dynamic> registro) async {
    try {
      final db = await database;

      final existing = await db.query(
        tableName,
        where: 'otst = ? AND session_id = ?',
        whereArgs: [registro['otst'], registro['session_id']],
      );

      if (existing.isNotEmpty) {
        await db.update(
          tableName,
          registro,
          where: 'otst = ? AND session_id = ?',
          whereArgs: [registro['otst'], registro['session_id']],
        );
        debugPrint(
            'Registro ACTUALIZADO - OTST: ${registro['otst']}, Session: ${registro['session_id']}');
      } else {
        await db.insert(tableName, registro);
        debugPrint(
            'NUEVO registro INSERTADO - OTST: ${registro['otst']}, Session: ${registro['session_id']}');
      }
    } catch (e) {
      debugPrint('Error en upsertRegistroCalibracion: $e');
      rethrow;
    }
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_database != null && _database!.isOpen) {
        return _database!;
      }
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (_isInitializing) {
      throw Exception('Database already initializing');
    }

    _isInitializing = true;

    try {
      String path = join(await getDatabasesPath(), 'diagnostico_correctivo.db');

      final directory = Directory(dirname(path));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final database = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onOpen: (db) {
          debugPrint('Base de datos abierta correctamente: $path');
        },
      );

      return database;
    } catch (e) {
      debugPrint('Error inicializando base de datos: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      debugPrint('Creando tabla diagnostico_correctivo...');

      await db.execute('''
      CREATE TABLE diagnostico_correctivo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        --INF CLIENTE Y PERSONAL
        tipo_servicio TEXT DEFAULT '',   
        cliente TEXT DEFAULT '',
        razon_social TEXT DEFAULT '',
        planta TEXT DEFAULT '',
        dir_planta TEXT DEFAULT '',
        dep_planta TEXT DEFAULT '',
        cod_planta TEXT DEFAULT '',
        personal TEXT DEFAULT '',
        otst TEXT DEFAULT '',
        session_id TEXT DEFAULT '',
        inf_bal TEXT DEFAULT '',
        
        --INF BALANZA
        foto_balanza TEXT DEFAULT '',
        categoria_balanza TEXT DEFAULT '',
        cod_metrica TEXT DEFAULT '',
        cod_int TEXT DEFAULT '',
        tipo_equipo TEXT DEFAULT '',
        marca TEXT DEFAULT '',
        modelo TEXT DEFAULT '',
        serie TEXT DEFAULT '',
        unidades TEXT DEFAULT '',
        num_celdas TEXT DEFAULT '',
        ubicacion TEXT DEFAULT '',
        cap_max1 TEXT DEFAULT '',
        d1 TEXT DEFAULT '',
        e1 TEXT DEFAULT '',
        dec1 TEXT DEFAULT '',
        cap_max2 TEXT DEFAULT '',
        d2 TEXT DEFAULT '',
        e2 TEXT DEFAULT '',
        dec2 TEXT DEFAULT '',
        cap_max3 TEXT DEFAULT '',
        d3 TEXT DEFAULT '',
        e3 TEXT DEFAULT '',
        dec3 TEXT DEFAULT '',
        
        --DATOS DE SERVICIO
        fecha_servicio TEXT DEFAULT '',
        hora_inicio TEXT DEFAULT '',
        hora_fin TEXT DEFAULT '',
        
        -- Inspección Visual
        reporte TEXT DEFAULT '',
        evaluacion TEXT DEFAULT '',
        trabajo_realizado TEXT DEFAULT '',
        estado_servicio TEXT DEFAULT '',

        -- Pruebas metrológicas finales
        retorno_cero_final_valoracion TEXT DEFAULT '',
        estabilizacion_final TEXT DEFAULT '',

        -- Pruebas de Excentricidad Final
        tipo_plataforma_final TEXT DEFAULT '',
        puntos_ind_final TEXT DEFAULT '',
        carga_exc_final TEXT DEFAULT '',
        
        posicion_final_1 TEXT DEFAULT '',
        indicacion_final_1 TEXT DEFAULT '',
        retorno_final_1 TEXT DEFAULT '',
        
        posicion_final_2 TEXT DEFAULT '',
        indicacion_final_2 TEXT DEFAULT '',
        retorno_final_2 TEXT DEFAULT '',
        
        posicion_final_3 TEXT DEFAULT '',
        indicacion_final_3 TEXT DEFAULT '',
        retorno_final_3 TEXT DEFAULT '',
        
        posicion_final_4 TEXT DEFAULT '',
        indicacion_final_4 TEXT DEFAULT '',
        retorno_final_4 TEXT DEFAULT '',
        
        posicion_final_5 TEXT DEFAULT '',
        indicacion_final_5 TEXT DEFAULT '',
        retorno_final_5 TEXT DEFAULT '',
        
        posicion_final_6 TEXT DEFAULT '',
        indicacion_final_6 TEXT DEFAULT '',
        retorno_final_6 TEXT DEFAULT '',
        
        -- Repetibilidad final (hasta 3 cargas con 10 mediciones cada una)
        repetibilidad_count_final INTEGER DEFAULT 0,
        repetibilidad_rows_final INTEGER DEFAULT 0,
        
        repetibilidad1_final TEXT DEFAULT '',
        indicacion1_final_1 TEXT DEFAULT '',
        retorno1_final_1 TEXT DEFAULT '',
        indicacion1_final_2 TEXT DEFAULT '',
        retorno1_final_2 TEXT DEFAULT '',
        indicacion1_final_3 TEXT DEFAULT '',
        retorno1_final_3 TEXT DEFAULT '',
        indicacion1_final_4 TEXT DEFAULT '',
        retorno1_final_4 TEXT DEFAULT '',
        indicacion1_final_5 TEXT DEFAULT '',
        retorno1_final_5 TEXT DEFAULT '',
        indicacion1_final_6 TEXT DEFAULT '',
        retorno1_final_6 TEXT DEFAULT '',
        indicacion1_final_7 TEXT DEFAULT '',
        retorno1_final_7 TEXT DEFAULT '',
        indicacion1_final_8 TEXT DEFAULT '',
        retorno1_final_8 TEXT DEFAULT '',
        indicacion1_final_9 TEXT DEFAULT '',
        retorno1_final_9 TEXT DEFAULT '',
        indicacion1_final_10 TEXT DEFAULT '',
        retorno1_final_10 TEXT DEFAULT '',

        
        -- Linealidad final (hasta 12 puntos)
        lin_final_1 TEXT DEFAULT '',
        ind_final_1 TEXT DEFAULT '',
        retorno_lin_final_1 TEXT DEFAULT '',
        
        lin_final_2 TEXT DEFAULT '',
        ind_final_2 TEXT DEFAULT '',
        retorno_lin_final_2 TEXT DEFAULT '',
        
        lin_final_3 TEXT DEFAULT '',
        ind_final_3 TEXT DEFAULT '',
        retorno_lin_final_3 TEXT DEFAULT '',
        
        lin_final_4 TEXT DEFAULT '',
        ind_final_4 TEXT DEFAULT '',
        retorno_lin_final_4 TEXT DEFAULT '',
        
        lin_final_5 TEXT DEFAULT '',
        ind_final_5 TEXT DEFAULT '',
        retorno_lin_final_5 TEXT DEFAULT '',
        
        lin_final_6 TEXT DEFAULT '',
        ind_final_6 TEXT DEFAULT '',
        retorno_lin_final_6 TEXT DEFAULT '',
        
        lin_final_7 TEXT DEFAULT '',
        ind_final_7 TEXT DEFAULT '',
        retorno_lin_final_7 TEXT DEFAULT '',
        
        lin_final_8 TEXT DEFAULT '',
        ind_final_8 TEXT DEFAULT '',
        retorno_lin_final_8 TEXT DEFAULT '',
        
        lin_final_9 TEXT DEFAULT '',
        ind_final_9 TEXT DEFAULT '',
        retorno_lin_final_9 TEXT DEFAULT '',
        
        lin_final_10 TEXT DEFAULT '',
        ind_final_10 TEXT DEFAULT '',
        retorno_lin_final_10 TEXT DEFAULT '',
        
        lin_final_11 TEXT DEFAULT '',
        ind_final_11 TEXT DEFAULT '',
        retorno_lin_final_11 TEXT DEFAULT '',
        
        lin_final_12 TEXT DEFAULT '',
        ind_final_12 TEXT DEFAULT '',
        retorno_lin_final_12 TEXT DEFAULT '',
        
        
        -- Estado Final (NUEVOS CAMPOS)
        comentario_general TEXT DEFAULT '',
        recomendacion TEXT DEFAULT '',
        fecha_prox_servicio TEXT DEFAULT '',
        fisico TEXT DEFAULT '',
        operacional TEXT DEFAULT '',
        metrologico TEXT DEFAULT ''
      )
      ''');

      debugPrint('Tabla diagnostico_correctivo creada exitosamente');
    } catch (e) {
      debugPrint('Error creando tabla: $e');
      rethrow;
    }
  }

  Future<int> insertRegistroRelevamiento(Map<String, dynamic> registro) async {
    try {
      final db = await database;
      return await db.insert(tableName, registro);
    } catch (e) {
      debugPrint('Error insertando registro: $e');
      rethrow;
    }
  }

  Future<void> exportDataToCSV() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> registros = await db.query(tableName);

      if (registros.isEmpty) {
        debugPrint('No hay datos para exportar');
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add(registros.first.keys.toList());

      for (var registro in registros) {
        rows.add(registro.values.toList());
      }

      String csv = const ListToCsvConverter().convert(rows);

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar archivo CSV',
        fileName:
            'diagnostico_correctivo_\${DateTime.now().toIso8601String()}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile != null) {
        await File(outputFile).writeAsString(csv);
        debugPrint('Datos exportados a $outputFile');
      }
    } catch (e) {
      debugPrint('Error exportando datos: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
