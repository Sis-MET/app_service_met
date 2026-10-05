import 'package:flutter/material.dart';

import '../../../utils/top_alert.dart';
import '../../registro_directo/seleccion_rapida_screen.dart';
import '../../registro_directo/widgets/formulario_entry_card.dart';
import '../opportunity_form_screen.dart';
import '../pending_opportunities_screen.dart';
import '../../../theme/app_icons.dart';

/// Acceso a "Oportunidades" desde Servicios: registrar una nueva sin estar
/// dentro de un servicio y abrir la lista, con el número de las que esperan
/// ser enviadas a Bitrix24.
class OpportunitiesEntryTile extends StatefulWidget {
  /// Técnico con sesión iniciada: figura como quien la registra.
  final String userName;

  const OpportunitiesEntryTile({super.key, required this.userName});

  @override
  State<OpportunitiesEntryTile> createState() => _OpportunitiesEntryTileState();
}

class _OpportunitiesEntryTileState extends State<OpportunitiesEntryTile> {
  int _unsent = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final count = await countUnsentOpportunities();
    if (mounted) setState(() => _unsent = count);
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PendingOpportunitiesScreen()),
    );
    await _refresh();
  }

  /// Fuera de un servicio: el técnico elige el cliente (y, si corresponde,
  /// la planta y el instrumento) y pasa al formulario de siempre.
  Future<void> _nueva() async {
    final service = await SeleccionRapidaScreen.open(
      context,
      proposito: PropositoSeleccion.oportunidad,
      userName: widget.userName,
    );
    if (service == null || !mounted) return;
    final outcome =
        await OpportunityFormScreen.open(context, serviceContext: service);
    if (outcome != null && mounted) TopAlert.show(context, outcome.message);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FormularioEntryCard(
      icon: AppIcons.oportunidad,
      title: 'Oportunidades comerciales',
      subtitle: _unsent == 0
          ? 'Necesidades del cliente que van a Prospectos de Bitrix24.'
          : '$_unsent pendiente(s) de enviar a Bitrix24.',
      pending: _unsent,
      onOpenList: _open,
      newLabel: 'Nueva oportunidad',
      onNew: _nueva,
    );
  }
}
