import 'package:sqflite/sqflite.dart';

import '../services/ubicacion_servicio.dart';
import 'app_database.dart';
import 'soporte_tecnico/database_helper_ajustes.dart';
import 'soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import 'soporte_tecnico/database_helper_instalacion.dart';
import 'soporte_tecnico/database_helper_mnt_prv_avanzado_stac.dart';
import 'soporte_tecnico/database_helper_mnt_prv_regular_stil.dart';
import 'soporte_tecnico/database_helper_relevamiento.dart';
import 'soporte_tecnico/database_helper_verificaciones.dart';

/// Una tabla de datos de servicio dentro de una base local.
///
/// Un mismo archivo puede contener varias tablas: `diagnostico_correctivo.db`
/// aloja tanto `diagnostico` como `diagnostico_correctivo`, y ambas se
/// distinguen por [table], no por el archivo.
class LocalTableSpec {
  /// Nombre del archivo en `getDatabasesPath()`, p. ej. `instalacion.db`.
  final String database;

  /// Nombre de la tabla dentro de ese archivo.
  final String table;

  /// Clave del submódulo de soporte; vacía para calibración.
  final String module;

  /// Nombre legible para la interfaz.
  final String label;

  /// Columnas que identifican un registro de forma única. Se usa para no
  /// duplicar al importar y para localizar filas al editar.
  final List<String> naturalKey;

  /// Abre la base viva de la app (reutiliza el singleton correspondiente, para
  /// no abrir una segunda conexión sobre el mismo archivo).
  final Future<Database> Function() openLive;

  const LocalTableSpec({
    required this.database,
    required this.table,
    required this.module,
    required this.label,
    required this.naturalKey,
    required this.openLive,
  });

  bool get isCalibracion => module.isEmpty;
}

/// Fuente única de verdad sobre qué bases locales existen, qué tablas
/// contienen y cómo se identifica un registro dentro de cada una.
class LocalDatabaseCatalog {
  LocalDatabaseCatalog._();

  static const List<String> _soporteKey = ['otst', 'session_id'];

  /// Abre la base viva de soporte con las columnas de ubicación ya creadas,
  /// para que importar un respaldo no las descarte.
  static Future<Database> Function() _conUbicacion(
    Future<Database> Function() abrir,
    String tabla,
  ) =>
      () async {
        final db = await abrir();
        await RegistroUbicacion.asegurarColumnas(db, tabla);
        return db;
      };

  static final List<LocalTableSpec> all = [
    LocalTableSpec(
      database: 'calibracion.db',
      table: 'registros_calibracion',
      module: '',
      label: 'Calibración',
      naturalKey: const ['seca', 'session_id'],
      openLive: () => AppDatabase().database,
    ),
    LocalTableSpec(
      database: 'ajustes_metrologicos.db',
      table: 'ajustes_metrologicos',
      module: 'ajuste_verificaciones',
      label: 'Ajuste y verificaciones',
      naturalKey: _soporteKey,
      openLive: _conUbicacion(
          () => DatabaseHelperAjustes().database, 'ajustes_metrologicos'),
    ),
    LocalTableSpec(
      database: 'diagnostico_correctivo.db',
      table: 'diagnostico',
      module: 'diagnostico',
      label: 'Diagnóstico',
      naturalKey: _soporteKey,
      openLive: _conUbicacion(
          () => DatabaseHelperDiagnosticoCorrectivo().database, 'diagnostico'),
    ),
    LocalTableSpec(
      database: 'instalacion.db',
      table: 'instalacion',
      module: 'instalacion',
      label: 'Instalación',
      naturalKey: _soporteKey,
      openLive: _conUbicacion(
          () => DatabaseHelperInstalacion().database, 'instalacion'),
    ),
    LocalTableSpec(
      database: 'diagnostico_correctivo.db',
      table: 'diagnostico_correctivo',
      module: 'mnt_correctivo',
      label: 'Mantenimiento correctivo',
      naturalKey: _soporteKey,
      openLive: _conUbicacion(
          () => DatabaseHelperDiagnosticoCorrectivo().database,
          'diagnostico_correctivo'),
    ),
    LocalTableSpec(
      database: 'mnt_prv_avanzado_stac.db',
      table: 'mnt_prv_avanzado_stac',
      module: 'mnt_prv_avanzado',
      label: 'Mantenimiento preventivo avanzado',
      naturalKey: _soporteKey,
      openLive: _conUbicacion(() => DatabaseHelperMntPrvAvanzadoStac().database,
          'mnt_prv_avanzado_stac'),
    ),
    LocalTableSpec(
      database: 'mnt_prv_regular_stil.db',
      table: 'mnt_prv_regular_stil',
      module: 'mnt_prv_regular',
      label: 'Mantenimiento preventivo regular',
      naturalKey: _soporteKey,
      openLive: _conUbicacion(() => DatabaseHelperMntPrvRegularStil().database,
          'mnt_prv_regular_stil'),
    ),
    LocalTableSpec(
      database: 'relevamiento_de_datos.db',
      table: 'relevamiento_de_datos',
      module: 'relevamiento_de_datos',
      label: 'Relevamiento de datos',
      naturalKey: _soporteKey,
      openLive: _conUbicacion(
          () => DatabaseHelperRelevamiento().database, 'relevamiento_de_datos'),
    ),
    LocalTableSpec(
      database: 'verificaciones_internas.db',
      table: 'verificaciones_internas',
      module: 'verificaciones_internas',
      label: 'Verificaciones internas',
      naturalKey: _soporteKey,
      openLive: _conUbicacion(() => DatabaseHelperVerificaciones().database,
          'verificaciones_internas'),
    ),
  ];

  static Iterable<LocalTableSpec> get soporte =>
      all.where((spec) => !spec.isCalibracion);

  static LocalTableSpec? byTable(String table) {
    for (final spec in all) {
      if (spec.table == table) return spec;
    }
    return null;
  }

  /// Todas las tablas que viven en [databaseFile].
  static List<LocalTableSpec> forDatabaseFile(String databaseFile) =>
      all.where((spec) => spec.database == databaseFile).toList();
}
