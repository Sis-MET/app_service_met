import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/precarga_bd.dart';
import '../../login/services/connection_profile_service.dart';
import '../../screens/calidad/utils/exportar_documento.dart';
import '../../screens/soporte_new/database/database_helper_soporte.dart';
import '../../theme/app_design.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../models/calibration_upload_models.dart';
import '../models/servicio_model.dart';
import '../services/calibration_upload_api_service.dart';
import '../services/local_service_record_repository.dart';
import '../services/support_upload_api_service.dart';
import '../services/support_upload_status_service.dart';
import '../services/upload_record_deduplicator.dart';
import '../widgets/asignar_codigo_sheet.dart';
import '../widgets/balanzas_nuevas_section.dart';
import '../widgets/upload_auth_dialog.dart';
import '../../theme/app_icons.dart';

class SupportUploadScreen extends StatefulWidget {
  final ServicioResumen servicio;

  const SupportUploadScreen({super.key, required this.servicio});

  @override
  State<SupportUploadScreen> createState() => _SupportUploadScreenState();
}

class _SupportUploadScreenState extends State<SupportUploadScreen> {
  final SupportUploadStatusService _status = SupportUploadStatusService();
  List<Map<String, dynamic>> _pending = [];
  int _uploadedCount = 0;
  int _duplicateCount = 0;
  bool _loading = true;
  bool _working = false;
  String? _error;
  CalibrationValidationResult? _validation;

  /// Equipos nuevos: su código métrica es provisional hasta registrarlos en
  /// DataMET. No se validan ni se suben hasta que tengan el definitivo.
  List<Map<String, dynamic>> get _nuevas =>
      _pending.where(esBalanzaNueva).toList();

  /// Lo que se valida y se sube: los equipos ya registrados en DataMET.
  List<Map<String, dynamic>> get _registradas =>
      _pending.where((record) => !esBalanzaNueva(record)).toList();

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
      final completed = widget.servicio.items
          .where(isSupportRecordComplete)
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
      final uploaded =
          await _status.uploadedLogicalKeys(widget.servicio.codigo);
      final unresolved = completed
          .where(
              (record) => !uploaded.contains(supportUploadLogicalKey(record)))
          .toList(growable: false);
      final deduplicated = deduplicateUploadRecords(
        unresolved,
        supportUploadLogicalKey,
      );
      if (!mounted) return;
      setState(() {
        _pending = deduplicated.records;
        _duplicateCount = deduplicated.duplicateCount;
        _uploadedCount = completed.length - unresolved.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron leer los servicios de soporte: $error';
      });
    }
  }

  SupportUploadApiService _api() {
    final profile = context.read<ConnectionProfileService>().perfilSeleccionado;
    if (profile == null || profile.apiUrl.isEmpty) {
      throw CalibrationUploadException(
        'Seleccione un perfil de conexión con una URL de API válida.',
      );
    }
    return SupportUploadApiService(profile.apiUrl);
  }

  bool _needsAuthentication(CalibrationUploadException error) =>
      error.statusCode == 401 ||
      error.code == 'LOCAL_CREDENTIALS_MISSING' ||
      error.code == 'MISSING_CREDENTIALS' ||
      error.code == 'INVALID_CREDENTIALS';

  Future<bool> _authenticate(SupportUploadApiService api) async {
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
            'Ingrese su contraseña para autorizar temporalmente la subida de soporte.',
      ),
    );
    if (password == null || password.isEmpty) return false;
    await api.authenticate(usuario: usuario, password: password);
    return true;
  }

  Future<T?> _withAuthentication<T>(
    SupportUploadApiService api,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on CalibrationUploadException catch (error) {
      if (!_needsAuthentication(error)) rethrow;
      if (!await _authenticate(api)) return null;
      return operation();
    }
  }

  Future<void> _validate() async {
    final registradas = _registradas;
    if (registradas.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    SupportUploadApiService? api;
    try {
      api = _api();
      final result =
          await _withAuthentication(api, () => api!.validate(registradas));
      if (result != null && mounted) setState(() => _validation = result);
    } on TimeoutException {
      _showError('El servidor no respondió dentro del tiempo esperado.');
    } catch (error) {
      _showError(error.toString());
    } finally {
      api?.close();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _upload({required bool validOnly}) async {
    final validation = _validation;
    if (validation == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(validOnly ? 'Subir registros válidos' : 'Subir lote completo'),
        content: Text((validOnly
                ? 'Se subirán ${validation.validCount} registros. Los ${validation.invalidCount} registros observados permanecerán pendientes.'
                : 'Se subirán ${validation.validCount} registros y sus resúmenes en una sola transacción.') +
            (_nuevas.isEmpty
                ? ''
                : '\n\n${_nuevas.length} equipo(s) nuevo(s) quedan pendientes hasta que asigne su código métrica.')),
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
    SupportUploadApiService? api;
    // Los índices de la respuesta son los de esta lista.
    final registradas = _registradas;
    try {
      api = _api();
      final result = await _withAuthentication(
        api,
        () => api!.upload(registradas, validOnly: validOnly),
      );
      if (result == null) return;
      final prefs = await SharedPreferences.getInstance();
      final uploadedBy = prefs.getString('logged_user') ?? '';
      for (final uploaded in result.uploaded) {
        if (uploaded.index < 0 || uploaded.index >= registradas.length) {
          continue;
        }
        await _status.markUploaded(
          record: registradas[uploaded.index],
          codigoRegistro: uploaded.codigoRegistro,
          serverN: uploaded.serverN,
          uploadedBy: uploadedBy,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.green),
      );
      await _load();
    } on TimeoutException {
      _showError(
        'La respuesta tardó demasiado. Actualice y valide antes de reintentar para evitar duplicados.',
      );
    } catch (error) {
      _showError(error.toString());
    } finally {
      api?.close();
      if (mounted) setState(() => _working = false);
    }
  }

  /// Cambia el código provisional de un equipo nuevo por el que le dio
  /// DataMET. Queda en el historial del registro.
  Future<void> _asignarCodigo(Map<String, dynamic> record) async {
    final modulo = record['_support_module']?.toString() ?? '';
    final anterior = record['cod_metrica']?.toString().trim() ?? '';
    final codigo = await showAsignarCodigoSheet(
      context,
      registro: record,
      buscarEnCatalogo: (codigo) =>
          DatabaseHelperPrecarga().getBalanzaPorCodigo(codigo),
      verificar: (codigo) async {
        // Otro registro del mismo módulo en esta OTST con ese código sería
        // el mismo servicio dos veces.
        final repetido = widget.servicio.items.any((item) =>
            !identical(item, record) &&
            item['_support_module']?.toString() == modulo &&
            item['id']?.toString() != record['id']?.toString() &&
            (item['cod_metrica']?.toString().trim().toUpperCase() ?? '') ==
                codigo.toUpperCase());
        return repetido
            ? 'Otro registro de ${record['_support_label'] ?? 'este módulo'} '
                'en esta OTST ya tiene el código $codigo.'
            : null;
      },
      guardar: (codigo) async {
        final prefs = await SharedPreferences.getInstance();
        await LocalServiceRecordRepository.asignarCodigoMetrica(
          TipoServicio.soporte,
          record,
          nuevo: codigo,
          usuario: prefs.getString('logged_user') ?? '',
          appVersion: await versionInstalada(),
        );
      },
    );
    if (codigo == null || !mounted) return;
    // La lista del servicio es la que se volvió a leer al abrir esta
    // pantalla: se actualiza para no volver a mostrar el código anterior.
    for (final item in widget.servicio.items) {
      if (item['_source_table'] == record['_source_table'] &&
          item['id']?.toString() == record['id']?.toString()) {
        item['cod_metrica'] = codigo;
      }
    }
    // El progreso de la sesión (para avisar servicios repetidos) también
    // usa el código; es un dato de control, no el registro técnico.
    try {
      await DatabaseHelperSoporte().actualizarCodMetrica(
        otst: record['otst']?.toString() ?? '',
        sessionId: record['session_id']?.toString() ?? '',
        anterior: anterior,
        nuevo: codigo,
      );
    } catch (error) {
      debugPrint('No se actualizó el progreso de la sesión: $error');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Código $codigo asignado. Valide los datos para subir '
          'este equipo.'),
      backgroundColor: Colors.green,
    ));
    await _load();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message.replaceFirst('Exception: ', ''));
  }

  @override
  void dispose() {
    _status.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      // La lista pasa por detrás del botón de subir y de la barra de
      // navegación, como en el inicio.
      extendBody: true,
      appBar: ServiceAppBar(
        title: 'Subir soporte',
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
                AppPanel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OTST ${widget.servicio.codigo}',
                        style: GoogleFonts.poppins(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${_pending.length} pendientes · '
                          '$_uploadedCount subidos'
                          '${_nuevas.isEmpty ? '' : ' · ${_nuevas.length} nuevo(s) sin código'}'),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _message(AppIcons.error, Colors.red, _error!),
                ],
                if (_duplicateCount > 0) ...[
                  const SizedBox(height: 12),
                  _message(
                    AppIcons.copiar,
                    Colors.orange,
                    'Se encontraron $_duplicateCount registro(s) local(es) '
                    'duplicado(s). Se subirá solamente el registro más reciente '
                    'de cada equipo.',
                  ),
                ],
                if (_nuevas.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  BalanzasNuevasSection(
                    registros: _nuevas,
                    hayRegistradas: _registradas.isNotEmpty,
                    onAsignar: _working ? null : _asignarCodigo,
                    etiqueta: (registro) =>
                        registro['_support_label']?.toString(),
                  ),
                ],
                const SizedBox(height: 20),
                if (_pending.isEmpty)
                  _message(
                    AppIcons.nubeLista,
                    Colors.green,
                    _uploadedCount > 0
                        ? 'Todos los servicios completos de esta OTST ya fueron subidos.'
                        : 'No hay registros completos disponibles para subir.',
                  )
                else if (_registradas.isEmpty)
                  const SizedBox.shrink()
                else if (_validation == null)
                  _message(
                    AppIcons.verificacion,
                    colors.primary,
                    'Se validarán tipos, longitudes, formatos y duplicados antes de escribir en el servidor.',
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
                child: _actionButton(),
              ),
            ),
    );
  }

  Widget _message(IconData icon, Color color, String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Widget _recordCard(UploadRecordValidation record) {
    final registradas = _registradas;
    final source = record.index >= 0 && record.index < registradas.length
        ? registradas[record.index]
        : const <String, dynamic>{};
    final color = record.valid ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          record.valid ? AppIcons.completo : AppIcons.cancelar,
          color: color,
        ),
        title: Text(record.codMetrica ?? 'Equipo sin código'),
        subtitle: Text(
          '${source['_support_label'] ?? 'Soporte'} · '
          '${record.valid ? 'Listo para subir' : '${record.errors.length} error(es)'}',
        ),
        children: record.errors
            .map(
              (error) => ListTile(
                dense: true,
                title: Text(error.column ?? 'Registro'),
                subtitle: Text(
                  '${error.message}\nValor: ${error.value ?? '(vacío)'}'
                  '${error.expected == null ? '' : '\nEsperado: ${error.expected}'}',
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _actionButton() {
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
    // Con equipos nuevos pendientes se aclara que solo suben los
    // registrados: los nuevos esperan su código métrica.
    final soloRegistradas = _nuevas.isNotEmpty;
    if (validation.invalidCount == 0) {
      return FilledButton.icon(
        onPressed: () => _upload(validOnly: false),
        icon: const Icon(AppIcons.subir),
        label: Text(soloRegistradas
            ? 'SUBIR REGISTRADOS (${validation.validCount})'
            : 'SUBIR LOTE COMPLETO (${validation.validCount})'),
      );
    }
    if (validation.validCount > 0) {
      return FilledButton.icon(
        onPressed: () => _upload(validOnly: true),
        icon: const Icon(AppIcons.subir),
        label: Text(soloRegistradas
            ? 'SUBIR REGISTRADOS VÁLIDOS (${validation.validCount})'
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
