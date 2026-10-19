/// Numeración del RIM: `RIM-{AA}-{NNNN}` ("RIM-26-0042").
///
/// AA es la gestión (año de emisión) y NNNN el número, único en la gestión
/// para todos los RIM: calibración, soporte, registro directo y DataMET+. El
/// teléfono no puede pedir el número al servidor en el momento de emitir
/// (trabaja sin conexión), así que recibe por adelantado **talonarios**: rangos
/// de números libres que el servidor no entrega a nadie más. Al emitir toma el
/// siguiente número del talonario, de modo que el cliente firma con el código
/// definitivo.
library;

/// Números libres por debajo de los cuales se pide otro talonario.
const rimUmbralTalonario = 5;

final _codigoRim = RegExp(r'^RIM-(\d{2})-(\d{4,5})$');

/// `RIM-26-0042` para la gestión 2026 y el número 42.
String rimCodigo({required int gestion, required int numero}) =>
    'RIM-${(gestion % 100).toString().padLeft(2, '0')}-'
    '${numero.toString().padLeft(4, '0')}';

/// Gestión y número de un código `RIM-AA-NNNN`; null si es un código
/// anterior a la numeración ("RIM-0103-11-26") o no es un código de RIM.
({int gestion, int numero})? leerCodigoRim(String? codigo) {
  final match = _codigoRim.firstMatch(codigo?.trim() ?? '');
  if (match == null) return null;
  final numero = int.parse(match.group(2)!);
  if (numero < 1) return null;
  return (gestion: 2000 + int.parse(match.group(1)!), numero: numero);
}

/// Rango de números de RIM que el servidor entregó a esta instalación.
class RimTalonario {
  /// Identificador del talonario en el servidor.
  final int id;

  /// Instalación de ServiceMET que lo recibió; solo ella puede usarlo.
  final String instalacion;
  final int gestion;
  final int desde;
  final int hasta;
  final DateTime recibidoEn;

  /// Cuándo se informó al servidor que ya no se usará (fin de gestión).
  final DateTime? cierreReportadoEn;

  const RimTalonario({
    required this.id,
    required this.instalacion,
    required this.gestion,
    required this.desde,
    required this.hasta,
    required this.recibidoEn,
    this.cierreReportadoEn,
  });

  int get cantidad => hasta - desde + 1;

  bool contiene(int numero) => numero >= desde && numero <= hasta;

  factory RimTalonario.fromRow(Map<String, Object?> row) => RimTalonario(
        id: row['id'] as int,
        instalacion: row['instalacion'].toString(),
        gestion: row['gestion'] as int,
        desde: row['desde'] as int,
        hasta: row['hasta'] as int,
        recibidoEn:
            DateTime.tryParse(row['recibido_en']?.toString() ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
        cierreReportadoEn:
            DateTime.tryParse(row['cierre_reportado_en']?.toString() ?? '')
                ?.toLocal(),
      );
}

/// Siguiente número libre de esta instalación en una gestión.
class RimNumero {
  final int talonarioId;
  final String instalacion;
  final int gestion;
  final int numero;

  /// Números que quedan en esta instalación para la gestión, contando este.
  final int restantes;

  const RimNumero({
    required this.talonarioId,
    required this.instalacion,
    required this.gestion,
    required this.numero,
    required this.restantes,
  });

  String get codigo => rimCodigo(gestion: gestion, numero: numero);
}

/// El RIM no se pudo guardar con el número que se mostró al técnico.
class RimNumeroNoDisponible implements Exception {
  final String message;

  const RimNumeroNoDisponible(this.message);

  @override
  String toString() => message;
}
