class ServiceSession {
  final SessionInfo sessionInfo;
  final ClienteInfo? cliente;
  final PlantaInfo? planta;
  final BalanzaInfo? balanza;
  final List<EquipoInfo> equipos;
  final InspeccionVisual? inspeccion;
  final PrecargasAjuste? precargasAjuste;
  final ExcentricidadData? excentricidad;
  final RepetibilidadData? repetibilidad;
  final LinealidadData? linealidad;
  final CondicionesFinales? condicionesFinales;
  final ExportacionData? exportacion;
  final SessionMetadata metadata;

  ServiceSession({
    required this.sessionInfo,
    this.cliente,
    this.planta,
    this.balanza,
    this.equipos = const [],
    this.inspeccion,
    this.precargasAjuste,
    this.excentricidad,
    this.repetibilidad,
    this.linealidad,
    this.condicionesFinales,
    this.exportacion,
    required this.metadata,
  });

  ServiceSession copyWith({
    SessionInfo? sessionInfo,
    ClienteInfo? cliente,
    PlantaInfo? planta,
    BalanzaInfo? balanza,
    List<EquipoInfo>? equipos,
    InspeccionVisual? inspeccion,
    PrecargasAjuste? precargasAjuste,
    ExcentricidadData? excentricidad,
    RepetibilidadData? repetibilidad,
    LinealidadData? linealidad,
    CondicionesFinales? condicionesFinales,
    ExportacionData? exportacion,
    SessionMetadata? metadata,
  }) {
    return ServiceSession(
      sessionInfo: sessionInfo ?? this.sessionInfo,
      cliente: cliente ?? this.cliente,
      planta: planta ?? this.planta,
      balanza: balanza ?? this.balanza,
      equipos: equipos ?? this.equipos,
      inspeccion: inspeccion ?? this.inspeccion,
      precargasAjuste: precargasAjuste ?? this.precargasAjuste,
      excentricidad: excentricidad ?? this.excentricidad,
      repetibilidad: repetibilidad ?? this.repetibilidad,
      linealidad: linealidad ?? this.linealidad,
      condicionesFinales: condicionesFinales ?? this.condicionesFinales,
      exportacion: exportacion ?? this.exportacion,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    bool isPesa(EquipoInfo e) {
      final tipo = e.tipo?.toLowerCase() ?? '';
      return tipo.contains('pesa') ||
          tipo.contains('masa') ||
          tipo.contains('patron') ||
          tipo.contains('patr');
    }

    final pesas = equipos.where(isPesa).take(5).toList();
    final medicion = equipos.where((e) => !isPesa(e)).take(2).toList();

    return {
      if (sessionInfo.seca != null) 'seca': sessionInfo.seca,
      if (sessionInfo.sessionId != null) 'session_id': sessionInfo.sessionId,
      if (sessionInfo.userName != null) 'personal': sessionInfo.userName,
      if (sessionInfo.fechaServicio != null)
        'fecha_servicio': sessionInfo.fechaServicio,
      if (sessionInfo.nReca != null) 'n_reca': sessionInfo.nReca,
      if (sessionInfo.sticker != null) 'sticker': sessionInfo.sticker,
      if (sessionInfo.codMetrica != null) 'cod_metrica': sessionInfo.codMetrica,
      if (cliente?.nombreComercial != null) 'cliente': cliente!.nombreComercial,
      if (cliente?.razonSocial != null) 'razon_social': cliente!.razonSocial,
      if (planta?.nombre != null) 'planta': planta!.nombre,
      if (planta?.direccion != null) 'dir_planta': planta!.direccion,
      if (planta?.departamento != null) 'dep_planta': planta!.departamento,
      if (planta?.codigo != null) 'cod_planta': planta!.codigo,
      // BalanzaInfo
      if (balanza?.categoria != null) 'categoria_balanza': balanza!.categoria,
      // tecnologia: solo visual, no se persiste en la BD
      // clase: solo visual, no se persiste en la BD
      if (balanza?.tipo != null) 'tipo_equipo': balanza!.tipo,
      if (balanza?.rango != null) 'rango': balanza!.rango,
      if (balanza?.nCeldas != null) 'n_celdas': balanza!.nCeldas,
      if (balanza?.unidad != null) 'unidades': balanza!.unidad,
      if (balanza?.ubicacion != null) 'ubicacion': balanza!.ubicacion,
      if (balanza?.codInterno != null) 'cod_int': balanza!.codInterno,
      if (balanza?.marca != null) 'marca': balanza!.marca,
      if (balanza?.modelo != null) 'modelo': balanza!.modelo,
      if (balanza?.serie != null) 'serie': balanza!.serie,
      if (balanza?.capMax1 != null) 'cap_max1': balanza!.capMax1,
      if (balanza?.capMax2 != null) 'cap_max2': balanza!.capMax2,
      if (balanza?.capMax3 != null) 'cap_max3': balanza!.capMax3,
      if (balanza?.d1 != null) 'd1': balanza!.d1,
      if (balanza?.d2 != null) 'd2': balanza!.d2,
      if (balanza?.d3 != null) 'd3': balanza!.d3,
      if (balanza?.e1 != null) 'e1': balanza!.e1,
      if (balanza?.e2 != null) 'e2': balanza!.e2,
      if (balanza?.e3 != null) 'e3': balanza!.e3,
      if (balanza?.dec1 != null) 'dec1': balanza!.dec1,
      if (balanza?.dec2 != null) 'dec2': balanza!.dec2,
      if (balanza?.dec3 != null) 'dec3': balanza!.dec3,
      if (balanza?.infBal != null && balanza!.infBal!.isNotEmpty) 'inf_bal': balanza!.infBal,
      // Equipos: pesas patron en 1-5, instrumentos de medicion en 6-7
      for (int i = 0; i < pesas.length; i++) ...{
        'equipo${i + 1}': pesas[i].codInstrumento,
        'certificado${i + 1}': pesas[i].certFecha,
        'ente_calibrador${i + 1}': pesas[i].enteCalibrador,
        'estado${i + 1}': pesas[i].estado,
        'cantidad${i + 1}': pesas[i].cantidad,
      },
      for (int i = 0; i < medicion.length; i++) ...{
        'equipo${i + 6}': medicion[i].codInstrumento,
        'certificado${i + 6}': medicion[i].certFecha,
        'ente_calibrador${i + 6}': medicion[i].enteCalibrador,
        'estado${i + 6}': medicion[i].estado,
        'cantidad${i + 6}': medicion[i].cantidad,
      },
      // Inspeccion
      if (inspeccion?.horaInicio != null) 'hora_inicio': inspeccion!.horaInicio,
      if (inspeccion?.tiempoEstab != null)
        'tiempo_estab': inspeccion!.tiempoEstab,
      if (inspeccion?.tiempoOperacion != null)
        't_ope_balanza': inspeccion!.tiempoOperacion,
      ...?inspeccion?.campos,
      ...?inspeccion?.comentarios,
      // Precargas Ajuste
      if (precargasAjuste?.ajusteRealizado != null)
        'ajuste': precargasAjuste!.ajusteRealizado! ? 'Sí' : 'No',
      if (precargasAjuste?.tipoAjuste != null)
        'tipo': precargasAjuste!.tipoAjuste,
      if (precargasAjuste?.cargasPesas != null)
        'cargas_pesas': precargasAjuste!.cargasPesas,
      if (precargasAjuste?.hora != null) 'hora': precargasAjuste!.hora,
      if (precargasAjuste?.hri != null) 'hri': precargasAjuste!.hri,
      if (precargasAjuste?.ti != null) 'ti': precargasAjuste!.ti,
      if (precargasAjuste?.patmi != null) 'patmi': precargasAjuste!.patmi,
      if (precargasAjuste?.precargas != null)
        for (int i = 0; i < precargasAjuste!.precargas.length; i++) ...{
          'precarga${i + 1}': precargasAjuste!.precargas[i].precarga,
          'p_indicador${i + 1}': precargasAjuste!.precargas[i].pIndicador,
        },
      // Excentricidad
      if (excentricidad?.tipoPlataforma != null)
        'tipo_plataforma': excentricidad!.tipoPlataforma,
      if (excentricidad?.puntosIndicacion != null)
        'puntos_ind': excentricidad!.puntosIndicacion,
      if (excentricidad?.carga != null) 'carga': excentricidad!.carga,
      if (excentricidad?.nota != null)
        'excentricidad_comentario': excentricidad!.nota,
      if (excentricidad?.posiciones != null)
        for (int i = 0; i < excentricidad!.posiciones.length; i++) ...{
          'posicion${i + 1}': excentricidad!.posiciones[i].posicion,
          'indicacion${i + 1}': excentricidad!.posiciones[i].indicacion,
          'retorno${i + 1}': excentricidad!.posiciones[i].retorno,
        },
      // Repetibilidad
      if (repetibilidad?.nota != null)
        'repetibilidad_comentario': repetibilidad!.nota,
      if (repetibilidad?.cargas != null)
        for (int i = 0; i < repetibilidad!.cargas.length; i++) ...{
          'repetibilidad${i + 1}': repetibilidad!.cargas[i].carga,
          for (int j = 0;
              j < repetibilidad!.cargas[i].indicaciones.length;
              j++) ...{
            'indicacion${i + 1}_${j + 1}':
                repetibilidad!.cargas[i].indicaciones[j],
            'retorno${i + 1}_${j + 1}': repetibilidad!.cargas[i].retornos[j],
          }
        },
      // Linealidad
      if (linealidad?.metodo != null) 'metodo': linealidad!.metodo,
      if (linealidad?.metodoCarga != null)
        'metodo_carga': linealidad!.metodoCarga,
      if (linealidad?.nota != null) 'linealidad_comentario': linealidad!.nota,
      if (linealidad?.filas != null)
        for (int i = 0; i < linealidad!.filas.length; i++) ...{
          'lin${i + 1}': linealidad!.filas[i].carga,
          'ind${i + 1}': linealidad!.filas[i].indicacion,
          'retorno_lin${i + 1}': linealidad!.filas[i].retorno,
        },
      // Condiciones Finales
      if (condicionesFinales?.horaFin != null)
        'hora_fin': condicionesFinales!.horaFin,
      if (condicionesFinales?.hriFin != null)
        'hri_fin': condicionesFinales!.hriFin,
      if (condicionesFinales?.tiFin != null)
        'ti_fin': condicionesFinales!.tiFin,
      if (condicionesFinales?.patmiFin != null)
        'patmi_fin': condicionesFinales!.patmiFin,
      if (condicionesFinales?.mantenimiento != null)
        'mant_soporte': condicionesFinales!.mantenimiento,
      if (condicionesFinales?.ventaPesas != null)
        'venta_pesas': condicionesFinales!.ventaPesas,
      if (condicionesFinales?.reemplazo != null)
        'reemplazo': condicionesFinales!.reemplazo,
      if (condicionesFinales?.observaciones != null)
        'observaciones': condicionesFinales!.observaciones,
      // Exportacion
      if (exportacion?.emp23001 != null) 'emp': exportacion!.emp23001,
      if (exportacion?.indicar != null) 'indicar': exportacion!.indicar,
      if (exportacion?.factorSeguridad != null)
        'factor': exportacion!.factorSeguridad,
      if (exportacion?.reglaAceptacion != null)
        'regla_aceptacion': exportacion!.reglaAceptacion,
    };
  }

  factory ServiceSession.fromMap(Map<String, dynamic> map) {
    List<EquipoInfo> equiposParsed = [];
    for (int i = 1; i <= 7; i++) {
      if (map['equipo$i'] != null && map['equipo$i'].toString().isNotEmpty) {
        equiposParsed.add(EquipoInfo(
          codInstrumento: map['equipo$i'],
          tipo: i <= 5 ? 'Pesa Patron' : 'Instrumento de medicion',
          certFecha: map['certificado$i'],
          enteCalibrador: map['ente_calibrador$i'],
          estado: map['estado$i'],
          cantidad: map['cantidad$i']?.toString(),
        ));
      }
    }

    List<PrecargaRow> precargasParsed = [];
    for (int i = 1; i <= 6; i++) {
      precargasParsed.add(PrecargaRow(
        precarga: map['precarga$i'],
        pIndicador: map['p_indicador$i'],
      ));
    }

    List<PosicionData> excentricidadPos = [];
    for (int i = 1; i <= 6; i++) {
      excentricidadPos.add(PosicionData(
        posicion: map['posicion$i'],
        indicacion: map['indicacion$i'],
        retorno: map['retorno$i'],
      ));
    }

    List<CargaRepetibilidad> cargasRep = [];
    for (int i = 1; i <= 3; i++) {
      List<String?> ind = [];
      List<String?> ret = [];
      for (int j = 1; j <= 10; j++) {
        ind.add(map['indicacion${i}_$j']);
        ret.add(map['retorno${i}_$j']);
      }
      cargasRep.add(CargaRepetibilidad(
        carga: map['repetibilidad$i'],
        indicaciones: ind,
        retornos: ret,
      ));
    }

    List<FilaLinealidad> filasLin = [];
    int lastLinealidadIndex = 0;
    for (int i = 1; i <= 60; i++) {
      final hasData = [
        map['lin$i'],
        map['ind$i'],
        map['retorno_lin$i'],
        map['mp_lin$i'],
        map['cs_lin$i'],
        map['ms_lin$i'],
        map['err_lin$i'],
      ].any((value) => value != null && value.toString().isNotEmpty);
      if (hasData) lastLinealidadIndex = i;
    }

    for (int i = 1; i <= lastLinealidadIndex; i++) {
      filasLin.add(FilaLinealidad(
        carga: map['lin$i'],
        masaPatron: map['mp_lin$i'],
        cargaSustitutiva: map['cs_lin$i'],
        metodSustitucion: map['ms_lin$i'],
        indicacion: map['ind$i'],
        retorno: map['retorno_lin$i'],
        error: map['err_lin$i'],
      ));
    }

    Map<String, String> inspeccionCampos = {
      'vibracion': map['vibracion'] ?? '',
      'polvo': map['polvo'] ?? '',
      'temp': map['temp'] ?? '',
      'humedad': map['humedad'] ?? '',
      'mesada': map['mesada'] ?? '',
      'iluminacion': map['iluminacion'] ?? '',
      'limp_foza': map['limp_foza'] ?? '',
      'estado_drenaje': map['estado_drenaje'] ?? '',
      'limp_general': map['limp_general'] ?? '',
      'golpes_terminal': map['golpes_terminal'] ?? '',
      'nivelacion': map['nivelacion'] ?? '',
      'limp_recepto': map['limp_recepto'] ?? '',
      'golpes_receptor': map['golpes_receptor'] ?? '',
      'encendido': map['encendido'] ?? '',
    };
    Map<String, String> inspeccionComentarios = {
      'vibracion_comentario': map['vibracion_comentario'] ?? '',
      'polvo_comentario': map['polvo_comentario'] ?? '',
      'temp_comentario': map['temp_comentario'] ?? '',
      'humedad_comentario': map['humedad_comentario'] ?? '',
      'mesada_comentario': map['mesada_comentario'] ?? '',
      'iluminacion_comentario': map['iluminacion_comentario'] ?? '',
      'limp_foza_comentario': map['limp_foza_comentario'] ?? '',
      'estado_drenaje_comentario': map['estado_drenaje_comentario'] ?? '',
      'limp_general_comentario': map['limp_general_comentario'] ?? '',
      'golpes_terminal_comentario': map['golpes_terminal_comentario'] ?? '',
      'nivelacion_comentario': map['nivelacion_comentario'] ?? '',
      'limp_recepto_comentario': map['limp_recepto_comentario'] ?? '',
      'golpes_receptor_comentario': map['golpes_receptor_comentario'] ?? '',
      'encendido_comentario': map['encendido_comentario'] ?? '',
    };

    return ServiceSession(
      sessionInfo: SessionInfo(
        seca: map['seca'],
        sessionId: map['session_id'],
        userName: map['personal'],
        fechaServicio: map['fecha_servicio'],
        nReca: map['n_reca'],
        sticker: map['sticker'],
        codMetrica: map['cod_metrica'],
      ),
      cliente: ClienteInfo(
        nombreComercial: map['cliente'],
        razonSocial: map['razon_social'],
      ),
      planta: PlantaInfo(
        nombre: map['planta'],
        direccion: map['dir_planta'],
        departamento: map['dep_planta'],
        codigo: map['cod_planta'],
      ),
      balanza: BalanzaInfo(
        categoria: map['categoria_balanza'],
        // tecnologia: solo visual, no se carga desde BD
        // clase: solo visual, no se carga desde BD
        tipo: map['tipo_equipo'],
        rango: map['rango'],
        nCeldas: map['n_celdas']?.toString(),
        unidad: map['unidades'],
        ubicacion: map['ubicacion'],
        codInterno: map['cod_int'],
        marca: map['marca'],
        modelo: map['modelo'],
        serie: map['serie'],
        capMax1: map['cap_max1']?.toString(),
        capMax2: map['cap_max2']?.toString(),
        capMax3: map['cap_max3']?.toString(),
        d1: double.tryParse(map['d1']?.toString() ?? ''),
        d2: double.tryParse(map['d2']?.toString() ?? ''),
        d3: double.tryParse(map['d3']?.toString() ?? ''),
        e1: double.tryParse(map['e1']?.toString() ?? ''),
        e2: double.tryParse(map['e2']?.toString() ?? ''),
        e3: double.tryParse(map['e3']?.toString() ?? ''),
        dec1: double.tryParse(map['dec1']?.toString() ?? ''),
        dec2: double.tryParse(map['dec2']?.toString() ?? ''),
        dec3: double.tryParse(map['dec3']?.toString() ?? ''),
        infBal: map['inf_bal'],
      ),
      equipos: equiposParsed,
      inspeccion: InspeccionVisual(
        horaInicio: map['hora_inicio'],
        tiempoEstab: map['tiempo_estab'],
        tiempoOperacion: map['t_ope_balanza'],
        campos: inspeccionCampos,
        comentarios: inspeccionComentarios,
      ),
      precargasAjuste: PrecargasAjuste(
        ajusteRealizado: map['ajuste'] == 'Sí',
        tipoAjuste: map['tipo'],
        cargasPesas: map['cargas_pesas'],
        hora: map['hora'],
        hri: map['hri'],
        ti: map['ti'],
        patmi: map['patmi'],
        precargas: precargasParsed,
      ),
      excentricidad: ExcentricidadData(
        tipoPlataforma: map['tipo_plataforma'],
        puntosIndicacion: map['puntos_ind'],
        carga: map['carga'],
        nota: map['excentricidad_comentario'],
        posiciones: excentricidadPos,
      ),
      repetibilidad: RepetibilidadData(
        nota: map['repetibilidad_comentario'],
        cargas: cargasRep,
      ),
      linealidad: LinealidadData(
        metodo: map['metodo'],
        metodoCarga: map['metodo_carga'],
        nota: map['linealidad_comentario'],
        filas: filasLin,
      ),
      condicionesFinales: CondicionesFinales(
        horaFin: map['hora_fin'],
        hriFin: map['hri_fin'],
        tiFin: map['ti_fin'],
        patmiFin: map['patmi_fin'],
        mantenimiento: map['mant_soporte'],
        ventaPesas: map['venta_pesas'],
        reemplazo: map['reemplazo'],
        observaciones: map['observaciones'],
      ),
      exportacion: ExportacionData(
        emp23001: map['emp'],
        indicar: map['indicar'],
        factorSeguridad: map['factor'],
        reglaAceptacion: map['regla_aceptacion'],
      ),
      metadata: SessionMetadata(
          currentStep: map['current_step'] != null
              ? int.parse(map['current_step'].toString())
              : _inferStep(map),
          secaConfirmed: map['seca_confirmed'] != null
              ? map['seca_confirmed'] == 1 || map['seca_confirmed'] == true
              : map['seca'] != null,
          balanzaConfirmed: map['balanza_confirmed'] != null
              ? map['balanza_confirmed'] == 1 || map['balanza_confirmed'] == true
              : false,
          isNewBalanza: false,
          hiddenEditedFields: ''),
    );
  }

  static int _inferStep(Map<String, dynamic> map) {
    if (_hasData(map['emp'])) return 11;
    if (_hasData(map['hora_fin'])) return 10;
    if (_hasData(map['lin1'])) return 8;
    if (_hasData(map['repetibilidad1'])) return 7;
    if (_hasData(map['carga'])) return 6;
    if (_hasData(map['precarga1'])) return 5;
    if (_hasData(map['hora_inicio'])) return 4;
    if (_hasData(map['cod_metrica'])) return 3;
    if (_hasData(map['seca'])) return 2;
    return 0;
  }

  static bool _hasData(dynamic value) {
    return value != null && value.toString().isNotEmpty;
  }
}

class SessionInfo {
  final String? seca;
  final String? sessionId;
  final String? userName;
  final String? fechaServicio;
  final String? nReca;
  final String? sticker;
  final String? codMetrica;

  SessionInfo(
      {this.seca,
      this.sessionId,
      this.userName,
      this.fechaServicio,
      this.nReca,
      this.sticker,
      this.codMetrica});

  SessionInfo copyWith({
    String? seca,
    String? sessionId,
    String? userName,
    String? fechaServicio,
    String? nReca,
    String? sticker,
    String? codMetrica,
  }) {
    return SessionInfo(
      seca: seca ?? this.seca,
      sessionId: sessionId ?? this.sessionId,
      userName: userName ?? this.userName,
      fechaServicio: fechaServicio ?? this.fechaServicio,
      nReca: nReca ?? this.nReca,
      sticker: sticker ?? this.sticker,
      codMetrica: codMetrica ?? this.codMetrica,
    );
  }
}

class ClienteInfo {
  final String? id;
  final String? codigoCliente;
  final String? nombreComercial;
  final String? razonSocial;
  final bool? isNew;

  ClienteInfo(
      {this.id,
      this.codigoCliente,
      this.nombreComercial,
      this.razonSocial,
      this.isNew});

  ClienteInfo copyWith(
      {String? id,
      String? codigoCliente,
      String? nombreComercial,
      String? razonSocial,
      bool? isNew}) {
    return ClienteInfo(
      id: id ?? this.id,
      codigoCliente: codigoCliente ?? this.codigoCliente,
      nombreComercial: nombreComercial ?? this.nombreComercial,
      razonSocial: razonSocial ?? this.razonSocial,
      isNew: isNew ?? this.isNew,
    );
  }
}

class PlantaInfo {
  final String? id;
  final String? nombre;
  final String? direccion;
  final String? departamento;
  final String? codigo;
  final bool? isNew;

  PlantaInfo(
      {this.id,
      this.nombre,
      this.direccion,
      this.departamento,
      this.codigo,
      this.isNew});

  PlantaInfo copyWith(
      {String? id,
      String? nombre,
      String? direccion,
      String? departamento,
      String? codigo,
      bool? isNew}) {
    return PlantaInfo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      departamento: departamento ?? this.departamento,
      codigo: codigo ?? this.codigo,
      isNew: isNew ?? this.isNew,
    );
  }
}

class BalanzaInfo {
  final String? codMetrica;
  final String? categoria;
  final String? tecnologia;
  final String? clase;
  final String? tipo;
  final String? rango;
  final String? nCeldas;
  final String? unidad;
  final String? ubicacion;
  final String? codInterno;
  final String? marca;
  final String? modelo;
  final String? serie;
  final String? capMax1, capMax2, capMax3;
  final double? d1, d2, d3, e1, e2, e3, dec1, dec2, dec3, exc;
  final String? infBal;
  final List<String> fotosPaths;

  BalanzaInfo({
    this.codMetrica,
    this.categoria,
    this.tecnologia,
    this.clase,
    this.tipo,
    this.rango,
    this.nCeldas,
    this.unidad,
    this.ubicacion,
    this.codInterno,
    this.marca,
    this.modelo,
    this.serie,
    this.capMax1,
    this.capMax2,
    this.capMax3,
    this.d1,
    this.d2,
    this.d3,
    this.e1,
    this.e2,
    this.e3,
    this.dec1,
    this.dec2,
    this.dec3,
    this.exc,
    this.infBal,
    this.fotosPaths = const [],
  });

  BalanzaInfo copyWith({
    String? codMetrica,
    String? categoria,
    String? tecnologia,
    String? clase,
    String? tipo,
    String? rango,
    String? nCeldas,
    String? unidad,
    String? ubicacion,
    String? codInterno,
    String? marca,
    String? modelo,
    String? serie,
    String? capMax1,
    String? capMax2,
    String? capMax3,
    double? d1,
    double? d2,
    double? d3,
    double? e1,
    double? e2,
    double? e3,
    double? dec1,
    double? dec2,
    double? dec3,
    double? exc,
    String? infBal,
    List<String>? fotosPaths,
  }) {
    return BalanzaInfo(
      codMetrica: codMetrica ?? this.codMetrica,
      categoria: categoria ?? this.categoria,
      tecnologia: tecnologia ?? this.tecnologia,
      clase: clase ?? this.clase,
      tipo: tipo ?? this.tipo,
      rango: rango ?? this.rango,
      nCeldas: nCeldas ?? this.nCeldas,
      unidad: unidad ?? this.unidad,
      ubicacion: ubicacion ?? this.ubicacion,
      codInterno: codInterno ?? this.codInterno,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      serie: serie ?? this.serie,
      capMax1: capMax1 ?? this.capMax1,
      capMax2: capMax2 ?? this.capMax2,
      capMax3: capMax3 ?? this.capMax3,
      d1: d1 ?? this.d1,
      d2: d2 ?? this.d2,
      d3: d3 ?? this.d3,
      e1: e1 ?? this.e1,
      e2: e2 ?? this.e2,
      e3: e3 ?? this.e3,
      dec1: dec1 ?? this.dec1,
      dec2: dec2 ?? this.dec2,
      dec3: dec3 ?? this.dec3,
      exc: exc ?? this.exc,
      infBal: infBal ?? this.infBal,
      fotosPaths: fotosPaths ?? this.fotosPaths,
    );
  }
}

class EquipoInfo {
  final String? codInstrumento;
  final String? tipo;
  final String? cantidad;
  final String? certFecha;
  final String? enteCalibrador;
  final String? estado;

  EquipoInfo(
      {this.codInstrumento,
      this.tipo,
      this.cantidad,
      this.certFecha,
      this.enteCalibrador,
      this.estado});

  EquipoInfo copyWith(
      {String? codInstrumento,
      String? tipo,
      String? cantidad,
      String? certFecha,
      String? enteCalibrador,
      String? estado}) {
    return EquipoInfo(
      codInstrumento: codInstrumento ?? this.codInstrumento,
      tipo: tipo ?? this.tipo,
      cantidad: cantidad ?? this.cantidad,
      certFecha: certFecha ?? this.certFecha,
      enteCalibrador: enteCalibrador ?? this.enteCalibrador,
      estado: estado ?? this.estado,
    );
  }
}

class InspeccionVisual {
  final String? horaInicio;
  final String? tiempoEstab;
  final String? tiempoOperacion;
  final Map<String, String> campos;
  final Map<String, String> comentarios;

  InspeccionVisual(
      {this.horaInicio,
      this.tiempoEstab,
      this.tiempoOperacion,
      this.campos = const {},
      this.comentarios = const {}});

  InspeccionVisual copyWith(
      {String? horaInicio,
      String? tiempoEstab,
      String? tiempoOperacion,
      Map<String, String>? campos,
      Map<String, String>? comentarios}) {
    return InspeccionVisual(
      horaInicio: horaInicio ?? this.horaInicio,
      tiempoEstab: tiempoEstab ?? this.tiempoEstab,
      tiempoOperacion: tiempoOperacion ?? this.tiempoOperacion,
      campos: campos ?? this.campos,
      comentarios: comentarios ?? this.comentarios,
    );
  }
}

class PrecargaRow {
  final String? precarga;
  final String? pIndicador;
  PrecargaRow({this.precarga, this.pIndicador});
}

class PrecargasAjuste {
  final List<PrecargaRow> precargas;
  final bool? ajusteRealizado;
  final String? tipoAjuste, cargasPesas, hora, hri, ti, patmi;

  PrecargasAjuste(
      {this.precargas = const [],
      this.ajusteRealizado,
      this.tipoAjuste,
      this.cargasPesas,
      this.hora,
      this.hri,
      this.ti,
      this.patmi});

  PrecargasAjuste copyWith(
      {List<PrecargaRow>? precargas,
      bool? ajusteRealizado,
      String? tipoAjuste,
      String? cargasPesas,
      String? hora,
      String? hri,
      String? ti,
      String? patmi}) {
    return PrecargasAjuste(
      precargas: precargas ?? this.precargas,
      ajusteRealizado: ajusteRealizado ?? this.ajusteRealizado,
      tipoAjuste: tipoAjuste ?? this.tipoAjuste,
      cargasPesas: cargasPesas ?? this.cargasPesas,
      hora: hora ?? this.hora,
      hri: hri ?? this.hri,
      ti: ti ?? this.ti,
      patmi: patmi ?? this.patmi,
    );
  }
}

class PosicionData {
  final String? posicion, indicacion, retorno;
  PosicionData({this.posicion, this.indicacion, this.retorno});
}

class ExcentricidadData {
  final String? tipoPlataforma, puntosIndicacion, carga, nota;
  final List<PosicionData> posiciones;

  ExcentricidadData(
      {this.tipoPlataforma,
      this.puntosIndicacion,
      this.carga,
      this.nota,
      this.posiciones = const []});

  ExcentricidadData copyWith(
      {String? tipoPlataforma,
      String? puntosIndicacion,
      String? carga,
      String? nota,
      List<PosicionData>? posiciones}) {
    return ExcentricidadData(
      tipoPlataforma: tipoPlataforma ?? this.tipoPlataforma,
      puntosIndicacion: puntosIndicacion ?? this.puntosIndicacion,
      carga: carga ?? this.carga,
      nota: nota ?? this.nota,
      posiciones: posiciones ?? this.posiciones,
    );
  }
}

class CargaRepetibilidad {
  final String? carga;
  final List<String?> indicaciones;
  final List<String?> retornos;
  CargaRepetibilidad(
      {this.carga, this.indicaciones = const [], this.retornos = const []});
}

class RepetibilidadData {
  final String? nota;
  final List<CargaRepetibilidad> cargas;

  RepetibilidadData({this.nota, this.cargas = const []});

  RepetibilidadData copyWith({String? nota, List<CargaRepetibilidad>? cargas}) {
    return RepetibilidadData(
      nota: nota ?? this.nota,
      cargas: cargas ?? this.cargas,
    );
  }
}

class FilaLinealidad {
  final String? carga,
      masaPatron,
      cargaSustitutiva,
      metodSustitucion,
      indicacion,
      retorno,
      error;
  FilaLinealidad(
      {this.carga,
      this.masaPatron,
      this.cargaSustitutiva,
      this.metodSustitucion,
      this.indicacion,
      this.retorno,
      this.error});
}

class LinealidadData {
  final String? metodo, metodoCarga, nota;
  final List<FilaLinealidad> filas;
  final List<String> fotosPaths;

  LinealidadData({
    this.metodo,
    this.metodoCarga,
    this.nota,
    this.filas = const [],
    this.fotosPaths = const [],
  });

  LinealidadData copyWith({
    String? metodo,
    String? metodoCarga,
    String? nota,
    List<FilaLinealidad>? filas,
    List<String>? fotosPaths,
  }) {
    return LinealidadData(
      metodo: metodo ?? this.metodo,
      metodoCarga: metodoCarga ?? this.metodoCarga,
      nota: nota ?? this.nota,
      filas: filas ?? this.filas,
      fotosPaths: fotosPaths ?? this.fotosPaths,
    );
  }
}

class CondicionesFinales {
  final String? horaFin,
      hriFin,
      tiFin,
      patmiFin,
      mantenimiento,
      ventaPesas,
      reemplazo,
      observaciones;
  final List<String>? fotosPaths;
  final List<String>? fotosFinalesPaths;
  final List<EquipoInfo> pesasSeleccionadas;

  CondicionesFinales(
      {this.horaFin,
      this.hriFin,
      this.tiFin,
      this.patmiFin,
      this.mantenimiento,
      this.ventaPesas,
      this.reemplazo,
      this.observaciones,
      this.fotosPaths,
      this.fotosFinalesPaths,
      this.pesasSeleccionadas = const []});

  CondicionesFinales copyWith(
      {String? horaFin,
      String? hriFin,
      String? tiFin,
      String? patmiFin,
      String? mantenimiento,
      String? ventaPesas,
      String? reemplazo,
      String? observaciones,
      List<String>? fotosPaths,
      List<String>? fotosFinalesPaths,
      List<EquipoInfo>? pesasSeleccionadas}) {
    return CondicionesFinales(
      horaFin: horaFin ?? this.horaFin,
      hriFin: hriFin ?? this.hriFin,
      tiFin: tiFin ?? this.tiFin,
      patmiFin: patmiFin ?? this.patmiFin,
      mantenimiento: mantenimiento ?? this.mantenimiento,
      ventaPesas: ventaPesas ?? this.ventaPesas,
      reemplazo: reemplazo ?? this.reemplazo,
      observaciones: observaciones ?? this.observaciones,
      fotosPaths: fotosPaths ?? this.fotosPaths,
      fotosFinalesPaths: fotosFinalesPaths ?? this.fotosFinalesPaths,
      pesasSeleccionadas: pesasSeleccionadas ?? this.pesasSeleccionadas,
    );
  }
}

class ExportacionData {
  final String? emp23001, indicar, factorSeguridad, reglaAceptacion;
  ExportacionData(
      {this.emp23001,
      this.indicar,
      this.factorSeguridad,
      this.reglaAceptacion});

  ExportacionData copyWith(
      {String? emp23001,
      String? indicar,
      String? factorSeguridad,
      String? reglaAceptacion}) {
    return ExportacionData(
      emp23001: emp23001 ?? this.emp23001,
      indicar: indicar ?? this.indicar,
      factorSeguridad: factorSeguridad ?? this.factorSeguridad,
      reglaAceptacion: reglaAceptacion ?? this.reglaAceptacion,
    );
  }
}

class SessionMetadata {
  final int currentStep;
  final bool secaConfirmed;
  final bool balanzaConfirmed;
  final bool isNewBalanza;
  final String hiddenEditedFields;

  SessionMetadata(
      {this.currentStep = 0,
      this.secaConfirmed = false,
      this.balanzaConfirmed = false,
      this.isNewBalanza = false,
      this.hiddenEditedFields = ''});

  SessionMetadata copyWith(
      {int? currentStep,
      bool? secaConfirmed,
      bool? balanzaConfirmed,
      bool? isNewBalanza,
      String? hiddenEditedFields}) {
    return SessionMetadata(
      currentStep: currentStep ?? this.currentStep,
      secaConfirmed: secaConfirmed ?? this.secaConfirmed,
      balanzaConfirmed: balanzaConfirmed ?? this.balanzaConfirmed,
      isNewBalanza: isNewBalanza ?? this.isNewBalanza,
      hiddenEditedFields: hiddenEditedFields ?? this.hiddenEditedFields,
    );
  }
}
