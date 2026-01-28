class AppVerificacionesInternasConstants {
  // Opciones de plataforma
  static const Map<String, List<String>> platformOptions = {
    'Rectangular': [
      'Rectangular 3 pts - Ind Derecha',
      'Rectangular 3 pts - Ind Izquierda',
      'Rectangular 3 pts - Ind Frontal',
      'Rectangular 3 pts - Ind Atras',
      'Rectangular 5 pts - Ind Derecha',
      'Rectangular 5 pts - Ind Izquierda',
      'Rectangular 5 pts - Ind Frontal',
      'Rectangular 5 pts - Ind Atras'
    ],
    'Circular': [
      'Circular 5 pts - Ind Derecha',
      'Circular 5 pts - Ind Izquierda',
      'Circular 5 pts - Ind Frontal',
      'Circular 5 pts - Ind Atras',
      'Circular 4 pts - Ind Derecha',
      'Circular 4 pts - Ind Izquierda',
      'Circular 4 pts - Ind Frontal',
      'Circular 4 pts - Ind Atras'
    ],
    'Cuadrada': [
      'Cuadrada - Ind Derecha',
      'Cuadrada - Ind Izquierda',
      'Cuadrada - Ind Frontal',
      'Cuadrada - Ind Atras'
    ],
    'Triangular': [
      'Triangular - Ind Izquierda',
      'Triangular - Ind Frontal',
      'Triangular - Ind Atras',
      'Triangular - Ind Derecha'
    ],
    'Báscula de camión': [
      'Caceta de control Atras',
      'Caceta de control Frontal',
      'Caceta de control Izquierda',
      'Caceta de control Derecha'
    ],
  };

  // Imágenes de opciones
  static const Map<String, String> optionImages = {
    'Rectangular 3 pts - Ind Derecha': 'images/Rectangular_3D.png',
    'Rectangular 3 pts - Ind Izquierda': 'images/Rectangular_3I.png',
    'Rectangular 3 pts - Ind Frontal': 'images/Rectangular_3F.png',
    'Rectangular 3 pts - Ind Atras': 'images/Rectangular_3A.png',
    'Rectangular 5 pts - Ind Derecha': 'images/Rectangular_5D.png',
    'Rectangular 5 pts - Ind Izquierda': 'images/Rectangular_5I.png',
    'Rectangular 5 pts - Ind Frontal': 'images/Rectangular_5F.png',
    'Rectangular 5 pts - Ind Atras': 'images/Rectangular_5A.png',
    'Circular 5 pts - Ind Derecha': 'images/Circular_5D.png',
    'Circular 5 pts - Ind Izquierda': 'images/Circular_5I.png',
    'Circular 5 pts - Ind Frontal': 'images/Circular_5F.png',
    'Circular 5 pts - Ind Atras': 'images/Circular_5A.png',
    'Circular 4 pts - Ind Derecha': 'images/Circular_4D.png',
    'Circular 4 pts - Ind Izquierda': 'images/Circular_4I.png',
    'Circular 4 pts - Ind Frontal': 'images/Circular_4F.png',
    'Circular 4 pts - Ind Atras': 'images/Circular_4A.png',
    'Cuadrada - Ind Derecha': 'images/Cuadrada_D.png',
    'Cuadrada - Ind Izquierda': 'images/Cuadrada_I.png',
    'Cuadrada - Ind Frontal': 'images/Cuadrada_F.png',
    'Cuadrada - Ind Atras': 'images/Cuadrada_A.png',
    'Triangular - Ind Derecha': 'images/Triangular_D.png',
    'Triangular - Ind Izquierda': 'images/Triangular_I.png',
    'Triangular - Ind Frontal': 'images/Triangular_F.png',
    'Triangular - Ind Atras': 'images/Triangular_A.png',
    'Caceta de control Atras': 'images/Caceta_A.png',
    'Caceta de control Frontal': 'images/Caceta_F.png',
    'Caceta de control Izquierda': 'images/Caceta_I.png',
    'Caceta de control Derecha': 'images/Caceta_D.png',
  };

  // Campos de estado general
  static const List<String> lozasYFundacionesCampos = [
    'Losas de aproximación (daños o grietas)',
    'Fundaciones (daños o grietas)',
  ];

  static const List<String> limpiezaYDrenajeCampos = [
    'Limpieza de perímetro de balanza',
    'Fosa libre de humedad',
    'Drenaje libre',
    'Bomba de sumidero funcional',
  ];

  static const List<String> chequeoCampos = [
    'Corrosión',
    'Puente de pesaje (grietas)',
    'Tapas superiores y pernos',
    'Desgaste y estrés',
    'Limpieza por debajo del puente',
    'Estado rieles laterales',
    'Limitadores Longitudinales',
    'Limitadores Transversales',
  ];

  static const List<String> verificacionesElectricasCampos = [
    'Cable home run',
    'Cables de celdas de carga',
    'Conexión entre celda de carga y cable',
    'Conectores de celdas de carga',
    'Conector de terminación',
    'Caja de unión o Sumadora',
  ];

  static const List<String> proteccionRayosCampos = [
    'Sistema de Protección contra Rayos',
    'Conexión de Malla de Tierra',
    'Tensión entre neutro y tierra adecuada',
    'Estado strike shield',
  ];

  static const List<String> verificacionesCeldasCampos = [
    'Limpieza e inspección conectores',
    'Limpieza e inspección de superficies de acoplamiento de la estructura',
    'Limpieza e inspección de bearing cups',
    'Limpieza e inspección de celdas de carga',
    'Lubricacion celdas de carga',
    'Lubricación bearing cups',
    'Protector de goma para celdas',
  ];

  static const List<String> terminalCampos = [
    'Carcasa',
    'Voltaje pila de Boton',
    'Estado del teclado',
    'Estado del display',
    'Registros Predictivo solo PDX',
    'Alertas de servicio MT',
    'Estado prensacables:',
    'Comunicación con PC',
  ];

  static const List<String> calibracionCampos = [
    'Balanza apta para Verificación Dentro tolerancias NB23001',
  ];

  // NUEVOS CAMPOS - Inspección Visual Simplificada
  static const List<String> inspeccionVisualCampos = [
    'Espaciamiento topes longitudinales',
    'Espaciamiento topes frontales',
    'Limpieza del puente de pesaje',
    'Limpieza debajo del puente',
  ];

  //Lista completa de todos los campos (para inicialización)
  static List<String> getAllCampos() {
    return [
      ...inspeccionVisualCampos,
    ];
  }
}
