import 'package:flutter/material.dart';

import '../../home/widgets/upload_auth_dialog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../utils/top_alert.dart';
import '../../widgets/service_ui/service_options_menu.dart';
import '../calidad/utils/exportar_documento.dart';
import '../oportunidades/models/opportunity_service_context.dart';
import '../oportunidades/widgets/opportunity_password_prompt.dart';
import '../registro_directo/seleccion_rapida_screen.dart';
import 'models/rim_documento.dart';
import 'rim_form_screen.dart';
import 'services/rim_pdf.dart';
import 'services/rim_store.dart';
import '../../theme/app_icons.dart';

/// Carpeta, dentro de ServiceMET, donde se guardan los PDF de los RIM.
const carpetaRim = 'RIM';

/// Dónde encuentra el técnico los RIM emitidos, para los avisos.
const rimUbicacion = 'Servicios › Recepción de instrumentos (RIM)';

/// Pide la contraseña para renovar la sesión con la API antes de subir un
/// RIM. Devuelve null si el técnico cancela.
Future<String?> askRimPassword(BuildContext context, String? error) async {
  final usuario = await loggedServiceMetUser();
  if (!context.mounted || usuario == null || usuario.isEmpty) return null;
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UploadAuthDialog(
      usuario: usuario,
      title: 'Subir RIM',
      message: error ??
          'La sesión con el servidor venció. Ingrese su contraseña para '
              'subir el RIM.',
    ),
  );
}

/// Guarda, comparte o imprime el PDF de [registro].
Future<void> exportarRimPdf(BuildContext context, RimRegistro registro) =>
    exportarPdf(
      context,
      titulo: registro.documento.codigo,
      carpeta: carpetaRim,
      fileName: RimPdf.nombreArchivo(registro.documento),
      generar: () => RimPdf.generar(registro),
    );

enum _DespuesDeEmitir { pdf, cambiarBalanza }

/// Recorrido del RIM desde un servicio: abrir el formulario, emitir y decidir
/// qué sigue.
class RimFlow {
  RimFlow._();

  /// Solo para pruebas: reemplaza la tabla local de RIM.
  @visibleForTesting
  static RimStore Function() storeBuilder = RimStore.new;

  /// Si [service] ya tiene un RIM vigente de su instrumento.
  static Future<bool> yaEmitido(OpportunityServiceContext service) async {
    try {
      return await storeBuilder().existsForService(
        sessionId: service.sessionId,
        codMetrica: service.metricCode,
      );
    } catch (_) {
      return false;
    }
  }

  /// RIM fuera de un servicio: el técnico elige el cliente, la planta y el
  /// instrumento en la selección rápida y pasa al formulario de siempre.
  static Future<RimRegistro?> nuevoDirecto(
    BuildContext context, {
    required String userName,
  }) async {
    final service = await SeleccionRapidaScreen.open(
      context,
      proposito: PropositoSeleccion.rim,
      userName: userName,
    );
    if (service == null || !context.mounted) return null;
    return emitir(context, serviceContext: service);
  }

  /// Abre el formulario del RIM para el instrumento de [serviceContext]. Al
  /// emitirlo ofrece el PDF y, con [onCambiarBalanza], cerrar esta balanza
  /// sin concluir el servicio para elegir otra.
  static Future<RimRegistro?> emitir(
    BuildContext context, {
    required OpportunityServiceContext serviceContext,
    Future<void> Function(BuildContext context)? onCambiarBalanza,
  }) async {
    FocusScope.of(context).unfocus();
    if (serviceContext.metricCode == null) {
      TopAlert.show(
        context,
        'Primero seleccione el instrumento del servicio.',
        isError: true,
      );
      return null;
    }
    if (await yaEmitido(serviceContext)) {
      if (!context.mounted) return null;
      final otro = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Este instrumento ya tiene un RIM'),
          content: Text(
            'En este servicio ya se emitió un RIM de '
            '${serviceContext.metricCode}. Puede verlo en $rimUbicacion.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Emitir otro'),
            ),
          ],
        ),
      );
      if (otro != true) return null;
    }
    if (!context.mounted) return null;

    final registro =
        await RimFormScreen.open(context, serviceContext: serviceContext);
    if (registro == null || !context.mounted) return registro;

    // El PDF se puede abrir más de una vez antes de decidir qué sigue.
    while (true) {
      if (!context.mounted) break;
      final accion = await showModalBottomSheet<_DespuesDeEmitir>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDesign.radiusLarge),
          ),
        ),
        builder: (_) => _HojaRimEmitido(
          registro: registro,
          conCambioDeBalanza: onCambiarBalanza != null,
        ),
      );
      if (!context.mounted) break;
      switch (accion) {
        case _DespuesDeEmitir.pdf:
          await exportarRimPdf(context, registro);
          continue;
        case _DespuesDeEmitir.cambiarBalanza:
          final confirmado = await _confirmarCambioDeBalanza(context, registro);
          if (confirmado != true) continue;
          if (context.mounted) await onCambiarBalanza!(context);
        case null:
          break;
      }
      break;
    }
    return registro;
  }

  static Future<bool?> _confirmarCambioDeBalanza(
    BuildContext context,
    RimRegistro registro,
  ) {
    final service = registro.documento.service;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cambiar de balanza?'),
        content: Text(
          'El servicio de ${service.metricCode} queda sin concluir: lo '
          'registrado se conserva en este teléfono, pero no se sube como '
          'servicio terminado. Seguirá con otra balanza en '
          '${service.secaLabel} ${service.seca ?? ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cambiar de balanza'),
          ),
        ],
      ),
    );
  }

  /// Antes de descartar un servicio pendiente: si su instrumento no tiene
  /// RIM, ofrece emitirlo. Devuelve si se sigue adelante con el descarte.
  static Future<bool> sugerirAntesDeDescartar(
    BuildContext context,
    OpportunityServiceContext service,
  ) async {
    if (service.metricCode == null || await yaEmitido(service)) return true;
    if (!context.mounted) return false;
    final emitir = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(AppIcons.rim, color: AppColors.warning),
        title: const Text('¿Emitir el RIM antes de descartar?'),
        content: Text(
          'Va a descartar el servicio de ${service.metricCode} sin '
          'concluirlo. Si la balanza presentó un problema que impide '
          'terminarlo, emita el RIM para dejar constancia con la firma del '
          'cliente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Descartar sin RIM'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Emitir RIM'),
          ),
        ],
      ),
    );
    // Cerrar el diálogo sin elegir no descarta nada.
    if (emitir == null) return false;
    if (!emitir) return true;
    if (!context.mounted) return false;
    final registro = await RimFlow.emitir(context, serviceContext: service);
    // Si canceló el formulario, el servicio sigue pendiente.
    return registro != null;
  }
}

/// "Emitir RIM" del menú ⋮ de Calibración y de Soporte.
///
/// No es un paso del servicio: abre el formulario encima y, al cerrarlo, el
/// técnico sigue en el mismo paso. [contextBuilder] se evalúa al elegirla,
/// para tomar lo que el servicio sabe en ese momento.
class RimMenuAction extends ServiceMenuAction {
  static const title = 'Emitir RIM (recepción de instrumento)';
  static const menuIcon = AppIcons.rim;

  RimMenuAction({
    required OpportunityServiceContext Function() contextBuilder,
    Future<void> Function(BuildContext context)? onCambiarBalanza,
  }) : super(
          icon: menuIcon,
          label: title,
          onSelected: (context) => RimFlow.emitir(
            context,
            serviceContext: contextBuilder(),
            onCambiarBalanza: onCambiarBalanza,
          ),
        );
}

/// Sugerencia del RIM al salir de un servicio a medias, cuando la balanza ya
/// está elegida ([enCurso]) y todavía no tiene RIM en este servicio.
ServiceExitSuggestion rimExitSuggestion({
  required OpportunityServiceContext Function() contextBuilder,
  Future<void> Function(BuildContext context)? onCambiarBalanza,
  bool Function()? enCurso,
}) =>
    ServiceExitSuggestion(
      icon: RimMenuAction.menuIcon,
      message: 'Si la balanza presenta un problema que no permite concluir el '
          'servicio, emita el RIM antes de salir.',
      label: 'Emitir RIM',
      applies: () async {
        if (enCurso != null && !enCurso()) return false;
        final service = contextBuilder();
        return service.metricCode != null && !await RimFlow.yaEmitido(service);
      },
      onSelected: (context) => RimFlow.emitir(
        context,
        serviceContext: contextBuilder(),
        onCambiarBalanza: onCambiarBalanza,
      ),
    );

class _HojaRimEmitido extends StatelessWidget {
  final RimRegistro registro;
  final bool conCambioDeBalanza;

  const _HojaRimEmitido({
    required this.registro,
    required this.conCambioDeBalanza,
  });

  @override
  Widget build(BuildContext context) {
    final rim = registro.documento;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('RIM emitido', style: AppDesign.titleStyle(context)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AppStatusPill(
                icon: AppIcons.completo,
                label: [rim.codigo, rim.service.metricCode]
                    .whereType<String>()
                    .join(' · '),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Quedó guardado en este teléfono, firmado por '
              '${rim.contactoNombre} y por Métrica. Súbalo al servidor desde '
              '$rimUbicacion.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _opcion(
              context,
              icono: AppIcons.documento,
              titulo: 'Ver o compartir el PDF',
              detalle: 'Guardarlo, enviarlo al cliente o imprimirlo',
              valor: _DespuesDeEmitir.pdf,
            ),
            if (conCambioDeBalanza)
              _opcion(
                context,
                icono: AppIcons.cambiar,
                titulo: 'Cambiar de balanza',
                detalle: 'Cierra esta balanza sin concluir el servicio y '
                    'permite elegir otra',
                valor: _DespuesDeEmitir.cambiarBalanza,
              ),
            _opcion(
              context,
              icono: AppIcons.adelante,
              titulo: conCambioDeBalanza ? 'Seguir con esta balanza' : 'Listo',
              detalle: conCambioDeBalanza
                  ? 'Vuelve al paso en el que estaba'
                  : 'Cerrar este aviso',
              valor: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcion(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String detalle,
    required _DespuesDeEmitir? valor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: AppDesign.mediumRadius),
      leading: Icon(icono),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(detalle),
      trailing: const Icon(AppIcons.siguiente),
      onTap: () => Navigator.pop(context, valor),
    );
  }
}
