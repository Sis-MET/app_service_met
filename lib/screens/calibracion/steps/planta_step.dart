import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';

class PlantaStep extends StatefulWidget {
  const PlantaStep({super.key});

  @override
  State<PlantaStep> createState() => _PlantaStepState();
}

class _PlantaStepState extends State<PlantaStep> {
  final TextEditingController _plantaDirController = TextEditingController();
  final TextEditingController _plantaDepController = TextEditingController();
  final TextEditingController _nombrePlantaController = TextEditingController();
  final CalibrationRepository _repository = CalibrationRepository();

  List<Map<String, dynamic>>? _plantas;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlantas();
    });
  }

  void _loadPlantas() async {
    final provider = context.read<ServiceSessionProvider>();
    final cliente = provider.session?.cliente;
    if (cliente != null && cliente.id != null && !(cliente.isNew ?? false)) {
      setState(() => _isLoading = true);
      final result = await _repository.getPlantas(cliente.id!);
      if (mounted) {
        setState(() {
          _plantas = result;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _plantas = []);
    }
  }

  @override
  void dispose() {
    _plantaDirController.dispose();
    _plantaDepController.dispose();
    _nombrePlantaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, child) {
        final cliente = provider.session?.cliente;
        final isNewClient = cliente?.isNew ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'SELECCIÓN DE PLANTA',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF2C3E50),
                ),
              ).animate().fadeIn(duration: 600.ms),
              const SizedBox(height: 30),
              _buildClienteInfo(cliente),
              const SizedBox(height: 30),
              if (isNewClient)
                _buildNewPlantaSection(provider)
              else
                _buildExistingPlantaSection(provider),
              const SizedBox(height: 20),
              if (provider.session?.planta?.codigo != null)
                _buildSelectedPlantaInfo(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClienteInfo(ClienteInfo? cliente) {
    if (cliente == null || cliente.nombreComercial == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue[200], shape: BoxShape.circle),
            child: const Icon(Icons.business, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cliente Seleccionado:', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[600])),
                Text(cliente.nombreComercial!, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                if (cliente.isNew ?? false)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(10)),
                    child: Text('NUEVO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3);
  }

  Widget _buildNewPlantaSection(ServiceSessionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATOS DE LA NUEVA PLANTA', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700])).animate(delay: 300.ms).fadeIn().slideX(begin: -0.3),
        const SizedBox(height: 20),
        TextFormField(
          controller: _nombrePlantaController,
          decoration: InputDecoration(labelText: 'Nombre de la Planta *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.factory)),
          onChanged: (value) => _updateNewPlanta(provider),
        ).animate(delay: 350.ms).fadeIn().slideX(begin: -0.3),
        const SizedBox(height: 20),
        TextFormField(
          controller: _plantaDirController,
          decoration: InputDecoration(labelText: 'Dirección de la Planta *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.location_on)),
          onChanged: (value) => _updateNewPlanta(provider),
        ).animate(delay: 400.ms).fadeIn().slideX(begin: -0.3),
        const SizedBox(height: 16),
        TextFormField(
          controller: _plantaDepController,
          decoration: InputDecoration(labelText: 'Departamento de la Planta *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.map)),
          onChanged: (value) => _updateNewPlanta(provider),
        ).animate(delay: 500.ms).fadeIn().slideX(begin: 0.3),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber[200]!)),
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('El código de planta se asignará después en el sistema de gestión. Por ahora se usará un código temporal (NNNN-NN).', style: GoogleFonts.inter(fontSize: 12, color: Colors.amber[800]))),
            ],
          ),
        ).animate(delay: 600.ms).fadeIn().scale(begin: const Offset(0.8, 0.8)),
      ],
    );
  }

  void _updateNewPlanta(ServiceSessionProvider provider) {
    provider.updatePlanta(PlantaInfo(
      nombre: _nombrePlantaController.text,
      direccion: _plantaDirController.text,
      departamento: _plantaDepController.text,
      codigo: 'NNNN-NN',
      isNew: true,
    ));
  }

  Widget _buildExistingPlantaSection(ServiceSessionProvider provider) {
    if (_isLoading || _plantas == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PLANTAS DISPONIBLES', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[700])),
            ElevatedButton.icon(
              onPressed: () => _showAddPlantaDialog(context, provider),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nueva Planta'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3e7732), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
          ],
        ).animate(delay: 300.ms).fadeIn().slideX(begin: -0.3),
        const SizedBox(height: 20),
        if (_plantas!.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange[200]!)),
            child: Column(
              children: [
                Icon(Icons.warning, color: Colors.orange[600], size: 48),
                const SizedBox(height: 16),
                Text('No hay plantas registradas', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                const SizedBox(height: 8),
                Text('Este cliente no tiene plantas registradas.\nUse el botón "Nueva Planta" para agregar una.', style: GoogleFonts.inter(fontSize: 14, color: Colors.orange[700]), textAlign: TextAlign.center),
              ],
            ),
          ).animate(delay: 400.ms).fadeIn().scale(begin: const Offset(0.9, 0.9))
        else
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: _plantas!.map((planta) {
                final isSelected = provider.session?.planta?.codigo == planta['codigo_planta'];
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
                  ),
                  child: ListTile(
                    title: Text(planta['planta']?.toString() ?? 'Planta sin nombre', style: GoogleFonts.poppins(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (planta['dir'] != null) Text('Dirección: ${planta['dir']}', style: GoogleFonts.inter(fontSize: 12)),
                        if (planta['dep'] != null) Text('Departamento: ${planta['dep']}', style: GoogleFonts.inter(fontSize: 12)),
                        if (planta['codigo_planta'] != null)
                          Text('Código: ${planta['codigo_planta']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[600])),
                      ],
                    ),
                    trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor) : const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      provider.updatePlanta(PlantaInfo(
                        id: planta['planta_id']?.toString() ?? planta['unique_key']?.toString(),
                        codigo: planta['codigo_planta'],
                        nombre: planta['planta'],
                        direccion: planta['dir'],
                        departamento: planta['dep'],
                        isNew: false,
                      ));
                    },
                  ),
                );
              }).toList(),
            ),
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
      ],
    );
  }

  Widget _buildSelectedPlantaInfo(ServiceSessionProvider provider) {
    final planta = provider.session!.planta!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green[50]!, Colors.green[100]!]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green[200], shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Planta Seleccionada', style: GoogleFonts.inter(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500)),
                    Text('Código: ${planta.codigo}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (planta.direccion != null) ...[
            _buildInfoRow('Dirección', planta.direccion!),
            const SizedBox(height: 8),
          ],
          if (planta.departamento != null) ...[
            _buildInfoRow('Departamento', planta.departamento!),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.3);
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(label == 'Dirección' ? Icons.location_on : Icons.map, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: $value', style: GoogleFonts.inter(fontSize: 12, color: Colors.green[700]))),
        ],
      ),
    );
  }

  void _showAddPlantaDialog(BuildContext context, ServiceSessionProvider provider) {
    final TextEditingController nCtrl = TextEditingController();
    final TextEditingController dCtrl = TextEditingController();
    final TextEditingController depCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Agregar Nueva Planta', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nCtrl, decoration: InputDecoration(labelText: 'Nombre de la Planta *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.factory))),
                const SizedBox(height: 16),
                TextField(controller: dCtrl, decoration: InputDecoration(labelText: 'Dirección *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.location_on))),
                const SizedBox(height: 16),
                TextField(controller: depCtrl, decoration: InputDecoration(labelText: 'Departamento *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.map))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nCtrl.dispose(); dCtrl.dispose(); depCtrl.dispose();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3e7732)),
              onPressed: () {
                if (nCtrl.text.trim().isEmpty || dCtrl.text.trim().isEmpty || depCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete todos los campos'), backgroundColor: Colors.red));
                  return;
                }
                provider.updatePlanta(PlantaInfo(
                  nombre: nCtrl.text.trim(),
                  direccion: dCtrl.text.trim(),
                  departamento: depCtrl.text.trim(),
                  codigo: 'NNNN-NN',
                  isNew: true,
                ));
                nCtrl.dispose(); dCtrl.dispose(); depCtrl.dispose();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Usar esta Planta'),
            ),
          ],
        );
      },
    );
  }
}
