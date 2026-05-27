import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/home/screens/home_screen.dart';

class ExportacionStep extends StatefulWidget {
  const ExportacionStep({super.key});

  @override
  State<ExportacionStep> createState() => _ExportacionStepState();
}

class _ExportacionStepState extends State<ExportacionStep> {
  String? _emp;
  String? _regla;
  final _indicarCtrl = TextEditingController();
  final _factorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final exp = provider.session?.exportacion;
    if (exp != null) {
      setState(() {
        _emp = exp.emp23001;
        _regla = exp.reglaAceptacion;
        _indicarCtrl.text = exp.indicar ?? '';
        _factorCtrl.text = exp.factorSeguridad ?? '';
      });
    }
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateExportacion(ExportacionData(
      emp23001: _emp,
      indicar: _indicarCtrl.text,
      factorSeguridad: _factorCtrl.text,
      reglaAceptacion: _regla,
    ));
  }

  Future<void> _exportar(ServiceSessionProvider provider) async {
    // Save latest
    _saveToProvider();

    // Auto save all
    await provider.flushAutoSave();

    // Trigger CSV Export from Provider if implemented, or show success
    bool success = await provider.exportToCSV();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Exportación exitosa. Datos guardados.')));
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Guardado finalizado. Falta implementar CSV writer.')));
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (r) => false);
      }
    }
  }

  @override
  void dispose() {
    _indicarCtrl.dispose();
    _factorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        final session = provider.session;
        final info = session?.sessionInfo;
        final seca = info?.seca ?? 'Sin SECA';
        final cod = info?.codMetrica ?? 'Sin Codigo';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Text(
                'DATOS DE EXPORTACIÓN',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF667EEA)),
              ).animate().fadeIn(duration: 600.ms)),
              const SizedBox(height: 24),

              // Resumen
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blueGrey[900] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SECA',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        Text(seca,
                            style: GoogleFonts.inter(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold)),
                      ]),
                  const Divider(),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Código Métrica',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        Text(cod,
                            style: GoogleFonts.inter(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold)),
                      ]),
                  const Divider(),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fecha',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        Text(DateFormat('dd MMM yyyy').format(DateTime.now()),
                            style: GoogleFonts.inter(color: Colors.blue[800])),
                      ]),
                ]),
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 30),

              // Formulario
              Text('Datos para el Certificado',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _emp,
                decoration: _deco('EMP NB 23001'),
                items: ['Sí', 'No']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _emp = v);
                  _saveToProvider();
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _indicarCtrl,
                        onChanged: (_) => _saveToProvider(),
                        keyboardType: TextInputType.number,
                        decoration: _deco('Indicar (%)'))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        controller: _factorCtrl,
                        onChanged: (_) => _saveToProvider(),
                        keyboardType: TextInputType.number,
                        decoration: _deco('Factor Seguridad'))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _regla,
                decoration: _deco('Regla de Aceptación'),
                items: ['Ninguna', 'Simple', 'Conservadora']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _regla = v);
                  _saveToProvider();
                },
              ),
              const SizedBox(height: 32),

              // Boton
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _exportar(provider),
                  icon: const Icon(Icons.file_download),
                  label: const Text('FINALIZAR Y EXPORTAR',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn().scale(),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
