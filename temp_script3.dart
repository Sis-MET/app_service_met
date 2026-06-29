import 'dart:io';

String extractBetween(String code, String startStr, String endStr) {
  int start = code.indexOf(startStr);
  if (start == -1) return '';
  int end = code.indexOf(endStr, start);
  if (end == -1) return '';
  end += endStr.length;
  return code.substring(start, end);
}

void main() {
  final balanzaPath =
      r'c:\Users\jhona\ServiceMET\lib\screens\calibracion\steps\balanza_step.dart';
  final condicionesPath =
      r'c:\Users\jhona\ServiceMET\lib\screens\calibracion\steps\condiciones_finales_step.dart';

  var balanzaCode = File(balanzaPath).readAsStringSync();
  var condicionesCode = File(condicionesPath).readAsStringSync();

  // 1. Blocks to extract from balanza_step.dart

  // _buildEquipamientosSection
  final buildEqStart = '  Widget _buildEquipamientosSection(';
  final buildEqEnd = '    ).animate(delay: 550.ms).fadeIn();\n  }';
  var buildEqBlock = extractBetween(balanzaCode, buildEqStart, buildEqEnd);

  // _emptyEquiposHint
  final emptyHintStart = '  Widget _emptyEquiposHint(';
  final emptyHintEnd = '      ),\n    );\n  }';
  // wait, let's just find the closing brace by counting braces
  String getBlockWithBraces(String code, String startStr) {
    int idx = code.indexOf(startStr);
    if (idx == -1) return '';
    int braceCount = 0;
    bool started = false;
    for (int i = idx; i < code.length; i++) {
      if (code[i] == '{') {
        braceCount++;
        started = true;
      } else if (code[i] == '}') {
        braceCount--;
        if (started && braceCount == 0) {
          return code.substring(idx, i + 1);
        }
      }
    }
    return '';
  }

  var emptyHintBlock = getBlockWithBraces(balanzaCode, emptyHintStart);
  var selectedTileBlock =
      getBlockWithBraces(balanzaCode, '  Widget _selectedEquipoTile(');
  var isPesaTipoBlock = getBlockWithBraces(balanzaCode, '  bool _isPesaTipo(');
  var instrumentTypeBlock =
      getBlockWithBraces(balanzaCode, '  String _instrumentType(');
  var instrumentSectionBlock =
      getBlockWithBraces(balanzaCode, '  String _instrumentSection(');
  var buildGroupedListBlock =
      getBlockWithBraces(balanzaCode, '  Widget _buildEquiposGroupedList(');
  var buildEquipoCardBlock =
      getBlockWithBraces(balanzaCode, '  Widget _buildEquipoCard(');
  var certStatusBlock =
      getBlockWithBraces(balanzaCode, '  _CertStatus _certStatus(');
  var equipoFromMapBlock =
      getBlockWithBraces(balanzaCode, '  EquipoInfo _equipoFromMap(');
  var saveEquipoSelectionBlock =
      getBlockWithBraces(balanzaCode, '  void _saveEquipoSelection(');
  var editCantidadBlock =
      getBlockWithBraces(balanzaCode, '  Future<void> _editCantidad(');
  var showEquipamientosDialogBlock =
      getBlockWithBraces(balanzaCode, '  void _showEquipamientosDialog({');
  var certStatusClassBlock =
      getBlockWithBraces(balanzaCode, 'class _CertStatus {');

  // Concatenate methods
  var methodsToAdd = [
    buildEqBlock,
    emptyHintBlock,
    selectedTileBlock,
    editCantidadBlock,
    showEquipamientosDialogBlock,
    isPesaTipoBlock,
    instrumentTypeBlock,
    instrumentSectionBlock,
    buildGroupedListBlock,
    buildEquipoCardBlock,
    certStatusBlock,
    equipoFromMapBlock,
    saveEquipoSelectionBlock,
  ].where((s) => s.isNotEmpty).join('\n\n');

  // Remove variables from balanza
  balanzaCode = balanzaCode.replaceAll(
      '  List<Map<String, dynamic>> _equipamientos = [];\n', '');
  balanzaCode =
      balanzaCode.replaceAll('  List<EquipoInfo> _selectedPesas = [];\n', '');
  balanzaCode = balanzaCode.replaceAll(
      '  List<EquipoInfo> _selectedMedicion = [];\n', '');
  balanzaCode =
      balanzaCode.replaceAll('  bool _isLoadingEquipamientos = false;\n', '');

  // Remove init calls
  balanzaCode = balanzaCode.replaceAll('      _loadEquipamientos();\n', '');
  balanzaCode = balanzaCode.replaceAll(
      '    _initEquiposFromSession(session.equipos);\n', '');
  var initBlock =
      getBlockWithBraces(balanzaCode, '  void _initEquiposFromSession(');
  if (initBlock.isNotEmpty) balanzaCode = balanzaCode.replaceAll(initBlock, '');

  var loadEqBlock =
      getBlockWithBraces(balanzaCode, '  Future<void> _loadEquipamientos()');
  if (loadEqBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(loadEqBlock, '');
  }

  balanzaCode = balanzaCode.replaceAll(
      '    provider.updateEquipos([..._selectedPesas, ..._selectedMedicion]);\n',
      '');
  balanzaCode = balanzaCode.replaceAll(
      '                const SizedBox(height: 24),\n                _buildEquipamientosSection(provider, isDark),\n',
      '');

  // Remove extracted blocks from balanza
  if (buildEqBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(buildEqBlock, '');
  }
  if (emptyHintBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(emptyHintBlock, '');
  }
  if (selectedTileBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(selectedTileBlock, '');
  }
  if (isPesaTipoBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(isPesaTipoBlock, '');
  }
  if (instrumentTypeBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(instrumentTypeBlock, '');
  }
  if (instrumentSectionBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(instrumentSectionBlock, '');
  }
  if (buildGroupedListBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(buildGroupedListBlock, '');
  }
  if (buildEquipoCardBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(buildEquipoCardBlock, '');
  }
  if (certStatusBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(certStatusBlock, '');
  }
  if (equipoFromMapBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(equipoFromMapBlock, '');
  }
  if (saveEquipoSelectionBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(saveEquipoSelectionBlock, '');
  }
  if (editCantidadBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(editCantidadBlock, '');
  }
  if (showEquipamientosDialogBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(showEquipamientosDialogBlock, '');
  }
  if (certStatusClassBlock.isNotEmpty) {
    balanzaCode = balanzaCode.replaceAll(certStatusClassBlock, '');
  }

  // Modify condiciones
  condicionesCode = condicionesCode.replaceFirst(
      "import 'package:provider/provider.dart';",
      "import 'package:provider/provider.dart';\nimport 'package:flutter/services.dart';");
  condicionesCode = condicionesCode.replaceFirst(
      "import 'package:service_met/repositories/calibration_repository.dart';",
      "import 'package:service_met/repositories/calibration_repository.dart';\nimport 'package:service_met/utils/top_alert.dart';");

  final varsOld =
      "  List<EquipoInfo> _selectedPesas = [];\n  List<Map<String, dynamic>> _availableEquipos = [];";
  final varsNew =
      "  List<EquipoInfo> _selectedPesas = [];\n  List<EquipoInfo> _selectedMedicion = [];\n  List<Map<String, dynamic>> _equipamientos = [];\n  bool _isLoadingEquipamientos = false;";
  condicionesCode = condicionesCode.replaceFirst(varsOld, varsNew);

  var oldLoadEquipos =
      getBlockWithBraces(condicionesCode, '  Future<void> _loadEquipos()');
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
    condicionesCode = condicionesCode.replaceFirst(
        '_loadEquipos();', '_loadEquipamientos();');
  }

  final initSessOld =
      '''      _obsCtrl.text = cf.observaciones ?? 'Sin Observaciones';
      _selectedPesas = List.from(session.equipos);
    } else {
      _obsCtrl.text = 'Sin Observaciones';
    }''';
  final initSessNew =
      '''      _obsCtrl.text = cf.observaciones ?? 'Sin Observaciones';
    } else {
      _obsCtrl.text = 'Sin Observaciones';
    }
    
    _initEquiposFromSession(session.equipos);''';
  condicionesCode = condicionesCode.replaceFirst(initSessOld, initSessNew);

  final initEqNew =
      '''  void _initEquiposFromSession(List<EquipoInfo> equipos) {
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
  condicionesCode =
      condicionesCode.replaceFirst("  void _saveToProvider() {", initEqNew);

  final saveOld = "    provider.updateEquipos(_selectedPesas);";
  final saveNew =
      "    provider.updateEquipos([..._selectedPesas, ..._selectedMedicion]);";
  condicionesCode = condicionesCode.replaceFirst(saveOld, saveNew);

  final buildOld = "  Widget build(BuildContext context) {";
  final buildNew = '''  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<ServiceSessionProvider>();''';
  condicionesCode = condicionesCode.replaceFirst(buildOld, buildNew);

  // replace the specific UI elements in condiciones
  int uiStart = condicionesCode
      .indexOf("          _header('4. Selección de Pesas Patrón'),");
  int uiEnd = condicionesCode
      .indexOf("          _header('5. Sticker de Calibrado (Referencial)'),");
  if (uiStart != -1 && uiEnd != -1) {
    String uiOld = condicionesCode.substring(uiStart, uiEnd);
    String uiNew =
        "          _buildEquipamientosSection(provider, isDark),\n          const SizedBox(height: 24),\n";
    condicionesCode = condicionesCode.replaceFirst(uiOld, uiNew);
  }

  var oldShowPesas =
      getBlockWithBraces(condicionesCode, '  void _showPesasDialog()');
  if (oldShowPesas.isNotEmpty) {
    condicionesCode = condicionesCode.replaceFirst(oldShowPesas, '');
  }

  condicionesCode = condicionesCode.trimRight();
  if (condicionesCode.endsWith('}')) {
    condicionesCode = condicionesCode.substring(0, condicionesCode.length - 1);
  }

  condicionesCode += '\n$methodsToAdd\n}\n\n$certStatusClassBlock\n';

  File(balanzaPath).writeAsStringSync(balanzaCode);
  File(condicionesPath).writeAsStringSync(condicionesCode);

  print('Done perfectly');
}
