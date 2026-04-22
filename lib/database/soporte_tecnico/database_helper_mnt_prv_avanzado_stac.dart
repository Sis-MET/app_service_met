import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelperMntPrvAvanzadoStac {
  static final DatabaseHelperMntPrvAvanzadoStac _instance =
      DatabaseHelperMntPrvAvanzadoStac._internal();
  factory DatabaseHelperMntPrvAvanzadoStac() => _instance;
  static Database? _database;
  static bool _isInitializing =
      false; // ← AGREGADO: Flag para evitar inicializaciones múltiples
  String get tableName => 'mnt_prv_avanzado_stac';

  DatabaseHelperMntPrvAvanzadoStac._internal();

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
        'mnt_prv_avanzado_stac',
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
        'mnt_prv_avanzado_stac',
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
      FROM mnt_prv_avanzado_stac 
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
      return await db.query('mnt_prv_avanzado_stac',
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
        'mnt_prv_avanzado_stac',
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
        'mnt_prv_avanzado_stac',
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
        'mnt_prv_avanzado_stac',
        where: 'otst = ? AND session_id = ?',
        whereArgs: [registro['otst'], registro['session_id']],
      );

      if (existing.isNotEmpty) {
        await db.update(
          'mnt_prv_avanzado_stac',
          registro,
          where: 'otst = ? AND session_id = ?',
          whereArgs: [registro['otst'], registro['session_id']],
        );
        debugPrint(
            'Registro ACTUALIZADO - OTST: ${registro['otst']}, Session: ${registro['session_id']}');
      } else {
        await db.insert('mnt_prv_avanzado_stac', registro);
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
      String path = join(await getDatabasesPath(), 'mnt_prv_avanzado_stac.db');

      // Crear directorio si no existe
      final directory = Directory(dirname(path));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Abrir/crear la base de datos
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
      debugPrint('Creando tabla mnt_prv_avanzado_stac...');

      await db.execute('''
      CREATE TABLE mnt_prv_avanzado_stac (
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
        
        -- Excentricidad Final
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
        posicion_final_7 TEXT DEFAULT '',
        indicacion_final_7 TEXT DEFAULT '',
        retorno_final_7 TEXT DEFAULT '',
        posicion_final_8 TEXT DEFAULT '',
        indicacion_final_8 TEXT DEFAULT '',
        retorno_final_8 TEXT DEFAULT '',
        posicion_final_9 TEXT DEFAULT '',
        indicacion_final_9 TEXT DEFAULT '',
        retorno_final_9 TEXT DEFAULT '',
        posicion_final_10 TEXT DEFAULT '',
        indicacion_final_10 TEXT DEFAULT '',
        retorno_final_10 TEXT DEFAULT '',
        posicion_final_11 TEXT DEFAULT '',
        indicacion_final_11 TEXT DEFAULT '',
        retorno_final_11 TEXT DEFAULT '',
        posicion_final_12 TEXT DEFAULT '',
        indicacion_final_12 TEXT DEFAULT '',
        retorno_final_12 TEXT DEFAULT '',
        
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
        
        -- Carga 1
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
        
        -- Linealidad Final
        linealidad_final_cantidad_puntos INTEGER DEFAULT '',
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
        otros_foto TEXT DEFAULT '',
        conclusion TEXT DEFAULT '',
        estado_servicio TEXT DEFAULT ''
      )
      ''');

      debugPrint('Tabla mnt_prv_avanzado_stac creada exitosamente');
    } catch (e) {
      debugPrint('Error creando tabla: $e');
      rethrow;
    }
  }

  Future<int> insertRegistroRelevamiento(Map<String, dynamic> registro) async {
    try {
      final db = await database;
      return await db.insert('mnt_prv_avanzado_stac', registro);
    } catch (e) {
      debugPrint('Error insertando registro: $e');
      rethrow;
    }
  }

  Future<void> exportDataToCSV() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> registros =
          await db.query('mnt_prv_avanzado_stac');

      if (registros.isEmpty) {
        debugPrint('No hay datos para exportar');
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add(registros.first.keys.toList());
      for (var registro in registros) {
        rows.add(registro.values.toList());
      }

      final String csv = const ListToCsvConverter().convert(rows);
      final Uint8List bytes = Uint8List.fromList(csv.codeUnits);
      final String fileName =
          'mnt_prv_avanzado_stac_${DateTime.now().millisecondsSinceEpoch}.csv';

      final params = SaveFileDialogParams(data: bytes, fileName: fileName);
      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (savedPath != null) {
        debugPrint('Datos exportados a $savedPath');
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
