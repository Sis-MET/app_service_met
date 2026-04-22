// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../../../../../../database/soporte_tecnico/database_helper_instalacion.dart';
import '../models/instalacion_model.dart';

class InstalacionController {
  final InstalacionModel model;
  final Map<String, List<File>> _fieldPhotos = {};

  InstalacionController({required this.model});

  // Gestión de fotos
  void agregarFoto(String campo, File foto) {
    if (!_fieldPhotos.containsKey(campo)) {
      _fieldPhotos[campo] = [];
    }

    if (_fieldPhotos[campo]!.length >= 5) {
      debugPrint('⚠️ Límite de 5 fotos alcanzado para: $campo');
      return;
    }

    _fieldPhotos[campo]!.add(foto);
    model.camposCondiciones[campo]?.agregarFoto(foto);
  }

  void eliminarFoto(String campo, int index) {
    if (_fieldPhotos.containsKey(campo) &&
        index < _fieldPhotos[campo]!.length) {
      _fieldPhotos[campo]!.removeAt(index);
      model.camposCondiciones[campo]?.eliminarFoto(index);
    }
  }

  void limpiarFotos() {
    _fieldPhotos.clear();
    model.camposCondiciones.forEach((key, value) {
      value.limpiarFotos();
    });
  }

  // Guardar datos en BD
  Future<void> saveDataToDatabase(BuildContext context,
      {bool showMessage = true}) async {
    try {
      final dbHelper = DatabaseHelperInstalacion();
      final Map<String, dynamic> dbData = _prepareDataForSave();

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

  // Guardar datos + Zip
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
        '${model.secaValue}_${model.codMetrica}_instalacion_${DateTime.now().millisecondsSinceEpoch}.zip';

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

  Map<String, dynamic> _prepareDataForSave() {
    final data = <String, dynamic>{
      'session_id': model.sessionId,
      'cod_metrica': model.codMetrica,
      'otst': model.secaValue,
      'tipo_servicio': 'INS.BL',
      'hora_inicio': model.horaInicio,
      'hora_fin': model.horaFin,
      'estado_servicio': 'Completo',
    };

    // Mapeo de Condiciones de Instalación
    final mapKeys = {
      'Entorno': 'entorno',
      'Superficie de Apoyo': 'superficie_apoyo',
      'Tensión de Red': 'tension_red',
      'Sistema de Tierra': 'sistema_tierra',
      'Comunicación PC/Impresora': 'comunicacion_pc',
      'Movilización': 'movilizacion',
      'Vibración Externa': 'vibracion_externa',
      'Flujo de Pesadas': 'flujo_pesadas',
    };

    mapKeys.forEach((modelKey, dbPrefix) {
      final campo = model.camposCondiciones[modelKey];
      if (campo != null) {
        data['${dbPrefix}_valor'] = campo.initialValue;
        data['${dbPrefix}_comentario'] = campo.comentario;
      }
    });

    // NUEVOS CAMPOS (V3)
    data['comentario_general'] = model.comentarioGeneral;
    data['recomendacion'] = model.recomendacion;
    data['fecha_prox_servicio'] = model.fechaProxServicio;
    data['estado_fisico'] = model.estadoFisico;
    data['estado_operacional'] = model.estadoOperacional;
    data['estado_metrologico'] = model.estadoMetrologico;

    // Pruebas Metrológicas (Iniciales)
    _addPruebasMetrologicasData(data);

    return data;
  }

  void _addPruebasMetrologicasData(Map<String, dynamic> data) {
    // Retorno a Cero
    data['retorno_cero_inicial_valoracion'] =
        model.pruebasIniciales.retornoCero.estado;
    data['retorno_cero_inicial_carga'] =
        model.pruebasIniciales.retornoCero.valor;
    data['retorno_cero_inicial_unidad'] =
        model.pruebasIniciales.retornoCero.unidad;
    data['retorno_cero_inicial_estabilidad'] =
        model.pruebasIniciales.retornoCero.estabilidad; // NUEVO (V3)

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
      // Map new column names
      data['tipo_plataforma_$tipo'] = exc!.tipoPlataforma ?? '';
      data['puntos_ind_$tipo'] = exc.puntosIndicador ?? '';
      data['carga_exc_$tipo'] = exc.carga;
      // data['ruta_imagen_$tipo'] = exc.imagenPath ?? ''; // Removed from DB definition

      for (int i = 0; i < exc.posiciones.length; i++) {
        final pos = exc.posiciones[i];
        final num = i + 1;

        if (num <= 6) {
          data['posicion_${tipo}_$num'] = pos.posicion;
          data['indicacion_${tipo}_$num'] = pos.indicacion;
          data['retorno_${tipo}_$num'] = pos.retorno;
        } else if (num <= 12) {
          // For 7-12, schema only has indicacion & retorno under new names
          // indicacion_inicial_7, retorno_inicial_7 etc.
          data['indicacion_${tipo}_$num'] = pos.indicacion;
          data['retorno_${tipo}_$num'] = pos.retorno;
        }
      }
    }
  }

  void _addRepetibilidadData(
      Map<String, dynamic> data, Repetibilidad? rep, String tipo) {
    if (rep?.activo ?? false) {
      // New names: repetibilidad_inicial_cantidad_cargas
      data['repetibilidad_${tipo}_cantidad_cargas'] = rep!.cantidadCargas;
      data['repetibilidad_${tipo}_cantidad_pruebas'] = rep.cantidadPruebas;

      for (int i = 0; i < rep.cargas.length; i++) {
        final carga = rep.cargas[i];
        final cargaNum = i + 1; // 1, 2, 3

        // DB: repetibilidad1_inicial (value of load)
        data['repetibilidad${cargaNum}_$tipo'] = carga.valor;

        for (int j = 0; j < carga.pruebas.length; j++) {
          final prueba = carga.pruebas[j];
          final testNum = j + 1; // 1 to 10

          // DB: indicacion1_inicial_1, retorno1_inicial_1
          data['indicacion${cargaNum}_${tipo}_$testNum'] = prueba.indicacion;
          data['retorno${cargaNum}_${tipo}_$testNum'] = prueba.retorno;
        }
      }
    }
  }

  void _addLinealidadData(
      Map<String, dynamic> data, Linealidad? lin, String tipo) {
    if (lin?.activo ?? false) {
      data['linealidad_${tipo}_cantidad_puntos'] = lin!.puntos.length;
      for (int i = 0; i < lin.puntos.length; i++) {
        final punto = lin.puntos[i];
        final num = i + 1;

        // New names: lin_inicial_1, ind_inicial_1, retorno_lin_inicial_1
        data['lin_${tipo}_$num'] = punto.lt;
        data['ind_${tipo}_$num'] = punto.indicacion;
        data['retorno_lin_${tipo}_$num'] = punto.retorno;
      }
    }
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

  // Obtener d1 desde la base de datos
  Future<double> getD1FromDatabase() async {
    try {
      final dbHelper = DatabaseHelperInstalacion();
      final d1Value = await dbHelper.getD1(model.codMetrica);
      return d1Value;
    } catch (e) {
      debugPrint('Error al obtener d1: $e');
      return 0.1; // Valor por defecto
    }
  }

  // Decimal helpers
  Future<List<String>> getIndicationSuggestions(
      String cargaText, String currentValue) async {
    try {
      final d1 = await getD1FromDatabase();

      // Usar el valor actual o la carga como base
      final baseValue = double.tryParse(
            (currentValue.isEmpty ? cargaText : currentValue)
                .replaceAll(',', '.'),
          ) ??
          0.0;

      // Calcular decimales basados en d1
      int decimals = 0;
      if (d1 % 1 != 0) {
        String d1Str = d1.toString();
        if (d1Str.contains('.')) {
          decimals = d1Str.split('.')[1].length;
        } else {
          decimals = 1;
        }
      }

      // Generar 11 sugerencias (5 abajo, actual, 5 arriba)
      return List.generate(11, (i) {
        final value = baseValue + ((i - 5) * d1);
        return value.toStringAsFixed(decimals);
      });
    } catch (e) {
      debugPrint('Error generando sugerencias: $e');
      return [];
    }
  }
}
