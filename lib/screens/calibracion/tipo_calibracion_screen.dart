import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../theme/app_icons.dart';
import '../../widgets/service_ui/nav_pill.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import '../soporte_new/precarga/precarga_controller.dart' show ServicioInfo;
import '../soporte_new/precarga/widgets/tipo_servicio_step.dart';

/// Qué se calibra.
enum TipoCalibracion { balanzas, temperatura }

/// Primer paso de Calibración: el tipo de calibración, con el mismo selector
/// que el «Tipo de servicio» de soporte. Devuelve el tipo elegido, o null si
/// el técnico vuelve atrás.
class TipoCalibracionScreen extends StatefulWidget {
  const TipoCalibracionScreen({
    super.key,
    this.pendientesTemperatura = 0,
    this.onRegistrosTemperatura,
  });

  /// Registros de temperatura finalizados que no se subieron.
  final int pendientesTemperatura;

  /// Abre la lista de registros de temperatura.
  final VoidCallback? onRegistrosTemperatura;

  static const balanzas = ServicioInfo(
    nombre: 'CALIBRACIÓN DE BALANZAS',
    codigo: 'CAL.BL',
    descripcion:
        'Balanzas y básculas: excentricidad, repetibilidad y linealidad con pesas patrón.',
    icon: AppIcons.balanza,
    color: AppColors.actionPositive,
    tag: 'MASA',
  );

  static const temperatura = ServicioInfo(
    nombre: 'CALIBRACIÓN DE TEMPERATURA',
    codigo: 'CAL.TE',
    descripcion:
        'Muflas, hornos, estufas e incubadoras: lecturas programadas con la cámara.',
    icon: AppIcons.temperatura,
    color: AppColors.actionPositive,
    tag: 'TEMPERATURA',
  );

  static Future<TipoCalibracion?> elegir(
    BuildContext context, {
    int pendientesTemperatura = 0,
    VoidCallback? onRegistrosTemperatura,
  }) {
    return Navigator.of(context).push<TipoCalibracion>(
      MaterialPageRoute(
        builder: (_) => TipoCalibracionScreen(
          pendientesTemperatura: pendientesTemperatura,
          onRegistrosTemperatura: onRegistrosTemperatura,
        ),
      ),
    );
  }

  @override
  State<TipoCalibracionScreen> createState() => _TipoCalibracionScreenState();
}

class _TipoCalibracionScreenState extends State<TipoCalibracionScreen> {
  String? _seleccion;

  TipoCalibracion? get _tipo => switch (_seleccion) {
        final nombre when nombre == TipoCalibracionScreen.balanzas.nombre =>
          TipoCalibracion.balanzas,
        final nombre when nombre == TipoCalibracionScreen.temperatura.nombre =>
          TipoCalibracion.temperatura,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final tipo = _tipo;
    return Scaffold(
      appBar: const ServiceAppBar(
        title: 'Calibración',
        subtitle: 'Tipo de calibración',
        centerTitle: true,
      ),
      body: Stack(
        children: [
          TipoServicioStep(
            title: 'Tipo de calibración',
            subtitle: 'Seleccione qué se va a calibrar',
            servicios: const [
              TipoCalibracionScreen.balanzas,
              TipoCalibracionScreen.temperatura,
            ],
            selectedServicio: _seleccion,
            onServicioSelected: (nombre) => setState(() => _seleccion = nombre),
            footer: widget.onRegistrosTemperatura == null
                ? null
                : AppPanel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      key: const ValueKey('registros-temperatura'),
                      contentPadding: const EdgeInsets.fromLTRB(18, 6, 14, 6),
                      leading: const Icon(AppIcons.historial,
                          color: AppColors.shimmerGold),
                      title: const Text('Registros de temperatura'),
                      subtitle: const Text(
                          'Ver, exportar y subir las calibraciones guardadas'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.pendientesTemperatura > 0)
                            Badge(
                              label: Text('${widget.pendientesTemperatura}'),
                              backgroundColor: AppColors.warning,
                            ),
                          const SizedBox(width: 6),
                          const Icon(AppIcons.siguiente),
                        ],
                      ),
                      onTap: widget.onRegistrosTemperatura,
                    ),
                  ),
          ),
          Positioned(
            bottom: ServiceNavPill.bottomOffset(context),
            right: 20,
            child: ServiceNavPill(
              label: 'Continuar',
              onBack: () => Navigator.of(context).maybePop(),
              onNext:
                  tipo == null ? null : () => Navigator.of(context).pop(tipo),
            ),
          ),
        ],
      ),
    );
  }
}
