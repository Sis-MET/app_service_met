import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_design.dart';
import '../../models/connection_profile.dart';
import '../../services/connection_profile_service.dart';

class ConnectionProfileSelector extends StatelessWidget {
  final bool isDark;

  const ConnectionProfileSelector({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ConnectionProfileService>();
    return Column(
      children: [
        for (final profile in service.perfiles)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProfileTile(
              profile: profile,
              selected: profile.id == service.perfilSeleccionadoId,
              onTap: () => service.seleccionarPerfil(profile.id),
              onEdit: () => _edit(context, service, profile),
              onDelete: profile.esPredeterminado
                  ? null
                  : () => _delete(context, service, profile),
            ),
          ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _edit(context, service, null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar servidor'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    ConnectionProfileService service,
    ConnectionProfile? current,
  ) async {
    final name = TextEditingController(text: current?.nombre ?? '');
    final apiUrl = TextEditingController(text: current?.apiUrl ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current == null ? 'Nuevo servidor' : 'Editar servidor'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa un nombre'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: apiUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL segura de la API',
                  hintText: 'https://192.168.1.5:3100',
                  prefixIcon: Icon(Icons.api_rounded),
                ),
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  if (uri == null ||
                      uri.scheme != 'https' ||
                      !uri.hasAuthority ||
                      uri.port != 3100) {
                    return 'Usa una URL HTTPS con puerto 3100';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final uri = Uri.parse(apiUrl.text.trim());
    final profile = ConnectionProfile(
      id: current?.id ?? service.generarId(),
      nombre: name.text.trim(),
      ip: uri.host,
      puerto: uri.port.toString(),
      baseDatos: '',
      usuarioBD: '',
      contrasenaBD: '',
      apiUrl: apiUrl.text.trim().replaceAll(RegExp(r'/+$'), ''),
      esPredeterminado: current?.esPredeterminado ?? false,
      fechaCreacion: current?.fechaCreacion,
    );
    await service.guardarPerfil(profile);
    await service.seleccionarPerfil(profile.id);
  }

  Future<void> _delete(
    BuildContext context,
    ConnectionProfileService service,
    ConnectionProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar servidor'),
        content: Text('¿Eliminar “${profile.nombre}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: AppDesign.negativeButtonStyle(),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await service.eliminarPerfil(profile.id);
  }
}

class _ProfileTile extends StatelessWidget {
  final ConnectionProfile profile;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _ProfileTile({
    required this.profile,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        selected ? (dark ? Colors.black : Colors.white) : colors.onSurface;
    return Material(
      color: selected
          ? (dark ? const Color(0xFFF1F1ED) : const Color(0xFF1C1C1C))
          : dark
              ? Colors.white.withOpacity(0.05)
              : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 6, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : dark
                      ? Colors.white24
                      : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? foreground.withOpacity(0.12)
                      : colors.surfaceContainerHighest.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.dns_outlined,
                  color: selected ? foreground : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.nombre,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.apiUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: selected
                            ? foreground.withOpacity(0.62)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                iconColor: foreground,
                onSelected: (value) =>
                    value == 'edit' ? onEdit() : onDelete?.call(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  if (onDelete != null)
                    const PopupMenuItem(
                        value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
