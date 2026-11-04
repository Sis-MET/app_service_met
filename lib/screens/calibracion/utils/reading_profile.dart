import 'needle_reader.dart';

/// Cómo se pasa el color del cuadro a grises antes de buscar los dígitos.
enum IndicatorColor {
  /// La luminancia, como hasta ahora: sirve para LCD y la mayoría de los
  /// displays.
  luma('Normal'),

  /// El canal más brillante de cada píxel: un LED de cualquier color queda
  /// tan claro como uno blanco, y el fondo oscuro sigue oscuro.
  brillo('Brillo'),

  /// Lo rojo: separa el valor del proceso (PV, casi siempre rojo) del valor
  /// programado (SV, casi siempre verde) en los controladores de muflas.
  rojo('Rojo'),

  /// Lo verde: el SV de los controladores o displays verdes.
  verde('Verde');

  const IndicatorColor(this.etiqueta);

  final String etiqueta;

  static IndicatorColor fromName(Object? name) => IndicatorColor.values
      .firstWhere((color) => color.name == name, orElse: () => luma);
}

/// Con qué se lee el display.
enum IndicatorEngine {
  /// Primero como display de 7 segmentos y, si no lo es, con el OCR.
  auto,

  /// Solo 7 segmentos: un OCR de texto no compite con la lectura.
  segmentos,

  /// Solo el OCR de texto: pantallas gráficas, matriz de puntos, TFT.
  texto,

  /// La aguja de un indicador analógico, con la escala que marcó el técnico
  /// ([ReadingProfile.dial]).
  aguja;

  static IndicatorEngine fromName(Object? name) => IndicatorEngine.values
      .firstWhere((engine) => engine.name == name, orElse: () => auto);
}

/// La manera de leer un display en particular. El lector empieza en
/// [automatico]; «Verificar lectura» busca el perfil con el que el display
/// da el valor que el técnico ve y lo fija para ese canal.
class ReadingProfile {
  const ReadingProfile({
    this.engine = IndicatorEngine.auto,
    this.color = IndicatorColor.luma,
    this.brightInk,
    this.scale = 0,
    this.bridge = false,
    this.units = false,
    this.dial,
  });

  /// Un indicador de aguja leído con la escala [dial].
  const ReadingProfile.aguja(DialScale this.dial)
      : engine = IndicatorEngine.aguja,
        color = IndicatorColor.luma,
        brightInk = null,
        scale = 0,
        bridge = false,
        units = false;

  static const automatico = ReadingProfile();

  /// Como [automatico], pero el display puede mostrar la unidad (`°C`,
  /// `F`) junto a los dígitos y mensajes sin valor (`----`, `OPEn`, `Err`).
  static const temperatura = ReadingProfile(units: true);

  final IndicatorEngine engine;
  final IndicatorColor color;

  /// Dígitos claros sobre fondo oscuro (LED, VFD, pantallas con luz) o al
  /// revés (LCD). Null: se prueban los dos.
  final bool? brightInk;

  /// Cuánto se amplía la franja antes del OCR de texto: 1 o 2. Con 0 se
  /// decide por el tamaño de la franja.
  final int scale;

  /// Une los segmentos separados antes del OCR de texto: el OCR aprendió
  /// letras continuas y en algunos displays ve cada segmento por separado.
  final bool bridge;

  /// La unidad junto a los dígitos se descarta y los mensajes sin valor se
  /// informan como tales (displays de temperatura).
  final bool units;

  /// La escala de un indicador de aguja: el eje y las marcas con su valor.
  final DialScale? dial;

  ReadingProfile copyWith({
    IndicatorEngine? engine,
    IndicatorColor? color,
    bool? brightInk,
    bool clearBrightInk = false,
    int? scale,
    bool? bridge,
    bool? units,
    DialScale? dial,
  }) =>
      ReadingProfile(
        engine: engine ?? this.engine,
        color: color ?? this.color,
        brightInk: clearBrightInk ? null : (brightInk ?? this.brightInk),
        scale: scale ?? this.scale,
        bridge: bridge ?? this.bridge,
        units: units ?? this.units,
        dial: dial ?? this.dial,
      );

  Map<String, Object?> toJson() => {
        'engine': engine.name,
        'color': color.name,
        if (brightInk != null) 'brightInk': brightInk,
        'scale': scale,
        'bridge': bridge,
        'units': units,
        if (dial != null) 'dial': dial!.toJson(),
      };

  factory ReadingProfile.fromJson(Map<String, Object?> json) => ReadingProfile(
        engine: IndicatorEngine.fromName(json['engine']),
        color: IndicatorColor.fromName(json['color']),
        brightInk: json['brightInk'] is bool ? json['brightInk'] as bool : null,
        scale: json['scale'] is int ? json['scale'] as int : 0,
        bridge: json['bridge'] == true,
        units: json['units'] == true,
        dial: DialScale.fromJson(json['dial']),
      );

  /// Los perfiles que «Verificar lectura» prueba, de los más baratos y
  /// confiables (7 segmentos) a los más caros (OCR con variantes). [units]
  /// se conserva en todos.
  static List<ReadingProfile> candidatos({
    required bool units,
    bool withColor = true,
  }) {
    final colors =
        withColor ? IndicatorColor.values : const [IndicatorColor.luma];
    return [
      for (final color in colors)
        for (final bright in const [true, false])
          ReadingProfile(
            engine: IndicatorEngine.segmentos,
            color: color,
            brightInk: bright,
            units: units,
          ),
      for (final color in withColor
          ? const [IndicatorColor.luma, IndicatorColor.brillo]
          : const [IndicatorColor.luma])
        for (final scale in const [1, 2])
          for (final bridge in const [false, true])
            ReadingProfile(
              engine: IndicatorEngine.texto,
              color: color,
              scale: scale,
              bridge: bridge,
              units: units,
            ),
    ];
  }

  /// Para mostrarle al técnico con qué se está leyendo.
  String get descripcion {
    final motor = switch (engine) {
      IndicatorEngine.auto => 'Automático',
      IndicatorEngine.segmentos => '7 segmentos',
      IndicatorEngine.texto => 'Texto',
      IndicatorEngine.aguja => 'Aguja',
    };
    final partes = [
      motor,
      if (color != IndicatorColor.luma) 'color ${color.etiqueta.toLowerCase()}',
      if (brightInk == true) 'dígitos claros',
      if (brightInk == false) 'dígitos oscuros',
      if (scale == 2) 'ampliado',
      if (bridge) 'segmentos unidos',
    ];
    return partes.join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingProfile &&
      other.engine == engine &&
      other.color == color &&
      other.brightInk == brightInk &&
      other.scale == scale &&
      other.bridge == bridge &&
      other.units == units &&
      other.dial == dial;

  @override
  int get hashCode =>
      Object.hash(engine, color, brightInk, scale, bridge, units, dial);
}
