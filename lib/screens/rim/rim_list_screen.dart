import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../login/services/connection_profile_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../utils/top_alert.dart';
import '../../widgets/service_ui/input_decoration.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../oportunidades/widgets/opportunity_password_prompt.dart';
import 'models/rim_documento.dart';
import 'rim_flow.dart';
import 'services/rim_repository.dart';
import 'services/rim_store.dart';
import '../../theme/app_icons.dart';

/// RIM emitidos en este teléfono: los pendientes de subir al servidor (se
/// suben a mano, nunca solos; los anulados también, para que su número
/// quede justificado), los ya subidos y los anulados ya registrados.
class RimListScreen extends StatefulWidget {
  /// Solo para pruebas.
  final RimRepository Function()? repositoryBuilder;

  const RimListScreen({super.key, this.repositoryBuilder});

  @override
  State<RimListScreen> createState() => _RimListScreenState();
}

class _RimListScreenState extends State<RimListScreen> {
  late final RimRepository _repository;
  List<RimRegistro> _items = const [];
  bool _loading = true;
  String? _loadError;
  final Set<String> _sending = {};
  bool _sendingAll = false;

  @override
  void initState() {
    super.initState();
    final builder = widget.repositoryBuilder;
    if (builder != null) {
      _repository = builder();
    } else {
      final profiles = context.read<ConnectionProfileService>();
      _repository = RimRepository(
        apiUrl: () => profiles.perfilSeleccionado?.apiUrl,
        loggedUser: loggedServiceMetUser,
      );
    }
    _load();
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _repository.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudieron leer los RIM: $error';
      });
    }
  }

  bool get _busy => _sendingAll || _sending.isNotEmpty;

  Future<RimUploadResult?> _subirUno(RimRegistro registro) async {
    setState(() => _sending.add(registro.uuid));
    try {
      return await _repository.subir(
        registro,
        onAuthRequired: (error) => askRimPassword(context, error),
      );
    } catch (error) {
      if (mounted) TopAlert.show(context, '$error', isError: true);
      return null;
    } finally {
      if (mounted) setState(() => _sending.remove(registro.uuid));
    }
  }

  Future<void> _subir(RimRegistro registro) async {
    final result = await _subirUno(registro);
    if (!mounted || result == null) return;
    TopAlert.show(
      context,
      result.sent
          ? '✓ ${registro.documento.codigo} registrado en el servidor '
              '(N.º ${result.registro.serverN}).'
          : result.error?.message ?? 'No se pudo subir.',
      isError: !result.sent,
    );
    await _load();
  }

  Future<void> _subirTodos() async {
    final pendientes = _items.where((item) => item.canUpload).toList();
    if (pendientes.isEmpty) return;
    setState(() => _sendingAll = true);
    var subidos = 0;
    String? motivo;
    try {
      for (final registro in pendientes) {
        if (!mounted) return;
        final result = await _subirUno(registro);
        if (result == null) break;
        if (result.sent) {
          subidos++;
        } else if (result.error?.retryable ?? false) {
          // Sin conexión no tiene sentido seguir intentando los demás.
          motivo = result.error!.message;
          break;
        }
      }
    } finally {
      if (mounted) setState(() => _sendingAll = false);
    }
    if (!mounted) return;
    final faltan = pendientes.length - subidos;
    TopAlert.show(
      context,
      [
        '$subidos de ${pendientes.length} RIM subido(s) al servidor.',
        if (motivo != null) motivo,
        if (faltan > 0 && motivo == null) 'Revise los que quedaron con error.',
      ].join(' '),
      isError: faltan > 0,
    );
    await _load();
  }

  Future<void> _anular(RimRegistro registro) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => _AnularDialog(codigo: registro.documento.codigo),
    );
    if (motivo == null || !mounted) return;
    try {
      final anulado = await _repository.anular(registro, motivo);
      if (!mounted) return;
      TopAlert.show(
        context,
        anulado
            ? '${registro.documento.codigo} quedó anulado.'
            : 'El RIM ya estaba subido o anulado.',
        isError: !anulado,
      );
    } catch (error) {
      if (mounted) TopAlert.show(context, '$error', isError: true);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final porSubir = _items.where((item) => item.canUpload).toList();
    final subidos =
        _items.where((item) => item.isSent && !item.anulado).toList();
    final anulados =
        _items.where((item) => item.isSent && item.anulado).toList();

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: ServiceAppBar(
          title: 'RIM',
          actions: [
            if (porSubir.isNotEmpty)
              TextButton.icon(
                onPressed: _busy ? null : _subirTodos,
                icon: _sendingAll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.subir),
                label: const Text('Subir todos'),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppDesign.pagePadding, 8, AppDesign.pagePadding, 40),
                  children: [
                    Text(
                      'Recepciones de instrumentos de pesaje emitidas desde '
                      'los servicios o desde esta pestaña. Se suben al '
                      'servidor solo cuando usted lo indica.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_loadError != null) ...[
                      const SizedBox(height: 16),
                      Text(_loadError!,
                          style:
                              const TextStyle(color: AppColors.actionNegative)),
                    ],
                    const SizedBox(height: 18),
                    if (_items.isEmpty && _loadError == null)
                      const _EmptyState()
                    else ...[
                      if (porSubir.isNotEmpty) ...[
                        _SectionTitle('Por subir (${porSubir.length})'),
                        for (final item in porSubir)
                          _RimCard(
                            registro: item,
                            sending: _sending.contains(item.uuid),
                            enabled: !_busy,
                            onPdf: () => exportarRimPdf(context, item),
                            onSubir: () => _subir(item),
                            onAnular: () => _anular(item),
                          ),
                      ],
                      if (subidos.isNotEmpty) ...[
                        const _SectionTitle('Subidos'),
                        for (final item in subidos)
                          _RimCard(
                            registro: item,
                            enabled: !_busy,
                            onPdf: () => exportarRimPdf(context, item),
                          ),
                      ],
                      if (anulados.isNotEmpty) ...[
                        const _SectionTitle('Anulados'),
                        for (final item in anulados)
                          _RimCard(
                            registro: item,
                            enabled: !_busy,
                            onPdf: () => exportarRimPdf(context, item),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(text, style: AppDesign.titleStyle(context)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        children: [
          const Icon(AppIcons.rim, size: 36, color: AppColors.shimmerGold),
          const SizedBox(height: 12),
          Text('Sin RIM emitidos', style: AppDesign.titleStyle(context)),
          const SizedBox(height: 6),
          Text(
            'Use "Nuevo RIM" en Servicios o, durante una calibración o un '
            'servicio de soporte con la balanza ya elegida, toque ⋮ › '
            '"${RimMenuAction.title}".',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RimCard extends StatelessWidget {
  final RimRegistro registro;
  final bool sending;
  final bool enabled;
  final VoidCallback onPdf;
  final VoidCallback? onSubir;
  final VoidCallback? onAnular;

  const _RimCard({
    required this.registro,
    required this.enabled,
    required this.onPdf,
    this.sending = false,
    this.onSubir,
    this.onAnular,
  });

  (String, Color, IconData) get _status {
    if (registro.anulado) {
      return (
        registro.isSent
            ? 'Anulado · N.º ${registro.serverN}'
            : 'Anulado · por subir',
        AppColors.actionNegative,
        AppIcons.bloquear,
      );
    }
    return switch (registro.estado) {
      RimEstadoSubida.sent => (
          'Subido · N.º ${registro.serverN}',
          AppColors.success,
          AppIcons.completo,
        ),
      RimEstadoSubida.error => (
          'Con error',
          AppColors.actionNegative,
          AppIcons.error,
        ),
      RimEstadoSubida.sending => (
          'Subida sin confirmar',
          AppColors.warning,
          AppIcons.ayuda,
        ),
      RimEstadoSubida.pending => (
          'Por subir',
          AppColors.warning,
          AppIcons.hora,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final rim = registro.documento;
    final service = rim.service;
    final (label, color, icon) = _status;
    final format = DateFormat('dd/MM/yyyy HH:mm');
    final small = Theme.of(context).textTheme.bodySmall;
    final origen = [
      service.serviceName,
      if (service.seca != null) '${service.secaLabel} ${service.seca}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: AppStatusPill(icon: icon, label: label, color: color),
                ),
                const Spacer(),
                Text(format.format(rim.emitidoEn), style: small),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              [rim.codigo, service.metricCode].whereType<String>().join(' · '),
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text([service.clientDisplay, service.plantName]
                .whereType<String>()
                .join(' · ')),
            const SizedBox(height: 2),
            Text(origen, style: small),
            Text('Firmó: ${rim.contactoNombre}', style: small),
            if (registro.isSent && registro.sentAt != null)
              Text('Subido ${format.format(registro.sentAt!)}', style: small),
            if (registro.anulado)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                        'Anulado',
                        if (registro.anuladoEn != null)
                          'el ${format.format(registro.anuladoEn!)}',
                        if (registro.anuladoPor != null)
                          'por ${registro.anuladoPor}',
                      ].join(' ') +
                      (registro.motivoAnulacion == null
                          ? ''
                          : ': ${registro.motivoAnulacion}'),
                  style: small?.copyWith(color: AppColors.actionNegative),
                ),
              )
            else if (!registro.isSent && registro.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  registro.lastError!,
                  style: small?.copyWith(color: AppColors.actionNegative),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: enabled ? onPdf : null,
                  icon: const Icon(AppIcons.documento),
                  label: const Text('PDF'),
                ),
                if (registro.canAnular && onAnular != null)
                  TextButton(
                    onPressed: enabled ? onAnular : null,
                    child: const Text('Anular'),
                  ),
                if (registro.canUpload && onSubir != null)
                  FilledButton.icon(
                    onPressed: enabled ? onSubir : null,
                    icon: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.subir),
                    label: const Text('Subir'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide el motivo de la anulación (obligatorio). Devuelve null si se cancela.
class _AnularDialog extends StatefulWidget {
  final String codigo;

  const _AnularDialog({required this.codigo});

  @override
  State<_AnularDialog> createState() => _AnularDialogState();
}

class _AnularDialogState extends State<_AnularDialog> {
  final _motivo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  void _confirmar() {
    final motivo = _motivo.text.trim();
    if (motivo.length < 5) {
      setState(() => _error = 'Escriba el motivo de la anulación.');
      return;
    }
    Navigator.pop(context, motivo);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Text('¿Anular ${widget.codigo}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El RIM no se borra: queda en este teléfono marcado como anulado, '
            'con su motivo, y se sube así al servidor para que su número '
            'quede justificado. Si corresponde, emita un RIM nuevo.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _motivo,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: serviceInputDeco('Motivo de la anulación', isDark)
                .copyWith(errorText: _error, alignLabelWithHint: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: AppDesign.negativeButtonStyle(),
          onPressed: _confirmar,
          child: const Text('Anular RIM'),
        ),
      ],
    );
  }
}

/// Número de RIM sin subir, para el acceso en Servicios.
Future<int> countUnsentRims() async {
  try {
    return await RimStore().countUnsent();
  } catch (_) {
    return 0;
  }
}
