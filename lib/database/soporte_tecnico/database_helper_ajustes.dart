import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:service_met/screens/soporte_new/utils/pruebas_omitidas.dart';

class DatabaseHelperAjustes {
  static final DatabaseHelperAjustes _instance =
      DatabaseHelperAjustes._internal();
  factory DatabaseHelperAjustes() => _instance;
  static Database? _database;
  static bool _isInitializing =
      false; // ← AGREGADO: Flag para evitar inicializaciones múltiples
  String get tableName => 'ajustes_metrologicos';

  DatabaseHelperAjustes._internal();

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
        'ajustes_metrologicos',
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
        'ajustes_metrologicos',
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
      FROM ajustes_metrologicos 
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
      return await db.query('ajustes_metrologicos',
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
        'ajustes_metrologicos',
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
        'ajustes_metrologicos',
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
      if (registro.containsKey(PruebasOmitidas.columna)) {
        await PruebasOmitidas.asegurarColumna(db, 'ajustes_metrologicos');
      }

      final existing = await db.query(
        'ajustes_metrologicos',
        where: 'otst = ? AND session_id = ?',
        whereArgs: [registro['otst'], registro['session_id']],
      );

      if (existing.isNotEmpty) {
        await db.update(
          'ajustes_metrologicos',
          registro,
          where: 'otst = ? AND session_id = ?',
          whereArgs: [registro['otst'], registro['session_id']],
        );
        debugPrint(
            'Registro ACTUALIZADO - OTST: ${registro['otst']}, Session: ${registro['session_id']}');
      } else {
        await db.insert('ajustes_metrologicos', registro);
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
      String path = join(await getDatabasesPath(), 'ajustes_metrologicos.db');

      // Crear directorio si no existe
      final directory = Directory(dirname(path));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Abrir/crear la base de datos
      final database = await openDatabase(
        path,
        version: 2, // Versión 2: Nuevas columnas Inspección y Estado Final
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
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
      debugPrint('Creando tabla ajustes_metrologicos...');

      await db.execute('''
      CREATE TABLE ajustes_metrologicos (  
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
        ubicacion TEXT DEFAULT '',
        num_celdas TEXT DEFAULT '',
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
        
        --DATOS SERVICIO 
        fecha_servicio TEXT DEFAULT '',
        hora_inicio TEXT DEFAULT '',
        hora_fin TEXT DEFAULT '',
        
        --Comentarios
        comentario_1 TEXT DEFAULT '',
        comentario_2 TEXT DEFAULT '',
        comentario_3 TEXT DEFAULT '',
        comentario_4 TEXT DEFAULT '',
        comentario_5 TEXT DEFAULT '',
        comentario_6 TEXT DEFAULT '',
        comentario_7 TEXT DEFAULT '',
        comentario_8 TEXT DEFAULT '',
        comentario_9 TEXT DEFAULT '',
        comentario_10 TEXT DEFAULT '',

        -- Estado Final y Recomendaciones (V2)
        comentario_general TEXT DEFAULT '',
        recomendacion TEXT DEFAULT '',
        fecha_prox_servicio TEXT DEFAULT '',
        fisico TEXT DEFAULT '',
        operacional TEXT DEFAULT '',
        metrologico TEXT DEFAULT '',

        -- Inspección Visual / Verificaciones (V2)
        superficie_apoyo TEXT DEFAULT '',
        tension_red TEXT DEFAULT '',
        sistema_tierra TEXT DEFAULT '',
        comunicacion_pc TEXT DEFAULT '',
        vibracion_externa TEXT DEFAULT '',
        
        -- Retorno a Cero
        retorno_cero_inicial_valoracion TEXT DEFAULT '',
        estabilizacion_inicial TEXT DEFAULT '',
        retorno_cero_final_valoracion TEXT DEFAULT '',
        estabilizacion_final TEXT DEFAULT '',

        -- Excentricidad Inicial
        excentricidad_inicial_tipo_plataforma TEXT DEFAULT '',
        excentricidad_inicial_carga TEXT DEFAULT '',
        excentricidad_inicial_cantidad_posiciones TEXT DEFAULT '',
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
        
        excentricidad_final_tipo_plataforma TEXT DEFAULT '',
        excentricidad_final_carga TEXT DEFAULT '',
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
        
        repetibilidad_inicial_cantidad_cargas TEXT DEFAULT '',
        repetibilidad_inicial_cantidad_pruebas TEXT DEFAULT '',

        -- REPETIBILIDAD INICIAL 
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
       
        -- REPETIBILIDAD FINAL
        repetibilidad_final_cantidad_cargas TEXT DEFAULT '',
        repetibilidad_final_cantidad_pruebas TEXT DEFAULT '',
        
        -- Carga 1
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
        
        -- LINEALIDAD INICIAL
        linealidad_inicial_cantidad_puntos TEXT DEFAULT '',
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
        
        -- LINEALIDAD FINAL
        linealidad_final_cantidad_puntos TEXT DEFAULT '',
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
        estado_servicio TEXT DEFAULT ''
       )
      ''');

      debugPrint('Tabla ajustes_metrologicos creada exitosamente');
    } catch (e) {
      debugPrint('Error creando tabla: $e');
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        debugPrint('Actualizando base de datos Ajustes a versión 2...');

        // Campos de Estado Final y Recomendaciones
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN comentario_general TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN recomendacion TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN fecha_prox_servicio TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN fisico TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN operacional TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN metrologico TEXT DEFAULT ''");

        // Nuevos campos de Inspección Visual / Verificaciones
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN superficie_apoyo TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN tension_red TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN sistema_tierra TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN comunicacion_pc TEXT DEFAULT ''");
        await db.execute(
            "ALTER TABLE ajustes_metrologicos ADD COLUMN vibracion_externa TEXT DEFAULT ''");
      }
    } catch (e) {
      debugPrint('Error en migración Ajustes: $e');
    }
  }

  Future<int> insertRegistroRelevamiento(Map<String, dynamic> registro) async {
    try {
      final db = await database;
      return await db.insert('ajustes_metrologicos', registro);
    } catch (e) {
      debugPrint('Error insertando registro: $e');
      rethrow;
    }
  }

  Future<void> exportDataToCSV() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> registros =
          await db.query('ajustes_metrologicos');

      if (registros.isEmpty) {
        debugPrint('No hay datos para exportar');
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add(registros.first.keys.toList());

      for (var registro in registros) {
        rows.add(registro.values.toList());
      }

      String csv = Csv().encode(rows);

      String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Guardar archivo CSV',
        fileName: 'ajustes_metrologicos${DateTime.now().toIso8601String()}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );

      if (outputFile != null) {
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
