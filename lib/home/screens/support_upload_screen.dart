import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../login/services/connection_profile_service.dart';
import '../../theme/app_design.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../models/calibration_upload_models.dart';
import '../models/servicio_model.dart';
import '../services/calibration_upload_api_service.dart';
import '../services/support_upload_api_service.dart';
import '../services/support_upload_status_service.dart';
import '../widgets/upload_auth_dialog.dart';
import '../widgets/new_scales_upload_notice.dart';

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
  bool _loading = true;
  bool _working = false;
  String? _error;
  CalibrationValidationResult? _validation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isComplete(Map<String, dynamic> record) {
    final module = record['_support_module']?.toString();
    if (module == 'diagnostico') {
      return const [
        'reporte',
        'evaluacion',
        'comentario_general',
        'hora_fin'
      ].every((column) => record[column]?.toString().trim().isNotEmpty == true);
    }
    if (module == 'relevamiento_de_datos') {
      return record['estado_servicio']?.toString() == 'Balanza Realizada';
    }
    return record['estado_servicio']?.toString() == 'Completo';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _validation = null;
    });
    try {
      final completed = widget.servicio.items
          .where(_isComplete)
          .map(Map<String, dynamic>.from)
          .toList(growable: false);
      final uploaded = await _status.uploadedKeys(widget.servicio.codigo);
      final pending = completed
          .where((record) => !uploaded.contains(_status.recordKey(record)))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _uploadedCount = completed.length - pending.length;
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
    if (_pending.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    SupportUploadApiService? api;
    try {
      api = _api();
      final result =
          await _withAuthentication(api, () => api!.validate(_pending));
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
        content: Text(validOnly
            ? 'Se subirán ${validation.validCount} registros. Los ${validation.invalidCount} registros observados permanecerán pendientes.'
            : 'Se subirán ${validation.validCount} registros y sus resúmenes en una sola transacción.'),
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
    try {
      api = _api();
      final result = await _withAuthentication(
        api,
        () => api!.upload(_pending, validOnly: validOnly),
      );
      if (result == null) return;
      final prefs = await SharedPreferences.getInstance();
      final uploadedBy = prefs.getString('logged_user') ?? '';
      for (final uploaded in result.uploaded) {
        if (uploaded.index < 0 || uploaded.index >= _pending.length) continue;
        await _status.markUploaded(
          record: _pending[uploaded.index],
          codigoRegistro: uploaded.codigoRegistro,
          serverN: uploaded.serverN,
          uploadedBy: uploadedBy,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.green),
      );
      await showNewScalesUploadNotice(context, result.newScaleCount);
      if (!mounted) return;
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
      appBar: ServiceAppBar(
        title: 'Subir soporte',
        actions: [
          IconButton(
            onPressed: _working ? null : _load,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
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
                      Text(
                          '${_pending.length} pendientes · $_uploadedCount subidos'),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _message(Icons.error_outline_rounded, Colors.red, _error!),
                ],
                const SizedBox(height: 20),
                if (_pending.isEmpty)
                  _message(
                    Icons.cloud_done_outlined,
                    Colors.green,
                    _uploadedCount > 0
                        ? 'Todos los servicios completos de esta OTST ya fueron subidos.'
                        : 'No hay registros completos disponibles para subir.',
                  )
                else if (_validation == null)
                  _message(
                    Icons.fact_check_outlined,
                    colors.primary,
                    'Se validarán tipos, longitudes, formatos y duplicados antes de escribir en el servidor.',
                  )
                else
                  ..._validation!.records.map(_recordCard),
              ],
            ),
      bottomNavigationBar: _pending.isEmpty
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
    final source = record.index >= 0 && record.index < _pending.length
        ? _pending[record.index]
        : const <String, dynamic>{};
    final color = record.valid ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          record.valid ? Icons.check_circle_outline : Icons.cancel_outlined,
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
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('VALIDAR DATOS'),
      );
    }
    if (validation.invalidCount == 0) {
      return FilledButton.icon(
        onPressed: () => _upload(validOnly: false),
        icon: const Icon(Icons.cloud_upload_outlined),
        label: Text('SUBIR LOTE COMPLETO (${validation.validCount})'),
      );
    }
    if (validation.validCount > 0) {
      return FilledButton.icon(
        onPressed: () => _upload(validOnly: true),
        icon: const Icon(Icons.cloud_upload_outlined),
        label: Text('SUBIR SOLO VÁLIDOS (${validation.validCount})'),
      );
    }
    return OutlinedButton.icon(
      onPressed: _validate,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('VALIDAR NUEVAMENTE'),
    );
  }
}
