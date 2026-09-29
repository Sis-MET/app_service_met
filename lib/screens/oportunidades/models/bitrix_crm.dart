/// Empresa de Bitrix24 (`crm.item.list`, entityTypeId 4). Se guarda su [id]:
/// el nombre solo sirve de referencia visual.
class BitrixCompany {
  final int id;
  final String title;
  final String? companyTypeId;
  final String? industry;

  const BitrixCompany({
    required this.id,
    required this.title,
    this.companyTypeId,
    this.industry,
  });

  factory BitrixCompany.fromJson(Map<String, dynamic> json) => BitrixCompany(
        id: (json['id'] as num).toInt(),
        title: json['title']?.toString() ?? '',
        companyTypeId: json['companyTypeId']?.toString(),
        industry: json['industry']?.toString(),
      );
}

class BitrixCompanySearch {
  final List<BitrixCompany> items;
  final int total;
  final bool truncated;

  const BitrixCompanySearch({
    required this.items,
    required this.total,
    required this.truncated,
  });

  factory BitrixCompanySearch.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => BitrixCompany.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return BitrixCompanySearch(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      truncated: json['truncated'] == true,
    );
  }
}

/// Contacto vinculado a una empresa de Bitrix24 (entityTypeId 3).
class BitrixContact {
  final int id;
  final String name;
  final String secondName;
  final String lastName;
  final String post;
  final String phone;
  final String email;
  final bool isPrimary;

  const BitrixContact({
    required this.id,
    this.name = '',
    this.secondName = '',
    this.lastName = '',
    this.post = '',
    this.phone = '',
    this.email = '',
    this.isPrimary = false,
  });

  factory BitrixContact.fromJson(Map<String, dynamic> json) => BitrixContact(
        id: (json['id'] as num).toInt(),
        name: json['name']?.toString() ?? '',
        secondName: json['secondName']?.toString() ?? '',
        lastName: json['lastName']?.toString() ?? '',
        post: json['post']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        isPrimary: json['isPrimary'] == true,
      );

  String get fullName {
    final text = [name, secondName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return text.isEmpty ? 'Contacto #$id' : text;
  }

  /// Cargo, teléfono y correo disponibles, en una línea.
  String get details =>
      [post, phone, email].where((part) => part.trim().isNotEmpty).join(' · ');
}

/// Opciones del formulario que dependen de la configuración de Bitrix24
/// (`GET /api/bitrix/form-options`). Se guardan en el teléfono para
/// ofrecerlas también sin conexión.
class BitrixFormOptions {
  /// Opciones de "Ciudad del prospecto"; vacía si no está configurada.
  final List<String> cities;
  final bool cityRequired;

  const BitrixFormOptions({this.cities = const [], this.cityRequired = false});

  factory BitrixFormOptions.fromJson(Map<String, dynamic> json) {
    final city = json['city'] is Map
        ? Map<String, dynamic>.from(json['city'] as Map)
        : const <String, dynamic>{};
    return BitrixFormOptions(
      cities: (city['options'] as List? ?? const [])
          .map((option) => option.toString().trim())
          .where((option) => option.isNotEmpty)
          .toList(growable: false),
      cityRequired: city['required'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'city': {'required': cityRequired, 'options': cities},
      };
}

/// Respuesta de `POST /api/bitrix/opportunities`.
class OpportunityCreated {
  final int leadId;
  final bool duplicate;
  final String message;

  const OpportunityCreated({
    required this.leadId,
    required this.duplicate,
    required this.message,
  });
}
