import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelperVerificaciones {
  static final DatabaseHelperVerificaciones _instance =
      DatabaseHelperVerificaciones._internal();
  factory DatabaseHelperVerificaciones() => _instance;
  static Database? _database;
  static bool _isInitializing =
      false; // ← AGREGADO: Flag para evitar inicializaciones múltiples
  String get tableName => 'verificaciones_internas';

  DatabaseHelperVerificaciones._internal();

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
        'verificaciones_internas',
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
        'verificaciones_internas',
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

  // REEMPLAZAR ESTE MÉTODO COMPLETO
  Future<String> generateSessionId(String otst) async {
    try {
      final db = await database;

      // Buscar el último session_id para este SECA
      final result = await db.rawQuery('''
      SELECT session_id 
      FROM verificaciones_internas 
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
      return await db.query('verificaciones_internas',
          orderBy: 'fecha_servicio DESC');
    } catch (e) {
      debugPrint('Error al obtener todos los registros: $e');
      return [];
    }
  }

  Future<bool> secaExists(String seca) async {
    try {
      final db = await database;
      final result = await db.query(
        'verificaciones_internas',
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
        'verificaciones_internas',
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
        'verificaciones_internas',
        where: 'otst = ? AND session_id = ?',
        whereArgs: [registro['otst'], registro['session_id']],
      );

      if (existing.isNotEmpty) {
        await db.update(
          'verificaciones_internas',
          registro,
          where: 'otst = ? AND session_id = ?',
          whereArgs: [registro['otst'], registro['session_id']],
        );
        debugPrint(
            'Registro ACTUALIZADO - OTST: ${registro['otst']}, Session: ${registro['session_id']}');
      } else {
        await db.insert('verificaciones_internas', registro);
        debugPrint(
            'NUEVO registro INSERTADO - OTST: ${registro['otst']}, Session: ${registro['session_id']}');
      }
    } catch (e) {
      debugPrint('Error en upsertRegistroCalibracion: $e');
      rethrow; // Re-lanzar el error para que lo maneje quien llama
    }
  }

  // ← MÉTODO CORREGIDO: Getter de database más robusto
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    // Evitar múltiples inicializaciones concurrentes
    if (_isInitializing) {
      // Esperar hasta que la inicialización termine
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

  // ← MÉTODO CORREGIDO: Inicialización más simple y robusta
  Future<Database> _initDatabase() async {
    if (_isInitializing) {
      throw Exception('Database already initializing');
    }

    _isInitializing = true;

    try {
      String path =
          join(await getDatabasesPath(), 'verificaciones_internas.db');

      // Crear directorio si no existe
      final directory = Directory(dirname(path));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Abrir/crear la base de datos
      final database = await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('DROP TABLE IF EXISTS verificaciones_internas');
            await _onCreate(db, newVersion);
          }
        },
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
      debugPrint('Creando tabla verificaciones_internas...');

      await db.execute('''
      CREATE TABLE verificaciones_internas (
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
        
        --apartados
        reporte TEXT DEFAULT '',
        evaluacion TEXT DEFAULT '',
      
        excentricidad_estado_general TEXT DEFAULT '',
        repetibilidad_estado_general TEXT DEFAULT '',
        linealidad_estado_general TEXT DEFAULT '',

        -- Inspección Visual Detallada (NUEVOS CAMPOS)
        comentario_general TEXT DEFAULT '',
        recomendacion TEXT DEFAULT '',
        fisico TEXT DEFAULT '',
        operacional TEXT DEFAULT '',
        metrologico TEXT DEFAULT '',
        fecha_prox_servicio TEXT DEFAULT '',

        -- Retorno a Cero
        retorno_cero_inicial_valoracion TEXT DEFAULT '',
        retorno_cero_inicial_carga TEXT DEFAULT '',
        retorno_cero_inicial_unidad TEXT DEFAULT '',
        retorno_cero_final_valoracion TEXT DEFAULT '',
        retorno_cero_final_carga TEXT DEFAULT '',
        retorno_cero_final_unidad TEXT DEFAULT '',

        -- Excentricidad Inicial
        excentricidad_inicial_tipo_plataforma TEXT DEFAULT '',
        excentricidad_inicial_opcion_prueba TEXT DEFAULT '',
        excentricidad_inicial_carga TEXT DEFAULT '',
        excentricidad_inicial_ruta_imagen TEXT DEFAULT '',
        excentricidad_inicial_cantidad_posiciones TEXT DEFAULT '',
        
        -- Posiciones Excentricidad Inicial (Mapeo directo y extendido)
        excentricidad_inicial_pos1_numero TEXT DEFAULT '',
        excentricidad_inicial_pos1_indicacion TEXT DEFAULT '',
        excentricidad_inicial_pos1_retorno TEXT DEFAULT '',
        excentricidad_inicial_pos1_error TEXT DEFAULT '',
        excentricidad_inicial_pos2_numero TEXT DEFAULT '',
        excentricidad_inicial_pos2_indicacion TEXT DEFAULT '',
        excentricidad_inicial_pos2_retorno TEXT DEFAULT '',
        excentricidad_inicial_pos2_error TEXT DEFAULT '',
        excentricidad_inicial_pos3_numero TEXT DEFAULT '',
        excentricidad_inicial_pos3_indicacion TEXT DEFAULT '',
        excentricidad_inicial_pos3_retorno TEXT DEFAULT '',
        excentricidad_inicial_pos3_error TEXT DEFAULT '',
        excentricidad_inicial_pos4_numero TEXT DEFAULT '',
        excentricidad_inicial_pos4_indicacion TEXT DEFAULT '',
        excentricidad_inicial_pos4_retorno TEXT DEFAULT '',
        excentricidad_inicial_pos4_error TEXT DEFAULT '',
        excentricidad_inicial_pos5_numero TEXT DEFAULT '',
        excentricidad_inicial_pos5_indicacion TEXT DEFAULT '',
        excentricidad_inicial_pos5_retorno TEXT DEFAULT '',
        excentricidad_inicial_pos5_error TEXT DEFAULT '',
        excentricidad_inicial_pos6_numero TEXT DEFAULT '',
        excentricidad_inicial_pos6_indicacion TEXT DEFAULT '',
        excentricidad_inicial_pos6_retorno TEXT DEFAULT '',
        excentricidad_inicial_pos6_error TEXT DEFAULT '',
        
        -- Excentricidad Final
        excentricidad_final_tipo_plataforma TEXT DEFAULT '',
        excentricidad_final_opcion_prueba TEXT DEFAULT '',
        excentricidad_final_carga TEXT DEFAULT '',
        excentricidad_final_ruta_imagen TEXT DEFAULT '',
        excentricidad_final_cantidad_posiciones TEXT DEFAULT '',
        
        excentricidad_final_pos1_numero TEXT DEFAULT '',
        excentricidad_final_pos1_indicacion TEXT DEFAULT '',
        excentricidad_final_pos1_retorno TEXT DEFAULT '',
        excentricidad_final_pos1_error TEXT DEFAULT '',
        excentricidad_final_pos2_numero TEXT DEFAULT '',
        excentricidad_final_pos2_indicacion TEXT DEFAULT '',
        excentricidad_final_pos2_retorno TEXT DEFAULT '',
        excentricidad_final_pos2_error TEXT DEFAULT '',
        excentricidad_final_pos3_numero TEXT DEFAULT '',
        excentricidad_final_pos3_indicacion TEXT DEFAULT '',
        excentricidad_final_pos3_retorno TEXT DEFAULT '',
        excentricidad_final_pos3_error TEXT DEFAULT '',
        excentricidad_final_pos4_numero TEXT DEFAULT '',
        excentricidad_final_pos4_indicacion TEXT DEFAULT '',
        excentricidad_final_pos4_retorno TEXT DEFAULT '',
        excentricidad_final_pos4_error TEXT DEFAULT '',
        excentricidad_final_pos5_numero TEXT DEFAULT '',
        excentricidad_final_pos5_indicacion TEXT DEFAULT '',
        excentricidad_final_pos5_retorno TEXT DEFAULT '',
        excentricidad_final_pos5_error TEXT DEFAULT '',
        excentricidad_final_pos6_numero TEXT DEFAULT '',
        excentricidad_final_pos6_indicacion TEXT DEFAULT '',
        excentricidad_final_pos6_retorno TEXT DEFAULT '',
        excentricidad_final_pos6_error TEXT DEFAULT '',

        -- Repetibilidad Inicial
        repetibilidad_inicial_cantidad_cargas TEXT DEFAULT '',
        repetibilidad_inicial_cantidad_pruebas TEXT DEFAULT '',
        
        -- Carga 1
        repetibilidad_inicial_carga1_valor TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba1_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba1_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba2_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba2_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba3_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba3_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba4_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba4_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba5_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba5_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba6_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba6_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba7_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba7_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba8_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba8_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba9_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba9_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba10_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga1_prueba10_retorno TEXT DEFAULT '',
        
        -- Carga 2
        repetibilidad_inicial_carga2_valor TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba1_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba1_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba2_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba2_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba3_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba3_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba4_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba4_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba5_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba5_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba6_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba6_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba7_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba7_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba8_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba8_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba9_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba9_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba10_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga2_prueba10_retorno TEXT DEFAULT '',
        
        -- Carga 3
        repetibilidad_inicial_carga3_valor TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba1_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba1_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba2_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba2_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba3_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba3_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba4_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba4_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba5_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba5_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba6_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba6_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba7_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba7_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba8_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba8_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba9_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba9_retorno TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba10_indicacion TEXT DEFAULT '',
        repetibilidad_inicial_carga3_prueba10_retorno TEXT DEFAULT '',
        
        -- Repetibilidad Final
        repetibilidad_final_cantidad_cargas TEXT DEFAULT '',
        repetibilidad_final_cantidad_pruebas TEXT DEFAULT '',
        
        -- Carga 1 (Final)
        repetibilidad_final_carga1_valor TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba1_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba1_retorno TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba2_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba2_retorno TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba3_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba3_retorno TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba4_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba4_retorno TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba5_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba5_retorno TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba6_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba6_retorno TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba7_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba7_retorno TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba8_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba8_retorno TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba9_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba9_retorno TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba10_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga1_prueba10_retorno TEXT DEFAULT '',

        -- Carga 2 (Final)
        repetibilidad_final_carga2_valor TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba1_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba1_retorno TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba2_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba2_retorno TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba3_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba3_retorno TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba4_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba4_retorno TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba5_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba5_retorno TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba6_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba6_retorno TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba7_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba7_retorno TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba8_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba8_retorno TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba9_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba9_retorno TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba10_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga2_prueba10_retorno TEXT DEFAULT '',

        -- Carga 3 (Final)
        repetibilidad_final_carga3_valor TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba1_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba1_retorno TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba2_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba2_retorno TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba3_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba3_retorno TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba4_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba4_retorno TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba5_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba5_retorno TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba6_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba6_retorno TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba7_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba7_retorno TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba8_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba8_retorno TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba9_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba9_retorno TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba10_indicacion TEXT DEFAULT '',
        repetibilidad_final_carga3_prueba10_retorno TEXT DEFAULT '',

        -- Linealidad Inicial
        linealidad_inicial_cantidad_puntos INTEGER DEFAULT '',
        linealidad_inicial_punto1_lt TEXT DEFAULT '',
        linealidad_inicial_punto1_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto1_retorno TEXT DEFAULT '',
        linealidad_inicial_punto1_error TEXT DEFAULT '',
        linealidad_inicial_punto2_lt TEXT DEFAULT '',
        linealidad_inicial_punto2_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto2_retorno TEXT DEFAULT '',
        linealidad_inicial_punto2_error TEXT DEFAULT '',
        linealidad_inicial_punto3_lt TEXT DEFAULT '',
        linealidad_inicial_punto3_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto3_retorno TEXT DEFAULT '',
        linealidad_inicial_punto3_error TEXT DEFAULT '',
        linealidad_inicial_punto4_lt TEXT DEFAULT '',
        linealidad_inicial_punto4_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto4_retorno TEXT DEFAULT '',
        linealidad_inicial_punto4_error TEXT DEFAULT '',
        linealidad_inicial_punto5_lt TEXT DEFAULT '',
        linealidad_inicial_punto5_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto5_retorno TEXT DEFAULT '',
        linealidad_inicial_punto5_error TEXT DEFAULT '',
        linealidad_inicial_punto6_lt TEXT DEFAULT '',
        linealidad_inicial_punto6_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto6_retorno TEXT DEFAULT '',
        linealidad_inicial_punto6_error TEXT DEFAULT '',
        linealidad_inicial_punto7_lt TEXT DEFAULT '',
        linealidad_inicial_punto7_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto7_retorno TEXT DEFAULT '',
        linealidad_inicial_punto7_error TEXT DEFAULT '',
        linealidad_inicial_punto8_lt TEXT DEFAULT '',
        linealidad_inicial_punto8_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto8_retorno TEXT DEFAULT '',
        linealidad_inicial_punto8_error TEXT DEFAULT '',
        linealidad_inicial_punto9_lt TEXT DEFAULT '',
        linealidad_inicial_punto9_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto9_retorno TEXT DEFAULT '',
        linealidad_inicial_punto9_error TEXT DEFAULT '',
        linealidad_inicial_punto10_lt TEXT DEFAULT '',
        linealidad_inicial_punto10_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto10_retorno TEXT DEFAULT '',
        linealidad_inicial_punto10_error TEXT DEFAULT '',
        linealidad_inicial_punto11_lt TEXT DEFAULT '',
        linealidad_inicial_punto11_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto11_retorno TEXT DEFAULT '',
        linealidad_inicial_punto11_error TEXT DEFAULT '',
        linealidad_inicial_punto12_lt TEXT DEFAULT '',
        linealidad_inicial_punto12_indicacion TEXT DEFAULT '',
        linealidad_inicial_punto12_retorno TEXT DEFAULT '',
        linealidad_inicial_punto12_error TEXT DEFAULT '',

        -- Linealidad Final
        linealidad_final_cantidad_puntos INTEGER DEFAULT '',
        linealidad_final_punto1_lt TEXT DEFAULT '',
        linealidad_final_punto1_indicacion TEXT DEFAULT '',
        linealidad_final_punto1_retorno TEXT DEFAULT '',
        linealidad_final_punto1_error TEXT DEFAULT '',
        linealidad_final_punto2_lt TEXT DEFAULT '',
        linealidad_final_punto2_indicacion TEXT DEFAULT '',
        linealidad_final_punto2_retorno TEXT DEFAULT '',
        linealidad_final_punto2_error TEXT DEFAULT '',
        linealidad_final_punto3_lt TEXT DEFAULT '',
        linealidad_final_punto3_indicacion TEXT DEFAULT '',
        linealidad_final_punto3_retorno TEXT DEFAULT '',
        linealidad_final_punto3_error TEXT DEFAULT '',
        linealidad_final_punto4_lt TEXT DEFAULT '',
        linealidad_final_punto4_indicacion TEXT DEFAULT '',
        linealidad_final_punto4_retorno TEXT DEFAULT '',
        linealidad_final_punto4_error TEXT DEFAULT '',
        linealidad_final_punto5_lt TEXT DEFAULT '',
        linealidad_final_punto5_indicacion TEXT DEFAULT '',
        linealidad_final_punto5_retorno TEXT DEFAULT '',
        linealidad_final_punto5_error TEXT DEFAULT '',
        linealidad_final_punto6_lt TEXT DEFAULT '',
        linealidad_final_punto6_indicacion TEXT DEFAULT '',
        linealidad_final_punto6_retorno TEXT DEFAULT '',
        linealidad_final_punto6_error TEXT DEFAULT '',
        linealidad_final_punto7_lt TEXT DEFAULT '',
        linealidad_final_punto7_indicacion TEXT DEFAULT '',
        linealidad_final_punto7_retorno TEXT DEFAULT '',
        linealidad_final_punto7_error TEXT DEFAULT '',
        linealidad_final_punto8_lt TEXT DEFAULT '',
        linealidad_final_punto8_indicacion TEXT DEFAULT '',
        linealidad_final_punto8_retorno TEXT DEFAULT '',
        linealidad_final_punto8_error TEXT DEFAULT '',
        linealidad_final_punto9_lt TEXT DEFAULT '',
        linealidad_final_punto9_indicacion TEXT DEFAULT '',
        linealidad_final_punto9_retorno TEXT DEFAULT '',
        linealidad_final_punto9_error TEXT DEFAULT '',
        linealidad_final_punto10_lt TEXT DEFAULT '',
        linealidad_final_punto10_indicacion TEXT DEFAULT '',
        linealidad_final_punto10_retorno TEXT DEFAULT '',
        linealidad_final_punto10_error TEXT DEFAULT '',
        linealidad_final_punto11_lt TEXT DEFAULT '',
        linealidad_final_punto11_indicacion TEXT DEFAULT '',
        linealidad_final_punto11_retorno TEXT DEFAULT '',
        linealidad_final_punto11_error TEXT DEFAULT '',
        linealidad_final_punto12_lt TEXT DEFAULT '',
        linealidad_final_punto12_indicacion TEXT DEFAULT '',
        linealidad_final_punto12_retorno TEXT DEFAULT '',
        linealidad_final_punto12_error TEXT DEFAULT '',
        
        -- CAMPOS DE MANTENIMIENTO (NUEVOS)
        
        -- losas
        losas_aproximacion_estado TEXT DEFAULT '',
        losas_aproximacion_solucion TEXT DEFAULT '',
        losas_aproximacion_foto TEXT DEFAULT '',
        
        -- Fundaciones
        fundaciones_estado TEXT DEFAULT '',
        fundaciones_solucion TEXT DEFAULT '',
        fundaciones_foto TEXT DEFAULT '',
        
        -- Limpieza del Perímetro
        limpieza_perimetro_estado TEXT DEFAULT '',
        limpieza_perimetro_solucion TEXT DEFAULT '',
        limpieza_perimetro_foto TEXT DEFAULT '',
        
        -- Humedad en Fosa
        fosa_humedad_estado TEXT DEFAULT '',
        fosa_humedad_solucion TEXT DEFAULT '',
        fosa_humedad_foto TEXT DEFAULT '',
        
        -- Drenaje Libre
        drenaje_libre_estado TEXT DEFAULT '',
        drenaje_libre_solucion TEXT DEFAULT '',
        drenaje_libre_foto TEXT DEFAULT '',
        
        -- Bomba de Sumidero
        bomba_sumidero_estado TEXT DEFAULT '',
        bomba_sumidero_solucion TEXT DEFAULT '',
        bomba_sumidero_foto TEXT DEFAULT '',
        
        -- Corrosión
        corrosion_estado TEXT DEFAULT '',
        corrosion_solucion TEXT DEFAULT '',
        corrosion_foto TEXT DEFAULT '',
        
        -- Grietas (Puente de pesaje)
        puente_grietas_estado TEXT DEFAULT '',
        puente_grietas_solucion TEXT DEFAULT '',
        puente_grietas_foto TEXT DEFAULT '',
        
        -- Topes y Pernos
        tapas_pernos_estado TEXT DEFAULT '',
        tapas_pernos_solucion TEXT DEFAULT '',
        tapas_pernos_foto TEXT DEFAULT '',
        
        -- Desgaste o Estrés
        desgaste_estres_estado TEXT DEFAULT '',
        desgaste_estres_solucion TEXT DEFAULT '',
        desgaste_estres_foto TEXT DEFAULT '',
        
        -- Limpieza por debajo del puente
        limpieza_puente_estado TEXT DEFAULT '',
        limpieza_puente_solucion TEXT DEFAULT '',
        limpieza_puente_foto TEXT DEFAULT '',
        
        -- Estado Rieles Laterales
        estado_rieles_estado TEXT DEFAULT '',
        estado_rieles_solucion TEXT DEFAULT '',
        estado_rieles_foto TEXT DEFAULT '',
        
        -- Limitadores Longitudinales
        limitadores_long_estado TEXT DEFAULT '',
        limitadores_long_solucion TEXT DEFAULT '',
        limitadores_long_foto TEXT DEFAULT '',
        
        -- Limitadores Transversales
        limitadores_trans_estado TEXT DEFAULT '',
        limitadores_trans_solucion TEXT DEFAULT '',
        limitadores_trans_foto TEXT DEFAULT '',
        
        -- Cable Homerun
        cable_homerun_estado TEXT DEFAULT '',
        cable_homerun_solucion TEXT DEFAULT '',
        cable_homerun_foto TEXT DEFAULT '',
        
        -- Conexión CeldaCable
        conexion_celda_cable_estado TEXT DEFAULT '',
        conexion_celda_cable_solucion TEXT DEFAULT '',
        conexion_celda_cable_foto TEXT DEFAULT '',
        
        -- Cables de Celdas
        cables_celdas_estado TEXT DEFAULT '',
        cables_celdas_solucion TEXT DEFAULT '',
        cables_celdas_foto TEXT DEFAULT '',
        
        -- Caja de Unión o Sumadora
        caja_union_estado TEXT DEFAULT '',
        caja_union_solucion TEXT DEFAULT '',
        caja_union_foto TEXT DEFAULT '',
        
        -- Conectores de Celdas
        conectores_celdas_estado TEXT DEFAULT '',
        conectores_celdas_solucion TEXT DEFAULT '',
        conectores_celdas_foto TEXT DEFAULT '',
        
        -- Conector y Terminación
        conector_terminacion_estado TEXT DEFAULT '',
        conector_terminacion_solucion TEXT DEFAULT '',
        conector_terminacion_foto TEXT DEFAULT '',
        
        -- Sistema Protección Rayos
        sistema_proteccion_rayos_estado TEXT DEFAULT '',
        sistema_proteccion_rayos_solucion TEXT DEFAULT '',
        sistema_proteccion_rayos_foto TEXT DEFAULT '',
        
        -- Conexión a Tierra
        sistema_tierra_estado TEXT DEFAULT '',
        sistema_tierra_solucion TEXT DEFAULT '',
        sistema_tierra_foto TEXT DEFAULT '',
        
        -- Conexion Malla Tierra
        conexion_malla_tierra_estado TEXT DEFAULT '',
        conexion_malla_tierra_solucion TEXT DEFAULT '',
        conexion_malla_tierra_foto TEXT DEFAULT '',
        
        -- Tensión entre Neutro y Tierra
        tension_neutro_tierra_estado TEXT DEFAULT '',
        tension_neutro_tierra_solucion TEXT DEFAULT '',
        tension_neutro_tierra_foto TEXT DEFAULT '',
        
        -- Estado Strike Shield
        estado_strike_shield_estado TEXT DEFAULT '',
        estado_strike_shield_solucion TEXT DEFAULT '',
        estado_strike_shield_foto TEXT DEFAULT '',
        
        -- Carcasa
        carcasa_estado TEXT DEFAULT '',
        carcasa_solucion TEXT DEFAULT '',
        carcasa_foto TEXT DEFAULT '',
        
        -- Voltaje Pila
        voltaje_pila_estado TEXT DEFAULT '',
        voltaje_pila_solucion TEXT DEFAULT '',
        voltaje_pila_foto TEXT DEFAULT '',
        
        -- Estado Teclado
        estado_teclado_estado TEXT DEFAULT '',
        estado_teclado_solucion TEXT DEFAULT '',
        estado_teclado_foto TEXT DEFAULT '',
        
        -- Estado Display
        estado_display_estado TEXT DEFAULT '',
        estado_display_solucion TEXT DEFAULT '',
        estado_display_foto TEXT DEFAULT '',
        
        -- Registros Predictivo
        registros_predictivo_estado TEXT DEFAULT '',
        registros_predictivo_solucion TEXT DEFAULT '',
        registros_predictivo_foto TEXT DEFAULT '',
        
        -- Alertas Servicio
        alertas_servicio_estado TEXT DEFAULT '',
        alertas_servicio_solucion TEXT DEFAULT '',
        alertas_servicio_foto TEXT DEFAULT '',
        
        -- Estado Prensacables
        estado_prensacables_estado TEXT DEFAULT '',
        estado_prensacables_solucion TEXT DEFAULT '',
        estado_prensacables_foto TEXT DEFAULT '',
        
        -- Backup InSite (si aplica)
        backup_insite_estado TEXT DEFAULT '',
        backup_insite_solucion TEXT DEFAULT '',
        backup_insite_foto TEXT DEFAULT '',
        
        -- Comunicacion PC
        comunicacion_pc_estado TEXT DEFAULT '',
        comunicacion_pc_solucion TEXT DEFAULT '',
        comunicacion_pc_foto TEXT DEFAULT '',
        
        -- Limpieza Conectores
        limpieza_conectores_estado TEXT DEFAULT '',
        limpieza_conectores_solucion TEXT DEFAULT '',
        limpieza_conectores_foto TEXT DEFAULT '',
        
        limpieza_estructura_estado TEXT DEFAULT '',
        limpieza_estructura_solucion TEXT DEFAULT '',
        limpieza_estructura_foto TEXT DEFAULT '',
        
        bearing_cups_estado TEXT DEFAULT '',
        bearing_cups_solucion TEXT DEFAULT '',
        bearing_cups_foto TEXT DEFAULT '',
        
        celdas_carga_estado TEXT DEFAULT '',
        celdas_carga_solucion TEXT DEFAULT '',
        celdas_carga_foto TEXT DEFAULT '',
        
        lubricacion_celdas_estado TEXT DEFAULT '',
        lubricacion_celdas_solucion TEXT DEFAULT '',
        lubricacion_celdas_foto TEXT DEFAULT '',
        
        lubricacion_bearing_estado TEXT DEFAULT '',
        lubricacion_bearing_solucion TEXT DEFAULT '',
        lubricacion_bearing_foto TEXT DEFAULT '',
        
        protector_goma_estado TEXT DEFAULT '',
        protector_goma_solucion TEXT DEFAULT '',
        protector_goma_foto TEXT DEFAULT '',
        
        -- Balanza Apta
        balanza_apta_estado TEXT DEFAULT '',
        balanza_apta_solucion TEXT DEFAULT '',
        balanza_apta_foto TEXT DEFAULT '',
        
        otros TEXT DEFAULT '',
        estado_servicio TEXT DEFAULT ''
      )
      ''');

      debugPrint('Tabla verificaciones_internas creada exitosamente');
    } catch (e) {
      debugPrint('Error creando tabla: $e');
      rethrow;
    }
  }

  Future<int> insertRegistroRelevamiento(Map<String, dynamic> registro) async {
    try {
      final db = await database;
      return await db.insert('verificaciones_internas', registro);
    } catch (e) {
      debugPrint('Error insertando registro: $e');
      rethrow;
    }
  }

  Future<void> exportDataToCSV() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> registros =
          await db.query('verificaciones_internas');

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
            'verificaciones_internas${DateTime.now().toIso8601String()}.csv',
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

  // ← MÉTODO AGREGADO: Para cerrar la base de datos correctamente
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
