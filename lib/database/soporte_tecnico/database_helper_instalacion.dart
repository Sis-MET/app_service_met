import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelperInstalacion {
  static final DatabaseHelperInstalacion _instance =
      DatabaseHelperInstalacion._internal();
  factory DatabaseHelperInstalacion() => _instance;
  static Database? _database;
  static bool _isInitializing =
      false; // ← AGREGADO: Flag para evitar inicializaciones múltiples
  String get tableName => 'instalacion';

  DatabaseHelperInstalacion._internal();

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
        'instalacion',
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
        'instalacion',
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
      FROM instalacion 
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
      return await db.query('instalacion', orderBy: 'fecha_servicio DESC');
    } catch (e) {
      debugPrint('Error al obtener todos los registros: $e');
      return [];
    }
  }

  Future<bool> secaExists(String seca) async {
    try {
      final db = await database;
      final result = await db.query(
        'instalacion',
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
        'instalacion',
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

  Future<double> getD1(String codMetrica) async {
    try {
      final db = await database;
      final result = await db.query(
        'instalacion',
        columns: ['d1'],
        where: 'cod_metrica = ?',
        whereArgs: [codMetrica],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final d1Str = result.first['d1'] as String?;
        if (d1Str != null && d1Str.isNotEmpty) {
          return double.tryParse(d1Str) ?? 0.1;
        }
      }
      return 0.1; // Valor por defecto
    } catch (e) {
      debugPrint('Error al obtener d1: $e');
      return 0.1;
    }
  }

  Future<void> upsertRegistroRelevamiento(Map<String, dynamic> registro) async {
    try {
      final db = await database;

      final existing = await db.query(
        'instalacion',
        where: 'otst = ? AND session_id = ?',
        whereArgs: [registro['otst'], registro['session_id']],
      );

      if (existing.isNotEmpty) {
        await db.update(
          'instalacion',
          registro,
          where: 'otst = ? AND session_id = ?',
          whereArgs: [registro['otst'], registro['session_id']],
        );
        debugPrint(
            'Registro ACTUALIZADO - OTST: ${registro['otst']}, Session: ${registro['session_id']}');
      } else {
        await db.insert('instalacion', registro);
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

  // ← MÉTODO CORREGIDO: Inicialización más simple y robusta|
  Future<Database> _initDatabase() async {
    if (_isInitializing) {
      throw Exception('Database already initializing');
    }

    _isInitializing = true;

    try {
      String path = join(await getDatabasesPath(), 'instalacion.db');

      // Crear directorio si no existe
      final directory = Directory(dirname(path));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Abrir/crear la base de datos
      final database = await openDatabase(
        path,
        version: 1, // Reset to version 1
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
      debugPrint('Creando tabla instalacion...');

      await db.execute('''
      CREATE TABLE instalacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        --INF CLIENTE Y PERSONAL
        tipo_servicio TEXT DEFAULT 'instalacion',   
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
        
        --INSTALACION
        entorno_valor TEXT DEFAULT '',
        entorno_comentario TEXT DEFAULT '',
        nivelacion_valor TEXT DEFAULT '',
        nivelacion_comentario TEXT DEFAULT '',
        movilizacion_valor TEXT DEFAULT '',
        movilizacion_comentario TEXT DEFAULT '',
        flujo_pesadas_valor TEXT DEFAULT '',
        flujo_pesadas_comentario TEXT DEFAULT '',

        -- NUEVOS CAMPOS (V3): ALINEACIÓN CON OTROS MÓDULOS
        comentario_general TEXT DEFAULT '',
        recomendacion TEXT DEFAULT '',
        fecha_prox_servicio TEXT DEFAULT '',
        estado_fisico TEXT DEFAULT '',
        estado_operacional TEXT DEFAULT '',
        estado_metrologico TEXT DEFAULT '',

        -- Retorno a Cero
        retorno_cero_inicial_valoracion TEXT DEFAULT '',
        retorno_cero_inicial_estabilidad TEXT DEFAULT '',
        
        retorno_cero_final_valoracion TEXT DEFAULT '',
        retorno_cero_final_estabilidad TEXT DEFAULT '',

        superficie_apoyo_valor TEXT DEFAULT '',
        superficie_apoyo_comentario TEXT DEFAULT '',
        tension_red_valor TEXT DEFAULT '',
        tension_red_comentario TEXT DEFAULT '',
        sistema_tierra_valor TEXT DEFAULT '',
        sistema_tierra_comentario TEXT DEFAULT '',
        comunicacion_pc_valor TEXT DEFAULT '',
        comunicacion_pc_comentario TEXT DEFAULT '',
        vibracion_externa_valor TEXT DEFAULT '',
        vibracion_externa_comentario TEXT DEFAULT '',

        -- Excentricidad Inicial
        tipo_plataforma_inicial TEXT DEFAULT '',
        puntos_ind_inicial TEXT DEFAULT '',
        carga_exc_inicial TEXT DEFAULT '',
        posicion_inicial_1 TEXT DEFAULT '',
        indicacion_inicial_1 TEXT DEFAULT '',
        retorno_inicial_1 TEXT DEFAULT '',
        posicion_inicial_2 TEXT DEFAULT '',
        indicacion_inicial_2 TEXT DEFAULT '',
        retorno_inicial_2 TEXT DEFAULT '',
        posicion_inicial_3 TEXT DEFAULT '',
        indicacion_inicial_3 TEXT DEFAULT '',
        retorno_inicial_3 TEXT DEFAULT '',
        posicion_inicial_4 TEXT DEFAULT '',
        indicacion_inicial_4 TEXT DEFAULT '',
        retorno_inicial_4 TEXT DEFAULT '',
        posicion_inicial_5 TEXT DEFAULT '',
        indicacion_inicial_5 TEXT DEFAULT '',
        retorno_inicial_5 TEXT DEFAULT '',
        posicion_inicial_6 TEXT DEFAULT '',
        indicacion_inicial_6 TEXT DEFAULT '',
        retorno_inicial_6 TEXT DEFAULT '',
        indicacion_inicial_7 TEXT DEFAULT '',
        retorno_inicial_7 TEXT DEFAULT '',
        indicacion_inicial_8 TEXT DEFAULT '',
        retorno_inicial_8 TEXT DEFAULT '',
        indicacion_inicial_9 TEXT DEFAULT '',
        retorno_inicial_9 TEXT DEFAULT '',
        indicacion_inicial_10 TEXT DEFAULT '',
        retorno_inicial_10 TEXT DEFAULT '',
        indicacion_inicial_11 TEXT DEFAULT '',
        retorno_inicial_11 TEXT DEFAULT '',
        indicacion_inicial_12 TEXT DEFAULT '',
        retorno_inicial_12 TEXT DEFAULT '',
        
        -- Carga 1
        repetibilidad1_inicial TEXT DEFAULT '',
        indicacion1_inicial_1 TEXT DEFAULT '',
        retorno1_inicial_1 TEXT DEFAULT '',
        indicacion1_inicial_2 TEXT DEFAULT '',
        retorno1_inicial_2 TEXT DEFAULT '',
        indicacion1_inicial_3 TEXT DEFAULT '',
        retorno1_inicial_3 TEXT DEFAULT '',
        indicacion1_inicial_4 TEXT DEFAULT '',
        retorno1_inicial_4 TEXT DEFAULT '',
        indicacion1_inicial_5 TEXT DEFAULT '',
        retorno1_inicial_5 TEXT DEFAULT '',
        indicacion1_inicial_6 TEXT DEFAULT '',
        retorno1_inicial_6 TEXT DEFAULT '',
        indicacion1_inicial_7 TEXT DEFAULT '',
        retorno1_inicial_7 TEXT DEFAULT '',
        indicacion1_inicial_8 TEXT DEFAULT '',
        retorno1_inicial_8 TEXT DEFAULT '',
        indicacion1_inicial_9 TEXT DEFAULT '',
        retorno1_inicial_9 TEXT DEFAULT '',
        indicacion1_inicial_10 TEXT DEFAULT '',
        retorno1_inicial_10 TEXT DEFAULT '',
        
         -- Linealidad Inicial
        linealidad_inicial_cantidad_puntos INTEGER DEFAULT '',
        lin_inicial_1 TEXT DEFAULT '',
        ind_inicial_1 TEXT DEFAULT '',
        retorno_lin_inicial_1 TEXT DEFAULT '',
        lin_inicial_2 TEXT DEFAULT '',
        ind_inicial_2 TEXT DEFAULT '',
        retorno_lin_inicial_2 TEXT DEFAULT '',
        lin_inicial_3 TEXT DEFAULT '',
        ind_inicial_3 TEXT DEFAULT '',
        retorno_lin_inicial_3 TEXT DEFAULT '',
        lin_inicial_4 TEXT DEFAULT '',
        ind_inicial_4 TEXT DEFAULT '',
        retorno_lin_inicial_4 TEXT DEFAULT '',
        lin_inicial_5 TEXT DEFAULT '',
        ind_inicial_5 TEXT DEFAULT '',
        retorno_lin_inicial_5 TEXT DEFAULT '',
        lin_inicial_6 TEXT DEFAULT '',
        ind_inicial_6 TEXT DEFAULT '',
        retorno_lin_inicial_6 TEXT DEFAULT '',
        lin_inicial_7 TEXT DEFAULT '',
        ind_inicial_7 TEXT DEFAULT '',
        retorno_lin_inicial_7 TEXT DEFAULT '',
        lin_inicial_8 TEXT DEFAULT '',
        ind_inicial_8 TEXT DEFAULT '',
        retorno_lin_inicial_8 TEXT DEFAULT '',
        lin_inicial_9 TEXT DEFAULT '',
        ind_inicial_9 TEXT DEFAULT '',
        retorno_lin_inicial_9 TEXT DEFAULT '',
        lin_inicial_10 TEXT DEFAULT '',
        ind_inicial_10 TEXT DEFAULT '',
        retorno_lin_inicial_10 TEXT DEFAULT '',
        lin_inicial_11 TEXT DEFAULT '',
        ind_inicial_11 TEXT DEFAULT '',
        retorno_lin_inicial_11 TEXT DEFAULT '',
        lin_inicial_12 TEXT DEFAULT '',
        ind_inicial_12 TEXT DEFAULT '',
        retorno_lin_inicial_12 TEXT DEFAULT '',
        
        estado_servicio TEXT DEFAULT ''
      )
      ''');

      debugPrint('Tabla instalacion creada exitosamente');
    } catch (e) {
      debugPrint('Error creando tabla: $e');
      rethrow;
    }
  }

  Future<int> insertRegistroRelevamiento(Map<String, dynamic> registro) async {
    try {
      final db = await database;
      return await db.insert('instalacion', registro);
    } catch (e) {
      debugPrint('Error insertando registro: $e');
      rethrow;
    }
  }

  Future<void> exportDataToCSV() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> registros =
          await db.query('instalacion');

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
        fileName: 'instalacion${DateTime.now().toIso8601String()}.csv',
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
