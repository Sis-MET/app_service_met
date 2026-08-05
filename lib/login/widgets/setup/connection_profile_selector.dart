// Selector de perfiles de conexión con editor integrado.
// Muestra los perfiles disponibles como tarjetas seleccionables
// y permite editar/agregar perfiles personalizados.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/theme/app_colors.dart';
import '../../models/connection_profile.dart';
import '../../services/connection_profile_service.dart';

class ConnectionProfileSelector extends StatefulWidget {
  final bool isDark;

  const ConnectionProfileSelector({
    super.key,
    required this.isDark,
  });

  @override
  State<ConnectionProfileSelector> createState() =>
      _ConnectionProfileSelectorState();
}

class _ConnectionProfileSelectorState extends State<ConnectionProfileSelector> {
  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ConnectionProfileService>();
    final perfiles = profileService.perfiles;
    final seleccionadoId = profileService.perfilSeleccionadoId;

    if (perfiles.isEmpty) {
      return Center(
        child: Text(
          'No hay perfiles disponibles',
          style: GoogleFonts.inter(
            color: widget.isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lista de perfiles
        ...perfiles.map((perfil) => _ProfileCard(
              perfil: perfil,
              isDark: widget.isDark,
              isSelected: perfil.id == seleccionadoId,
              onTap: () {
                profileService.seleccionarPerfil(perfil.id);
              },
              onEdit: () => _showEditDialog(context, profileService, perfil),
              onDelete: () => _confirmDelete(context, profileService, perfil),
            )),

        const SizedBox(height: 12),

        // Botón agregar nuevo perfil
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.isDark ? Colors.white60 : Colors.black54,
              side: BorderSide(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                style: BorderStyle.solid,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _showNewProfileDialog(context, profileService),
            icon: const Icon(Icons.add, size: 20),
            label: Text(
              'Agregar nueva conexión',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Diálogo para nuevo perfil ──
  Future<void> _showNewProfileDialog(
    BuildContext context,
    ConnectionProfileService service,
  ) async {
    final result = await _showProfileEditorDialog(
      context: context,
      isDark: widget.isDark,
      titulo: 'Nueva Conexión',
      perfil: null,
    );

    if (result != null) {
      final nuevoPerfil = ConnectionProfile(
        id: service.generarId(),
        nombre: result['nombre']!,
        ip: result['ip']!,
        puerto: result['puerto']!,
        baseDatos: result['baseDatos']!,
        usuarioBD: result['usuarioBD']!,
        contrasenaBD: result['contrasenaBD']!,
        apiUrl: result['apiUrl']!,
        esPredeterminado: false,
      );
      await service.guardarPerfil(nuevoPerfil);
      await service.seleccionarPerfil(nuevoPerfil.id);
    }
  }

  // ── Diálogo para editar perfil ──
  Future<void> _showEditDialog(
    BuildContext context,
    ConnectionProfileService service,
    ConnectionProfile perfil,
  ) async {
    final result = await _showProfileEditorDialog(
      context: context,
      isDark: widget.isDark,
      titulo: 'Editar ${perfil.nombre}',
      perfil: perfil,
    );

    if (result != null) {
      final editado = perfil.copyWith(
        nombre: result['nombre'],
        ip: result['ip'],
        puerto: result['puerto'],
        baseDatos: result['baseDatos'],
        usuarioBD: result['usuarioBD'],
        contrasenaBD: result['contrasenaBD'],
        apiUrl: result['apiUrl'],
      );
      await service.guardarPerfil(editado);
    }
  }

  // ── Confirmar eliminación ──
  Future<void> _confirmDelete(
    BuildContext context,
    ConnectionProfileService service,
    ConnectionProfile perfil,
  ) async {
    if (perfil.esPredeterminado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se puede eliminar un perfil predeterminado'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Eliminar perfil'),
        content: Text(
          '¿Eliminar "${perfil.nombre}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await service.eliminarPerfil(perfil.id);
    }
  }
}

// ── Editor de perfil (reutilizable para nuevo y edición) ──
Future<Map<String, String>?> _showProfileEditorDialog({
  required BuildContext context,
  required bool isDark,
  required String titulo,
  required ConnectionProfile? perfil,
}) async {
  final nombreCtrl = TextEditingController(text: perfil?.nombre ?? '');
  final ipCtrl = TextEditingController(text: perfil?.ip ?? '');
  final portCtrl = TextEditingController(text: perfil?.puerto ?? '1433');
  final dbCtrl = TextEditingController(text: perfil?.baseDatos ?? '');
  final userCtrl = TextEditingController(text: perfil?.usuarioBD ?? '');
  final passCtrl = TextEditingController(text: perfil?.contrasenaBD ?? '');
  final apiUrlCtrl = TextEditingController(text: perfil?.apiUrl ?? '');
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.dns_outlined,
                        color: AppColors.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        titulo,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _buildField(
                  label: 'Nombre del perfil',
                  controller: nombreCtrl,
                  icon: Icons.label_outline,
                  isDark: isDark,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                _buildField(
                  label: 'IP del Servidor',
                  controller: ipCtrl,
                  icon: Icons.dns_outlined,
                  isDark: isDark,
                  isNumber: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                _buildField(
                  label: 'Puerto',
                  controller: portCtrl,
                  icon: Icons.cable_outlined,
                  isDark: isDark,
                  isNumber: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                _buildField(
                  label: 'Base de Datos',
                  controller: dbCtrl,
                  icon: Icons.storage_outlined,
                  isDark: isDark,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                _buildField(
                  label: 'Usuario BD',
                  controller: userCtrl,
                  icon: Icons.admin_panel_settings_outlined,
                  isDark: isDark,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),

                _buildField(
                  label: 'Contraseña BD',
                  controller: passCtrl,
                  icon: Icons.vpn_key_outlined,
                  isDark: isDark,
                  isPassword: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),

                const SizedBox(height: 16),

                _buildField(
                  label: 'URL API Node.js',
                  controller: apiUrlCtrl,
                  icon: Icons.api_outlined,
                  isDark: isDark,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final uri = Uri.tryParse(v.trim());
                    if (uri == null ||
                        !uri.hasAuthority ||
                        (uri.scheme != 'http' && uri.scheme != 'https')) {
                      return 'Ingrese una URL http(s) válida';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx, {
                        'nombre': nombreCtrl.text.trim(),
                        'ip': ipCtrl.text.trim(),
                        'puerto': portCtrl.text.trim(),
                        'baseDatos': dbCtrl.text.trim(),
                        'usuarioBD': userCtrl.text.trim(),
                        'contrasenaBD': passCtrl.text.trim(),
                        'apiUrl': (apiUrlCtrl.text.trim().isEmpty
                                ? 'http://${ipCtrl.text.trim()}:3000'
                                : apiUrlCtrl.text.trim())
                            .replaceAll(RegExp(r'/+$'), ''),
                      });
                    },
                    child: Text(
                      'Guardar',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  nombreCtrl.dispose();
  ipCtrl.dispose();
  portCtrl.dispose();
  dbCtrl.dispose();
  userCtrl.dispose();
  passCtrl.dispose();
  apiUrlCtrl.dispose();

  return result;
}

// ── Campo de formulario reutilizable ──
Widget _buildField({
  required String label,
  required TextEditingController controller,
  required IconData icon,
  required bool isDark,
  bool isNumber = false,
  bool isPassword = false,
  String? Function(String?)? validator,
}) {
  bool obscure = isPassword;

  return StatefulBuilder(
    builder: (context, setLocalState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: isPassword && obscure,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Ingresa $label',
              hintStyle: GoogleFonts.inter(
                color: isDark ? Colors.white30 : Colors.black26,
                fontSize: 13,
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color:
                      isDark ? Colors.white24 : Colors.black.withOpacity(0.15),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: Icon(icon,
                  color: isDark ? Colors.white70 : Colors.black38, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark ? Colors.white70 : Colors.black38,
                        size: 20,
                      ),
                      onPressed: () {
                        setLocalState(() => obscure = !obscure);
                      },
                    )
                  : null,
            ),
            validator: validator,
          ),
        ],
      );
    },
  );
}

// ── Tarjeta de perfil individual ──
class _ProfileCard extends StatelessWidget {
  final ConnectionProfile perfil;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.perfil,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withOpacity(0.06)
                : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F7FA)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? activeColor.withOpacity(0.4)
                  : (isDark ? Colors.white12 : Colors.black12),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Radio indicator
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? activeColor : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: activeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Icono
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: perfil.esPredeterminado
                      ? Colors.blue.withOpacity(0.12)
                      : activeColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  perfil.esPredeterminado
                      ? Icons.cloud_outlined
                      : Icons.dns_outlined,
                  size: 18,
                  color: perfil.esPredeterminado ? Colors.blue : activeColor,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perfil.nombre,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${perfil.ip}:${perfil.puerto}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),

              // Acciones
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  if (!perfil.esPredeterminado)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
