/// Reglas de vencimiento y fechas, sin acceso a base de datos ni al plugin,
/// para poder probarlas con datos fijos.
library;

/// La precarga no trae el intervalo de calibración de cada patrón o balanza;
/// DataMET trabaja con certificados anuales.
const calibrationValidity = Duration(days: 365);

/// Anticipación con la que un vencimiento empieza a avisarse.
const expiryWarning = Duration(days: 30);

/// Una balanza vencida hace más tiempo probablemente ya no es cliente activo
/// o se calibró por otra vía; seguir avisándola solo agrega ruido.
const overdueTrackingWindow = Duration(days: 60);

/// Días sin actualizar la precarga a partir de los cuales se recuerda.
const precargaStaleAfter = Duration(days: 7);

/// Interpreta las fechas tal como llegan de DataMET y de las bases locales:
/// ISO (`2026-08-12`, `2026-08-12 10:30:00`) o `dd/mm/yyyy` / `dd-mm-yyyy`.
DateTime? parseServiceDate(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;

  final iso = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  if (iso != null) return iso;

  final parts = text.split(RegExp(r'[/-]'));
  if (parts.length == 3 && parts[2].length == 4) {
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null) {
      final parsed = DateTime(year, month, day);
      if (parsed.year == year && parsed.month == month && parsed.day == day) {
        return parsed;
      }
    }
  }
  return null;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Días calendario de [from] a [to]; negativo si [to] ya pasó.
int daysBetween(DateTime from, DateTime to) =>
    _dateOnly(to).difference(_dateOnly(from)).inDays;

/// Un instrumento (patrón o balanza) con su último certificado conocido.
class CertifiedItem {
  final String codigo;
  final String descripcion;
  final DateTime ultimaCalibracion;

  const CertifiedItem({
    required this.codigo,
    required this.descripcion,
    required this.ultimaCalibracion,
  });

  DateTime get vence => ultimaCalibracion.add(calibrationValidity);
}

class DueItem {
  final CertifiedItem item;

  /// Días hasta el vencimiento contados desde la fecha evaluada; negativo si
  /// ya venció.
  final int diasRestantes;

  const DueItem(this.item, this.diasRestantes);

  bool get vencido => diasRestantes < 0;

  String get codigo => item.codigo;
  String get descripcion => item.descripcion;

  String get plazo {
    if (diasRestantes < 0) {
      final dias = -diasRestantes;
      return dias == 1 ? 'vencido hace 1 día' : 'vencido hace $dias días';
    }
    if (diasRestantes == 0) return 'vence hoy';
    return diasRestantes == 1 ? 'vence mañana' : 'vence en $diasRestantes días';
  }
}

/// Patrones vencidos (todos: no deben usarse) y los que vencen dentro de
/// [expiryWarning], del más urgente al menos urgente.
List<DueItem> evaluatePatrones(Iterable<CertifiedItem> patrones, DateTime at) {
  final result = <DueItem>[];
  for (final patron in patrones) {
    final dias = daysBetween(at, patron.vence);
    if (dias <= expiryWarning.inDays) result.add(DueItem(patron, dias));
  }
  result.sort((a, b) => a.diasRestantes.compareTo(b.diasRestantes));
  return result;
}

/// Balanza del historial de servicios, ubicada en su cliente y planta.
class BalanzaHistorial extends CertifiedItem {
  final String cliente;
  final String planta;

  const BalanzaHistorial({
    required super.codigo,
    required super.ultimaCalibracion,
    required this.cliente,
    required this.planta,
    super.descripcion = '',
  });
}

class PlantaDue {
  final String cliente;
  final String planta;
  final List<DueItem> balanzas;

  const PlantaDue({
    required this.cliente,
    required this.planta,
    required this.balanzas,
  });

  int get masUrgente => balanzas.first.diasRestantes;
  int get vencidas => balanzas.where((b) => b.vencido).length;
}

/// Balanzas que vencen dentro de [expiryWarning] o vencieron hace menos de
/// [overdueTrackingWindow], agrupadas por cliente y planta para planificar
/// visitas. Los grupos más urgentes van primero.
List<PlantaDue> evaluateBalanzas(
  Iterable<BalanzaHistorial> balanzas,
  DateTime at,
) {
  final groups = <String, List<DueItem>>{};
  final names = <String, BalanzaHistorial>{};
  for (final balanza in balanzas) {
    final dias = daysBetween(at, balanza.vence);
    if (dias > expiryWarning.inDays || dias < -overdueTrackingWindow.inDays) {
      continue;
    }
    final key = '${balanza.cliente}|${balanza.planta}';
    names.putIfAbsent(key, () => balanza);
    groups.putIfAbsent(key, () => []).add(DueItem(balanza, dias));
  }

  final result = groups.entries.map((entry) {
    entry.value.sort((a, b) => a.diasRestantes.compareTo(b.diasRestantes));
    final first = names[entry.key]!;
    return PlantaDue(
      cliente: first.cliente,
      planta: first.planta,
      balanzas: entry.value,
    );
  }).toList()
    ..sort((a, b) {
      final byUrgency = a.masUrgente.compareTo(b.masUrgente);
      if (byUrgency != 0) return byUrgency;
      return b.balanzas.length.compareTo(a.balanzas.length);
    });
  return result;
}

/// Última calibración por código métrica a partir de las filas de
/// `servicios` de la precarga (`cod_metrica`, `reg_fecha`).
Map<String, DateTime> latestServiceByCodMetrica(
  Iterable<Map<String, Object?>> servicios,
) {
  final latest = <String, DateTime>{};
  for (final row in servicios) {
    final codigo = row['cod_metrica']?.toString().trim() ?? '';
    final fecha = parseServiceDate(row['reg_fecha']);
    if (codigo.isEmpty || fecha == null) continue;
    final current = latest[codigo];
    if (current == null || fecha.isAfter(current)) latest[codigo] = fecha;
  }
  return latest;
}

/// Ubica un código métrica (`CLIENTE-PLANTA-NNN`) en su planta.
///
/// [plantasPorPrefijo] usa como clave el mismo prefijo con el que la app
/// filtra balanzas por planta (ver `CalibrationRepository.getBalanzas`).
/// Se prueba del prefijo más largo al más corto para no confundir plantas
/// cuyos códigos empiezan igual.
T? plantaForCodMetrica<T>(String codMetrica, Map<String, T> plantasPorPrefijo) {
  final parts = codMetrica.trim().split('-');
  for (var length = parts.length - 1; length > 0; length--) {
    final match = plantasPorPrefijo[parts.take(length).join('-')];
    if (match != null) return match;
  }
  return null;
}

/// Prefijo de código métrica que corresponde a una planta.
String plantaPrefix(String codigoPlanta, String codigoCliente) {
  final planta = codigoPlanta.trim();
  if (planta.contains('-') || codigoCliente.trim().isEmpty) return planta;
  return '${codigoCliente.trim()}-$planta';
}

/// Primer horario de [slots] (hora, minuto) que cae al menos [lead] después
/// de [now].
DateTime nextSlot(
  DateTime now,
  List<(int, int)> slots, {
  Duration lead = Duration.zero,
}) {
  final earliest = now.add(lead);
  for (var dayOffset = 0; dayOffset < 3; dayOffset++) {
    for (final (hour, minute) in slots) {
      final candidate =
          DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
      if (!candidate.isBefore(earliest)) return candidate;
    }
  }
  throw ArgumentError('slots vacío');
}

/// Próximo [weekday] (`DateTime.monday`...) a la hora indicada, estrictamente
/// después de [now].
DateTime nextWeekdayAt(DateTime now, int weekday, int hour, int minute) {
  var candidate = DateTime(now.year, now.month, now.day, hour, minute);
  while (candidate.weekday != weekday || !candidate.isAfter(now)) {
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day + 1,
      hour,
      minute,
    );
  }
  return candidate;
}

/// Cantidad de fechas dentro de `[start, end)`.
int countInWindow(Iterable<DateTime> dates, DateTime start, DateTime end) =>
    dates.where((d) => !d.isBefore(start) && d.isBefore(end)).length;

String plural(int count, String singular, String pluralForm) =>
    '$count ${count == 1 ? singular : pluralForm}';
