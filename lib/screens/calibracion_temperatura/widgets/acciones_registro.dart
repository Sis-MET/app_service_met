import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../database/precarga_bd.dart';
import '../../../home/widgets/asignar_codigo_sheet.dart';
import '../../../home/widgets/upload_auth_dialog.dart';
import '../../../login/services/connection_profile_service.dart';
import '../../../utils/service_exporter.dart';
import '../../../utils/top_alert.dart';
import '../../oportunidades/widgets/opportunity_password_prompt.dart'
    show loggedServiceMetUser, serviceMetAppVersion;
import '../data/temperatura_store.dart';
import '../models/temperatura_models.dart';
import '../services/temperatura_export.dart';
import '../services/temperatura_repository.dart';

/// Guarda el CSV del registro en la carpeta del servicio.
Future<void> exportarCsvTemperatura(
  BuildContext context,
  TempPaquete paquete,
) async {
  try {
    final result = await ServiceExporter.exportDocument(
      codigoServicio: paquete.servicio.seca ?? 'SIN-SECA',
      fileName: TemperaturaExport.csvFileName(paquete.servicio),
      mimeType: ServiceExporter.csvMime,
      bytes: TemperaturaExport.csv(paquete),
    );
    if (!context.mounted || !result.saved) return;
    TopAlert.show(context, 'CSV guardado en ${result.destination}.');
  } catch (error) {
    if (context.mounted) {
      TopAlert.show(context, 'No se pudo exportar: $error', isError: true);
    }
  }
}

/// Sube el registro a DataMET. Devuelve el registro actualizado, o null si
/// no se pudo (el motivo se muestra).
Future<TempServicio?> subirRegistroTemperatura(
  BuildContext context,
  String uuid, {
  TemperaturaStore? store,
}) async {
  final profiles = context.read<ConnectionProfileService>();
  final repository = TemperaturaRepository(
    apiUrl: () => profiles.perfilSeleccionado?.apiUrl,
    loggedUser: loggedServiceMetUser,
    store: store,
  );
  try {
    final resultado = await repository.subir(
      uuid,
      onAuthRequired: (error) async {
        final usuario = await loggedServiceMetUser();
        if (!context.mounted || usuario == null || usuario.isEmpty) return null;
        return showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => UploadAuthDialog(
            usuario: usuario,
            title: 'Subir a DataMET',
            message: error ??
                'La sesión con el servidor venció. Ingrese su contraseña '
                    'para subir la calibración.',
          ),
        );
      },
    );
    if (!context.mounted) return resultado.servicio;
    final error = resultado.error;
    if (error == null) {
      TopAlert.show(
        context,
        resultado.duplicado
            ? 'El registro ya estaba en DataMET (N.º ${resultado.servicio.serverN}).'
            : 'Subido a DataMET con el N.º ${resultado.servicio.serverN}.',
      );
      return resultado.servicio;
    }
    final detalles = error.details ?? const [];
    if (detalles.isEmpty) {
      TopAlert.show(context, error.message, isError: true);
    } else {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('El servidor rechazó el registro'),
          content: SingleChildScrollView(
            child: Text([error.message, ...detalles.take(12)].join('\n• ')),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
    return null;
  } catch (error) {
    if (context.mounted) {
      TopAlert.show(context, 'No se pudo subir: $error', isError: true);
    }
    return null;
  } finally {
    repository.close();
  }
}

/// Pide el código métrica que DataMET asignó a un equipo nuevo y lo guarda
/// con su historial.
Future<TempServicio?> asignarCodigoTemperatura(
  BuildContext context,
  TempServicio servicio, {
  TemperaturaStore? store,
}) async {
  final almacen = store ?? TemperaturaStore();
  final usuario = await loggedServiceMetUser() ?? servicio.personal ?? '';
  final version = await serviceMetAppVersion().catchError((_) => null) ?? '';
  if (!context.mounted) return null;
  final equipo = servicio.equipo;
  TempServicio? actualizado;
  final codigo = await showAsignarCodigoSheet(
    context,
    registro: {
      'cod_metrica': equipo?.codMetrica,
      'marca': equipo?.marca,
      'modelo': equipo?.modelo,
      'serie': equipo?.serie,
      'ubicacion': equipo?.ubicacion,
      'seca': servicio.seca,
    },
    buscarEnCatalogo: (codigo) =>
        DatabaseHelperPrecarga().getInfPorCodigo(codigo),
    verificar: (codigo) async {
      final seca = servicio.seca;
      if (seca == null) return null;
      return await almacen.equipoYaEnSeca(seca, codigo,
              exceptoUuid: servicio.uuid)
          ? 'Otro equipo de la SECA $seca ya tiene ese código.'
          : null;
    },
    guardar: (codigo) async {
      actualizado = await almacen.asignarCodigo(
        servicio.uuid,
        codigo: codigo,
        usuario: usuario,
        appVersion: version,
      );
    },
  );
  if (codigo == null || !context.mounted) return null;
  TopAlert.show(context, 'Código $codigo asignado.');
  return actualizado;
}
