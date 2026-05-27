import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/providers/service_session_provider.dart';

class SecaStep extends StatefulWidget {
  const SecaStep({super.key});

  @override
  State<SecaStep> createState() => _SecaStepState();
}

class _SecaStepState extends State<SecaStep> {
  final TextEditingController _cotizacionController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ServiceSessionProvider>();
      final session = provider.session;
      if (session != null && !session.metadata.secaConfirmed) {
         _cotizacionController.text = 'C01';
      } else if (session != null && session.metadata.secaConfirmed) {
         final parts = session.sessionInfo.seca?.split('-') ?? [];
         if (parts.length >= 4) {
            _cotizacionController.text = parts[3]; // format: XXXX-XX-XXX-C01-24? No wait, XXXX-XX-C01-24. So parts is: [0]:XXXX, [1]:XX, [2]:C01, [3]:24
         }
      }
    });
  }

  @override
  void dispose() {
    _cotizacionController.dispose();
    super.dispose();
  }

  String _getFixedSecaPart(ServiceSessionProvider provider) {
    final plantaCod = provider.session?.planta?.codigo ?? 'NNNN-NN';
    return '$plantaCod-';
  }

  String _getYearPart() {
    return '-${DateTime.now().year.toString().substring(2)}';
  }

  String _generateProposedSeca(ServiceSessionProvider provider) {
    final cotizacion = _cotizacionController.text.isEmpty ? 'C01' : _cotizacionController.text;
    return '${_getFixedSecaPart(provider)}$cotizacion${_getYearPart()}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, child) {
        final session = provider.session;
        if (session == null) return const SizedBox.shrink();
        
        final isConfirmed = session.metadata.secaConfirmed;
        final currentSeca = isConfirmed ? session.sessionInfo.seca : _generateProposedSeca(provider);
        final tieneCodigoTemporal = currentSeca?.contains('NNNN-NN') ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'CÓDIGO SECA GENERADO',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2C3E50)),
              ).animate().fadeIn(duration: 600.ms),
              const SizedBox(height: 30),
              _buildInfoSummary(provider),
              const SizedBox(height: 30),
              _buildSecaCard(provider, isConfirmed, currentSeca),
              const SizedBox(height: 30),
              _buildAdditionalInfo(isConfirmed, tieneCodigoTemporal),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSummary(ServiceSessionProvider provider) {
    final session = provider.session!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue[200]!)),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
              const SizedBox(width: 12),
              Text('Resumen de la Información', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800])),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Cliente', session.cliente?.nombreComercial ?? 'N/A'),
          const SizedBox(height: 8),
          _buildSummaryRow('Código Planta', session.planta?.codigo ?? 'N/A'),
          const SizedBox(height: 8),
          _buildSummaryRow('Técnico', session.sessionInfo.userName ?? 'N/A'),
          const SizedBox(height: 8),
          _buildSummaryRow('Fecha', session.sessionInfo.fechaServicio ?? 'N/A'),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: -0.3);
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text('$label:', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.blue[700]))),
        Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 14, color: Colors.blue[800]))),
      ],
    );
  }

  Widget _buildSecaCard(ServiceSessionProvider provider, bool isConfirmed, String? currentSeca) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: isConfirmed ? [Colors.green[100]!, Colors.green[50]!] : [Colors.blue[100]!, Colors.blue[50]!]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isConfirmed ? Colors.green[300]! : Colors.blue[300]!, width: 2),
        boxShadow: [BoxShadow(color: (isConfirmed ? Colors.green : Colors.blue).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(isConfirmed ? 'SECA Confirmado:' : 'SECA Sugerido:', style: GoogleFonts.inter(fontSize: 16, color: isConfirmed ? Colors.green[700] : Colors.blue[700], fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          if (isConfirmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green[200]!)),
              child: Text(currentSeca ?? '', style: GoogleFonts.robotoMono(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[800], letterSpacing: 2), textAlign: TextAlign.center),
            ).animate(delay: 300.ms).fadeIn()
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue[200]!)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_getFixedSecaPart(provider), style: GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800], letterSpacing: 2)),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _cotizacionController,
                      style: GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800], letterSpacing: 2),
                      decoration: InputDecoration(border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue[300]!, width: 2)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue[600]!, width: 2)), contentPadding: const EdgeInsets.symmetric(vertical: 8), hintText: 'C01'),
                      textAlign: TextAlign.center,
                      maxLength: 3,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      onChanged: (value) {
                         setState(() {}); // refresh proposed SECA
                      },
                    ),
                  ),
                  Text(_getYearPart(), style: GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800], letterSpacing: 2)),
                ],
              ),
            ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 24),
          if (isConfirmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.green[200], borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green[800], size: 20),
                  const SizedBox(width: 8),
                  Text('Confirmado y Registrado', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 14)),
                ],
              ),
            ).animate(delay: 400.ms).fadeIn().scale(begin: const Offset(0.8, 0.8))
          else
            ElevatedButton(
              onPressed: () async {
                 final secaToConfirm = _generateProposedSeca(provider);
                 await provider.confirmSeca(secaToConfirm);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              child: const Text('Confirmar SECA'),
            ).animate(delay: 400.ms).fadeIn(),
          if (isConfirmed && provider.session?.sessionInfo.sessionId != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.key, color: Colors.green[600], size: 16),
                  const SizedBox(width: 8),
                  Flexible(child: Text('ID Sesión: ${provider.session!.sessionInfo.sessionId}', style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ).animate(delay: 500.ms).fadeIn(),
          ],
        ],
      ),
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3);
  }

  Widget _buildAdditionalInfo(bool isConfirmed, bool tieneCodigoTemporal) {
    return Column(
      children: [
        if (tieneCodigoTemporal)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue[300]!)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Código Temporal', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                      const SizedBox(height: 4),
                      Text('Este SECA contiene "NNNN-NN" porque el cliente o planta es nuevo. El código definitivo se asignará desde el sistema de gestión.', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[700])),
                    ],
                  ),
                ),
              ],
            ),
          ).animate(delay: 400.ms).fadeIn().scale(begin: const Offset(0.95, 0.95)),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange[200]!)),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.orange[600], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Formato del Código SECA', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                    const SizedBox(height: 4),
                    Text('El código se genera automáticamente usando:\n• Código de planta ${tieneCodigoTemporal ? "(temporal: NNNN-NN)" : "seleccionado"}\n• Numeración correlativa (C01, C02...)\n• Año actual (${DateTime.now().year.toString().substring(2)})', style: GoogleFonts.inter(fontSize: 12, color: Colors.orange[700])),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: 500.ms).fadeIn().slideX(begin: -0.3),
      ],
    );
  }
}
