import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../../../widgets/service_ui/input_decoration.dart';
import '../controllers/opportunity_form_controller.dart';
import '../models/bitrix_crm.dart';

/// Busca y elige la empresa de Bitrix24. El cliente de ServiceMET solo sirve
/// para sugerir la búsqueda: el técnico siempre elige explícitamente, porque
/// los nombres pueden no coincidir ("Coca-Cola Embol S.A." / "EMBOL S.A.").
Future<BitrixCompany?> showBitrixCompanyPicker(
  BuildContext context,
  OpportunityFormController controller,
) {
  return showModalBottomSheet<BitrixCompany>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: controller,
      child: const _CompanyPickerSheet(),
    ),
  );
}

class _CompanyPickerSheet extends StatefulWidget {
  const _CompanyPickerSheet();

  @override
  State<_CompanyPickerSheet> createState() => _CompanyPickerSheetState();
}

class _CompanyPickerSheetState extends State<_CompanyPickerSheet> {
  late final TextEditingController _query;

  @override
  void initState() {
    super.initState();
    final controller = context.read<OpportunityFormController>();
    final initial = controller.query.isNotEmpty
        ? controller.query
        : controller.suggestedQuery;
    _query = TextEditingController(text: initial);
    if (controller.results == null && initial.trim().length >= 2) {
      // Después del primer frame: buscar avisa a los oyentes y el árbol
      // todavía se está construyendo.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.search(initial, immediate: true);
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _searchWord(OpportunityFormController controller, String word) {
    _query.value = TextEditingValue(
      text: word,
      selection: TextSelection.collapsed(offset: word.length),
    );
    controller.search(word, immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OpportunityFormController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final results = controller.results;
    final reference = controller.serviceContext.clientDisplay;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Empresa en Bitrix24', style: AppDesign.titleStyle(context)),
              if (reference != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Cliente en ServiceMET: $reference',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: controller.search,
                onSubmitted: (value) =>
                    controller.search(value, immediate: true),
                decoration: serviceInputDeco(
                  'Buscar por nombre',
                  isDark,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _query.clear();
                            controller.search('');
                          },
                        ),
                ),
              ),
              if (controller.searchSuggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final word in controller.searchSuggestions)
                      ActionChip(
                        avatar:
                            const Icon(Icons.manage_search_rounded, size: 16),
                        label: Text(word),
                        onPressed: () => _searchWord(controller, word),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                height: 3,
                child: controller.searching
                    ? const LinearProgressIndicator()
                    : null,
              ),
              const SizedBox(height: 6),
              Expanded(child: _buildResults(context, controller, results)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    OpportunityFormController controller,
    BitrixCompanySearch? results,
  ) {
    final error = controller.searchError;
    if (error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        color: AppColors.actionNegative,
        text: error,
      );
    }
    if (results == null) {
      return const _Message(
        icon: Icons.business_outlined,
        text: 'Escriba al menos 2 letras del nombre de la empresa.',
      );
    }
    if (results.items.isEmpty) {
      return const _Message(
        icon: Icons.search_off_rounded,
        text: 'Sin resultados. Pruebe con otra palabra del nombre; en Bitrix24 '
            'la empresa puede figurar con su razón social o una abreviatura.',
      );
    }
    final selectedId = controller.company?.id;
    return ListView.separated(
      itemCount: results.items.length + (results.truncated ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == results.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Se muestran ${results.items.length} de ${results.total}. '
              'Escriba más letras para afinar la búsqueda.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        final company = results.items[index];
        final details = [
          'ID ${company.id}',
          if (company.industry != null) company.industry!,
          if (company.companyTypeId != null) company.companyTypeId!,
        ].join(' · ');
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.business_rounded),
          title: Text(
            company.title,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(details),
          trailing: company.id == selectedId
              ? const Icon(Icons.check_circle_rounded,
                  color: AppColors.actionPositive)
              : null,
          onTap: () => Navigator.of(context).pop(company),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _Message({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: color ?? muted),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
