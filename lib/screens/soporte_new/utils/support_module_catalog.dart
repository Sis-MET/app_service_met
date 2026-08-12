class SupportModuleDefinition {
  final String key;
  final String serviceName;
  final int totalSteps;

  const SupportModuleDefinition(this.key, this.serviceName, this.totalSteps);
}

class SupportModuleCatalog {
  static const regular = SupportModuleDefinition(
    'mnt_prv_regular',
    'MNT PREVENTIVO REGULAR',
    7,
  );
  static const avanzado = SupportModuleDefinition(
    'mnt_prv_avanzado_stac',
    'MNT PREVENTIVO AVANZADO',
    9,
  );
  static const correctivo = SupportModuleDefinition(
    'mnt_correctivo',
    'MANTENIMIENTO CORRECTIVO',
    3,
  );
  static const diagnostico =
      SupportModuleDefinition('diagnostico', 'DIAGNÓSTICO', 2);
  static const verificaciones = SupportModuleDefinition(
    'verificaciones_internas',
    'VERIFICACIONES INTERNAS',
    3,
  );
  static const relevamiento = SupportModuleDefinition(
    'relevamiento_de_datos',
    'RELEVAMIENTO DE DATOS',
    5,
  );
  static const instalacion =
      SupportModuleDefinition('instalacion', 'INSTALACIÓN', 3);
  static const ajustes = SupportModuleDefinition(
    'ajustes_metrologicos',
    'AJUSTE DE VERIFICACIONES',
    3,
  );

  static const all = [
    regular,
    avanzado,
    correctivo,
    diagnostico,
    verificaciones,
    relevamiento,
    instalacion,
    ajustes,
  ];

  static SupportModuleDefinition? byKey(String key) {
    for (final definition in all) {
      if (definition.key == key) return definition;
    }
    return null;
  }
}
