import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Estado del guardado automático para el indicador del AppBar.
enum SaveStatus { idle, saving, success, error }

/// Indicador de estado de guardado (spinner / nube verde / error rojo),
/// idéntico al usado en el AppBar de Calibración.
class SaveStatusIndicator extends StatelessWidget {
  final SaveStatus status;

  const SaveStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Widget child;
    switch (status) {
      case SaveStatus.saving:
        child = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case SaveStatus.error:
        child = const Icon(Icons.error_outline, color: Colors.red);
        break;
      case SaveStatus.success:
      case SaveStatus.idle:
        child = const Icon(Icons.cloud_done, color: Colors.green);
        break;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: child,
      ),
    );
  }
}

/// AppBar plano estilo Calibración: elevation 0, fondo = scaffold,
/// título Poppins 20 w700, iconTheme según brillo.
class ServiceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const ServiceAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          height: 1.1,
        ),
      ),
      actions: actions,
    );
  }
}
