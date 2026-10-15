// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/permisos_app.dart';
import '../theme/app_colors.dart';
import '../theme/app_design.dart';
import '../theme/app_icons.dart';
import 'dialogo_permiso.dart';

/// Envuelve la pantalla de un servicio (calibración o soporte): mientras la
/// app no tenga permiso de ubicación, o la ubicación del teléfono esté
/// apagada, el servicio queda bloqueado y [child] no se construye.
///
/// Al entrar avisa antes de la solicitud del sistema. Si el técnico la
/// rechaza, muestra cómo concederla y vuelve a revisar al regresar de
/// Ajustes.
class RequiereUbicacion extends StatefulWidget {
  const RequiereUbicacion({super.key, required this.child});

  final Widget child;

  /// La ruta de una pantalla de servicio, ya protegida.
  static MaterialPageRoute<T> ruta<T>(Widget pantalla) =>
      MaterialPageRoute<T>(builder: (_) => RequiereUbicacion(child: pantalla));

  @override
  State<RequiereUbicacion> createState() => _RequiereUbicacionState();
}

class _RequiereUbicacionState extends State<RequiereUbicacion>
    with WidgetsBindingObserver {
  EstadoUbicacion? _estado;
  bool _revisando = false;

  AccesoUbicacion get _acceso => AccesoUbicacion.instancia;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _entrar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de Ajustes se revisa de nuevo, sin pedir nada.
    if (state == AppLifecycleState.resumed &&
        _estado != null &&
        _estado != EstadoUbicacion.concedida) {
      _revisar();
    }
  }

  Future<void> _entrar() async {
    final estado = await _consultar(_acceso.estado);
    if (!mounted || estado != EstadoUbicacion.denegada) return;
    // Primero el aviso de la app; recién después, la solicitud del sistema.
    final continuar = await confirmarPermiso(
      context,
      PermisoApp.ubicacion,
      obligatorio: true,
    );
    if (continuar && mounted) await _consultar(_acceso.solicitar);
  }

  Future<void> _revisar() => _consultar(_acceso.estado);

  Future<EstadoUbicacion?> _consultar(
      Future<EstadoUbicacion> Function() consulta) async {
    if (_revisando) return _estado;
    _revisando = true;
    try {
      final estado = await consulta();
      if (mounted) setState(() => _estado = estado);
      return estado;
    } catch (_) {
      // Sin respuesta del sistema, se trata como sin permiso.
      if (mounted) setState(() => _estado = EstadoUbicacion.denegada);
      return EstadoUbicacion.denegada;
    } finally {
      _revisando = false;
    }
  }

  Future<void> _resolver() async {
    switch (_estado) {
      case EstadoUbicacion.denegada:
        await _consultar(_acceso.solicitar);
      case EstadoUbicacion.denegadaSiempre:
        await _acceso.abrirAjustesApp();
      case EstadoUbicacion.apagada:
        await _acceso.abrirAjustesUbicacion();
      case EstadoUbicacion.concedida:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    if (estado == EstadoUbicacion.concedida) return widget.child;
    if (estado == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _ServicioBloqueado(
      estado: estado,
      onResolver: _resolver,
      onReintentar: _revisar,
    );
  }
}

class _ServicioBloqueado extends StatelessWidget {
  const _ServicioBloqueado({
    required this.estado,
    required this.onResolver,
    required this.onReintentar,
  });

  final EstadoUbicacion estado;
  final Future<void> Function() onResolver;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final oscuro = cs.brightness == Brightness.dark;
    final (detalle, accion) = switch (estado) {
      EstadoUbicacion.denegadaSiempre => (
          'El permiso fue rechazado. Actívelo en Ajustes › Permisos › '
              'Ubicación y vuelva a la app.',
          'Abrir ajustes',
        ),
      EstadoUbicacion.apagada => (
          'La ubicación del teléfono está desactivada. Actívela y vuelva a la '
              'app.',
          'Activar ubicación',
        ),
      _ => (
          'Permita el acceso cuando el teléfono lo solicite.',
          'Permitir ubicación',
        ),
    };

    return Scaffold(
      appBar: AppBar(
        leading: const Center(child: AppBackButton()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color:
                      AppColors.accentYellow.withOpacity(oscuro ? 0.16 : 0.28),
                  borderRadius: AppDesign.largeRadius,
                ),
                child: Icon(AppIcons.ubicacion, size: 38, color: cs.onSurface),
              ),
              const SizedBox(height: 24),
              Text(
                'Ubicación requerida',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Por procedimientos de la empresa, para iniciar o continuar un '
                'servicio debe permitir el acceso a la ubicación de este '
                'dispositivo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14.5, height: 1.45, color: cs.onSurface),
              ),
              const SizedBox(height: 10),
              Text(
                detalle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, height: 1.4, color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: AppDesign.positiveButtonStyle(),
                  onPressed: onResolver,
                  icon: const Icon(AppIcons.ubicacion, size: 18),
                  label: Text(accion),
                ),
              ),
              if (estado != EstadoUbicacion.denegada) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: AppDesign.neutralButtonStyle(context),
                    onPressed: onReintentar,
                    icon: const Icon(AppIcons.actualizar, size: 18),
                    label: const Text('Ya lo activé'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
