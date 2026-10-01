import 'package:flutter/material.dart';

import '../../registro_directo/widgets/formulario_entry_card.dart';
import '../rim_flow.dart';
import '../rim_list_screen.dart';

/// Acceso a los RIM desde Servicios: emitir uno nuevo sin estar dentro de un
/// servicio y abrir la lista, con el número de los que esperan ser subidos.
class RimEntryTile extends StatefulWidget {
  /// Técnico con sesión iniciada: recibe los instrumentos que se emiten
  /// desde aquí.
  final String userName;

  const RimEntryTile({super.key, required this.userName});

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

  Future<void> _nuevo() async {
    await RimFlow.nuevoDirecto(context, userName: widget.userName);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FormularioEntryCard(
      icon: RimMenuAction.menuIcon,
      title: 'Recepción de instrumentos (RIM)',
      subtitle: _unsent == 0
          ? 'Constancia del estado de una balanza, con la firma del cliente.'
          : '$_unsent pendiente(s) de subir al servidor.',
      pending: _unsent,
      onOpenList: _open,
      newLabel: 'Nuevo RIM',
      onNew: _nuevo,
    );
  }
}
