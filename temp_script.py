import re

balanza_path = r'c:\Users\jhona\ServiceMET\lib\screens\calibracion\steps\balanza_step.dart'
condiciones_path = r'c:\Users\jhona\ServiceMET\lib\screens\calibracion\steps\condiciones_finales_step.dart'

with open(balanza_path, 'r', encoding='utf-8') as f:
    balanza_code = f.read()

with open(condiciones_path, 'r', encoding='utf-8') as f:
    condiciones_code = f.read()

# 1. Extracción de métodos de balanza_step.dart
equipamientos_methods = re.search(r'(  Widget _buildEquipamientosSection.*?\n  Widget _buildFotosSection)', balanza_code, re.DOTALL).group(1)
equipamientos_methods = equipamientos_methods.replace('  Widget _buildFotosSection', '')

equipos_helpers = re.search(r'(  bool _isPesaTipo.*?\n  Widget _infoSearchRow)', balanza_code, re.DOTALL).group(1)
equipos_helpers = equipos_helpers.replace('  Widget _infoSearchRow', '')

cert_status_class = re.search(r'(class _CertStatus \{.*?\})', balanza_code, re.DOTALL).group(1)

selected_equipo_tile = re.search(r'(  Widget _selectedEquipoTile.*?\}\n\n)', balanza_code, re.DOTALL).group(1)
empty_equipos_hint = re.search(r'(  Widget _emptyEquiposHint.*?\}\n\n)', balanza_code, re.DOTALL).group(1)

# 2. Modificaciones en balanza_step.dart
balanza_code = re.sub(r'  List<Map<String, dynamic>> _equipamientos = \[\];\n', '', balanza_code)
balanza_code = re.sub(r'  List<EquipoInfo> _selectedPesas = \[\];\n', '', balanza_code)
balanza_code = re.sub(r'  List<EquipoInfo> _selectedMedicion = \[\];\n', '', balanza_code)
balanza_code = re.sub(r'  bool _isLoadingEquipamientos = false;\n', '', balanza_code)

balanza_code = re.sub(r'      _loadEquipamientos\(\);\n', '', balanza_code)
balanza_code = re.sub(r'  Future<void> _loadEquipamientos\(\) async \{.*?\n  \}\n\n', '', balanza_code, flags=re.DOTALL)
balanza_code = re.sub(r'    _initEquiposFromSession\(session\.equipos\);\n', '', balanza_code)
balanza_code = re.sub(r'  void _initEquiposFromSession\(List<EquipoInfo> equipos\) \{.*?\n  \}\n\n', '', balanza_code, flags=re.DOTALL)
balanza_code = re.sub(r'    provider\.updateEquipos\(\[\.\.\._selectedPesas, \.\.\._selectedMedicion\]\);\n', '', balanza_code)
balanza_code = re.sub(r'                const SizedBox\(height: 24\),\n                _buildEquipamientosSection\(provider, isDark\),\n', '', balanza_code)

balanza_code = balanza_code.replace(equipamientos_methods, '')
balanza_code = balanza_code.replace(empty_equipos_hint, '')
balanza_code = balanza_code.replace(selected_equipo_tile, '')
balanza_code = balanza_code.replace(equipos_helpers, '')
balanza_code = balanza_code.replace(cert_status_class, '')

# 3. Modificaciones en condiciones_finales_step.dart
condiciones_code = condiciones_code.replace(
    "import 'package:provider/provider.dart';",
    "import 'package:provider/provider.dart';\nimport 'package:flutter/services.dart';"
)
condiciones_code = condiciones_code.replace(
    "import 'package:service_met/repositories/calibration_repository.dart';",
    "import 'package:service_met/repositories/calibration_repository.dart';\nimport 'package:service_met/utils/top_alert.dart';"
)

vars_old = """  List<EquipoInfo> _selectedPesas = [];
  List<Map<String, dynamic>> _availableEquipos = [];"""
vars_new = """  List<EquipoInfo> _selectedPesas = [];
  List<EquipoInfo> _selectedMedicion = [];
  List<Map<String, dynamic>> _equipamientos = [];
  bool _isLoadingEquipamientos = false;"""
condiciones_code = condiciones_code.replace(vars_old, vars_new)

load_old = """  Future<void> _loadEquipos() async {
    final repo = context.read<ServiceSessionProvider>();
    // Need to use the raw repo or via provider. Since we don't expose it directly in Provider,
    // we instantiate it or use it if available.
    final items = await CalibrationRepository().getEquipos();
    if (mounted) {
      setState(() {
        _availableEquipos = items.where((e) {
          final inst = e['instrumento']?.toString().toLowerCase() ?? '';
          final tipo = e['tipo_instrumento']?.toString().toLowerCase() ?? '';
          final desc = e['descripcion']?.toString().toLowerCase() ?? '';
          return inst.contains('pesa') ||
              tipo.contains('pesa') ||
              desc.contains('pesa') ||
              inst.contains('masa') ||
              tipo.contains('masa') ||
              desc.contains('masa');
        }).toList();
      });
    }
  }"""

load_new = """  Future<void> _loadEquipamientos() async {
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
  }"""
condiciones_code = condiciones_code.replace(load_old, load_new)
condiciones_code = condiciones_code.replace('_loadEquipos();', '_loadEquipamientos();')

init_sess_old = """      _obsCtrl.text = cf.observaciones ?? 'Sin Observaciones';
      _selectedPesas = List.from(session.equipos);
    } else {
      _obsCtrl.text = 'Sin Observaciones';
    }"""
init_sess_new = """      _obsCtrl.text = cf.observaciones ?? 'Sin Observaciones';
    } else {
      _obsCtrl.text = 'Sin Observaciones';
    }
    
    _initEquiposFromSession(session.equipos);"""
condiciones_code = condiciones_code.replace(init_sess_old, init_sess_new)

condiciones_code = condiciones_code.replace("  void _saveToProvider() {", """  void _initEquiposFromSession(List<EquipoInfo> equipos) {
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

  void _saveToProvider() {""")

save_old = "    provider.updateEquipos(_selectedPesas);"
save_new = "    provider.updateEquipos([..._selectedPesas, ..._selectedMedicion]);"
condiciones_code = condiciones_code.replace(save_old, save_new)

build_old = "  Widget build(BuildContext context) {"
build_new = """  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<ServiceSessionProvider>();"""
condiciones_code = condiciones_code.replace(build_old, build_new)

ui_old = """          _header('4. Selección de Pesas Patrón'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showPesasDialog,
              icon: const Icon(Icons.fitness_center),
              label: Text('Seleccionar Pesas (${_selectedPesas.length}/5)'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF365666),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 12),
          ..._selectedPesas.map((p) => Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.check_circle, color: Color(0xFF365666)),
                  title: Text(p.codInstrumento ?? 'Sin cod'),
                  subtitle: Text('Cant: ${p.cantidad}'),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() => _selectedPesas.remove(p));
                        _saveToProvider();
                      }),
                ),
              )),
          const SizedBox(height: 24),"""
ui_new = """          _buildEquipamientosSection(provider, isDark),
          const SizedBox(height: 24),"""
condiciones_code = condiciones_code.replace(ui_old, ui_new)

show_pesas_old = re.search(r'  void _showPesasDialog\(\) \{.*?\n  \}\n', condiciones_code, re.DOTALL).group(0)
condiciones_code = condiciones_code.replace(show_pesas_old, '')

condiciones_code = condiciones_code.rstrip()
if condiciones_code.endswith('}'):
    condiciones_code = condiciones_code[:-1]

condiciones_code += "\n" + equipamientos_methods + empty_equipos_hint + selected_equipo_tile + equipos_helpers + "}\n\n" + cert_status_class + "\n"

with open(balanza_path, 'w', encoding='utf-8') as f:
    f.write(balanza_code)

with open(condiciones_path, 'w', encoding='utf-8') as f:
    f.write(condiciones_code)

print('Done')
