import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/calibration_record_validator.dart';
import '../../database/precarga_bd.dart';
import '../../login/services/connection_profile_service.dart';
import '../../repositories/calibration_repository.dart';
import '../../screens/calidad/utils/exportar_documento.dart';
import '../../theme/app_design.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../models/calibration_upload_models.dart';
import '../models/servicio_model.dart';
import '../services/calibration_upload_api_service.dart';
import '../services/local_service_record_repository.dart';
import '../services/upload_record_deduplicator.dart';
import '../widgets/asignar_codigo_sheet.dart';
import '../widgets/balanzas_nuevas_section.dart';
import '../widgets/upload_auth_dialog.dart';
import '../../theme/app_icons.dart';

class CalibrationUploadScreen extends StatefulWidget {
  final String seca;

  const CalibrationUploadScreen({super.key, required this.seca});

  @override
  State<CalibrationUploadScreen> createState() =>
      _CalibrationUploadScreenState();
}

class _CalibrationUploadScreenState extends State<CalibrationUploadScreen> {
  final CalibrationRepository _repository = CalibrationRepository();
  List<Map<String, dynamic>> _pendingRecords = [];
  int _uploadedCount = 0;
  int _duplicateCount = 0;
  bool _loading = true;
  bool _working = false;
  String? _error;
  CalibrationValidationResult? _validation;

  /// Balanzas nuevas: su código métrica es provisional hasta registrarlas en
  /// DataMET. No se validan ni se suben hasta que tengan el definitivo.
  List<Map<String, dynamic>> get _nuevas =>
      _pendingRecords.where(esBalanzaNueva).toList();

  /// Lo que se valida y se sube: las balanzas ya registradas en DataMET.
  List<Map<String, dynamic>> get _registradas =>
      _pendingRecords.where((record) => !esBalanzaNueva(record)).toList();

  /// Balanzas pendientes sin alguna prueba guardada: "0032-11-020: Linealidad".
  /// El servidor solo revisa tipos y formatos; una prueba vacía la aceptaría.
  List<String> get _incompleteRecords => [
        for (final record in _pendingRecords)
          if (CalibrationRecordValidator.missingTests(record) case final faltan
              when faltan.isNotEmpty)
            '${record['cod_metrica'] ?? 'Sin código'}: ${faltan.join(', ')}',
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _validation = null;
    });
    try {
      final records = await _repository.getRegistrosPorSeca(widget.seca);
      final statuses = await _repository.getUploadStatus(widget.seca);
      final uploadedCodes = statuses.values
          .map((status) =>
              status['codigo_registro']?.toString().trim().toUpperCase() ?? '')
          .where((code) => code.isNotEmpty)
          .toSet();
      final completed = records
          .where((record) =>
              record['estado_servicio_bal']?.toString() == 'Balanza Calibrada')
          .toList();
      final unresolved = completed
          .where((record) {
            final sessionId = record['session_id']?.toString() ?? '';
            final code = '${record['seca']}-${record['cod_metrica']}'
                .trim()
                .toUpperCase();
            return !statuses.containsKey(sessionId) &&
                !uploadedCodes.contains(code);
          })
          .map(Map<String, dynamic>.from)
          .toList();
      final deduplicated = deduplicateUploadRecords(
        unresolved,
        calibrationUploadLogicalKey,
      );
      if (!mounted) return;
      setState(() {
        _pendingRecords = deduplicated.records;
        _duplicateCount = deduplicated.duplicateCount;
        _uploadedCount = completed.length - unresolved.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar los registros: $error';
      });
    }
  }

  CalibrationUploadApiService _api() {
    final profile = context.read<ConnectionProfileService>().perfilSeleccionado;
    if (profile == null || profile.apiUrl.isEmpty) {
      throw CalibrationUploadException(
          'Seleccione un perfil de conexión con una URL de API válida.');
    }
    return CalibrationUploadApiService(profile.apiUrl);
  }

  Future<void> _validate() async {
    if (_registradas.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    CalibrationUploadApiService? api;
    try {
      api = _api();
      final result = await _validateWithAuthentication(api);
      if (result == null) return;
      if (!mounted) return;
      setState(() => _validation = result);
    } on TimeoutException {
      _showError('El servidor no respondió dentro del tiempo esperado.');
    } catch (error) {
      _showError(error.toString());
    } finally {
      api?.close();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<CalibrationValidationResult?> _validateWithAuthentication(
      CalibrationUploadApiService api) async {
    final registradas = _registradas;
    try {
      return await api.validate(registradas);
    } on CalibrationUploadException catch (error) {
      if (!_requiresCredentials(error)) rethrow;
      final authenticated = await _requestPasswordAndAuthenticate(api);
      if (!authenticated) return null;
      return api.validate(registradas);
    }
  }

  bool _requiresCredentials(CalibrationUploadException error) {
    return error.code == 'LOCAL_CREDENTIALS_MISSING' ||
        error.code == 'MISSING_CREDENTIALS' ||
        error.code == 'INVALID_CREDENTIALS';
  }

  Future<bool> _requestPasswordAndAuthenticate(
      CalibrationUploadApiService api) async {
    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('logged_user');
    if (usuario == null || usuario.isEmpty || !mounted) {
      throw CalibrationUploadException(
        'No hay un usuario activo. Cierre sesión e ingrese nuevamente.',
      );
    }

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UploadAuthDialog(
        usuario: usuario,
        message:
            'Ingrese su contraseña para obtener una autorización temporal del servidor.',
      ),
    );
    if (password == null || password.isEmpty) return false;

    await api.authenticate(usuario: usuario, password: password);
    return true;
  }

  Future<void> _upload({required bool validOnly}) async {
    final validation = _validation;
    if (validation == null) return;
    final incompletas = _incompleteRecords.length;
    final nuevas = _nuevas.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(validOnly ? 'Subir registros válidos' : 'Subir lote completo'),
        content: Text(
            '${validOnly ? 'Se subirán ${validation.validCount} balanzas. Las ${validation.invalidCount} balanzas con errores permanecerán pendientes.' : 'Se subirán ${validation.validCount} balanzas en una sola transacción.'}'
            '${incompletas > 0 ? '\n\nAtención: $incompletas balanza(s) no tienen todas sus pruebas guardadas y se subirán así.' : ''}'
            '${nuevas > 0 ? '\n\n$nuevas balanza(s) nueva(s) quedan pendientes hasta que asigne su código métrica.' : ''}'
            '\n\n¿Desea continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar subida'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _working = true;
      _error = null;
    });
    CalibrationUploadApiService? api;
    // Los índices de la respuesta son los de esta lista.
    final registradas = _registradas;
    try {
      api = _api();
      final result =
          await _uploadWithAuthentication(api, registradas, validOnly);
      if (result == null) return;
      final prefs = await SharedPreferences.getInstance();
      final uploadedBy = prefs.getString('logged_user') ?? '';
      final localStatuses = <Map<String, dynamic>>[];
      for (final uploaded in result.uploaded) {
        if (uploaded.index < 0 || uploaded.index >= registradas.length) {
          continue;
        }
        final local = registradas[uploaded.index];
        localStatuses.add({
          'seca': local['seca'],
          'session_id': local['session_id'],
          'codigo_registro': uploaded.codigoRegistro,
          'server_n': uploaded.serverN,
        });
      }
      await _repository.markRecordsUploaded(
        localStatuses,
        uploadedBy: uploadedBy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      await _load();
    } on TimeoutException {
      _showError(
          'La respuesta del servidor tardó demasiado. Actualice y valide antes de reintentar para evitar duplicados.');
    } catch (error) {
      _showError(error.toString());
    } finally {
      api?.close();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<CalibrationUploadResult?> _uploadWithAuthentication(
      CalibrationUploadApiService api,
      List<Map<String, dynamic>> records,
      bool validOnly) async {
    try {
      return await api.upload(records, validOnly: validOnly);
    } on CalibrationUploadException catch (error) {
      if (!_requiresCredentials(error)) rethrow;
      final authenticated = await _requestPasswordAndAuthenticate(api);
      if (!authenticated) return null;
      return api.upload(records, validOnly: validOnly);
    }
  }

  /// Cambia el código provisional de una balanza nueva por el que le dio
  /// DataMET. Queda en el historial del registro.
  Future<void> _asignarCodigo(Map<String, dynamic> record) async {
    final codigo = await showAsignarCodigoSheet(
      context,
      registro: record,
      buscarEnCatalogo: (codigo) =>
          DatabaseHelperPrecarga().getBalanzaPorCodigo(codigo),
      verificar: (codigo) async {
        final duplicado = await _repository.findDuplicateService(
          seca: widget.seca,
          codMetrica: codigo,
          excludingSessionId: record['session_id']?.toString() ?? '',
        );
        return duplicado == null
            ? null
            : 'La balanza $codigo ya tiene un registro en esta SECA.';
      },
      guardar: (codigo) async {
        final prefs = await SharedPreferences.getInstance();
        await LocalServiceRecordRepository.asignarCodigoMetrica(
          TipoServicio.calibracion,
          record,
          nuevo: codigo,
          usuario: prefs.getString('logged_user') ?? '',
          appVersion: await versionInstalada(),
        );
      },
    );
    if (codigo == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Código $codigo asignado. Valide los datos para subir '
          'esta balanza.'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
    await _load();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message.replaceFirst('Exception: ', ''));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    return Scaffold(
      // La lista pasa por detrás del botón de subir y de la barra de
      // navegación, como en el inicio.
      extendBody: true,
      appBar: ServiceAppBar(
        title: 'Subir calibración',
        actions: [
          IconButton(
            onPressed: _working ? null : _load,
            tooltip: 'Actualizar',
            icon: const Icon(AppIcons.actualizar),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 120 + MediaQuery.paddingOf(context).bottom),
              children: [
                _summaryCard(colors, isDark),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _messageCard(
                    icon: AppIcons.error,
                    color: Colors.red,
                    text: _error!,
                  ),
                ],
                if (_duplicateCount > 0) ...[
                  const SizedBox(height: 12),
                  _messageCard(
                    icon: AppIcons.copiar,
                    color: Colors.orange,
                    text: 'Se encontraron $_duplicateCount registro(s) '
                        'local(es) duplicado(s). Se subirá solamente la '
                        'calibración más reciente de cada balanza.',
                  ),
                ],
                if (_incompleteRecords.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _messageCard(
                    icon: AppIcons.lista,
                    color: Colors.red,
                    text: 'Estas balanzas no tienen todas sus pruebas '
                        'guardadas en el teléfono. Revíselas antes de '
                        'subir:\n${_incompleteRecords.map((linea) => '• $linea').join('\n')}',
                  ),
                ],
                if (_nuevas.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  BalanzasNuevasSection(
                    registros: _nuevas,
                    hayRegistradas: _registradas.isNotEmpty,
                    onAsignar: _working ? null : _asignarCodigo,
                  ),
                ],
                const SizedBox(height: 20),
                if (_pendingRecords.isEmpty)
                  _messageCard(
                    icon: AppIcons.nubeLista,
                    color: Colors.green,
                    text: _uploadedCount > 0
                        ? 'Todas las balanzas completas de esta SECA ya fueron subidas.'
                        : 'No hay balanzas completas disponibles para subir.',
                  )
                else if (_registradas.isEmpty)
                  const SizedBox.shrink()
                else if (_validation == null)
                  _messageCard(
                    icon: AppIcons.verificacion,
                    color: colors.primary,
                    text:
                        'Primero se comprobarán tipos, longitudes, formatos y duplicados. Esta acción no escribe datos en el servidor.',
                  )
                else
                  ..._validation!.records.map(_recordCard),
              ],
            ),
      bottomNavigationBar: _registradas.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _buildActionButton(),
              ),
            ),
    );
  }

  Widget _summaryCard(ColorScheme colors, bool isDark) {
    final profile =
        context.watch<ConnectionProfileService>().perfilSeleccionado;
    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SECA ${widget.seca}',
            style:
                GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
            '${_pendingRecords.length} pendientes · $_uploadedCount subidas'
            '${_nuevas.isEmpty ? '' : ' · ${_nuevas.length} nueva(s) sin código'}',
            style: GoogleFonts.inter(color: colors.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('Conexión: ${profile?.nombre ?? 'sin seleccionar'}',
            style: GoogleFonts.inter(
                fontSize: 12, color: colors.onSurfaceVariant)),
      ]),
    );
  }

  Widget _messageCard(
      {required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.inter(height: 1.4))),
      ]),
    );
  }

  Widget _recordCard(UploadRecordValidation record) {
    final color = record.valid ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          record.valid ? AppIcons.completo : AppIcons.cancelar,
          color: color,
        ),
        title: Text(record.codMetrica ?? 'Balanza sin código',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        subtitle: Text(record.valid
            ? 'Lista para subir'
            : '${record.errors.length} error(es)'),
        children: record.errors
            .map((issue) => ListTile(
                  dense: true,
                  title: Text(issue.column ?? 'Registro',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${issue.message}\nValor: ${issue.value ?? '(vacío)'}'
                    '${issue.expected == null ? '' : '\nEsperado: ${issue.expected}'}',
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_working) {
      return const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final validation = _validation;
    if (validation == null) {
      return FilledButton.icon(
        onPressed: _validate,
        icon: const Icon(AppIcons.verificacion),
        label: const Text('VALIDAR DATOS'),
      );
    }
    // Con balanzas nuevas pendientes se aclara que solo suben las
    // registradas: las nuevas esperan su código métrica.
    final soloRegistradas = _nuevas.isNotEmpty;
    if (validation.invalidCount == 0) {
      return FilledButton.icon(
        onPressed: () => _upload(validOnly: false),
        icon: const Icon(AppIcons.subir),
        label: Text(soloRegistradas
            ? 'SUBIR REGISTRADAS (${validation.validCount})'
            : 'SUBIR LOTE COMPLETO (${validation.validCount})'),
      );
    }
    if (validation.validCount > 0) {
      return FilledButton.icon(
        onPressed: () => _upload(validOnly: true),
        icon: const Icon(AppIcons.subir),
        label: Text(soloRegistradas
            ? 'SUBIR REGISTRADAS VÁLIDAS (${validation.validCount})'
            : 'SUBIR SOLO VÁLIDOS (${validation.validCount})'),
      );
    }
    return OutlinedButton.icon(
      onPressed: _validate,
      icon: const Icon(AppIcons.actualizar),
      label: const Text('VALIDAR NUEVAMENTE'),
    );
  }
}
