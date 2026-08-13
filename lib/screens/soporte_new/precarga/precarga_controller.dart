import 'package:flutter/material.dart';
import 'package:service_met/database/precarga_bd.dart';
import 'package:service_met/screens/soporte_new/database/database_helper_soporte.dart';
import 'package:service_met/utils/scale_range_validator.dart';

class ServicioInfo {
  final String nombre;
  final String codigo;
  final String descripcion;
  final IconData icon;
  final Color color;
  final String tag;

  const ServicioInfo({
    required this.nombre,
    required this.codigo,
    required this.descripcion,
    required this.icon,
    required this.color,
    required this.tag,
  });
}

class PrecargaController extends ChangeNotifier {
  final DatabaseHelperPrecarga _precargaDb = DatabaseHelperPrecarga();
  final DatabaseHelperSoporte _soporteDb = DatabaseHelperSoporte();

  String? sessionId;
  String? userName;
  String? clienteId;
  String? plantaCodigo;

  int currentStep = 0;
  static const int totalSteps = 6;

  final List<String> stepLabels = const [
    'Servicio',
    'Cliente',
    'Planta',
    'OTST',
    'Instrumento',
    'Resumen',
  ];

  static const List<ServicioInfo> serviciosDisponibles = [
    ServicioInfo(
      nombre: 'MNT PREVENTIVO REGULAR',
      codigo: 'MPR.BL',
      descripcion:
          'Mantenimiento preventivo periódico básico y limpieza general del equipo.',
      icon: Icons.build_circle_outlined,
      color: Color(0xFFE65100),
      tag: 'PREVENTIVO',
    ),
    ServicioInfo(
      nombre: 'MNT PREVENTIVO AVANZADO',
      codigo: 'MPA.SP',
      descripcion:
          'Mantenimiento preventivo profundo con inspección detallada de componentes.',
      icon: Icons.handyman_outlined,
      color: Color(0xFFBF360C),
      tag: 'AVANZADO',
    ),
    ServicioInfo(
      nombre: 'MANTENIMIENTO CORRECTIVO',
      codigo: 'MCR.BL',
      descripcion:
          'Reparación de fallas, reemplazo de repuestos o ajustes por avería.',
      icon: Icons.healing_outlined,
      color: Color(0xFFC62828),
      tag: 'CORRECTIVO',
    ),
    ServicioInfo(
      nombre: 'DIAGNÓSTICO',
      codigo: 'DIG.BL',
      descripcion:
          'Evaluación técnica inicial para determinar el estado y fallas del equipo.',
      icon: Icons.search_rounded,
      color: Color(0xFF00838F),
      tag: 'EVALUACIÓN',
    ),
    ServicioInfo(
      nombre: 'VERIFICACIONES INTERNAS',
      codigo: 'VIN.SP',
      descripcion:
          'Comprobación interna de tolerancias y rendimiento del instrumento.',
      icon: Icons.fact_check_outlined,
      color: Color(0xFF46824B),
      tag: 'VERIFICACIÓN',
    ),
    ServicioInfo(
      nombre: 'RELEVAMIENTO DE DATOS',
      codigo: 'REL.BL',
      descripcion:
          'Toma de datos técnicos y levantamiento de inventario en planta.',
      icon: Icons.assignment_outlined,
      color: Color(0xFF6A1B9A),
      tag: 'INVENTARIO',
    ),
    ServicioInfo(
      nombre: 'INSTALACIÓN',
      codigo: 'INS.BL',
      descripcion:
          'Puesta en marcha, montaje y configuración inicial en ubicación final.',
      icon: Icons.precision_manufacturing_outlined,
      color: Color(0xFF2E7D32),
      tag: 'INSTALACIÓN',
    ),
    ServicioInfo(
      nombre: 'AJUSTE DE VERIFICACIONES',
      codigo: 'IBM.BL',
      descripcion:
          'Calibración interna, ajuste de cero, span o linealidad según norma.',
      icon: Icons.tune_rounded,
      color: Color(0xFF4A148C),
      tag: 'AJUSTE',
    ),
  ];

  static List<String> get servicioOptions =>
      serviciosDisponibles.map((s) => s.nombre).toList();

  String? get selectedServiceCode {
    final selected = selectedServicio;
    if (selected == null) return null;
    for (final servicio in serviciosDisponibles) {
      if (servicio.nombre == selected) return servicio.codigo;
    }
    return null;
  }

  String? get suggestedCodigoRegistro {
    final otst = selectedSeca ?? suggestedSeca;
    final serviceCode = selectedServiceCode;
    final metrica = codMetrica;
    if (otst == null || serviceCode == null || metrica == null) return null;
    if (otst.isEmpty || metrica.isEmpty) return null;
    return '$otst-$serviceCode-$metrica';
  }

  String? selectedServicio;
  String? selectedSeca;
  String? suggestedSeca;
  String cotizacionSuffix = 'S01';
  bool secaConfirmed = false;
  bool noOtst = false;

  String? selectedInstrumento;
  String? nReca;
  String? codMetrica;

  List<Map<String, dynamic>> clientes = [];
  List<Map<String, dynamic>> plantas = [];
  List<Map<String, dynamic>> instrumentos = [];

  Map<String, dynamic>? selectedCliente;
  Map<String, dynamic>? selectedPlanta;
  Map<String, dynamic>? selectedInstrumentoData;

  bool isLoading = false;
  String? errorMessage;

  final List<String?> stepErrors = List.filled(totalSteps, null);

  Future<void> generateSessionId() async {
    sessionId = await _soporteDb.generateSessionId();
    notifyListeners();
  }

  Future<void> loadClientes() async {
    _setLoading(true);
    try {
      final result = await _precargaDb.getClientes();
      clientes = _mapClientes(result);
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Error al cargar clientes: $e';
      clientes = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> searchClientes(String query) async {
    final result = await _precargaDb.searchClientes(query);
    return _mapClientes(result);
  }

  List<Map<String, dynamic>> _mapClientes(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final nombre = row['cliente']?.toString() ?? 'Sin nombre';
      final razon = row['razonsocial']?.toString() ?? '';
      return {
        ...row,
        'nombre': nombre,
        'codigo': row['codigo_cliente'] ?? '',
        '_searchKey': '$nombre $razon'.toLowerCase(),
      };
    }).toList();
  }

  Future<void> loadPlantas() async {
    if (clienteId == null || clienteId!.isEmpty) return;
    _setLoading(true);
    try {
      final todas = await _precargaDb.getPlantas();
      final result =
          todas.where((p) => p['cliente_id']?.toString() == clienteId).toList();
      plantas = result
          .map((row) => {
                ...row,
                'nombre': row['planta'] ?? 'Sin nombre',
                'codigo': row['codigo_planta'] ?? '',
              })
          .toList();
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Error al cargar plantas: $e';
      plantas = [];
    } finally {
      _setLoading(false);
    }
  }

  void generateSuggestedSeca() {
    final cod = plantaCodigo ?? 'NNNN-NN';
    final year = DateTime.now().year.toString().substring(2);
    suggestedSeca = '$year-$cod-$cotizacionSuffix';
    notifyListeners();
  }

  void setCotizacionSuffix(String suffix) {
    final digits = suffix.replaceAll(RegExp(r'\D'), '');
    cotizacionSuffix =
        digits.isEmpty ? 'S01' : 'S${digits.padLeft(2, '0').substring(0, 2)}';
    generateSuggestedSeca();
  }

  void setNoOtst(bool value) {
    noOtst = value;
    cotizacionSuffix = value ? 'S00' : 'S01';
    generateSuggestedSeca();
  }

  void resetSeca() {
    secaConfirmed = false;
    selectedSeca = null;
    instrumentos = [];
    selectedInstrumento = null;
    selectedInstrumentoData = null;
    stepErrors[3] = 'Debe confirmar la OTST';
    notifyListeners();
  }

  Future<bool> checkSecaExists(String seca) async {
    if (seca.isEmpty) return false;
    try {
      final registros = await _soporteDb.getRegistrosPorSeca('precarga', seca);
      return registros.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> confirmSeca() async {
    if (suggestedSeca == null) generateSuggestedSeca();
    selectedSeca = suggestedSeca;
    secaConfirmed = true;
    stepErrors[3] = null;
    notifyListeners();
    await loadInstrumentos();
  }

  Future<void> loadInstrumentos() async {
    if (plantaCodigo == null || plantaCodigo!.isEmpty) {
      instrumentos = [];
      notifyListeners();
      return;
    }
    _setLoading(true);
    try {
      final result = await _precargaDb.getBalanzasPorPrefix(plantaCodigo!);
      instrumentos = result
          .map((row) => {
                ...row,
                'descripcion': row['instrumento']?.toString() ??
                    row['cod_metrica']?.toString() ??
                    'Sin descripción',
              })
          .toList();
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Error al cargar instrumentos: $e';
      instrumentos = [];
    } finally {
      _setLoading(false);
    }
  }

  void selectServicio(String servicio) {
    selectedServicio = servicio;
    stepErrors[0] = null;
    // Reseteo en cascada
    selectedCliente = null;
    clienteId = null;
    selectedPlanta = null;
    plantaCodigo = null;
    suggestedSeca = null;
    selectedSeca = null;
    secaConfirmed = false;
    noOtst = false;
    selectedInstrumento = null;
    selectedInstrumentoData = null;
    plantas = [];
    instrumentos = [];
    notifyListeners();
    loadClientes();
  }

  void selectCliente(Map<String, dynamic> cliente) {
    selectedCliente = cliente;
    clienteId = cliente['cliente_id']?.toString() ?? cliente['id']?.toString();
    selectedPlanta = null;
    plantaCodigo = null;
    suggestedSeca = null;
    selectedSeca = null;
    secaConfirmed = false;
    selectedInstrumento = null;
    selectedInstrumentoData = null;
    plantas = [];
    instrumentos = [];
    stepErrors[1] = null;
    notifyListeners();
    loadPlantas();
  }

  void selectPlanta(Map<String, dynamic> planta) {
    selectedPlanta = planta;
    plantaCodigo =
        planta['codigo_planta']?.toString() ?? planta['codigo']?.toString();
    selectedSeca = null;
    secaConfirmed = false;
    selectedInstrumento = null;
    selectedInstrumentoData = null;
    instrumentos = [];
    stepErrors[2] = null;
    generateSuggestedSeca();
    notifyListeners();
  }

  void selectInstrumento(Map<String, dynamic> instrumento,
      {bool notify = true}) {
    selectedInstrumentoData = instrumento;
    selectedInstrumento = instrumento['cod_metrica']?.toString() ??
        instrumento['codigo']?.toString();
    nReca = instrumento['n_reca']?.toString();
    codMetrica = selectedInstrumento;
    stepErrors[4] = null;
    if (notify) notifyListeners();
  }

  void setStep(int step) {
    if (step >= 0 && step < totalSteps) {
      currentStep = step;
      notifyListeners();
    }
  }

  void updateStepErrors() {
    for (int i = 0; i < totalSteps; i++) {
      stepErrors[i] = getStepError(i);
    }
    notifyListeners();
  }

  String? getStepError(int step) {
    switch (step) {
      case 0:
        return selectedServicio == null
            ? 'Seleccione un tipo de servicio'
            : null;
      case 1:
        return selectedCliente == null ? 'Seleccione un cliente' : null;
      case 2:
        return selectedPlanta == null ? 'Seleccione una planta' : null;
      case 3:
        return (!secaConfirmed || selectedSeca == null)
            ? 'Debe confirmar la OTST'
            : null;
      case 4:
        if (selectedInstrumento == null) {
          return selectedServicio == 'INSTALACIÓN'
              ? 'Debe registrar una balanza nueva para la instalación'
              : 'Seleccione un instrumento';
        }
        if (selectedServicio == 'INSTALACIÓN' &&
            selectedInstrumentoData?['isNew'] != true) {
          return 'Instalación solo admite una balanza nueva';
        }
        if (selectedInstrumentoData?['isNew'] == true) {
          final data = selectedInstrumentoData!;
          final rangeError = ScaleRangeValidator.validate([
            ScaleRangeValues(
              capacity: data['cap_max1'],
              division: data['d1'],
              verificationDivision: data['e1'],
              decimals: data['dec1'],
            ),
            ScaleRangeValues(
              capacity: data['cap_max2'],
              division: data['d2'],
              verificationDivision: data['e2'],
              decimals: data['dec2'],
            ),
            ScaleRangeValues(
              capacity: data['cap_max3'],
              division: data['d3'],
              verificationDivision: data['e3'],
              decimals: data['dec3'],
            ),
          ]);
          if (rangeError != null) return rangeError;
        }
        return null;
      case 5:
        return null;
      default:
        return null;
    }
  }

  bool isStepValid(int step) {
    return getStepError(step) == null;
  }

  bool canProceedFromStep(int step) {
    for (int i = 0; i <= step; i++) {
      if (!isStepValid(i)) return false;
    }
    return true;
  }

  void setClienteId(String id) {
    clienteId = id;
  }

  void setPlantaCodigo(String codigo) {
    plantaCodigo = codigo;
  }

  Future<void> presetForNuevaBalanza({
    required String servicio,
    required String clienteId,
    required String plantaCodigo,
    required String seca,
  }) async {
    selectedServicio = servicio;
    this.clienteId = clienteId;
    this.plantaCodigo = plantaCodigo;

    await loadClientes();
    final cliente = clientes.firstWhere(
      (c) => (c['cliente_id']?.toString() ?? c['id']?.toString()) == clienteId,
      orElse: () => <String, dynamic>{},
    );
    if (cliente.isNotEmpty) {
      selectedCliente = cliente;
    }

    await loadPlantas();
    final planta = plantas.firstWhere(
      (p) =>
          (p['codigo_planta']?.toString() ?? p['codigo']?.toString()) ==
          plantaCodigo,
      orElse: () => <String, dynamic>{},
    );
    if (planta.isNotEmpty) {
      selectedPlanta = planta;
    }

    selectedSeca = seca;
    suggestedSeca = seca;
    secaConfirmed = true;
    stepErrors[3] = null;

    await loadInstrumentos();

    currentStep = 4;
    notifyListeners();
  }

  void reset() {
    sessionId = null;
    userName = null;
    clienteId = null;
    plantaCodigo = null;
    currentStep = 0;
    selectedServicio = null;
    suggestedSeca = null;
    selectedSeca = null;
    cotizacionSuffix = 'S01';
    secaConfirmed = false;
    noOtst = false;
    selectedInstrumento = null;
    nReca = null;
    codMetrica = null;
    selectedCliente = null;
    selectedPlanta = null;
    selectedInstrumentoData = null;
    clientes = [];
    plantas = [];
    instrumentos = [];
    isLoading = false;
    errorMessage = null;
    for (int i = 0; i < stepErrors.length; i++) {
      stepErrors[i] = null;
    }
    notifyListeners();
  }

  Future<Set<String>> getCompletedCodMetricas() async {
    if (selectedSeca == null || selectedSeca!.isEmpty) return {};
    try {
      final registros =
          await _soporteDb.getRegistrosPorSeca('precarga', selectedSeca!);
      return registros
          .map((r) => r['cod_metrica']?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
