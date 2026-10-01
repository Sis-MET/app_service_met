import '../../database/precarga_bd.dart';

/// Clientes, plantas e instrumentos entre los que el técnico elige cuando
/// llena un formulario fuera de un servicio. Las filas son las de la precarga
/// (`clientes`, `plantas` y balanzas con su ficha).
abstract class CatalogoServicio {
  Future<List<Map<String, dynamic>>> buscarClientes(String texto);

  /// Cliente con ese código de DataMET ("0032"), para el código QR.
  Future<Map<String, dynamic>?> clientePorCodigo(String codigoCliente);

  Future<List<Map<String, dynamic>>> plantasDe(Map<String, dynamic> cliente);

  Future<List<Map<String, dynamic>>> instrumentosDe(
    Map<String, dynamic> planta,
  );
}

/// Catálogo sobre la precarga descargada al teléfono: funciona sin conexión.
class PrecargaCatalogoServicio implements CatalogoServicio {
  final DatabaseHelperPrecarga _precarga;

  PrecargaCatalogoServicio([DatabaseHelperPrecarga? precarga])
      : _precarga = precarga ?? DatabaseHelperPrecarga();

  @override
  Future<List<Map<String, dynamic>>> buscarClientes(String texto) =>
      _precarga.searchClientes(texto);

  @override
  Future<Map<String, dynamic>?> clientePorCodigo(String codigoCliente) async {
    final codigo = codigoCliente.trim();
    for (final cliente in await _precarga.getClientes()) {
      if (cliente['codigo_cliente']?.toString().trim() == codigo) {
        return cliente;
      }
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> plantasDe(
    Map<String, dynamic> cliente,
  ) async {
    final clienteId = cliente['cliente_id']?.toString() ?? '';
    if (clienteId.isEmpty) return const [];
    return _precarga.getPlantasPorCliente(clienteId);
  }

  @override
  Future<List<Map<String, dynamic>>> instrumentosDe(
    Map<String, dynamic> planta,
  ) async {
    final codigo = planta['codigo_planta']?.toString().trim() ?? '';
    if (codigo.isEmpty) return const [];
    final instrumentos = await _precarga.getBalanzasPorPrefix(codigo);
    return [...instrumentos]..sort((a, b) =>
        (a['cod_metrica']?.toString() ?? '')
            .compareTo(b['cod_metrica']?.toString() ?? ''));
  }
}
