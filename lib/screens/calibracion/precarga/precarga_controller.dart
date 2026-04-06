// precarga_controller.dart
// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:archive/archive_io.dart';
import '../../../database/app_database.dart';

class PrecargaController extends ChangeNotifier {
  Function(Map<String, dynamic>)? onBalanzaSelected;

  String? _baseFotoPath;
  String? get baseFotoPath => _baseFotoPath;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Estados del flujo
  int _currentStep = 0;
  bool _isDataSaved = false;
  String? _generatedSessionId;
  String? _generatedSeca;
  bool _secaConfirmed = false;

  // Registro incompleto en recuperación 
  Map<String, dynamic>? _registroIncompletoActual;
  Map<String, dynamic>? get registroIncompletoActual => _registroIncompletoActual;

  void clearRegistroIncompleto() {
    _registroIncompletoActual = null;
  }

  // Validación por paso
  Map<int, String?> _stepErrors = {0: null, 1: null, 2: null, 3: null};
  Map<int, String?> get stepErrors => _stepErrors;

  // Getters
  int get currentStep => _currentStep;
  bool get isDataSaved => _isDataSaved;
  String? get generatedSessionId => _generatedSessionId;
  String? get generatedSeca => _generatedSeca;
  bool get secaConfirmed => _secaConfirmed;

  // Datos del cliente
  List<dynamic>? _clientes;
  List<dynamic>? _filteredClientes;
  String? _selectedClienteId;
  String? _selectedClienteName;
  String? _selectedClienteRazonSocial;
  bool _isNewClient = false;

  // Getters cliente
  List<dynamic>? get clientes => _clientes;
  List<dynamic>? get filteredClientes => _filteredClientes;
  String? get selectedClienteId => _selectedClienteId;
  String? get selectedClienteName => _selectedClienteName;
  String? get selectedClienteRazonSocial => _selectedClienteRazonSocial;
  bool get isNewClient => _isNewClient;

  // Datos de la planta
  String? _selectedPlantaNombre;
  String? get selectedPlantaNombre => _selectedPlantaNombre;

  List<dynamic>? _plantas;
  String? _selectedPlantaKey;
  String? _selectedPlantaDir;
  String? _selectedPlantaDep;
  String? _selectedPlantaCodigo;

  // Getters planta
  List<dynamic>? get plantas => _plantas;
  String? get selectedPlantaKey => _selectedPlantaKey;
  String? get selectedPlantaDir => _selectedPlantaDir;
  String? get selectedPlantaDep => _selectedPlantaDep;
  String? get selectedPlantaCodigo => _selectedPlantaCodigo;

  // Datos de balanza
  List<Map<String, dynamic>> _balanzas = [];
  Map<String, dynamic>? _selectedBalanza;
  bool _isNewBalanza = false;

  // Estado de desbloqueo de campos (antes validación)
  final Map<String, bool> _balanzaUnlockState = {};
  Map<String, bool> get balanzaUnlockState => _balanzaUnlockState;

  // Campo oculto para rastrear ediciones
  String _hiddenEditedFields = '';
  String get hiddenEditedFields => _hiddenEditedFields;

  // Ya no bloqueamos por "validación", pero mantenemos el concepto de unlock
  bool isFieldUnlock(String key) {
    return _balanzaUnlockState[key] ?? false;
  }

  void toggleBalanzaUnlock(String key, bool? value) {
    if (_balanzaUnlockState.containsKey(key)) {
      bool isUnlocked = value ?? false;
      _balanzaUnlockState[key] = isUnlocked;

      // Actualizar campo oculto
      List<String> currentEdited =
          _hiddenEditedFields.isEmpty ? [] : _hiddenEditedFields.split(',');

      if (isUnlocked) {
        if (!currentEdited.contains(key)) {
          currentEdited.add(key);
        }
      } else {
        currentEdited.remove(key);
      }

      _hiddenEditedFields = currentEdited.join(',');

      notifyListeners();
    }
  }

  void _initializeBalanzaUnlockState() {
    _balanzaUnlockState.clear();
    _hiddenEditedFields = '';

    // Campos que pueden desbloquearse
    final fieldsToUnlock = [
      'cod_metrica',
      'categoria_balanza',
      'cod_int',
      'tipo_equipo',
      'marca',
      'modelo',
      'serie',
      'unidades',
      'ubicacion',
      'tecnologia',
      'clase',
      'rango_balanza',
      'n_celdas' // NUEVO
    ];

    for (var field in fieldsToUnlock) {
      _balanzaUnlockState[field] = false; // Bloqueado por defecto
    }
  }

  // Getters balanza
  List<Map<String, dynamic>> get balanzas => _balanzas;
  Map<String, dynamic>? get selectedBalanza => _selectedBalanza;
  bool get isNewBalanza => _isNewBalanza;

  // Equipos
  List<dynamic> _equipos = [];
  List<Map<String, dynamic>> _selectedEquipos = [];
  List<Map<String, dynamic>> _selectedTermohigrometros = [];

  // Getters equipos
  List<dynamic> get equipos => _equipos;
  List<Map<String, dynamic>> get selectedEquipos => _selectedEquipos;
  List<Map<String, dynamic>> get selectedTermohigrometros =>
      _selectedTermohigrometros;

  // Fotos
  final Map<String, List<File>> _balanzaPhotos = {};
  bool _fotosTomadas = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Getters fotos
  Map<String, List<File>> get balanzaPhotos => _balanzaPhotos;
  bool get fotosTomadas => _fotosTomadas;

  // Modo QR
  bool _isQrMode = false;
  String? _qrCodMetrica;
  bool get isQrMode => _isQrMode;
  String? get qrCodMetrica => _qrCodMetrica;

  // Listas de opciones
  final List<String> unidadesPermitidas = ['mg', 'g', 'kg'];

  final List<String> marcasBalanzas = [
    'ACCULAB',
    'AIV ELECTRONIC TECH',
    'AIV-ELECTRONIC TECH',
    'AND',
    'ASPIRE',
    'AVERY',
    'BALPER',
    'CAMRY',
    'CARDINAL',
    'CAS',
    'CAUDURO',
    'CLEVER',
    'DAYANG',
    'DIGITAL SCALE',
    'DOLPHIN',
    'ELECTRONIC SCALE',
    'FAIRBANKS',
    'FAIRBANKS MORSE',
    'AOSAI',
    'FAMOCOL',
    'FERTON',
    'FILIZOLA',
    'GRAM',
    'GRAM PRECISION',
    'GSC',
    'GUOMING',
    'HBM',
    'HIWEIGH',
    'HOWE',
    'INESA',
    'JADEVER',
    'JM',
    'KERN',
    'KRETZ',
    'LUTRANA',
    'METTLER',
    'METTLER TOLEDO',
    'MY WEIGH',
    'OHAUS',
    'PRECISA',
    'PRECISION HISPANA',
    'PT Ltd',
    'QUANTUM SCALES',
    'RADWAG',
    'RINSTRUM',
    'SARTORIUS',
    'SCIENTECH',
    'SECA',
    'SHANGAI',
    'SHIMADZU',
    'SIPEL',
    'STAVOL',
    'SYMMETRY',
    'SYSTEL',
    'TOLEDO',
    'TOP BRAND',
    'TOP INSTRUMENTS',
    'TRANSCELL',
    'TRINER',
    'TRINNER SCALES',
    'WATERPROOF',
    'WHITE BIRD',
    'CONSTANT',
    'JEWELLRY SCALE',
    'YAOHUA',
    'PRIX'
  ];

  final List<String> tiposEquipo = [
    'BALANZA',
    'BALANZA ANALIZADORA DE HUMEDAD',
    'BALANZA ANALÍTICA',
    'BALANZA MECÁNICA',
    'BALANZA ELECTROMECÁNICA',
    'BALANZA ELECTRÓNICA DE DOBLE RANGO',
    'BALANZA ELECTRÓNICA DE TRIPLE RANGO',
    'BALANZA ELECTRÓNICA DE DOBLE INTERVALO',
    'BALANZA ELECTRÓNICA DE TRIPLE INTERVALO',
    'BALANZA SEMIMICROANALÍTICA',
    'BALANZA MICROANALÍTICA',
    'BALANZA SEMIMICROANALÍTICA DE DOBLE RANGO',
    'BALANZA SEMIMICROANALÍTICA DE TRIPLE RANGO',
    'BALANZA ELECTRONICA',
  ];

  // MÉTODOS DE VALIDACIÓN
  String? validateStep(int step) {
    switch (step) {
      case 0: // Cliente
        if (_selectedClienteName == null || _selectedClienteName!.isEmpty) {
          return 'Debe seleccionar un cliente';
        }
        return null;

      case 1: // Planta
        if (_selectedPlantaDir == null || _selectedPlantaDir!.isEmpty) {
          return 'La dirección de planta es requerida';
        }
        if (_selectedPlantaDep == null || _selectedPlantaDep!.isEmpty) {
          return 'El departamento es requerido';
        }
        // CAMBIO: Solo validar código si NO es cliente nuevo
        if (!_isNewClient &&
            (_selectedPlantaCodigo == null || _selectedPlantaCodigo!.isEmpty)) {
          return 'Debe seleccionar una planta';
        }
        return null;

      case 2: // SECA
        if (!_secaConfirmed) {
          return 'Debe confirmar el SECA';
        }
        return null;

      case 3: // Balanza
        if (_selectedBalanza == null && !_isNewBalanza) {
          // Check if new balanza also counts
          return 'Debe seleccionar una balanza';
        }
        // YA NO REQUERIMOS VALIDACIÓN OBLIGATORIA AQUÍ
        // La advertencia se manejará en el botón Finalizar
        return null;

      default:
        return null;
    }
  }

  void updateStepErrors() {
    for (int i = 0; i <= _currentStep && i <= 3; i++) {
      _stepErrors[i] = validateStep(i);
    }
    notifyListeners();
  }

  bool canProceedToStep(int step) {
    final error = validateStep(step);
    return error == null;
  }

  // MÉTODOS DE NAVEGACIÓN
  void nextStep() {
    if (_currentStep < 3) {
      _currentStep++;
      updateStepErrors();
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      updateStepErrors();
      notifyListeners();
    }
  }

  void goToStep(int step) {
    _currentStep = step;
    updateStepErrors();
    notifyListeners();
  }

  void setCurrentStep(int step) {
    if (step >= 0 && step <= 3) {
      _currentStep = step;
      updateStepErrors();
      notifyListeners();
    }
  }

  void setInternalValues({
    required String sessionId,
    required String seca,
    String? clienteName,
    String? clienteRazonSocial,
    String? plantaDir,
    String? plantaDep,
    String? plantaCodigo,
    String? plantaNombre, // NUEVO
  }) {
    _generatedSessionId = sessionId;
    _generatedSeca = seca;
    _secaConfirmed = true;

    if (clienteName != null) _selectedClienteName = clienteName;
    if (clienteRazonSocial != null) {
      _selectedClienteRazonSocial = clienteRazonSocial;
    }
    if (plantaDir != null) _selectedPlantaDir = plantaDir;
    if (plantaDep != null) _selectedPlantaDep = plantaDep;
    if (plantaNombre != null) _selectedPlantaNombre = plantaNombre; // NUEVO
    if (plantaCodigo != null) {
      _selectedPlantaCodigo = plantaCodigo;
      fetchBalanzas(plantaCodigo);
    }

    updateStepErrors();
    notifyListeners();
  }

  Future<void> addNewPlanta({
    required String nombrePlanta,
    required String direccion,
    required String departamento,
  }) async {
    try {
      String path = join(await getDatabasesPath(), 'precarga_database.db');
      final db = await openDatabase(path);

      if (_disposed) return;

      final plantaId = DateTime.now().millisecondsSinceEpoch.toString();
      final depId = (DateTime.now().millisecondsSinceEpoch + 1)
          .toString(); // +1 para evitar duplicados

      // Código temporal para plantas nuevas
      final codigoTemporal = 'NNNN-NN';

      await db.insert('plantas', {
        'cliente_id': _selectedClienteId,
        'planta_id': plantaId,
        'dep_id': depId,
        'planta': nombrePlanta,
        'dir': direccion,
        'dep': departamento,
        'codigo_planta': codigoTemporal,
      });

      await db.close();

      // Recargar plantas
      await fetchPlantas(_selectedClienteId!);

      // Seleccionar la planta recién creada
      final uniqueKey = '${plantaId}_$depId';
      selectPlanta(uniqueKey);

      notifyListeners();
    } catch (e) {
      throw Exception('Error al agregar planta: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchServicioData(String codMetrica) async {
    try {
      String path = join(await getDatabasesPath(), 'precarga_database.db');
      final db = await openDatabase(path);

      final List<Map<String, dynamic>> servicioData = await db.query(
        'servicios',
        where: 'cod_metrica = ?',
        whereArgs: [codMetrica],
        orderBy: 'reg_fecha DESC',
        limit: 1,
      );

      await db.close();

      if (servicioData.isNotEmpty) {
        return servicioData.first;
      }

      return null;
    } catch (e) {
      debugPrint('Error al cargar datos de servicio: $e');
      return null;
    }
  }

  // MÉTODOS DE CLIENTE
  Future<void> fetchClientes() async {
    try {
      String path = join(await getDatabasesPath(), 'precarga_database.db');
      final db = await openDatabase(path);
      final List<Map<String, dynamic>> clientesList =
          await db.query('clientes');

      _clientes = clientesList;
      _filteredClientes = clientesList;
      await db.close();
      if (_disposed) return;
      notifyListeners();
    } catch (e) {
      throw Exception('Error al cargar clientes: $e');
    }
  }

  void filterClientes(String query) {
    final queryLower = query.toLowerCase();
    _filteredClientes = _clientes?.where((cliente) {
      final clienteName = cliente['cliente']?.toLowerCase() ?? '';
      return clienteName.contains(queryLower);
    }).toList();
    notifyListeners();
  }

  void selectClientFromList(Map<String, dynamic> cliente) {
    _isNewClient = false;
    _selectedClienteId = cliente['cliente_id']?.toString() ?? '';
    _selectedClienteName = cliente['cliente']?.toString() ?? '';
    _selectedClienteRazonSocial = cliente['razonsocial']?.toString() ?? '';

    // NUEVO: Limpiar selección de planta al cambiar de cliente
    clearPlantaSelection();

    updateStepErrors();
    notifyListeners();

    fetchPlantas(_selectedClienteId!);
    fetchEquipos();
  }

  void selectNewClient(String nombreComercial, String razonSocial) {
    _isNewClient = true;
    _selectedClienteName = nombreComercial;
    _selectedClienteRazonSocial = razonSocial;
    _selectedClienteId = null;
    _plantas = null;

    // NUEVO: Limpiar selección de planta al cambiar a cliente nuevo
    clearPlantaSelection();

    updateStepErrors();
    notifyListeners();
  }

  void clearClientSelection() {
    _selectedClienteId = null;
    _selectedClienteName = null;
    _selectedClienteRazonSocial = null;
    _isNewClient = false;
    _plantas = null;
    _selectedPlantaKey = null;

    // NUEVO: Limpiar también los datos de planta manual
    _selectedPlantaNombre = null;
    _selectedPlantaDir = null;
    _selectedPlantaDep = null;
    _selectedPlantaCodigo = null;
    _selectedBalanza = null;
    _isNewBalanza = false;
    _initializeBalanzaUnlockState(); // Reset unlock state
    updateStepErrors();
    notifyListeners();
  }

  void clearPlantaSelection() {
    _selectedPlantaKey = null;
    _selectedPlantaNombre = null;
    _selectedPlantaDir = null;
    _selectedPlantaDep = null;
    _selectedPlantaCodigo = null;
    _generatedSeca = null;
    _secaConfirmed = false;
    updateStepErrors();
    notifyListeners();
  }

  // MÉTODOS DE PLANTA
  Future<void> fetchPlantas(String clienteId) async {
    try {
      String path = join(await getDatabasesPath(), 'precarga_database.db');
      final db = await openDatabase(path);

      final List<Map<String, dynamic>> plantasList = await db.query(
        'plantas',
        where: 'cliente_id = ?',
        whereArgs: [clienteId],
      );

      final plantasModificadas = plantasList.map((planta) {
        return {
          ...planta,
          'unique_key': '${planta['planta_id']}_${planta['dep_id']}',
        };
      }).toList();

      _plantas = plantasModificadas;
      await db.close();
      if (_disposed) return;
      notifyListeners();
    } catch (e) {
      throw Exception('Error al cargar plantas: $e');
    }
  }

  void selectPlanta(String uniqueKey) {
    final selectedPlanta = _plantas!.firstWhere(
      (planta) => planta['unique_key'] == uniqueKey,
      orElse: () => <String, dynamic>{},
    );

    _selectedPlantaKey = uniqueKey;
    _selectedPlantaNombre = selectedPlanta['planta']?.toString() ?? '';
    _selectedPlantaDir = selectedPlanta['dir']?.toString() ?? '';
    _selectedPlantaDep = selectedPlanta['dep']?.toString() ?? '';
    _selectedPlantaCodigo = selectedPlanta['codigo_planta']?.toString() ?? '';

    generateSugestedSeca();
    updateStepErrors();
    notifyListeners();
  }

  void setPlantaManualData(
      String direccion, String departamento, dynamic controller,
      {String? nombrePlanta}) {
    _selectedPlantaDir = direccion;
    _selectedPlantaDep = departamento;
    _selectedPlantaCodigo = 'NNNN-NN';

    // Solo actualizar nombre si se proporciona y no está vacío
    if (nombrePlanta != null && nombrePlanta.isNotEmpty) {
      _selectedPlantaNombre = nombrePlanta;
    } else if (_selectedPlantaNombre == null ||
        _selectedPlantaNombre!.isEmpty) {
      // Fallback: usar nombre del cliente si está disponible
      _selectedPlantaNombre =
          'Planta ${controller.selectedClienteName ?? "Nueva"}';
    }

    generateSugestedSeca();
    updateStepErrors();
    notifyListeners();
  }

  // MÉTODOS DE SECA
  void generateSugestedSeca() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);

    // CAMBIO: Usar código de planta o NNNN-NN si no existe/es nuevo
    String codigoBase = _selectedPlantaCodigo ?? 'NNNN-NN';

    // Si el código es vacío o es el genérico, usar NNNN-NN
    if (codigoBase.isEmpty || codigoBase == 'NNNN-NN') {
      codigoBase = 'NNNN-NN';
    }

    // Solo generar si NO existe un SECA o si NO está confirmado
    if (_generatedSeca == null || !_secaConfirmed) {
      _generatedSeca = '$year-$codigoBase-C01';
      notifyListeners();
    }
  }

  void updateNumeroCotizacion(String nuevoNumero) {
    if (nuevoNumero.isEmpty) {
      return; // No hacer nada si está vacío
    }

    final regex = RegExp(r'^C\d{2}$');
    if (!regex.hasMatch(nuevoNumero)) {
      throw Exception('Formato inválido. Use C01 a C99');
    }

    if (_generatedSeca != null) {
      final partes = _generatedSeca!.split('-');

      // Si tiene 3 partes (año-planta-C01), reemplazar la última
      if (partes.length == 3) {
        partes[2] = nuevoNumero;
        _generatedSeca = partes.join('-');
      }
      // Si tiene 4 partes (año-planta-algo-C01), reemplazar la última
      else if (partes.length == 4) {
        partes[3] = nuevoNumero;
        _generatedSeca = partes.join('-');
      }

      notifyListeners();
    }
  }

  Future<void> confirmSeca(String userName, String fechaServicio) async {
    if (_generatedSeca == null) throw Exception('No hay SECA generado');

    try {
      final dbHelper = AppDatabase();

      final secaExiste = await dbHelper.secaExists(_generatedSeca!);

      if (secaExiste) {
        final ultimoRegistro =
            await dbHelper.getUltimoRegistroPorSeca(_generatedSeca!);
        throw SecaExistsException(ultimoRegistro?['fecha_servicio'] ?? 'N/A');
      } else {
        await createNewSecaSession(userName, fechaServicio);
      }
      if (_disposed) return;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createNewSecaSession(
      String userName, String fechaServicio) async {
    try {
      final dbHelper = AppDatabase();
      _generatedSessionId = await dbHelper.generateSessionId(_generatedSeca!);

      final Map<String, dynamic> sessionData = {
        'seca': _generatedSeca!,
        'fecha_servicio': fechaServicio,
        'personal': userName,
        'session_id': _generatedSessionId!,
        'cliente': _selectedClienteName ?? 'No especificado',
        'razon_social': _selectedClienteRazonSocial ?? 'No especificado',
        'planta': _selectedPlantaNombre ?? 'No especificado',
        'dir_planta': _selectedPlantaDir ?? 'No especificado',
        'dep_planta': _selectedPlantaDep ?? 'No especificado',
        'cod_planta': _selectedPlantaCodigo ?? 'No especificado',
        'inf_bal': _hiddenEditedFields, // GUARDAR CAMPOS EDITADOS
      };

      // Guardar Termohigrómetros en slots 6 y 7
      for (int i = 0; i < _selectedTermohigrometros.length; i++) {
        if (i < 2) {
          // Solo permitimos 2
          final index = i + 6; // 6 y 7
          final termo = _selectedTermohigrometros[i];
          sessionData['equipo$index'] = termo['cod_instrumento'];
          sessionData['certificado$index'] = termo['cert_fecha'];
          sessionData['ente_calibrador$index'] = termo['ente_calibrador'];
          // sessionData['estado$index'] = termo['estado']; // No está en la estructura equipo, quizá solo en DB?
          sessionData['cantidad$index'] = termo['cantidad'];
        }
      }

      await dbHelper.upsertRegistroCalibracion(sessionData);

      if (_disposed) return;

      _secaConfirmed = true;
      updateStepErrors();
      notifyListeners();

      await fetchBalanzas(_selectedPlantaCodigo!);
    } catch (e) {
      throw Exception('Error al crear sesión: $e');
    }
  }

  // MÉTODOS DE BALANZA
  Future<void> fetchBalanzas(String plantaCodigo) async {
    try {
      String path = join(await getDatabasesPath(), 'precarga_database.db');
      final db = await openDatabase(path);

      // CAMBIO: Consulta optimizada con LEFT JOIN y ORDER BY
      // Se usa TRIM y COLLATE NOCASE para asegurar que se encuentren coincidencias
      // a pesar de diferencias de espacios o mayúsculas.
      final String query = '''
        SELECT 
          b.*, 
          i.cod_interno as i_cod_interno, 
          i.marca as i_marca, 
          i.modelo as i_modelo, 
          i.serie as i_serie, 
          i.ubicacion as i_ubicacion, 
          i.estado as i_estado, 
          i.instrumento as i_instrumento, 
          i.tipo_instrumento as i_tipo_instrumento,
          i.detalles as i_detalles
        FROM balanzas b
        LEFT JOIN inf i ON TRIM(b.cod_metrica) = TRIM(i.cod_metrica) COLLATE NOCASE
        WHERE b.cod_metrica LIKE ?
        ORDER BY b.cod_metrica ASC
      ''';

      final List<Map<String, dynamic>> rawResults = await db.rawQuery(
        query,
        ['$plantaCodigo%'],
      );

      List<Map<String, dynamic>> processedBalanzas = [];

      for (var result in rawResults) {
        final codMetrica = result['cod_metrica'].toString();

        // Mantener verificación de estado (aunque sigue siendo N+1, es más seguro mantener la lógica existente por ahora)
        final estadoCalibacion = await _verificarEstadoCalibacion(codMetrica);

        // Construir mapa base
        Map<String, dynamic> balanzaCompleta = {
          // Datos base de tabla BALANZAS
          'cod_metrica': result['cod_metrica'],
          'categoria': result['categoria'],
          'tecnologia': result['tecnologia'],
          'clase': result['clase'],
          // 'tipo': result['tipo'], // Se sobreescribe abajo
          'rango': result['rango'],
          'unidad': result['unidad'],
          'n_celdas': result['n_celdas'],

          // Rango 1
          'cap_max1': result['cap_max1'],
          'd1': result['d1'],
          'e1': result['e1'],
          'dec1': result['dec1'],

          // Rango 2
          'cap_max2': result['cap_max2'],
          'd2': result['d2'],
          'e2': result['e2'],
          'dec2': result['dec2'],

          // Rango 3
          'cap_max3': result['cap_max3'],
          'd3': result['d3'],
          'e3': result['e3'],
          'dec3': result['dec3'],

          // Datos de INF (usando alias para evitar conflictos)
          'cod_interno': result['i_cod_interno'],
          'marca': result['i_marca'],
          'modelo': result['i_modelo'],
          'serie': result['i_serie'],
          'ubicacion': result['i_ubicacion'],
          'estado': result['i_estado'],
          'instrumento': result['i_instrumento'],

          // Datos calculados de calibración (NUEVO: Agregar lo que faltaba)
          'estado_calibracion': estadoCalibacion['estado'],
          'tiene_registro': estadoCalibacion['tiene_registro'],
        };

        // Lógica de tipo/instrumento
        // Formato: "instrumento - tipo"
        final instrumento = result['i_instrumento']?.toString() ?? '';
        final tipo = result['tipo']?.toString() ?? '';

        if (instrumento.isNotEmpty && tipo.isNotEmpty) {
          balanzaCompleta['tipo'] = '$instrumento - $tipo';
        } else if (instrumento.isNotEmpty) {
          balanzaCompleta['tipo'] = instrumento;
        } else {
          balanzaCompleta['tipo'] = tipo;
        }

        processedBalanzas.add(balanzaCompleta);
      }

      _balanzas = processedBalanzas;
      await db.close();
      if (_disposed) return;
      notifyListeners();
    } catch (e) {
      throw Exception('Error al cargar balanzas: $e');
    }
  }

  Future<Map<String, dynamic>> _verificarEstadoCalibacion(
      String codMetrica) async {
    try {
      final dbHelper = AppDatabase();
      final db = await dbHelper.database;

      final List<Map<String, dynamic>> registros = await db.query(
        'registros_calibracion',
        where: 'cod_metrica = ?',
        whereArgs: [codMetrica],
        orderBy: 'fecha_servicio DESC',
        limit: 1,
      );

      if (registros.isEmpty) {
        return {'estado': 'sin_registro', 'tiene_registro': false};
      }

      final estadoServicio =
          registros.first['estado_servicio_bal']?.toString() ?? '';

      if (estadoServicio == 'Balanza Calibrada') {
        return {'estado': 'calibrada', 'tiene_registro': true};
      } else {
        return {'estado': 'no_calibrada', 'tiene_registro': true};
      }
    } catch (e) {
      return {'estado': 'error', 'tiene_registro': false};
    }
  }

  void selectBalanza(Map<String, dynamic> balanza) async {
    _selectedBalanza = balanza;
    _isNewBalanza = false;
    _initializeBalanzaUnlockState(); // Inicializar estado de desbloqueo
    updateStepErrors();

    // NUEVO: Cargar datos del servicio anterior
    final codMetrica = balanza['cod_metrica']?.toString();
    if (codMetrica != null) {
      await _loadServicioDataForBalanza(codMetrica);
    }

    // NUEVO: Notificar al provider
    if (onBalanzaSelected != null) {
      onBalanzaSelected!(balanza);
    }

    notifyListeners();
  }

  Future<void> _loadServicioDataForBalanza(String codMetrica) async {
    try {
      final servicioData = await fetchServicioData(codMetrica);

      if (servicioData != null && _selectedBalanza != null) {
        // Agregar datos del servicio a la balanza seleccionada
        _selectedBalanza!['servicio'] = servicioData;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error al cargar servicio: $e');
    }
  }

  // ==================== MÉTODOS DE RECUPERACIÓN DE SERVICIOS INCOMPLETOS ====================

  /// Verifica si existe un servicio incompleto para el cod_metrica seleccionado
  Future<Map<String, dynamic>?> checkServicioIncompleto(String codMetrica) async {
    try {
      final dbHelper = AppDatabase();
      final servicioIncompleto =
          await dbHelper.getServicioIncompletoPorCodMetrica(codMetrica);
      return servicioIncompleto;
    } catch (e) {
      debugPrint('Error al verificar servicio incompleto: $e');
      return null;
    }
  }

  /// Carga los datos de un servicio incompleto en el controller
  Future<void> loadServicioIncompleto(Map<String, dynamic> registro) async {
    try {
      debugPrint('🔄 Recuperando servicio incompleto...');
      // Guardar referencia al registro para pasarlo a InicioServicioScreen
      _registroIncompletoActual = registro;

      // Cargar datos básicos del servicio
      if (registro['seca'] != null) {
        _generatedSeca = registro['seca'];
        _secaConfirmed = true;
      }

      if (registro['session_id'] != null) {
        _generatedSessionId = registro['session_id'];
      }

      if (registro['cliente'] != null) {
        _selectedClienteName = registro['cliente'];
      }

      if (registro['razon_social'] != null) {
        _selectedClienteRazonSocial = registro['razon_social'];
      }

      if (registro['planta'] != null) {
        _selectedPlantaNombre = registro['planta'];
      }

      if (registro['dir_planta'] != null) {
        _selectedPlantaDir = registro['dir_planta'];
      }

      if (registro['dep_planta'] != null) {
        _selectedPlantaDep = registro['dep_planta'];
      }

      if (registro['cod_planta'] != null) {
        _selectedPlantaCodigo = registro['cod_planta'];
      }

      // Cargar datos de la balanza si existen
      if (_selectedBalanza != null) {
        final balanzaData = _selectedBalanza!;

        // Campos editados
        if (registro['inf_bal'] != null) {
          _hiddenEditedFields = registro['inf_bal'];
          // Parsear campos editados y desbloquearlos
          final camposEditados =
              _hiddenEditedFields.isEmpty ? [] : _hiddenEditedFields.split(',');
          for (var campo in camposEditados) {
            _balanzaUnlockState[campo] = true;
          }
        }

        // Cargar datos de la balanza desde el registro
        if (registro['cod_int'] != null) {
          balanzaData['cod_interno'] = registro['cod_int'];
        }
        if (registro['marca'] != null) {
          balanzaData['marca'] = registro['marca'];
        }
        if (registro['modelo'] != null) {
          balanzaData['modelo'] = registro['modelo'];
        }
        if (registro['serie'] != null) {
          balanzaData['serie'] = registro['serie'];
        }
        if (registro['tipo_equipo'] != null) {
          balanzaData['tipo'] = registro['tipo_equipo'];
        }
        if (registro['unidades'] != null) {
          balanzaData['unidad'] = registro['unidades'];
        }
        if (registro['ubicacion'] != null) {
          balanzaData['ubicacion'] = registro['ubicacion'];
        }
        if (registro['n_celdas'] != null) {
          balanzaData['n_celdas'] = registro['n_celdas'];
        }
        if (registro['cap_max1'] != null) {
          balanzaData['cap_max1'] = registro['cap_max1'];
        }
        if (registro['d1'] != null) {
          balanzaData['d1'] = registro['d1'];
        }
        if (registro['cap_max2'] != null) {
          balanzaData['cap_max2'] = registro['cap_max2'];
        }
        if (registro['d2'] != null) {
          balanzaData['d2'] = registro['d2'];
        }
        if (registro['cap_max3'] != null) {
          balanzaData['cap_max3'] = registro['cap_max3'];
        }
        if (registro['d3'] != null) {
          balanzaData['d3'] = registro['d3'];
        }
      }

      // Cargar datos de inspección visual (Paso 1 de inicio_servicio)
      // Estos datos serán cargados por el InicioServicioController cuando corresponda

      debugPrint('✅ Servicio incompleto recuperado exitosamente');
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar servicio incompleto: $e');
      rethrow;
    }
  }

  /// Verifica si hay datos de inspección visual guardados
  Future<bool> hasInspeccionVisualData(String seca, String sessionId) async {
    try {
      final dbHelper = AppDatabase();
      final registro = await dbHelper.getRegistroBySeca(seca, sessionId);

      if (registro == null) return false;

      // Verificar si tiene datos de inspección visual
      return registro['vibracion'] != null &&
          registro['vibracion'].toString().isNotEmpty;
    } catch (e) {
      debugPrint('Error al verificar datos de inspección visual: $e');
      return false;
    }
  }

  /// Verifica si hay datos de precargas y ajuste guardados
  Future<bool> hasPrecargasData(String seca, String sessionId) async {
    try {
      final dbHelper = AppDatabase();
      final registro = await dbHelper.getRegistroBySeca(seca, sessionId);

      if (registro == null) return false;

      // Verificar si tiene datos de precargas
      return registro['precarga1'] != null &&
          registro['precarga1'].toString().isNotEmpty;
    } catch (e) {
      debugPrint('Error al verificar datos de precargas: $e');
      return false;
    }
  }

  /// Verifica si hay datos de excentricidad guardados
  Future<bool> hasExcentricidadData(String seca, String sessionId) async {
    try {
      final dbHelper = AppDatabase();
      final registro = await dbHelper.getRegistroBySeca(seca, sessionId);

      if (registro == null) return false;

      // Verificar si tiene datos de excentricidad
      return registro['tipo_plataforma'] != null &&
          registro['tipo_plataforma'].toString().isNotEmpty;
    } catch (e) {
      debugPrint('Error al verificar datos de excentricidad: $e');
      return false;
    }
  }

  /// Verifica si hay datos de repetibilidad guardados
  Future<bool> hasRepetibilidadData(String seca, String sessionId) async {
    try {
      final dbHelper = AppDatabase();
      final registro = await dbHelper.getRegistroBySeca(seca, sessionId);

      if (registro == null) return false;

      // Verificar si tiene datos de repetibilidad
      return registro['repetibilidad1'] != null &&
          registro['repetibilidad1'].toString().isNotEmpty;
    } catch (e) {
      debugPrint('Error al verificar datos de repetibilidad: $e');
      return false;
    }
  }

  /// Verifica si hay datos de linealidad guardados
  Future<bool> hasLinealidadData(String seca, String sessionId) async {
    try {
      final dbHelper = AppDatabase();
      final registro = await dbHelper.getRegistroBySeca(seca, sessionId);

      if (registro == null) return false;

      // Verificar si tiene datos de linealidad
      return registro['lin1'] != null &&
          registro['lin1'].toString().isNotEmpty;
    } catch (e) {
      debugPrint('Error al verificar datos de linealidad: $e');
      return false;
    }
  }

  /// Obtiene el paso actual del servicio incompleto
  /// Retorna: 0 = sin datos, 1 = inspección visual, 2 = precargas,
  /// 3 = excentricidad, 4 = repetibilidad, 5 = linealidad, 6 = foto/final
  Future<int> getPasoActualServicio(String seca, String sessionId) async {
    try {
      final dbHelper = AppDatabase();
      final registro = await dbHelper.getRegistroBySeca(seca, sessionId);

      if (registro == null) return 0;

      // Verificar datos de linealidad (paso más avanzado)
      if (await hasLinealidadData(seca, sessionId)) return 5;

      // Verificar datos de repetibilidad
      if (await hasRepetibilidadData(seca, sessionId)) return 4;

      // Verificar datos de excentricidad
      if (await hasExcentricidadData(seca, sessionId)) return 3;

      // Verificar datos de precargas
      if (await hasPrecargasData(seca, sessionId)) return 2;

      // Verificar datos de inspección visual
      if (await hasInspeccionVisualData(seca, sessionId)) return 1;

      return 0;
    } catch (e) {
      debugPrint('Error al obtener paso actual: $e');
      return 0;
    }
  }

  // NUEVO: Método para buscar y seleccionar balanza por QR
  String? selectBalanzaByQr(String codMetrica) {
    if (_balanzas.isEmpty) {
      return 'No hay instrumentos disponibles en esta planta.';
    }

    try {
      final balanzaEncontrada = _balanzas.firstWhere(
        (b) => b['cod_metrica'] == codMetrica,
      );
      selectBalanza(balanzaEncontrada);
      return null; // Éxito
    } catch (e) {
      return 'No se encontró el instrumento $codMetrica en esta planta.';
    }
  }

  void createNewBalanza() {
    final now = DateTime.now();
    final formattedDateTime =
        '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';

    _isNewBalanza = true;

    // CAMBIO: Usar código de planta o NNNN-NN si no existe/es nuevo
    String codMetrica;
    if (_selectedPlantaCodigo == null ||
        _selectedPlantaCodigo!.isEmpty ||
        _selectedPlantaCodigo == 'NNNN-NN') {
      codMetrica = 'NNNN-NN-$formattedDateTime';
    } else {
      codMetrica = '$_selectedPlantaCodigo-$formattedDateTime';
    }

    _selectedBalanza = {
      'cod_metrica': codMetrica,
    };

    // Notificar que es balanza nueva (sin servicio anterior)
    if (onBalanzaSelected != null) {
      onBalanzaSelected!(_selectedBalanza!);
    }

    _initializeBalanzaUnlockState(); // Inicializar estado de desbloqueo
    updateStepErrors();
    notifyListeners();
  }

  // MÉTODOS DE EQUIPOS
  Future<void> fetchEquipos() async {
    try {
      String path = join(await getDatabasesPath(), 'precarga_database.db');
      final db = await openDatabase(path);

      final List<Map<String, dynamic>> equiposList = await db.query(
        'equipamientos',
        where: "estado != 'DESACTIVADO'",
      );

      _equipos = equiposList;
      await db.close();
      if (_disposed) return;
      notifyListeners();
    } catch (e) {
      throw Exception('Error al cargar equipos: $e');
    }
  }

  void addEquipo(Map<String, dynamic> equipo, String tipo, String cantidad) {
    final equipoWithType = {
      ...equipo,
      'tipo': tipo,
      'cantidad': cantidad,
    };

    if (tipo == 'pesa') {
      if (_selectedEquipos.length < 5) {
        _selectedEquipos.add(equipoWithType);
      }
    } else if (tipo == 'termohigrometro') {
      if (_selectedTermohigrometros.length < 2) {
        _selectedTermohigrometros.add(equipoWithType);
      }
    }

    updateStepErrors();
    notifyListeners();
  }

  void removeEquipo(String codInstrumento, String tipo) {
    if (tipo == 'pesa') {
      _selectedEquipos.removeWhere(
          (e) => e['cod_instrumento'] == codInstrumento && e['tipo'] == tipo);
    } else if (tipo == 'termohigrometro') {
      _selectedTermohigrometros.removeWhere(
          (e) => e['cod_instrumento'] == codInstrumento && e['tipo'] == tipo);
    }

    updateStepErrors();
    notifyListeners();
  }

  void updateEquipoCantidad(
      String codInstrumento, String tipo, String cantidad) {
    List<Map<String, dynamic>> targetList =
        tipo == 'pesa' ? _selectedEquipos : _selectedTermohigrometros;

    for (var equipo in targetList) {
      if (equipo['cod_instrumento'] == codInstrumento &&
          equipo['tipo'] == tipo) {
        equipo['cantidad'] = cantidad;
        break;
      }
    }

    updateStepErrors();
    notifyListeners();
  }

  List<Map<String, dynamic>> getAllSelectedEquipos() {
    return [..._selectedEquipos, ..._selectedTermohigrometros];
  }

  Future<void> takePhoto() async {
    final photo = await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      _balanzaPhotos['identificacion'] ??= [];

      if (_balanzaPhotos['identificacion']!.length < 5) {
        try {
          // Guardar directamente en memoria, sin carpeta previa
          _balanzaPhotos['identificacion']!.add(File(photo.path));
          _fotosTomadas = true;
          notifyListeners();
        } catch (e) {
          throw Exception('Error al procesar foto: $e');
        }
      }
    }
  }

  void removePhoto(File photo) {
    try {
      _balanzaPhotos['identificacion']?.remove(photo);

      if (_balanzaPhotos['identificacion']?.isEmpty ?? true) {
        _fotosTomadas = false;
      }

      notifyListeners();
    } catch (e) {
      throw Exception('Error al eliminar foto: $e');
    }
  }

  Future<List<File>> getGuardedasPhotos() async {
    try {
      if (_baseFotoPath == null) return [];

      final folder = Directory(_baseFotoPath!);
      if (!await folder.exists()) return [];

      final files = folder.listSync();
      return files
          .whereType<File>()
          .where((file) => file.path.endsWith('.jpg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    } catch (e) {
      throw Exception('Error al listar fotos: $e');
    }
  }

  String? getFotoDirectoryPath() {
    return _baseFotoPath;
  }

  Future<String?> createPhotosZip() async {
    try {
      final photos = _balanzaPhotos['identificacion'] ?? [];
      if (photos.isEmpty) {
        throw Exception('No hay fotos para comprimir');
      }

      // Permitir al usuario seleccionar ubicación para el ZIP
      final String? zipPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleccionar ubicación para guardar ZIP de fotos',
      );

      if (zipPath == null) {
        return null; // Usuario canceló
      }

      // Crear nombre del ZIP
      final zipFileName =
          '${_selectedBalanza?['cod_metrica']}_fotos_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipFilePath = join(zipPath, zipFileName);

      // Crear archivo ZIP
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      // Agregar fotos al ZIP
      for (var photo in photos) {
        await encoder.addFile(photo);
      }

      encoder.close();

      return zipFilePath;
    } catch (e) {
      throw Exception('Error al crear ZIP: $e');
    }
  }

  // GUARDADO FINAL
  Future<void> saveAllData({
    required String userName,
    required String fechaServicio,
    required String nReca,
    required String sticker,
    required Map<String, String> balanzaData,
  }) async {
    try {
      final dbHelper = AppDatabase();

      // Filtrar campos que solo son visuales y no deben guardarse
      final dataToSave = Map<String, String>.from(balanzaData);
      dataToSave.remove('tecnologia');
      dataToSave.remove('clase');
      dataToSave.remove('rango'); // REMOVIDO
      dataToSave.remove('n_celdas'); // REMOVIDO

      final registro = {
        'seca': _generatedSeca!,
        'session_id': _generatedSessionId!,
        'personal': userName,
        'fecha_servicio': fechaServicio,
        'cliente': _selectedClienteName ?? 'No especificado',
        'razon_social': _selectedClienteRazonSocial ?? 'No especificado',
        'planta': _selectedPlantaNombre ?? 'No especificado',
        'dir_planta': _selectedPlantaDir ?? 'No especificado',
        'dep_planta': _selectedPlantaDep ?? 'No especificado',
        'cod_planta': _selectedPlantaCodigo ?? 'No especificado',
        'n_reca': nReca,
        'sticker': sticker,
        'inf_bal': _hiddenEditedFields, // GUARDAR CAMPOS EDITADOS
        ...dataToSave,
      };

      // GUARDAR SOLO LAS PESAS PATRÓN SELECCIONADAS (equipo1 a equipo5)
      for (int i = 0; i < _selectedEquipos.length && i < 5; i++) {
        final pesa = _selectedEquipos[i];
        registro['equipo${i + 1}'] = pesa['cod_instrumento']?.toString() ?? '';
        registro['certificado${i + 1}'] = pesa['cert_fecha']?.toString() ?? '';
        registro['ente_calibrador${i + 1}'] =
            pesa['ente_calibrador']?.toString() ?? '';
        registro['estado${i + 1}'] = pesa['estado']?.toString() ?? '';
        registro['cantidad${i + 1}'] = pesa['cantidad']?.toString() ?? '1';
      }

      // GUARDAR SOLO LOS TERMOHIGRÓMETROS SELECCIONADOS (equipo6 y equipo7)
      for (int i = 0; i < _selectedTermohigrometros.length && i < 2; i++) {
        final equipoNum = i + 6;
        final termo = _selectedTermohigrometros[i];
        registro['equipo$equipoNum'] =
            termo['cod_instrumento']?.toString() ?? '';
        registro['certificado$equipoNum'] =
            termo['cert_fecha']?.toString() ?? '';
        registro['ente_calibrador$equipoNum'] =
            termo['ente_calibrador']?.toString() ?? '';
        registro['estado$equipoNum'] = termo['estado']?.toString() ?? '';
        registro['cantidad$equipoNum'] = termo['cantidad']?.toString() ?? '1';
      }

      // Guardar en la base de datos
      await dbHelper.upsertRegistroCalibracion(registro);

      _isDataSaved = true;
      notifyListeners();
    } catch (e) {
      throw Exception('Error al guardar datos: $e');
    }
  }

  // UTILIDADES
  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  void reset() {
    _currentStep = 0;
    _isDataSaved = false;
    _generatedSessionId = null;
    _generatedSeca = null;
    _secaConfirmed = false;

    _clientes = null;
    _filteredClientes = null;
    _selectedClienteId = null;
    _selectedClienteName = null;
    _selectedClienteRazonSocial = null;
    _isNewClient = false;

    _plantas = null;
    _selectedPlantaKey = null;
    _selectedPlantaDir = null;
    _selectedPlantaDep = null;
    _selectedPlantaCodigo = null;

    _balanzas = [];
    _selectedBalanza = null;
    _isNewBalanza = false;
    _registroIncompletoActual = null;

    _equipos = [];
    _selectedEquipos = [];
    _selectedTermohigrometros = [];

    _balanzaPhotos.clear();
    _fotosTomadas = false;

    _stepErrors = {0: null, 1: null, 2: null, 3: null, 4: null};

    notifyListeners();
  }

  Future<void> loadEquiposFromSession(Map<String, dynamic> registro) async {
    try {
      _selectedEquipos.clear();
      _selectedTermohigrometros.clear();

      // Cargar Pesas (equipo1 - equipo5)
      for (int i = 1; i <= 5; i++) {
        final codInstrumento = registro['equipo$i']?.toString();
        if (codInstrumento != null && codInstrumento.isNotEmpty) {
          // Buscar en la lista de equipos cargados para tener todos los datos
          final dynamic equipoFound = _equipos.firstWhere(
            (e) => e['cod_instrumento'] == codInstrumento,
            orElse: () => <String, dynamic>{},
          );

          final Map<String, dynamic> equipoOriginal =
              Map<String, dynamic>.from(equipoFound as Map);

          if (equipoOriginal.isNotEmpty) {
            final Map<String, dynamic> equipoConDatos = {
              ...equipoOriginal,
              'tipo': 'pesa',
              'cantidad': registro['cantidad$i']?.toString() ?? '1',
              // Usar datos guardados en sesión si existen, o los del maestro
              'cert_fecha': registro['certificado$i']?.toString() ??
                  equipoOriginal['cert_fecha'],
              'ente_calibrador': registro['ente_calibrador$i']?.toString() ??
                  equipoOriginal['ente_calibrador'],
              'estado':
                  registro['estado$i']?.toString() ?? equipoOriginal['estado'],
            };
            _selectedEquipos.add(equipoConDatos);
          }
        }
      }

      // Cargar Termohigrómetros (equipo6 - equipo7)
      for (int i = 6; i <= 7; i++) {
        final codInstrumento = registro['equipo$i']?.toString();
        if (codInstrumento != null && codInstrumento.isNotEmpty) {
          // Buscar en la lista de equipos cargados
          final dynamic equipoFound = _equipos.firstWhere(
            (e) => e['cod_instrumento'] == codInstrumento,
            orElse: () => <String, dynamic>{},
          );

          final Map<String, dynamic> equipoOriginal =
              Map<String, dynamic>.from(equipoFound as Map);

          if (equipoOriginal.isNotEmpty) {
            final Map<String, dynamic> equipoConDatos = {
              ...equipoOriginal,
              'tipo': 'termohigrometro',
              'cantidad': registro['cantidad$i']?.toString() ?? '1',
              'cert_fecha': registro['certificado$i']?.toString() ??
                  equipoOriginal['cert_fecha'],
              'ente_calibrador': registro['ente_calibrador$i']?.toString() ??
                  equipoOriginal['ente_calibrador'],
              'estado':
                  registro['estado$i']?.toString() ?? equipoOriginal['estado'],
            };
            _selectedTermohigrometros.add(equipoConDatos);
          }
        }
      }

      updateStepErrors();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar equipos de la sesión: $e');
    }
  }

  // ==================== MÉTODOS DE QR ====================

  /// Procesa un código métrica escaneado desde un QR.
  /// Formato esperado: XXXX-XX-XXX (ej: 0032-11-001)
  /// Auto-selecciona cliente (paso 1) y planta (paso 2),
  /// almacena el código completo para auto-seleccionar balanza en paso 4.
  Future<String?> processQrCode(String codMetrica) async {
    _isQrMode = true;
    _qrCodMetrica = codMetrica;

    // Parsear el código métrica: XXXX-XX-XXX
    final parts = codMetrica.split('-');
    if (parts.length != 3) {
      _isQrMode = false;
      _qrCodMetrica = null;
      return 'Formato de código métrica inválido: $codMetrica';
    }

    final codigoCliente = parts[0]; // ej: 0032
    final codigoPlanta = '${parts[0]}-${parts[1]}'; // ej: 0032-11

    // 1. Buscar y auto-seleccionar cliente
    if (_clientes == null || _clientes!.isEmpty) {
      await fetchClientes();
    }

    final clienteMatch = _clientes?.firstWhere(
      (c) => c['codigo_cliente']?.toString().trim() == codigoCliente,
      orElse: () => <String, dynamic>{},
    );

    if (clienteMatch == null || clienteMatch.isEmpty) {
      _isQrMode = false;
      _qrCodMetrica = null;
      return 'No se encontró cliente con código: $codigoCliente';
    }

    // Seleccionar cliente MANUALMENTE (no usar selectClientFromList porque
    // este dispara fetchPlantas sin await, causando acceso concurrente a la BD)
    _isNewClient = false;
    _selectedClienteId = clienteMatch['cliente_id']?.toString() ?? '';
    _selectedClienteName = clienteMatch['cliente']?.toString() ?? '';
    _selectedClienteRazonSocial = clienteMatch['razonsocial']?.toString() ?? '';
    clearPlantaSelection();
    updateStepErrors();
    notifyListeners();

    // 2. Cargar plantas UNA SOLA VEZ con await
    await fetchPlantas(_selectedClienteId!);
    await fetchEquipos();

    if (_plantas == null || _plantas!.isEmpty) {
      return 'No se encontraron plantas para el cliente: ${clienteMatch['cliente']}';
    }

    final plantaMatch = _plantas!.firstWhere(
      (p) => p['codigo_planta']?.toString().trim() == codigoPlanta,
      orElse: () => <String, dynamic>{},
    );

    if (plantaMatch.isEmpty) {
      return 'No se encontró planta con código: $codigoPlanta';
    }

    // Seleccionar planta
    selectPlanta(plantaMatch['unique_key']?.toString() ?? '');

    // 3. Ir al paso 2 (SECA) - el usuario debe confirmar manualmente
    _currentStep = 2;
    updateStepErrors();
    notifyListeners();

    return null; // Sin error
  }

  /// Auto-selecciona la balanza que coincida con el código QR escaneado.
  /// Debe llamarse después de que se carguen las balanzas (después de confirmar SECA).
  Future<String?> autoSelectBalanzaFromQr() async {
    if (!_isQrMode || _qrCodMetrica == null) return null;

    if (_balanzas.isEmpty) {
      return 'No hay balanzas disponibles para selección automática';
    }

    final balanzaMatch = _balanzas.firstWhere(
      (b) => b['cod_metrica']?.toString().trim() == _qrCodMetrica?.trim(),
      orElse: () => <String, dynamic>{},
    );

    if (balanzaMatch.isEmpty) {
      return 'No se encontró balanza con código: $_qrCodMetrica';
    }

    // Seleccionar la balanza automáticamente
    selectBalanza(balanzaMatch);
    return null; // Sin error
  }

  /// Resetea el modo QR
  void clearQrMode() {
    _isQrMode = false;
    _qrCodMetrica = null;
    notifyListeners();
  }
}

// Excepción personalizada para SECA existente
class SecaExistsException implements Exception {
  final String fechaUltimoServicio;

  SecaExistsException(this.fechaUltimoServicio);

  @override
  String toString() => 'SECA ya existe. Último servicio: $fechaUltimoServicio';
}
