// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../../../../../../database/soporte_tecnico/database_helper_verificaciones.dart';
import '../models/verificaciones_internas_model.dart';

class VerificacionesInternasController {
  final VerificacionesInternasModel model;
  final Map<String, List<File>> _fieldPhotos = {};

  Timer? _autoSaveTimer;
  final ValueNotifier<bool> isAutoSaving = ValueNotifier(false);
  final ValueNotifier<bool> lastSaveSuccessful = ValueNotifier(true);

  VerificacionesInternasController({required this.model});

  void dispose() {
    _autoSaveTimer?.cancel();
    isAutoSaving.dispose();
    lastSaveSuccessful.dispose();
  }

  void scheduleAutoSave(BuildContext context) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () {
      _autoSave(context);
    });
  }

  Future<void> flushAutoSave(BuildContext context) async {
    _autoSaveTimer?.cancel();
    await _autoSave(context);
  }

  Future<void> _autoSave(BuildContext context) async {
    if (isAutoSaving.value) return;
    isAutoSaving.value = true;

    try {
      await saveDataToDatabase(context, showMessage: false);
      lastSaveSuccessful.value = true;
    } catch (e) {
      lastSaveSuccessful.value = false;
      debugPrint('Error en auto-guardado (Verific Internas): $e');
    } finally {
      isAutoSaving.value = false;
    }
  }

  Future<void> loadInitialValues() async {
    try {
      final dbHelper = DatabaseHelperVerificaciones();
      final db = await dbHelper.database;
      final results = await db.query(
        'verificaciones_internas',
        where: 'session_id = ? AND otst = ?',
        whereArgs: [model.sessionId, model.secaValue],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final registro = results.first;

        model.horaFin = registro['hora_fin']?.toString() ?? '';
        model.comentarioGeneral = registro['comentario_general']?.toString() ?? '';
        model.recomendacion = registro['recomendacion']?.toString() ?? '';
        model.estadoFisico = registro['fisico']?.toString() ?? '';
        model.estadoOperacional = registro['operacional']?.toString() ?? '';
        model.estadoMetrologico = registro['metrologico']?.toString() ?? '';
        model.fechaProxServicio = registro['fecha_prox_servicio']?.toString() ?? '';
        
        // Mapear campos de ESTADO
        final camposMap = {
          'espaciamiento_topes_long': 'Espaciamiento topes longitudinales',
          'espaciamiento_topes_front': 'Espaciamiento topes frontales',
          'limpieza_puente': 'Limpieza del puente de pesaje',
          'limpieza_debajo_puente': 'Limpieza debajo del puente',
        };

        camposMap.forEach((dbKey, modelKey) {
          if (model.camposEstado.containsKey(modelKey)) {
            final estado = registro['${dbKey}_estado']?.toString();
            final solucion = registro['${dbKey}_solucion']?.toString();
            if (estado != null && estado.isNotEmpty) {
              model.camposEstado[modelKey]!.initialValue = estado;
            }
            if (solucion != null && solucion.isNotEmpty) {
              model.camposEstado[modelKey]!.solutionValue = solucion;
            }
          }
        });

        // Pruebas Iniciales
        final retCeroIniEst = registro['retorno_cero_inicial_valoracion']?.toString();
        if (retCeroIniEst != null && retCeroIniEst.isNotEmpty) {
           model.pruebasIniciales.retornoCero.estado = retCeroIniEst;
        }
        final retCeroIniVal = registro['retorno_cero_inicial_carga']?.toString();
        if (retCeroIniVal != null && retCeroIniVal.isNotEmpty) {
           model.pruebasIniciales.retornoCero.valor = retCeroIniVal;
        }

        _loadExcentricidadData(registro, model.pruebasIniciales, 'inicial');
        _loadRepetibilidadData(registro, model.pruebasIniciales, 'inicial');
        _loadLinealidadData(registro, model.pruebasIniciales, 'inicial');
      }
    } catch (e) {
      debugPrint('Error al cargar initial values en Verificaciones Internas: $e');
    }
  }

  void _loadExcentricidadData(Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
    final tipoPlataforma = registro['tipo_plataforma_$tipo']?.toString();
    if (tipoPlataforma != null && tipoPlataforma.isNotEmpty) {
      pruebas.excentricidad ??= Excentricidad();
      final exc = pruebas.excentricidad!;
      exc.activo = true;
      exc.tipoPlataforma = tipoPlataforma;
      exc.puntosIndicador = registro['puntos_ind_$tipo']?.toString() ?? '';
      // Si "carga_exc_inicial" no existiese usa fallback `carga` pero su map guarda en carga_exc_$tipo
      exc.carga = registro['carga_exc_$tipo']?.toString() ?? '';

      exc.posiciones.clear();
      for (int i = 0; i < 6; i++) {
        final posVal = registro['posicion_${tipo}_${i + 1}']?.toString();
        if (posVal != null && posVal.isNotEmpty) {
          exc.posiciones.add(PosicionExcentricidad(
            posicion: posVal,
            indicacion: registro['indicacion_${tipo}_${i + 1}']?.toString() ?? '',
            retorno: registro['retorno_${tipo}_${i + 1}']?.toString() ?? '0',
          ));
        }
      }
    }
  }

  void _loadRepetibilidadData(Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
    final carga1Str = registro['repetibilidad1_$tipo']?.toString();
    if (carga1Str != null && carga1Str.isNotEmpty) {
      pruebas.repetibilidad ??= Repetibilidad();
      final rep = pruebas.repetibilidad!;
      rep.activo = true;
      
      rep.cargas.clear();
      final carga1 = CargaRepetibilidad(valor: carga1Str);
      carga1.pruebas.clear();

      for (int j = 0; j < 10; j++) {
        final ind = registro['indicacion1_${tipo}_${j + 1}']?.toString();
        if (ind != null && ind.isNotEmpty) {
          carga1.pruebas.add(PruebaRepetibilidad(
            indicacion: ind,
            retorno: registro['retorno1_${tipo}_${j + 1}']?.toString() ?? '0',
          ));
        }
      }

      if (carga1.pruebas.isNotEmpty) {
        rep.cargas.add(carga1);
        rep.cantidadPruebas = carga1.pruebas.length;
      }
    }
  }

  void _loadLinealidadData(Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
    final lin1Str = registro['lin_${tipo}_1']?.toString();
    if (lin1Str != null && lin1Str.isNotEmpty) {
      pruebas.linealidad ??= Linealidad();
      final lin = pruebas.linealidad!;
      lin.activo = true;
      lin.puntos.clear();

      for (int i = 0; i < 12; i++) {
        final ptVal = registro['lin_${tipo}_${i + 1}']?.toString();
        if (ptVal != null && ptVal.isNotEmpty) {
          lin.puntos.add(PuntoLinealidad(
            lt: ptVal,
            indicacion: registro['ind_${tipo}_${i + 1}']?.toString() ?? '',
            retorno: registro['retorno_lin_${tipo}_${i + 1}']?.toString() ?? '0',
          ));
        }
      }
    }
  }

  void copiarPruebasInicialesAFinales() {
    model.copiarPruebasInicialesAFinales();
  }

  // Obtener d1 desde la base de datos
  Future<double> getD1FromDatabase() async {
    try {
      final dbHelper = DatabaseHelperVerificaciones();
      final db = await dbHelper.database;

      final results = await db.query(
        'verificaciones_internas',
        columns: ['d1'],
        where: 'session_id = ? AND cod_metrica = ?',
        whereArgs: [model.sessionId, model.codMetrica],
        limit: 1,
      );

      if (results.isNotEmpty && results.first['d1'] != null) {
        final d1Value = results.first['d1'];
        if (d1Value is double) {
          return d1Value;
        } else if (d1Value is int) {
          return d1Value.toDouble();
        } else if (d1Value is String) {
          return double.tryParse(d1Value) ?? 0.1;
        }
      }

      return 0.1;
    } catch (e) {
      debugPrint('Error al obtener d1: $e');
      return 0.1;
    }
  }

  // Lógica de decimales adaptada para carga
  Future<double> getDForCarga(double carga) async {
    try {
      final dbHelper = DatabaseHelperVerificaciones();
      final db = await dbHelper.database;

      final results = await db.query(
        'verificaciones_internas',
        columns: ['d1', 'd2', 'd3', 'cap_max1', 'cap_max2', 'cap_max3'],
        where: 'session_id = ? AND cod_metrica = ?',
        whereArgs: [model.sessionId, model.codMetrica],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final data = results.first;
        final d1 = double.tryParse(data['d1']?.toString() ?? '') ?? 0.1;
        final d2 = double.tryParse(data['d2']?.toString() ?? '') ?? 0.1;
        final d3 = double.tryParse(data['d3']?.toString() ?? '') ?? 0.1;

        final capMax1 =
            double.tryParse(data['cap_max1']?.toString() ?? '') ?? 0.0;
        final capMax2 =
            double.tryParse(data['cap_max2']?.toString() ?? '') ?? 0.0;
        final capMax3 =
            double.tryParse(data['cap_max3']?.toString() ?? '') ?? 0.0;

        if (carga <= capMax1 && capMax1 > 0) return d1;
        if (carga <= capMax2 && capMax2 > 0) return d2;
        if (carga <= capMax3 && capMax3 > 0) return d3;
        return d1;
      }
      return 0.1;
    } catch (e) {
      debugPrint('Error al obtener D: $e');
      return 0.1;
    }
  }

  int getDecimalPlaces(double dValue) {
    if (dValue >= 1) return 0;
    if (dValue >= 0.1) return 1;
    if (dValue >= 0.01) return 2;
    if (dValue >= 0.001) return 3;
    return 1;
  }

  Future<List<String>> getIndicationSuggestions(
      String cargaText, String currentValue) async {
    final carga = double.tryParse(cargaText.replaceAll(',', '.')) ?? 0.0;
    final dValue = await getDForCarga(carga);
    final decimalPlaces = getDecimalPlaces(dValue);

    final baseText = currentValue.trim().isEmpty ? cargaText : currentValue;
    final baseValue = double.tryParse(baseText.replaceAll(',', '.')) ?? carga;

    return List.generate(11, (i) {
      final value = baseValue + ((i - 5) * dValue);
      return value.toStringAsFixed(decimalPlaces);
    });
  }

  // Guardar datos en BD
  Future<void> saveDataToDatabase(BuildContext context,
      {bool showMessage = true}) async {
    try {
      final dbHelper = DatabaseHelperVerificaciones();
      final Map<String, dynamic> dbData = _prepareDataForSave();

      // IDs clave
      dbData['session_id'] = model.sessionId;
      dbData['otst'] = model.secaValue;
      dbData['cod_metrica'] = model.codMetrica;

      await dbHelper.upsertRegistroRelevamiento(dbData);

      if (showMessage && context.mounted) {
        _showSnackBar(
          context,
          'Datos guardados exitosamente',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('Error al guardar en BD: $e');
      if (showMessage && context.mounted) {
        _showSnackBar(
          context,
          'Error al guardar: ${e.toString()}',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
      rethrow;
    }
  }

  Future<void> saveData(BuildContext context) async {
    try {
      await _savePhotos(context);
      await saveDataToDatabase(context, showMessage: true);
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Error al guardar datos: ${e.toString()}',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  bool _isServiceComplete() {
    return model.estadoFisico.isNotEmpty &&
        model.estadoOperacional.isNotEmpty &&
        model.estadoMetrologico.isNotEmpty &&
        model.fechaProxServicio.isNotEmpty &&
        model.horaFin.isNotEmpty;
  }

  // Preparar mapa de datos para BD
  Map<String, dynamic> _prepareDataForSave() {
    final data = <String, dynamic>{
      'estado_servicio': _isServiceComplete() ? 'Completo' : 'Pendiente',
      'tipo_servicio': 'VIN.SP',
      'hora_inicio': model.horaInicio,
      'hora_fin': model.horaFin,
      'comentario_general': model.comentarioGeneral,
      'recomendacion': model.recomendacion,
      'fisico': model.estadoFisico,
      'operacional': model.estadoOperacional,
      'metrologico': model.estadoMetrologico,
      'fecha_prox_servicio': model.fechaProxServicio,
    };

    _addCamposEstadoData(data);
    _addPruebasMetrologicasData(data);

    return data;
  }

  // Agregar datos de campos de estado
  void _addCamposEstadoData(Map<String, dynamic> data) {
    void addCampo(String dbKey, String modelKey) {
      final campo = model.camposEstado[modelKey];
      if (campo != null) {
        data['${dbKey}_estado'] = campo.initialValue;
        data['${dbKey}_solucion'] = campo.solutionValue;
        data['${dbKey}_foto'] = campo.fotos.isNotEmpty
            ? campo.fotos.map((f) => f.path.split('/').last).join(',')
            : '';
      }
    }

    final camposMap = {
      // Inspección Visual (NUEVOS CAMPOS SIMPLIFICADOS)
      'espaciamiento_topes_long': 'Espaciamiento topes longitudinales',
      'espaciamiento_topes_front': 'Espaciamiento topes frontales',
      'limpieza_puente': 'Limpieza del puente de pesaje',
      'limpieza_debajo_puente': 'Limpieza debajo del puente',
    };

    camposMap.forEach((dbKey, modelKey) => addCampo(dbKey, modelKey));
  }

  void _addPruebasMetrologicasData(Map<String, dynamic> data) {
    // Retorno a Cero Inicial
    data['retorno_cero_inicial_valoracion'] =
        model.pruebasIniciales.retornoCero.estado;
    data['retorno_cero_inicial_carga'] =
        model.pruebasIniciales.retornoCero.valor;
    data['retorno_cero_inicial_unidad'] =
        model.pruebasIniciales.retornoCero.unidad;

    // Pruebas Iniciales
    _addExcentricidadData(
        data, model.pruebasIniciales.excentricidad, 'inicial');
    _addRepetibilidadData(
        data, model.pruebasIniciales.repetibilidad, 'inicial');
    _addLinealidadData(data, model.pruebasIniciales.linealidad, 'inicial');
  }

  void _addExcentricidadData(
      Map<String, dynamic> data, Excentricidad? exc, String tipo) {
    if (exc?.activo ?? false) {
      data['tipo_plataforma_$tipo'] = exc!.tipoPlataforma ?? '';
      data['puntos_ind_$tipo'] = exc.puntosIndicador ?? '';
      data['carga_exc_$tipo'] = exc.carga;

      for (int i = 0; i < exc.posiciones.length; i++) {
        final pos = exc.posiciones[i];
        final num = i + 1;

        // La base de datos solo soporta hasta 6 etiquetas de posición
        if (num <= 6) {
          data['posicion_${tipo}_$num'] = pos.posicion;
        }

        // La base de datos soporta hasta 12 puntos de indicación y retorno
        if (num <= 12) {
          data['indicacion_${tipo}_$num'] = pos.indicacion;
          data['retorno_${tipo}_$num'] = pos.retorno;
        }
      }
    }
  }

  void _addRepetibilidadData(
      Map<String, dynamic> data, Repetibilidad? rep, String tipo) {
    if (rep?.activo ?? false) {
      for (int i = 0; i < rep!.cargas.length; i++) {
        final carga = rep.cargas[i];
        final cargaNum = i + 1;
        data['repetibilidad${cargaNum}_$tipo'] = carga.valor;

        for (int j = 0; j < carga.pruebas.length; j++) {
          final prueba = carga.pruebas[j];
          final testNum = j + 1;
          data['indicacion${cargaNum}_${tipo}_$testNum'] = prueba.indicacion;
          data['retorno${cargaNum}_${tipo}_$testNum'] = prueba.retorno;
        }
      }
    }
  }

  void _addLinealidadData(
      Map<String, dynamic> data, Linealidad? lin, String tipo) {
    if (lin?.activo ?? false) {
      for (int i = 0; i < lin!.puntos.length; i++) {
        final punto = lin.puntos[i];
        final num = i + 1;
        data['lin_${tipo}_$num'] = punto.lt;
        data['ind_${tipo}_$num'] = punto.indicacion;
        data['retorno_lin_${tipo}_$num'] = punto.retorno;
      }
    }
  }

  // Gestión de fotos
  void agregarFoto(String campo, File foto) {
    if (!_fieldPhotos.containsKey(campo)) {
      _fieldPhotos[campo] = [];
    }
    if (_fieldPhotos[campo]!.length >= 5) return;

    _fieldPhotos[campo]!.add(foto);
    model.camposEstado[campo]?.agregarFoto(foto);
  }

  void eliminarFoto(String campo, int index) {
    if (_fieldPhotos.containsKey(campo) &&
        index < _fieldPhotos[campo]!.length) {
      _fieldPhotos[campo]!.removeAt(index);
      model.camposEstado[campo]?.eliminarFoto(index);
    }
  }

  void limpiarFotos() {
    _fieldPhotos.clear();
    model.camposEstado.forEach((key, value) {
      value.limpiarFotos();
    });
  }

  Future<void> _savePhotos(BuildContext context) async {
    bool hasPhotos = _fieldPhotos.values.any((photos) => photos.isNotEmpty);
    if (!hasPhotos) return;

    final archive = Archive();

    _fieldPhotos.forEach((label, photos) {
      for (var i = 0; i < photos.length; i++) {
        final file = photos[i];
        final fileName = '${_sanitizeFileName(label)}_${i + 1}.jpg';
        archive.addFile(ArchiveFile(
          fileName,
          file.lengthSync(),
          file.readAsBytesSync(),
        ));
      }
    });

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    final uint8ListData = Uint8List.fromList(zipData);
    final zipFileName =
        '${model.secaValue}_${model.codMetrica}_fotos_${DateTime.now().millisecondsSinceEpoch}.zip';

    final params = SaveFileDialogParams(
      data: uint8ListData,
      fileName: zipFileName,
      mimeTypesFilter: ['application/zip'],
    );

    try {
      await FlutterFileDialog.saveFile(params: params);
    } catch (e) {
      debugPrint('Error saving file: $e');
    }
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w\-]'), '');
  }

  void _showSnackBar(BuildContext context, String message,
      {Color? backgroundColor, Color? textColor}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: TextStyle(color: textColor ?? Colors.white)),
        backgroundColor: backgroundColor ?? Colors.grey[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
