import 'dart:io';

void main() {
  final balanzaPath = r'c:\Users\jhona\ServiceMET\lib\screens\calibracion\steps\balanza_step.dart';
  final condicionesPath = r'c:\Users\jhona\ServiceMET\lib\screens\calibracion\steps\condiciones_finales_step.dart';

  var balanzaCode = File(balanzaPath).readAsStringSync();
  var condicionesCode = File(condicionesPath).readAsStringSync();

  // 1. Extracción de métodos de balanza_step.dart
  final equipamientosMethodsRegex = RegExp(r'(  Widget _buildEquipamientosSection.*?\n  Widget _buildFotosSection)', dotAll: true);
  var equipamientosMethods = equipamientosMethodsRegex.firstMatch(balanzaCode)?.group(1) ?? '';
  equipamientosMethods = equipamientosMethods.replaceAll('  Widget _buildFotosSection', '');

  final equiposHelpersRegex = RegExp(r'(  bool _isPesaTipo.*?\n  Widget _infoSearchRow)', dotAll: true);
  var equiposHelpers = equiposHelpersRegex.firstMatch(balanzaCode)?.group(1) ?? '';
  equiposHelpers = equiposHelpers.replaceAll('  Widget _infoSearchRow', '');

  final certStatusClassRegex = RegExp(r'(class _CertStatus \{.*?\})', dotAll: true);
  var certStatusClass = certStatusClassRegex.firstMatch(balanzaCode)?.group(1) ?? '';

  final selectedEquipoTileRegex = RegExp(r'(  Widget _selectedEquipoTile.*?\}\n\n)', dotAll: true);
  var selectedEquipoTileMatch = selectedEquipoTileRegex.firstMatch(balanzaCode);
  var selectedEquipoTile = '';
  if (selectedEquipoTileMatch != null) {
      selectedEquipoTile = selectedEquipoTileMatch.group(1) ?? '';
  }

  final emptyEquiposHintRegex = RegExp(r'(  Widget _emptyEquiposHint.*?\}\n\n)', dotAll: true);
  var emptyEquiposHintMatch = emptyEquiposHintRegex.firstMatch(balanzaCode);
  var emptyEquiposHint = '';
  if (emptyEquiposHintMatch != null) {
      emptyEquiposHint = emptyEquiposHintMatch.group(1) ?? '';
  }

  // 2. Modificaciones en balanza_step.dart
  balanzaCode = balanzaCode.replaceAll('  List<Map<String, dynamic>> _equipamientos = [];\n', '');
  balanzaCode = balanzaCode.replaceAll('  List<EquipoInfo> _selectedPesas = [];\n', '');
  balanzaCode = balanzaCode.replaceAll('  List<EquipoInfo> _selectedMedicion = [];\n', '');
  balanzaCode = balanzaCode.replaceAll('  bool _isLoadingEquipamientos = false;\n', '');

  balanzaCode = balanzaCode.replaceAll('      _loadEquipamientos();\n', '');
  balanzaCode = balanzaCode.replaceFirst(RegExp(r'  Future<void> _loadEquipamientos\(\) async \{.*?\n  \}\n\n', dotAll: true), '');
  balanzaCode = balanzaCode.replaceAll('    _initEquiposFromSession(session.equipos);\n', '');
  balanzaCode = balanzaCode.replaceFirst(RegExp(r'  void _initEquiposFromSession\(List<EquipoInfo> equipos\) \{.*?\n  \}\n\n', dotAll: true), '');
  balanzaCode = balanzaCode.replaceAll('    provider.updateEquipos([..._selectedPesas, ..._selectedMedicion]);\n', '');
  balanzaCode = balanzaCode.replaceAll('                const SizedBox(height: 24),\n                _buildEquipamientosSection(provider, isDark),\n', '');

  if (equipamientosMethods.isNotEmpty) balanzaCode = balanzaCode.replaceAll(equipamientosMethods, '');
  if (emptyEquiposHint.isNotEmpty) balanzaCode = balanzaCode.replaceAll(emptyEquiposHint, '');
  if (selectedEquipoTile.isNotEmpty) balanzaCode = balanzaCode.replaceAll(selectedEquipoTile, '');
  if (equiposHelpers.isNotEmpty) balanzaCode = balanzaCode.replaceAll(equiposHelpers, '');
  if (certStatusClass.isNotEmpty) balanzaCode = balanzaCode.replaceAll(certStatusClass, '');

  // 3. Modificaciones en condiciones_finales_step.dart
  condicionesCode = condicionesCode.trimRight();
  if (condicionesCode.endsWith('}')) {
      condicionesCode = condicionesCode.substring(0, condicionesCode.length - 1);
  }

  condicionesCode += '\n' + equipamientosMethods + emptyEquiposHint + selectedEquipoTile + equiposHelpers + '}\n\n' + certStatusClass + '\n';

  File(balanzaPath).writeAsStringSync(balanzaCode);
  File(condicionesPath).writeAsStringSync(condicionesCode);

  print('Done');
}
