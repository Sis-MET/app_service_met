import '../../../database/precarga_bd.dart';
import '../models/temperatura_models.dart';

/// Lo que la calibración de temperatura lee de la precarga: clientes,
/// plantas, los equipos de la planta y los patrones del laboratorio. Las
/// pruebas lo reemplazan.
abstract class CatalogoTemperatura {
  Future<List<Map<String, dynamic>>> buscarClientes(String texto);
  Future<Map<String, dynamic>?> clientePorCodigo(String codigo);
  Future<List<Map<String, dynamic>>> plantasDe(String clienteId);

  /// Instrumentos de la planta que no son balanzas.
  Future<List<Map<String, dynamic>>> equiposDe(String codPlanta);
  Future<Map<String, dynamic>?> equipoPorCodigo(String codMetrica);

  /// Los equipos del laboratorio (`DATA_EQUIPOS_CAL`).
  Future<List<Map<String, dynamic>>> patrones();
}

class PrecargaCatalogoTemperatura implements CatalogoTemperatura {
  PrecargaCatalogoTemperatura([DatabaseHelperPrecarga? precarga])
      : _precarga = precarga ?? DatabaseHelperPrecarga();

  final DatabaseHelperPrecarga _precarga;

  @override
  Future<List<Map<String, dynamic>>> buscarClientes(String texto) =>
      _precarga.searchClientes(texto);

  @override
  Future<Map<String, dynamic>?> clientePorCodigo(String codigo) async {
    for (final cliente in await _precarga.getClientes()) {
      if (cliente['codigo_cliente']?.toString().trim() == codigo.trim()) {
        return cliente;
      }
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> plantasDe(String clienteId) =>
      _precarga.getPlantasPorCliente(clienteId);

  @override
  Future<List<Map<String, dynamic>>> equiposDe(String codPlanta) =>
      _precarga.getInstrumentosNoBalanzaPorPrefix(codPlanta);

  @override
  Future<Map<String, dynamic>?> equipoPorCodigo(String codMetrica) =>
      _precarga.getInfPorCodigo(codMetrica);

  @override
  Future<List<Map<String, dynamic>>> patrones() => _precarga.getEquipamientos();
}

/// Filtros sobre las filas de la precarga.
abstract final class FiltrosTemperatura {
  static String _texto(Map<String, dynamic> row, String key) =>
      row[key]?.toString().trim() ?? '';

  /// Pesas y masas patrón: nunca son patrones de temperatura.
  static bool esPesa(Map<String, dynamic> row) {
    final texto =
        '${_texto(row, 'instrumento')} ${_texto(row, 'cod_instrumento')}'
            .toLowerCase();
    return RegExp(r'\bpesas?\b|\bmasas?\b|juego de pesas').hasMatch(texto);
  }

  /// Un termohigrómetro u otro instrumento para el ambiente.
  static bool esAmbiente(Map<String, dynamic> row) {
    final texto = _texto(row, 'instrumento').toLowerCase();
    return RegExp(r'higr[oó]metr|termohigr|ambient|bar[oó]metr')
        .hasMatch(texto);
  }

  /// Un patrón o sensor de temperatura del laboratorio (termómetro,
  /// termopar, PT100, registrador…). Las pesas y los termohigrómetros no.
  static bool esPatronTemperatura(Map<String, dynamic> row) {
    if (esPesa(row) || esAmbiente(row)) return false;
    final texto =
        '${_texto(row, 'instrumento')} ${_texto(row, 'cod_instrumento')}'
            .toLowerCase();
    return RegExp(
      r'term[oó]metr|termopar|termocupla|pt-?100|pt-?1000|\brtd\b|'
      r'registrador|data ?logger|temperatura|sonda|sensor|pir[oó]metr|'
      r'calibrador de temp|bloque seco|horno de calibraci',
    ).hasMatch(texto);
  }

  /// El equipo de la precarga tal como lo guarda la calibración.
  static TempEquipo equipoDe(Map<String, dynamic> row) {
    final instrumento = _texto(row, 'instrumento');
    final tipoInstrumento = _texto(row, 'tipo_instrumento');
    String? tipo;
    final texto = '$instrumento $tipoInstrumento'.toLowerCase();
    for (final candidato in tiposEquipoTemperatura) {
      if (texto.contains(candidato.toLowerCase())) {
        tipo = candidato;
        break;
      }
    }
    String? vacio(String key) {
      final value = _texto(row, key);
      return value.isEmpty ? null : value;
    }

    return TempEquipo(
      codMetrica: _texto(row, 'cod_metrica'),
      tipo: tipo,
      instrumento: instrumento.isEmpty ? null : instrumento,
      marca: vacio('marca'),
      modelo: vacio('modelo'),
      serie: vacio('serie'),
      codInterno: vacio('cod_interno'),
      ubicacion: vacio('ubicacion'),
    );
  }

  static TempPatron patronDe(Map<String, dynamic> row, {required String uso}) =>
      TempPatron(
        codInstrumento: _texto(row, 'cod_instrumento'),
        instrumento: _texto(row, 'instrumento').isEmpty
            ? null
            : _texto(row, 'instrumento'),
        certFecha: _texto(row, 'cert_fecha').isEmpty
            ? null
            : _texto(row, 'cert_fecha'),
        enteCalibrador: _texto(row, 'ente_calibrador').isEmpty
            ? null
            : _texto(row, 'ente_calibrador'),
        estado: _texto(row, 'estado').isEmpty ? null : _texto(row, 'estado'),
        uso: uso,
      );
}
