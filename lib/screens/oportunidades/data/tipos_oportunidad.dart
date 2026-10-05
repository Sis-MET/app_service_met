import 'package:flutter/material.dart';
import '../../../theme/app_icons.dart';

/// Líneas comerciales del campo "TIPO DE OPORTUNIDAD" de Prospectos en el
/// Bitrix24 de METRICA. El servidor las busca por texto (sin distinguir
/// mayúsculas ni tildes) en esa lista; si Bitrix24 cambia sus opciones, el
/// dato queda en el comentario del prospecto en vez de perderse.
class OpportunityLine {
  OpportunityLine._();

  static const venta = 'VENTA';
  static const soporteTecnico = 'SOPORTE TECNICO';
  static const calibracion = 'CALIBRACIÓN';
}

/// Tipo de oportunidad comercial que detecta el técnico.
///
/// La [key] es estable y viaja al servidor; el [label] es lo que ve el
/// técnico y el detalle que llega al título y al comentario. La [line] es la
/// línea comercial que se asigna sola en Bitrix24 (null = sin línea).
class OpportunityType {
  final String key;
  final String label;
  final IconData icon;
  final String? line;

  const OpportunityType(this.key, this.label, this.icon, this.line);
}

/// Catálogo local, como [SupportModuleCatalog]: debe estar disponible sin
/// conexión, porque una oportunidad puede guardarse como pendiente en planta.
class OpportunityTypeCatalog {
  OpportunityTypeCatalog._();

  static const nuevaBalanza = OpportunityType('nueva_balanza',
      'Venta de nueva balanza', AppIcons.balanza, OpportunityLine.venta);
  static const reemplazoEquipo = OpportunityType('reemplazo_equipo',
      'Reemplazo de equipo', AppIcons.cambiar, OpportunityLine.venta);
  static const reemplazoIndicador = OpportunityType('reemplazo_indicador',
      'Reemplazo de indicador', AppIcons.computadora, OpportunityLine.venta);
  static const ventaIndicador = OpportunityType('venta_indicador',
      'Venta de indicador', AppIcons.venta, OpportunityLine.venta);
  static const repuestos = OpportunityType('repuestos', 'Repuestos',
      AppIcons.configurarEquipo, OpportunityLine.venta);
  static const accesorios = OpportunityType(
      'accesorios', 'Accesorios', AppIcons.extension, OpportunityLine.venta);
  static const mantenimiento = OpportunityType('mantenimiento', 'Mantenimiento',
      AppIcons.soporte, OpportunityLine.soporteTecnico);
  static const reparacion = OpportunityType('reparacion', 'Reparación',
      AppIcons.herramientas, OpportunityLine.soporteTecnico);
  static const servicioAdicional = OpportunityType(
      'servicio_adicional',
      'Servicio adicional',
      AppIcons.agregarTarea,
      OpportunityLine.soporteTecnico);
  static const calibracion = OpportunityType(
      'calibracion',
      'Calibración de otro equipo',
      AppIcons.verificado,
      OpportunityLine.calibracion);
  static const otro = OpportunityType('otro', 'Otro', AppIcons.mas, null);

  static const all = [
    nuevaBalanza,
    reemplazoEquipo,
    reemplazoIndicador,
    ventaIndicador,
    repuestos,
    accesorios,
    mantenimiento,
    reparacion,
    servicioAdicional,
    calibracion,
    otro,
  ];

  static OpportunityType? byKey(String? key) {
    for (final type in all) {
      if (type.key == key) return type;
    }
    return null;
  }
}

enum OpportunityPriority {
  baja('Baja'),
  media('Media'),
  alta('Alta');

  final String label;
  const OpportunityPriority(this.label);

  static OpportunityPriority? fromName(String? value) {
    for (final priority in values) {
      if (priority.name == value) return priority;
    }
    return null;
  }
}
