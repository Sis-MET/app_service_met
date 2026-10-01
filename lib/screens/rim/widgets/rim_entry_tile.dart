import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../rim_list_screen.dart';

/// Acceso a los RIM desde Servicios, con el número de los que esperan ser
/// subidos al servidor.
class RimEntryTile extends StatefulWidget {
  const RimEntryTile({super.key});

  @override
  State<RimEntryTile> createState() => _RimEntryTileState();
}

class _RimEntryTileState extends State<RimEntryTile> {
  int _unsent = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final count = await countUnsentRims();
    if (mounted) setState(() => _unsent = count);
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RimListScreen()),
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
          Icons.inventory_2_outlined,
          color: AppColors.shimmerGold,
        ),
        title: const Text('Recepción de instrumentos (RIM)'),
        subtitle: Text(
          _unsent == 0
              ? 'Emitidos en los servicios, con la firma del cliente.'
              : '$_unsent pendiente(s) de subir al servidor.',
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
