import 'dart:io';

String extractBlock(String code, String declaration) {
  int startIndex = code.indexOf(declaration);
  if (startIndex == -1) return '';
  int braceCount = 0;
  bool inBlock = false;
  int endIndex = -1;

  for (int i = startIndex; i < code.length; i++) {
    if (code[i] == '{') {
      braceCount++;
      inBlock = true;
    } else if (code[i] == '}') {
      braceCount--;
      if (inBlock && braceCount == 0) {
        endIndex = i + 1;
        break;
      }
    }
  }

  if (endIndex != -1) {
    return code.substring(startIndex, endIndex);
  }
  return '';
}

void main() {
  final balanzaPath = r'c:\Users\jhona\ServiceMET\lib\screens\calibracion\steps\balanza_step.dart';
  final condicionesPath = r'c:\Users\jhona\ServiceMET\lib\screens\calibracion\steps\condiciones_finales_step.dart';

  var balanzaCode = File(balanzaPath).readAsStringSync();
  var condicionesCode = File(condicionesPath).readAsStringSync();

  // 1. Blocks to extract
  final blocksToExtract = [
    '  Widget _buildEquipamientosSection(',
    '  Widget _emptyEquiposHint(',
    '  Widget _selectedEquipoTile(',
    '  Future<void> _editCantidad(',
    '  void _showEquipamientosDialog({',
    '  bool _isPesaTipo(',
    '  String _instrumentType(',
    '  String _instrumentSection(',
    '  Widget _buildEquiposGroupedList(',
    '  Widget _buildEquipoCard(',
    '  _CertStatus _certStatus(',
    '  EquipoInfo _equipoFromMap(',
    '  void _saveEquipoSelection(',
  ];

  String extractedMethods = '';
  for (var decl in blocksToExtract) {
    var block = extractBlock(balanzaCode, decl);
    if (block.isNotEmpty) {
      extractedMethods += '\n' + block + '\n';
      balanzaCode = balanzaCode.replaceFirst(block, '');
    } else {
        print('Warning: could not extract \$decl');
    }
  }

  // extract _CertStatus class
  final certStatusClass = extractBlock(balanzaCode, 'class _CertStatus {');
  if (certStatusClass.isNotEmpty) {
    balanzaCode = balanzaCode.replaceFirst(certStatusClass, '');
  }

  // Remove state variables
  balanzaCode = balanzaCode.replaceAll('  List<Map<String, dynamic>> _equipamientos = [];\n', '');
  balanzaCode = balanzaCode.replaceAll('  List<EquipoInfo> _selectedPesas = [];\n', '');
  balanzaCode = balanzaCode.replaceAll('  List<EquipoInfo> _selectedMedicion = [];\n', '');
  balanzaCode = balanzaCode.replaceAll('  bool _isLoadingEquipamientos = false;\n', '');

  // Remove calls from initState
  balanzaCode = balanzaCode.replaceAll('      _loadEquipamientos();\n', '');

  // Remove _loadEquipamientos
  var loadEq = extractBlock(balanzaCode, '  Future<void> _loadEquipamientos() async {');
  if (loadEq.isNotEmpty) balanzaCode = balanzaCode.replaceFirst(loadEq, '');

  // Remove _initEquiposFromSession call & method
  balanzaCode = balanzaCode.replaceAll('    _initEquiposFromSession(session.equipos);\n', '');
  var initEq = extractBlock(balanzaCode, '  void _initEquiposFromSession(List<EquipoInfo> equipos) {');
  if (initEq.isNotEmpty) balanzaCode = balanzaCode.replaceFirst(initEq, '');

  // Remove from _saveToProvider
  balanzaCode = balanzaCode.replaceAll('    provider.updateEquipos([..._selectedPesas, ..._selectedMedicion]);\n', '');
  balanzaCode = balanzaCode.replaceAll('    provider.updateEquipos(_selectedPesas);\n', '');

  // Remove call from build form
  balanzaCode = balanzaCode.replaceAll('                const SizedBox(height: 24),\n                _buildEquipamientosSection(provider, isDark),\n', '');


  // 3. Modificaciones en condiciones_finales_step.dart
  condicionesCode = condicionesCode.replaceFirst(
      "import 'package:provider/provider.dart';",
      "import 'package:provider/provider.dart';\nimport 'package:flutter/services.dart';"
  );
  condicionesCode = condicionesCode.replaceFirst(
      "import 'package:service_met/repositories/calibration_repository.dart';",
      "import 'package:service_met/repositories/calibration_repository.dart';\nimport 'package:service_met/utils/top_alert.dart';"
  );

  final varsOld = "  List<EquipoInfo> _selectedPesas = [];\n  List<Map<String, dynamic>> _availableEquipos = [];";
  final varsNew = "  List<EquipoInfo> _selectedPesas = [];\n  List<EquipoInfo> _selectedMedicion = [];\n  List<Map<String, dynamic>> _equipamientos = [];\n  bool _isLoadingEquipamientos = false;";
  condicionesCode = condicionesCode.replaceFirst(varsOld, varsNew);

  var oldLoadEquipos = extractBlock(condicionesCode, '  Future<void> _loadEquipos() async {');
  final loadNew = '''  Future<void> _loadEquipamientos() async {
    setState(() => _isLoadingEquipamientos = true);
    final result = await CalibrationRepository().getEquipos();
    final mutableResult = List<Map<String, dynamic>>.from(result);
    mutableResult.sort((a, b) {
      final typeA = a['instrumento']?.toString() ?? '';
      final typeB = b['instrumento']?.toString() ?? '';
      final codeA = a['cod_instrumento']?.toString() ?? '';
      final codeB = b['cod_instrumento']?.toString() ?? '';
      final typeCompare = typeA.compareTo(typeB);
      return typeCompare != 0 ? typeCompare : codeA.compareTo(codeB);
    });
    if (!mounted) return;
    setState(() {
      _equipamientos = mutableResult;
      _isLoadingEquipamientos = false;
    });
  }''';
  if (oldLoadEquipos.isNotEmpty) {
      condicionesCode = condicionesCode.replaceFirst(oldLoadEquipos, loadNew);
      condicionesCode = condicionesCode.replaceFirst('_loadEquipos();', '_loadEquipamientos();');
  }

  final initSessOld = '''      _obsCtrl.text = cf.observaciones ?? 'Sin Observaciones';
      _selectedPesas = List.from(session.equipos);
    } else {
      _obsCtrl.text = 'Sin Observaciones';
    }''';
  final initSessNew = '''      _obsCtrl.text = cf.observaciones ?? 'Sin Observaciones';
    } else {
      _obsCtrl.text = 'Sin Observaciones';
    }
    
    _initEquiposFromSession(session.equipos);''';
  condicionesCode = condicionesCode.replaceFirst(initSessOld, initSessNew);

  final initEqNew = '''  void _initEquiposFromSession(List<EquipoInfo> equipos) {
    _selectedPesas = [];
    _selectedMedicion = [];
    for (final equipo in equipos) {
      if (_isPesaTipo(equipo.tipo)) {
        if (_selectedPesas.length < 5) _selectedPesas.add(equipo);
      } else {
        if (_selectedMedicion.length < 2) _selectedMedicion.add(equipo);
      }
    }
  }

  void _saveToProvider() {''';
  condicionesCode = condicionesCode.replaceFirst("  void _saveToProvider() {", initEqNew);

  final saveOld = "    provider.updateEquipos(_selectedPesas);";
  final saveNew = "    provider.updateEquipos([..._selectedPesas, ..._selectedMedicion]);";
  condicionesCode = condicionesCode.replaceFirst(saveOld, saveNew);

  final buildOld = "  Widget build(BuildContext context) {";
  final buildNew = '''  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<ServiceSessionProvider>();''';
  condicionesCode = condicionesCode.replaceFirst(buildOld, buildNew);

  // remove UI section
  int uiStart = condicionesCode.indexOf("          _header('4. Selección de Pesas Patrón'),");
  int uiEnd = condicionesCode.indexOf("          _header('5. Sticker de Calibrado (Referencial)'),");
  if (uiStart != -1 && uiEnd != -1) {
      String uiOld = condicionesCode.substring(uiStart, uiEnd);
      String uiNew = "          _buildEquipamientosSection(provider, isDark),\n          const SizedBox(height: 24),\n";
      condicionesCode = condicionesCode.replaceFirst(uiOld, uiNew);
  }

  var oldShowPesas = extractBlock(condicionesCode, '  void _showPesasDialog() {');
  if (oldShowPesas.isNotEmpty) {
      condicionesCode = condicionesCode.replaceFirst(oldShowPesas, '');
  }

  condicionesCode = condicionesCode.trimRight();
  if (condicionesCode.endsWith('}')) {
      condicionesCode = condicionesCode.substring(0, condicionesCode.length - 1);
  }

  condicionesCode += '\n' + extractedMethods + '}\n\n' + certStatusClass + '\n';

  File(balanzaPath).writeAsStringSync(balanzaCode);
  File(condicionesPath).writeAsStringSync(condicionesCode);

  print('Done parsing');
}
