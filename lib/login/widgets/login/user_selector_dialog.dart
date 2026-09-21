import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class UserSelectorSheet extends StatefulWidget {
  final List<UserModel> users;
  final String? selectedUsername;
  final VoidCallback onAdd;
  final Future<UserModel?> Function(UserModel user) onDelete;

  const UserSelectorSheet({
    super.key,
    required this.users,
    required this.selectedUsername,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<UserSelectorSheet> createState() => _UserSelectorSheetState();
}

class _UserSelectorSheetState extends State<UserSelectorSheet> {
  late final List<UserModel> _users = List.of(widget.users);
  late String? _selectedUsername = widget.selectedUsername;
  String? _deletingUsername;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: screenHeight * 0.88,
        ),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF171715) : const Color(0xFFF8F7F2),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDesign.radiusLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withOpacity(0.18),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usuarios del dispositivo',
                          style: GoogleFonts.poppins(
                            fontSize: 23,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _users.isEmpty
                              ? 'Aún no hay accesos vinculados.'
                              : '${_users.length} acceso${_users.length == 1 ? '' : 's'} disponible${_users.length == 1 ? '' : 's'} en este equipo.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.35,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _users.isEmpty
                  ? const _EmptyUsers()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      shrinkWrap: true,
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return _SavedUserCard(
                          user: user,
                          selected: user.usuario == _selectedUsername,
                          deleting: user.usuario == _deletingUsername,
                          onSelect: user.isSelectable
                              ? () => Navigator.pop(context, user)
                              : null,
                          onDelete: () => _confirmDelete(user),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 4, 20, 20 + MediaQuery.paddingOf(context).bottom),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: widget.onAdd,
                  style: AppDesign.positiveButtonStyle(),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  label: Text(
                    'Vincular otro usuario',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.person_remove_outlined),
        title: const Text('Quitar acceso del dispositivo'),
        content: Text(
          'Se eliminará el acceso offline de ${user.fullName}. '
          'Podrás volver a vincularlo con conexión al servidor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: AppDesign.negativeButtonStyle(),
            child: const Text('Quitar acceso'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingUsername = user.usuario);
    final fallback = await widget.onDelete(user);
    if (!mounted) return;
    setState(() {
      _users.removeWhere((item) => item.usuario == user.usuario);
      _selectedUsername = fallback?.usuario ??
          (_selectedUsername == user.usuario ? null : _selectedUsername);
      _deletingUsername = null;
    });
  }
}

class _SavedUserCard extends StatelessWidget {
  final UserModel user;
  final bool selected;
  final bool deleting;
  final VoidCallback? onSelect;
  final VoidCallback onDelete;

  const _SavedUserCard({
    required this.user,
    required this.selected,
    required this.deleting,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = _statusFor(user);

    return Material(
      color: dark ? Colors.white.withOpacity(0.055) : Colors.white,
      borderRadius: AppDesign.mediumRadius,
      child: InkWell(
        onTap: deleting ? null : onSelect,
        borderRadius: AppDesign.mediumRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: AppDesign.mediumRadius,
            border: Border.all(
              color: selected
                  ? (dark ? Colors.white70 : AppDesign.ink)
                  : colors.outlineVariant.withOpacity(0.72),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accentYellow.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _UserAvatar(name: user.fullName),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (selected)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.check_circle_rounded, size: 19),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@${user.usuario}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            status.label,
                            style: GoogleFonts.inter(
                              color: status.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (selected) ...[
                          Text(
                            'EN USO',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              deleting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Quitar del dispositivo',
                      onPressed: onDelete,
                      icon: const Icon(Icons.person_remove_outlined),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  ({String label, Color color}) _statusFor(UserModel user) {
    if (!user.isActive) {
      return (label: 'INACTIVO', color: AppColors.warning);
    }
    if (!user.hasAppAccess) {
      return (label: 'SIN PERMISO', color: AppColors.error);
    }
    final verifiedAt = user.lastVerifiedAt;
    if (verifiedAt != null &&
        DateTime.now().difference(verifiedAt) >
            AuthService.offlineAccessValidity) {
      return (label: 'RENOVAR ACCESO', color: AppColors.warning);
    }
    return (label: 'OFFLINE LISTO', color: AppColors.success);
  }
}

class _UserAvatar extends StatelessWidget {
  final String name;

  const _UserAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? Colors.white : AppDesign.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: GoogleFonts.inter(
          color: dark ? AppDesign.ink : Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.people_outline_rounded, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Este dispositivo aún no tiene usuarios',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Vincula una cuenta corporativa para habilitar el acceso offline.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
