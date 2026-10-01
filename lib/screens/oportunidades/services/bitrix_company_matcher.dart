import '../models/bitrix_crm.dart';
import '../models/opportunity_service_context.dart';

/// Cómo quedó asignada la empresa de Bitrix24 de una oportunidad.
enum CompanySource {
  /// La eligió el técnico en el buscador.
  manual,

  /// La que el técnico ya había elegido antes para ese cliente, en este
  /// teléfono.
  remembered,

  /// Coincidencia exacta de nombre o razón social con el cliente.
  exact;

  static CompanySource? fromName(String? value) {
    for (final source in values) {
      if (source.name == value) return source;
    }
    return null;
  }
}

/// Resultado de buscar la empresa de Bitrix24 de un cliente de ServiceMET.
class CompanyResolution {
  /// Null si no se pudo asignar con seguridad.
  final BitrixCompany? company;
  final CompanySource? source;

  /// Hay más de una empresa con el nombre del cliente.
  final bool ambiguous;

  const CompanyResolution.found(BitrixCompany this.company, this.source)
      : ambiguous = false;

  const CompanyResolution.none({this.ambiguous = false})
      : company = null,
        source = null;

  /// Por qué el técnico tiene que elegirla a mano.
  String get message => ambiguous
      ? 'Hay más de una empresa con ese nombre en Bitrix24: elija la correcta.'
      : 'Elija la empresa de Bitrix24: no hay una coincidencia exacta con el '
          'cliente.';
}

/// Decide, sin adivinar, qué empresa de Bitrix24 corresponde a un cliente de
/// ServiceMET. Los nombres pueden no coincidir ("Coca-Cola Embol S.A." /
/// "EMBOL S.A."), así que solo se acepta una igualdad completa, ignorando
/// mayúsculas, tildes, puntuación y la forma societaria.
class BitrixCompanyMatcher {
  BitrixCompanyMatcher._();

  static const _legalForms = {'sa', 'srl', 'ltda', 'sac', 'cia', 'eirl'};

  static const _accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  /// Nombre reducido a lo que lo identifica: "EMBOL S.A." → "embol".
  static String identity(String? name) {
    final plain = (name ?? '')
        .toLowerCase()
        .split('')
        .map((char) => _accents[char] ?? char)
        .join()
        // "S.A." y "S.R.L." son una sola palabra.
        .replaceAll('.', '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return plain
        .split(' ')
        .where((word) => word.isNotEmpty && !_legalForms.contains(word))
        .join(' ');
  }

  /// Clave con la que se recuerda la empresa de un cliente: su código de
  /// DataMET o, si el servicio no lo tiene, su nombre. Null sin cliente.
  static String? clientKey(OpportunityServiceContext service) {
    final code = service.clientCode;
    if (code != null) return 'codigo:$code';
    final name = identity(service.clientDisplay);
    return name.isEmpty ? null : 'nombre:$name';
  }

  /// Textos con los que buscar al cliente en Bitrix24, del más específico
  /// al más amplio: sus nombres sin la forma societaria y su palabra más
  /// larga (por si en Bitrix24 figura con otra puntuación).
  static List<String> queries(OpportunityServiceContext service) {
    final result = <String>[];
    void add(String text) {
      final query = text.trim();
      if (query.length >= 2 &&
          !result.any((q) => q.toLowerCase() == query.toLowerCase())) {
        result.add(query);
      }
    }

    final names = [service.clientName, service.clientLegalName]
        .whereType<String>()
        .toList();
    for (final name in names) {
      add(_withoutLegalForm(name));
    }
    for (final name in names) {
      final words = identity(name).split(' ')
        ..sort((a, b) => b.length.compareTo(a.length));
      if (words.isNotEmpty && words.first.length >= 4) add(words.first);
    }
    return result;
  }

  /// Empresas de [candidates] cuyo nombre es el del cliente.
  static List<BitrixCompany> exactMatches(
    OpportunityServiceContext service,
    Iterable<BitrixCompany> candidates,
  ) {
    final wanted = {
      identity(service.clientName),
      identity(service.clientLegalName),
    }..remove('');
    final matches = <int, BitrixCompany>{};
    for (final company in candidates) {
      if (wanted.contains(identity(company.title))) {
        matches[company.id] = company;
      }
    }
    return matches.values.toList(growable: false);
  }

  static String _withoutLegalForm(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    while (words.length > 1 &&
        _legalForms.contains(
            words.last.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''))) {
      words.removeLast();
    }
    // "Empresa, S.A." deja una coma suelta que rompería la búsqueda.
    return words.join(' ').replaceAll(RegExp(r'[,;.\s]+$'), '');
  }
}
