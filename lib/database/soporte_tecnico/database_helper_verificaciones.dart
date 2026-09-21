import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
            for (final column in [
              'campos_estado TEXT DEFAULT \'\'',
              'pruebas_iniciales TEXT DEFAULT \'\'',
              'pruebas_finales TEXT DEFAULT \'\'',
            ]) {
              await db.execute(
                  'ALTER TABLE verificaciones_internas ADD COLUMN $column');
            }
          }
        },
        onOpen: (db) async {
          await _ensureFotoColumns(db);
          debugPrint('Base de datos abierta correctamente: $path');
        },
      );

      return database;
    } catch (e) {
      debugPrint('Error inicializando base de datos: $e');
      rethrow; // Re-lanzar para manejar en la UI
    } finally {
      _isInitializing = false;
    }
  }

  /// Fotos de todos los campos de inspección, una lista por campo en JSON.
  /// Las columnas `*_foto` del servidor solo cubren los primeros cuatro, y
  /// sin esta, al continuar un servicio pendiente las fotos desaparecían. La
  /// subida descarta las columnas `*_foto`.
  static const camposEstadoFotoColumn = 'campos_estado_foto';

  Future<void> _ensureFotoColumns(Database db) async {
    final rows =
        await db.rawQuery('PRAGMA table_info(verificaciones_internas)');
    final existing = rows.map((row) => row['name']?.toString()).toSet();
    if (!existing.contains(camposEstadoFotoColumn)) {
      await db.execute('ALTER TABLE verificaciones_internas '
          "ADD COLUMN $camposEstadoFotoColumn TEXT DEFAULT ''");
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
        estabilizacion_inicial TEXT DEFAULT '',
        retorno_cero_final_valoracion TEXT DEFAULT '',
        estabilizacion_final TEXT DEFAULT '',

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
        
        -- CAMPOS NUEVOS
        espaciamiento_topes_long_estado TEXT DEFAULT '',
        espaciamiento_topes_long_solucion TEXT DEFAULT '',
        espaciamiento_topes_long_foto TEXT DEFAULT '',
        
        espaciamiento_topes_front_estado TEXT DEFAULT '',
        espaciamiento_topes_front_solucion TEXT DEFAULT '',
        espaciamiento_topes_front_foto TEXT DEFAULT '',
        
        limpieza_debajo_puente_estado TEXT DEFAULT '',
        limpieza_debajo_puente_solucion TEXT DEFAULT '',
        limpieza_debajo_puente_foto TEXT DEFAULT '',

        limpieza_puente_estado TEXT DEFAULT '',
        limpieza_puente_solucion TEXT DEFAULT '',
        limpieza_puente_foto TEXT DEFAULT '',
        
        estado_servicio TEXT DEFAULT ''
      )
      ''');

      for (final column in [
        'campos_estado TEXT DEFAULT \'\'',
        'pruebas_iniciales TEXT DEFAULT \'\'',
        'pruebas_finales TEXT DEFAULT \'\'',
      ]) {
        await db
            .execute('ALTER TABLE verificaciones_internas ADD COLUMN $column');
      }

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

      String csv = Csv().encode(rows);

      String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Guardar archivo CSV',
        fileName:
            'verificaciones_internas${DateTime.now().toIso8601String()}.csv',
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
