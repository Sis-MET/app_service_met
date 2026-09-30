import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../pending_opportunities_screen.dart';

/// Acceso a "Oportunidades" desde Otros apartados, con el número de
/// oportunidades que esperan ser enviadas a Bitrix24.
class OpportunitiesEntryTile extends StatefulWidget {
  const OpportunitiesEntryTile({super.key});

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

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: const Icon(
          Icons.handshake_outlined,
          color: AppColors.shimmerGold,
        ),
        title: const Text('Oportunidades comerciales'),
        subtitle: Text(
          _unsent == 0
              ? 'Registradas en los servicios y enviadas a Bitrix24.'
              : '$_unsent pendiente(s) de enviar a Bitrix24.',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_unsent > 0)
              Badge(
                label: Text('$_unsent'),
                backgroundColor: AppColors.warning,
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: _open,
      ),
    );
  }
}
