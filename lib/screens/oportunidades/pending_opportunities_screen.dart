import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../login/services/connection_profile_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../utils/top_alert.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import 'models/opportunity_draft.dart';
import 'opportunity_form_screen.dart';
import 'services/opportunity_repository.dart';
import 'services/pending_opportunity_store.dart';
import 'widgets/opportunity_password_prompt.dart';

/// Oportunidades guardadas en el teléfono: las pendientes de enviar a
/// Bitrix24 (se reenvían a mano, nunca solas) y las últimas enviadas.
class PendingOpportunitiesScreen extends StatefulWidget {
  /// Solo para pruebas.
  final OpportunityRepository Function()? repositoryBuilder;

  const PendingOpportunitiesScreen({super.key, this.repositoryBuilder});

  @override
  State<PendingOpportunitiesScreen> createState() =>
      _PendingOpportunitiesScreenState();
}

class _PendingOpportunitiesScreenState
    extends State<PendingOpportunitiesScreen> {
  late final OpportunityRepository _repository;
  List<PendingOpportunity> _items = const [];
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
      _repository = OpportunityRepository(
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
        _loadError = 'No se pudieron leer las oportunidades: $error';
      });
    }
  }

  bool get _busy => _sendingAll || _sending.isNotEmpty;

  Future<OpportunitySubmitResult?> _sendOne(PendingOpportunity record) async {
    setState(() => _sending.add(record.uuid));
    try {
      return await _repository.resend(
        record,
        onAuthRequired: (error) => askOpportunityPassword(context, error),
      );
    } catch (error) {
      if (mounted) TopAlert.show(context, '$error', isError: true);
      return null;
    } finally {
      if (mounted) setState(() => _sending.remove(record.uuid));
    }
  }

  Future<void> _send(PendingOpportunity record) async {
    if (!record.canSendDirectly) return _complete(record);
    final result = await _sendOne(record);
    if (!mounted || result == null) return;
    TopAlert.show(
      context,
      switch (result.outcome) {
        OpportunitySubmitOutcome.sent =>
          '✓ Registrada en Prospectos de Bitrix24 (#${result.leadId}).',
        _ => result.error?.message ?? 'No se pudo enviar.',
      },
      isError: result.outcome != OpportunitySubmitOutcome.sent,
    );
    await _load();
  }

  Future<void> _sendAll() async {
    final sendable = _items.where((item) => item.canSendDirectly).toList();
    if (sendable.isEmpty) return;
    setState(() => _sendingAll = true);
    var sent = 0;
    String? stopReason;
    try {
      for (final record in sendable) {
        if (!mounted) return;
        final result = await _sendOne(record);
        if (result == null) break;
        if (result.outcome == OpportunitySubmitOutcome.sent) {
          sent++;
        } else if (result.error?.retryable ?? false) {
          // Sin conexión no tiene sentido seguir intentando las demás.
          stopReason = result.error!.message;
          break;
        }
      }
    } finally {
      if (mounted) setState(() => _sendingAll = false);
    }
    if (!mounted) return;
    final pending = sendable.length - sent;
    TopAlert.show(
      context,
      [
        '$sent de ${sendable.length} enviada(s) a Bitrix24.',
        if (stopReason != null) stopReason,
        if (pending > 0 && stopReason == null)
          'Revise las que quedaron con error.',
      ].join(' '),
      isError: pending > 0,
    );
    await _load();
  }

  Future<void> _complete(PendingOpportunity record) async {
    final outcome = await OpportunityFormScreen.open(
      context,
      serviceContext: record.draft.service,
      existing: record,
      repositoryBuilder: widget.repositoryBuilder,
    );
    if (!mounted) return;
    if (outcome != null) TopAlert.show(context, outcome.message);
    await _load();
  }

  Future<void> _discard(PendingOpportunity record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Descartar esta oportunidad?'),
        content: Text(
          '"${record.draft.title}" no se enviará a Bitrix24 y se borrará '
          'de este teléfono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _repository.discard(record.uuid);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final unsent = _items.where((item) => !item.isSent).toList();
    final sent = _items.where((item) => item.isSent).toList();
    final canSendAll = unsent.any((item) => item.canSendDirectly);

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: ServiceAppBar(
          title: 'Oportunidades',
          actions: [
            if (canSendAll)
              TextButton.icon(
                onPressed: _busy ? null : _sendAll,
                icon: _sendingAll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: const Text('Enviar todas'),
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
                      'Oportunidades comerciales registradas durante los '
                      'servicios. Las pendientes se envían a Bitrix24 solo '
                      'cuando usted lo indica.',
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
                      if (unsent.isNotEmpty) ...[
                        _SectionTitle('Por enviar (${unsent.length})'),
                        for (final item in unsent)
                          _OpportunityCard(
                            record: item,
                            sending: _sending.contains(item.uuid),
                            enabled: !_busy,
                            onSend: () => _send(item),
                            onDiscard: () => _discard(item),
                          ),
                      ],
                      if (sent.isNotEmpty) ...[
                        const _SectionTitle('Enviadas'),
                        for (final item in sent)
                          _OpportunityCard(record: item, enabled: false),
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
          const Icon(Icons.business_center_outlined,
              size: 36, color: AppColors.shimmerGold),
          const SizedBox(height: 12),
          Text('Sin oportunidades', style: AppDesign.titleStyle(context)),
          const SizedBox(height: 6),
          Text(
            'Durante una calibración o un servicio de soporte, toque el '
            'maletín del encabezado para registrar una oportunidad.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final PendingOpportunity record;
  final bool sending;
  final bool enabled;
  final VoidCallback? onSend;
  final VoidCallback? onDiscard;

  const _OpportunityCard({
    required this.record,
    required this.enabled,
    this.sending = false,
    this.onSend,
    this.onDiscard,
  });

  (String, Color, IconData) get _status => switch (record.status) {
        OpportunityStatus.sent => (
            'Prospecto #${record.bitrixLeadId}',
            AppColors.success,
            Icons.check_circle_rounded,
          ),
        OpportunityStatus.error => (
            'Con error',
            AppColors.actionNegative,
            Icons.error_outline_rounded,
          ),
        OpportunityStatus.sending => (
            'Envío sin confirmar',
            AppColors.warning,
            Icons.help_outline_rounded,
          ),
        OpportunityStatus.pending => (
            'Pendiente',
            AppColors.warning,
            Icons.schedule_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final draft = record.draft;
    final service = draft.service;
    final (label, color, icon) = _status;
    final format = DateFormat('dd/MM/yyyy HH:mm');
    final serviceLine = [
      service.serviceName,
      if (service.seca != null) '${service.secaLabel} ${service.seca}',
      if (service.metricCode != null) service.metricCode!,
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
                AppStatusPill(icon: icon, label: label, color: color),
                const Spacer(),
                Text(format.format(draft.createdAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              draft.title,
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              draft.hasCompany
                  ? [draft.companyName, draft.contactName]
                      .whereType<String>()
                      .where((part) => part.isNotEmpty)
                      .join(' · ')
                  : 'Falta elegir la empresa de Bitrix24',
              style: TextStyle(
                color: draft.hasCompany ? null : AppColors.actionNegative,
              ),
            ),
            const SizedBox(height: 2),
            Text(serviceLine, style: Theme.of(context).textTheme.bodySmall),
            if (record.isSent && record.sentAt != null)
              Text('Enviada ${format.format(record.sentAt!)}',
                  style: Theme.of(context).textTheme.bodySmall),
            if (!record.isSent && record.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                record.lastError!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.actionNegative),
              ),
            ],
            if (!record.isSent) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: enabled ? onDiscard : null,
                    child: const Text('Descartar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: enabled ? onSend : null,
                    icon: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(record.canSendDirectly
                            ? Icons.send_rounded
                            : Icons.edit_outlined),
                    label: Text(record.canSendDirectly
                        ? 'Enviar'
                        : record.status == OpportunityStatus.error
                            ? 'Revisar y enviar'
                            : 'Completar y enviar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Número de oportunidades sin enviar, para el acceso en Otros apartados.
Future<int> countUnsentOpportunities() async {
  try {
    return await PendingOpportunityStore().countUnsent();
  } catch (_) {
    return 0;
  }
}
