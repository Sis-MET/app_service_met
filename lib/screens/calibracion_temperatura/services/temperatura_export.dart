import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../models/temperatura_models.dart';
import 'temperatura_resultados.dart';

/// Lo que sale del teléfono: el cuerpo de la subida a DataMET y el CSV para
/// el laboratorio.
abstract final class TemperaturaExport {
  /// Cuerpo de `POST /api/calibracion/temperatura`. Las imágenes de
  /// evidencia, el recuadro y el perfil del lector se quedan en el teléfono.
  static Map<String, Object?> uploadJson(TempPaquete paquete) {
    final s = paquete.servicio;
    final equipo = s.equipo;
    return {
      'uuid': s.uuid,
      'codigo_registro': s.codigoRegistro,
      'seca': s.seca,
      'session_id': s.sessionId,
      'estado': s.estado.valor,
      'cod_metrica': equipo?.codMetrica,
      'equipo_nuevo': equipo?.nuevo ?? false,
      'codigo_cliente': s.cliente?.codigo,
      'cliente': s.cliente?.nombre,
      'razon_social': s.cliente?.razonSocial,
      'cod_planta': s.planta?.codigo,
      'planta': s.planta?.nombre,
      'dep': s.planta?.departamento,
      'dir': s.planta?.direccion,
      'tipo_equipo': equipo?.tipo,
      'instrumento': equipo?.instrumento,
      'marca': equipo?.marca,
      'modelo': equipo?.modelo,
      'serie': equipo?.serie,
      'cod_interno': equipo?.codInterno,
      'ubicacion': equipo?.ubicacion,
      'rango_min': equipo?.rangoMin,
      'rango_max': equipo?.rangoMax,
      'unidad': equipo?.unidad,
      'resolucion': equipo?.resolucion,
      'indicador': equipo?.indicador,
      'temp_amb_inicio': s.ambiente.temperaturaInicio,
      'hr_inicio': s.ambiente.humedadInicio,
      'temp_amb_fin': s.ambiente.temperaturaFin,
      'hr_fin': s.ambiente.humedadFin,
      'fecha_servicio': s.fechaServicio,
      'hora_inicio': s.horaInicio,
      'hora_fin': s.horaFin,
      'personal': s.personal,
      'observaciones': s.observaciones,
      'registro_sensores': s.registroSensores,
      'app_version': s.appVersion,
      'finalizado_en': s.finalizadoEn,
      'gps': paquete.ubicacion,
      'patrones': [
        for (var i = 0; i < paquete.patrones.length; i++)
          {
            'n': i + 1,
            'cod_instrumento': paquete.patrones[i].codInstrumento,
            'instrumento': paquete.patrones[i].instrumento,
            'cert_fecha': paquete.patrones[i].certFecha,
            'ente_calibrador': paquete.patrones[i].enteCalibrador,
            'estado': paquete.patrones[i].estado,
            'uso': paquete.patrones[i].uso,
          },
      ],
      'canales': [
        for (final canal in paquete.canales)
          {
            'n_canal': canal.n,
            'nombre': canal.nombre,
            'rol': canal.rol.valor,
            'cod_patron': canal.codPatron,
            'posicion': canal.posicion,
            'metodo': canal.metodo.valor,
            'decimales': canal.decimales,
          },
      ],
      'puntos': [
        for (final punto in paquete.puntos)
          {
            'n_punto': punto.n,
            'temperatura_nominal': punto.temperaturaNominal,
            'estabilizacion_min': punto.estabilizacionMin,
            'duracion_min': punto.duracionMin,
            'intervalo_s': punto.intervaloS,
            'lecturas_programadas': punto.lecturas,
            'estado': punto.estado.valor,
            'inicio_medicion': punto.inicioMedicion,
            'fin_medicion': punto.finMedicion,
            'motivo_interrupcion': punto.motivoInterrupcion,
            'observaciones': punto.observaciones,
          },
      ],
      'lecturas': [
        for (final lectura in paquete.lecturas)
          {
            'n_punto': lectura.nPunto,
            'n_lectura': lectura.nLectura,
            'n_canal': lectura.nCanal,
            'tiempo_programado_s': lectura.tiempoProgramadoS,
            'capturada_en': lectura.capturadaEn,
            'valor': lectura.valor,
            'valor_original': lectura.valorOriginal,
            'texto_leido': lectura.textoLeido,
            'origen': lectura.origen.valor,
            'coincidencia': lectura.coincidencia,
            'cuadros': lectura.cuadros,
            'alerta': lectura.alerta,
            'estado': lectura.estado.valor,
            'motivo': lectura.motivo,
          },
      ],
      'correcciones': [
        for (final correccion in paquete.correcciones)
          {
            'n_punto': correccion.nPunto,
            'n_lectura': correccion.nLectura,
            'n_canal': correccion.nCanal,
            'tipo': correccion.tipo.valor,
            'valor_anterior': correccion.valorAnterior,
            'valor_nuevo': correccion.valorNuevo,
            'motivo': correccion.motivo,
            'usuario': correccion.usuario,
            'fecha': correccion.fecha,
          },
      ],
    };
  }

  /// `TEMP_<SECA>_<COD>.csv`.
  static String csvFileName(TempServicio servicio) {
    String limpio(String? texto) =>
        (texto ?? '').replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return 'TEMP_${limpio(servicio.seca)}_${limpio(servicio.equipo?.codMetrica)}.csv';
  }

  /// Un CSV con separador «;» (como los demás de la app): la ficha, una fila
  /// por lectura programada con una columna por canal, y los resultados
  /// preliminares de cada punto.
  static Uint8List csv(TempPaquete paquete) {
    final s = paquete.servicio;
    final equipo = s.equipo;
    final unidad = equipo?.unidad ?? '°C';
    final rows = <List<Object?>>[
      ['Calibración de temperatura', codigoServicioTemperatura],
      ['SECA', s.seca],
      ['Código de registro', s.codigoRegistro],
      ['Cliente', s.cliente?.nombre],
      ['Planta', s.planta?.nombre],
      ['Equipo', equipo?.tipo, equipo?.codMetrica],
      ['Marca / modelo / serie', equipo?.marca, equipo?.modelo, equipo?.serie],
      [
        'Rango',
        textoNumero(equipo?.rangoMin),
        textoNumero(equipo?.rangoMax),
        unidad
      ],
      ['Resolución', textoNumero(equipo?.resolucion)],
      ['Técnico', s.personal],
      ['Inicio', s.horaInicio],
      ['Fin', s.horaFin],
      [
        'Ambiente inicio (°C / %HR)',
        textoNumero(s.ambiente.temperaturaInicio),
        textoNumero(s.ambiente.humedadInicio),
      ],
      [
        'Ambiente fin (°C / %HR)',
        textoNumero(s.ambiente.temperaturaFin),
        textoNumero(s.ambiente.humedadFin),
      ],
      [
        'Patrones',
        ...paquete.patrones.map((p) => '${p.codInstrumento} (${p.uso})'),
      ],
      [
        'Sensores (en su software)',
        ...paquete.sensores.map((c) => [c.nombre, c.codPatron, c.posicion]
            .whereType<String>()
            .join(' · ')),
      ],
      ['Registro de los sensores', s.registroSensores],
      [],
    ];
    final leidos = paquete.canalesLeidos;
    for (final punto in paquete.puntos) {
      if (punto.estado == EstadoPunto.pendiente) continue;
      rows.add([
        'Punto ${punto.n}',
        '${textoNumero(punto.temperaturaNominal)} $unidad',
        '${punto.lecturas} lecturas cada ${punto.intervaloS} s',
        punto.estado.etiqueta,
        punto.motivoInterrupcion,
      ]);
      rows.add([
        'Lectura',
        'Tiempo (s)',
        for (final canal in leidos)
          '${canal.nombre} (${canal.rol.etiqueta}) [$unidad]',
        'Hora',
      ]);
      final lecturas = paquete.lecturasDe(punto.n);
      final porNumero = <int, Map<int, TempLectura>>{};
      for (final lectura in lecturas) {
        porNumero.putIfAbsent(lectura.nLectura, () => {})[lectura.nCanal] =
            lectura;
      }
      final numeros = porNumero.keys.toList()..sort();
      for (final n in numeros) {
        final fila = porNumero[n]!;
        rows.add([
          n,
          fila.values.first.tiempoProgramadoS,
          for (final canal in leidos) _celda(fila[canal.n], canal),
          fila.values
              .map((l) => l.capturadaEn)
              .reduce((a, b) => a.compareTo(b) <= 0 ? a : b),
        ]);
      }
      final resumen =
          TemperaturaResultados.punto(punto, paquete.canales, lecturas);
      rows.add([
        'Promedio',
        '',
        for (final c in resumen.canales)
          _numero(c.promedio, c.canal.decimales + 2),
      ]);
      rows.add([
        'Desv. estándar',
        '',
        for (final c in resumen.canales)
          _numero(c.desviacion, c.canal.decimales + 2),
      ]);
      rows.add([
        'Máx − mín',
        '',
        for (final c in resumen.canales)
          _numero(c.variacion, c.canal.decimales + 1),
      ]);
      rows.add(['Temperatura del patrón', _numero(resumen.patron, 3)]);
      if (resumen.uniformidad != null) {
        rows.add(['Uniformidad', _numero(resumen.uniformidad, 3)]);
      }
      for (final entry in resumen.errores.entries) {
        final canal = paquete.canales.firstWhere((c) => c.n == entry.key);
        rows.add(
            ['Error de indicación (${canal.nombre})', _numero(entry.value, 3)]);
      }
      rows.add([]);
    }
    if (paquete.correcciones.isNotEmpty) {
      rows.add(['Correcciones']);
      rows.add([
        'Punto',
        'Lectura',
        'Canal',
        'Tipo',
        'Anterior',
        'Nuevo',
        'Motivo',
        'Usuario',
        'Fecha'
      ]);
      for (final c in paquete.correcciones) {
        rows.add([
          c.nPunto,
          c.nLectura,
          c.nCanal,
          c.tipo.etiqueta,
          textoNumero(c.valorAnterior),
          textoNumero(c.valorNuevo),
          c.motivo,
          c.usuario,
          c.fecha,
        ]);
      }
      rows.add([]);
    }
    rows.add([
      'Resultados preliminares: sin correcciones del certificado del patrón '
          'ni incertidumbre.',
    ]);
    final text = Csv(fieldDelimiter: ';', autoDetect: false).encode(rows);
    // Con BOM, para que Excel lea los acentos.
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
  }

  static String _celda(TempLectura? lectura, TempCanal canal) {
    if (lectura == null) return '';
    return switch (lectura.estado) {
      EstadoLectura.sinLectura => 'sin lectura',
      EstadoLectura.excluida =>
        '${textoNumero(lectura.valor, decimales: canal.decimales)} (excluida)',
      EstadoLectura.valida =>
        textoNumero(lectura.valor, decimales: canal.decimales),
    };
  }

  static String _numero(double? valor, int decimales) =>
      valor == null ? '' : valor.toStringAsFixed(decimales);
}
