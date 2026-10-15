// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/permisos_app.dart';
import '../theme/app_colors.dart';
import '../theme/app_design.dart';
import '../theme/app_icons.dart';

/// Aviso de la app antes de una solicitud de permiso del sistema.
///
/// Indica que el permiso responde a procedimientos de la empresa, sin
/// detallar para qué se usa. Devuelve true si el técnico elige continuar
/// (o, con [irAAjustes], abrir los ajustes).
Future<bool> confirmarPermiso(
  BuildContext context,
  PermisoApp permiso, {
  bool obligatorio = false,
  bool irAAjustes = false,
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    barrierDismissible: !obligatorio,
    builder: (_) => DialogoPermiso(
      permiso: permiso,
      obligatorio: obligatorio,
      irAAjustes: irAAjustes,
    ),
  );
  return respuesta == true;
}

/// Antes de abrir la cámara: si todavía no hay permiso, avisa primero. Si el
/// técnico no continúa, la cámara no se abre.
Future<bool> asegurarCamara(BuildContext context) async {
  if (await PermisoCamara.concedido()) return true;
  if (!context.mounted) return false;
  return confirmarPermiso(context, PermisoApp.camara);
}

class DialogoPermiso extends StatelessWidget {
  const DialogoPermiso({
    super.key,
    required this.permiso,
    this.obligatorio = false,
    this.irAAjustes = false,
  });

  final PermisoApp permiso;
  final bool obligatorio;
  final bool irAAjustes;

  static String titulo(PermisoApp permiso) => switch (permiso) {
        PermisoApp.ubicacion => 'Permiso de ubicación',
        PermisoApp.notificaciones => 'Permiso de notificaciones',
        PermisoApp.camara => 'Permiso de cámara',
      };

  static String requerimiento(PermisoApp permiso) => switch (permiso) {
        PermisoApp.ubicacion => 'Por procedimientos de la empresa, ServiceMET '
            'necesita acceder a la ubicación de este dispositivo.',
        PermisoApp.notificaciones => 'Por procedimientos de la empresa, '
            'ServiceMET necesita enviarle notificaciones en este dispositivo.',
        PermisoApp.camara => 'Por procedimientos de la empresa, ServiceMET '
            'necesita acceder a la cámara de este dispositivo.',
      };

  static IconData icono(PermisoApp permiso) => switch (permiso) {
        PermisoApp.ubicacion => AppIcons.ubicacion,
        PermisoApp.notificaciones => AppIcons.notificaciones,
        PermisoApp.camara => AppIcons.camara,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final oscuro = cs.brightness == Brightness.dark;
    final cuerpo = GoogleFonts.inter(
        fontSize: 14, height: 1.45, color: cs.onSurface.withOpacity(0.85));
    return PopScope(
      // Un permiso obligatorio se responde con un botón, no con "atrás".
      canPop: !obligatorio,
      child: AlertDialog(
        backgroundColor: oscuro ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppDesign.largeRadius),
        // Centrado: el diálogo estira el ícono a todo el ancho.
        icon: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentYellow.withOpacity(oscuro ? 0.16 : 0.28),
              borderRadius: AppDesign.mediumRadius,
            ),
            child: Icon(icono(permiso), size: 26, color: cs.onSurface),
          ),
        ),
        title: Text(
          titulo(permiso),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(requerimiento(permiso),
                textAlign: TextAlign.center, style: cuerpo),
            if (obligatorio) ...[
              const SizedBox(height: 10),
              Text(
                'Sin este permiso no se puede iniciar ni continuar un '
                'servicio.',
                textAlign: TextAlign.center,
                style: cuerpo.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              irAAjustes
                  ? 'El permiso fue rechazado. Actívelo en Ajustes › Permisos '
                      'y vuelva a la app.'
                  : 'Al continuar, el teléfono le pedirá confirmarlo: elija '
                      'permitir.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12.5, height: 1.4, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(obligatorio ? 'Volver' : 'Ahora no'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.actionPositive,
                    foregroundColor: AppColors.actionPositiveInk,
                    shape: RoundedRectangleBorder(
                        borderRadius: AppDesign.mediumRadius),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(irAAjustes ? 'Abrir ajustes' : 'Continuar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
