import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../login/services/connection_profile_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import '../../widgets/service_ui/input_decoration.dart';
import '../../widgets/service_ui/service_app_bar.dart';
import 'controllers/opportunity_form_controller.dart';
import 'data/tipos_oportunidad.dart';
import 'models/bitrix_crm.dart';
import 'models/opportunity_draft.dart';
import 'models/opportunity_service_context.dart';
import 'services/bitrix_company_matcher.dart';
import 'services/opportunity_repository.dart';
import 'widgets/bitrix_company_picker.dart';
import 'widgets/opportunity_password_prompt.dart';

/// Cómo terminó el formulario, para avisarlo en la pantalla del servicio.
class OpportunityFormOutcome {
  final String message;

  /// Prospecto creado (o ya existente) en Bitrix24; null si quedó en el
  /// teléfono.
  final int? leadId;

  const OpportunityFormOutcome(this.message, {this.leadId});

  bool get sent => leadId != null;
}

/// Formulario único de oportunidad comercial, para Calibración y Soporte.
///
/// Se abre como ruta a pantalla completa encima del servicio: el paso actual
/// sigue montado debajo, así que al registrar o cancelar el técnico vuelve
/// exactamente donde estaba. No lee ni escribe los datos del servicio: recibe
/// una foto de solo lectura ([OpportunityServiceContext]).
class OpportunityFormScreen extends StatefulWidget {
  const OpportunityFormScreen({super.key});

  /// [existing] completa una oportunidad pendiente (por ejemplo, para elegir
  /// la empresa que no pudo buscarse sin conexión).
  static Future<OpportunityFormOutcome?> open(
    BuildContext context, {
    required OpportunityServiceContext serviceContext,
    PendingOpportunity? existing,
    OpportunityRepository Function()? repositoryBuilder,
  }) {
    final profiles = repositoryBuilder == null
        ? context.read<ConnectionProfileService>()
        : null;
    return Navigator.of(context).push<OpportunityFormOutcome>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChangeNotifierProvider(
          create: (_) => OpportunityFormController(
            serviceContext: serviceContext,
            existing: existing,
            loggedUser: loggedServiceMetUser,
            appVersion: serviceMetAppVersion,
            repository: repositoryBuilder?.call() ??
                OpportunityRepository(
                  apiUrl: () => profiles?.perfilSeleccionado?.apiUrl,
                  loggedUser: loggedServiceMetUser,
                ),
          ),
          child: const OpportunityFormScreen(),
        ),
      ),
    );
  }

  @override
  State<OpportunityFormScreen> createState() => _OpportunityFormScreenState();
}

class _OpportunityFormScreenState extends State<OpportunityFormScreen> {
  late final OpportunityFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<OpportunityFormController>()
      ..passwordPrompt = (error) => askOpportunityPassword(context, error);
  }

  Future<void> _pickCompany() async {
    FocusScope.of(context).unfocus();
    final company = await showBitrixCompanyPicker(context, _controller);
    if (company != null && mounted) _controller.selectCompany(company);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final result = await _controller.submit();
    if (result == null || !mounted) return;
    switch (result.outcome) {
      case OpportunitySubmitOutcome.sent:
        final id = result.leadId;
        Navigator.of(context).pop(OpportunityFormOutcome(
          result.duplicate
              ? 'La oportunidad ya estaba registrada en Prospectos de '
                  'Bitrix24 (#$id).'
              : '✓ Oportunidad registrada en Prospectos de Bitrix24 (#$id).',
          leadId: id,
        ));
      case OpportunitySubmitOutcome.savedPending:
        final sinEmpresa = !(result.record?.draft.hasCompany ?? true);
        Navigator.of(context).pop(OpportunityFormOutcome(
          '${result.error?.message ?? 'Bitrix24 no está disponible.'} '
          'La oportunidad quedó pendiente: con conexión '
          '${sinEmpresa ? 'se buscará la empresa del cliente y ' : ''}'
          'se enviará sola. Puede verla en Servicios › Oportunidades '
          'comerciales.',
        ));
      case OpportunitySubmitOutcome.failed:
        // Se queda en el formulario: el error se muestra arriba del botón.
        break;
    }
  }

  Future<void> _cancel() async {
    if (_controller.busy) return;
    if (_controller.isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Descartar la oportunidad?'),
          content: const Text(
            'Lo que escribió no se guardará. El servicio no se modifica.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      _controller.storedLocally
          ? const OpportunityFormOutcome(
              'La oportunidad quedó guardada en el teléfono; puede revisarla '
              'en Servicios › Oportunidades comerciales.',
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OpportunityFormController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !controller.busy && !controller.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: ServiceAppBar(
          title: controller.editingExisting
              ? 'Oportunidad pendiente'
              : 'Nueva oportunidad',
          leading: Center(
            child: IconButton(
              tooltip: 'Cancelar',
              icon: const Icon(Icons.close_rounded),
              onPressed: controller.busy ? null : _cancel,
            ),
          ),
        ),
        body: AbsorbPointer(
          absorbing: controller.busy,
          // Todo el formulario queda construido (no es una lista larga): los
          // campos conservan su estado aunque se desplacen fuera de la vista.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppDesign.pagePadding, 8, AppDesign.pagePadding, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ServiceSummary(context: controller.serviceContext),
                const SizedBox(height: 22),
                const ServiceSectionHeader('Cliente en Bitrix24'),
                _CompanyField(controller: controller, onTap: _pickCompany),
                const SizedBox(height: 12),
                _ContactField(controller: controller, isDark: isDark),
                _CityField(controller: controller, isDark: isDark),
                const SizedBox(height: 22),
                const ServiceSectionHeader('Equipo'),
                _EquipmentSummary(context: controller.serviceContext),
                const SizedBox(height: 22),
                const ServiceSectionHeader('Oportunidad'),
                _OpportunityFields(controller: controller, isDark: isDark),
                if (controller.formError != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: controller.formError!),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDesign.pagePadding, 8, AppDesign.pagePadding, 12),
            // Un solo botón: con conexión la registra en Bitrix24; sin
            // conexión la deja pendiente y la app la envía sola después.
            child: FilledButton(
              style: AppDesign.positiveButtonStyle(),
              onPressed: controller.busy ? null : _submit,
              child: controller.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text(
                      'Registrar oportunidad',
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceSummary extends StatelessWidget {
  final OpportunityServiceContext context;

  const _ServiceSummary({required this.context});

  @override
  Widget build(BuildContext buildContext) {
    final service = context;
    final plant = [service.plantName, service.plantDepartment]
        .whereType<String>()
        .join(' - ');
    final when = DateFormat('dd/MM/yyyy HH:mm').format(service.capturedAt);
    final label = service.serviceLabel;
    return AppPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppStatusPill(
            icon: Icons.check_circle_rounded,
            label: label,
            color: AppColors.actionPositive,
          ),
          const SizedBox(height: 12),
          _ReadOnlyRow(service.secaLabel, service.seca),
          _ReadOnlyRow('Cliente', service.clientDisplay),
          _ReadOnlyRow('Planta', plant.isEmpty ? null : plant),
          _ReadOnlyRow('Técnico', service.technician),
          _ReadOnlyRow(
              'Fecha',
              service.serviceDate == null
                  ? when
                  : '${service.serviceDate} · registro $when'),
        ],
      ),
    );
  }
}

class _EquipmentSummary extends StatelessWidget {
  final OpportunityServiceContext context;

  const _EquipmentSummary({required this.context});

  @override
  Widget build(BuildContext buildContext) {
    final service = context;
    final rows = [
      _ReadOnlyRow('Código métrica', service.metricCode),
      _ReadOnlyRow('Tipo', service.equipmentType),
      _ReadOnlyRow('Marca', service.brand),
      _ReadOnlyRow('Modelo', service.model),
      _ReadOnlyRow('Serie', service.serial),
      _ReadOnlyRow('Capacidad', service.capacityWithUnit),
      _ReadOnlyRow('División', service.divisionWithUnit),
      _ReadOnlyRow('Ubicación', service.location),
    ].where((row) => row.value != null).toList();
    return AppPanel(
      padding: const EdgeInsets.all(16),
      child: rows.isEmpty
          ? Text(
              'Todavía no se eligió el instrumento en este servicio.',
              style: Theme.of(buildContext).textTheme.bodySmall,
            )
          : Column(children: rows),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String? value;

  const _ReadOnlyRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: muted),
            ),
          ),
          Expanded(
            child: SelectableText(
              text,
              style:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyField extends StatelessWidget {
  final OpportunityFormController controller;
  final VoidCallback onTap;

  const _CompanyField({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final company = controller.company;
    final reference = controller.serviceContext.clientDisplay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reference != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'En ServiceMET: $reference. Elija la empresa exacta de Bitrix24; '
              'el nombre puede ser distinto.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (company == null || controller.companySource != CompanySource.manual)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              switch (controller.companySource) {
                CompanySource.remembered =>
                  'Es la empresa que usó antes para este cliente. Cámbiela si '
                      'no corresponde.',
                CompanySource.exact =>
                  'Empresa vinculada por coincidencia exacta con el cliente. '
                      'Cámbiela si no corresponde.',
                _ => 'Si no la elige, al registrar se usa la que coincida '
                    'exactamente con el cliente. Sin conexión, la oportunidad '
                    'queda pendiente y se completa y envía sola después.',
              },
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        InkWell(
          onTap: onTap,
          borderRadius: AppDesign.mediumRadius,
          child: InputDecorator(
            isEmpty: company == null,
            decoration: serviceInputDeco(
              'Empresa Bitrix24',
              isDark,
              prefixIcon: const Icon(Icons.business_rounded),
              suffixIcon: const Icon(Icons.search_rounded),
              hintText: 'Buscar empresa…',
            ).copyWith(errorText: controller.fieldErrors['company']),
            child: company == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        company.title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'ID ${company.id}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ContactField extends StatelessWidget {
  final OpportunityFormController controller;
  final bool isDark;

  const _ContactField({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (controller.company == null) return const SizedBox.shrink();
    if (controller.loadingContacts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Cargando contactos…'),
          ],
        ),
      );
    }
    final error = controller.contactsError;
    if (error != null) {
      return Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$error Puede continuar sin contacto.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: controller.loadContacts,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    final contacts = [...controller.contacts];
    final selected = controller.contact;
    if (selected != null && !contacts.any((c) => c.id == selected.id)) {
      contacts.insert(0, selected);
    }
    if (controller.contactsLoaded && contacts.isEmpty) {
      return Text(
        'La empresa no tiene contactos en Bitrix24. Se registrará sin contacto.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return DropdownButtonFormField<int>(
      key: ValueKey('contactos-${controller.company?.id}'),
      initialValue: selected?.id ?? 0,
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      itemHeight: null,
      decoration: serviceInputDeco(
        'Contacto',
        isDark,
        prefixIcon: const Icon(Icons.person_outline_rounded),
      ).copyWith(errorText: controller.fieldErrors['contact']),
      selectedItemBuilder: (_) => [
        const Text('Sin contacto'),
        for (final contact in contacts)
          Text(contact.fullName, overflow: TextOverflow.ellipsis),
      ],
      items: [
        const DropdownMenuItem(value: 0, child: Text('Sin contacto')),
        for (final contact in contacts)
          DropdownMenuItem(
            value: contact.id,
            child: _ContactOption(contact: contact),
          ),
      ],
      onChanged: (id) => controller.selectContact(
        id == null || id == 0
            ? null
            : contacts.firstWhere((contact) => contact.id == id),
      ),
    );
  }
}

/// "Ciudad del prospecto" de Bitrix24. Por defecto es automática: el
/// servidor la deduce del departamento de la planta; el técnico puede elegir
/// otra.
class _CityField extends StatelessWidget {
  final OpportunityFormController controller;
  final bool isDark;

  const _CityField({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final options = controller.cityOptions;
    if (options.isEmpty) return const SizedBox.shrink();
    final department = controller.serviceContext.plantDepartment;
    final suggested = controller.suggestedCity;
    final automatic = suggested != null
        ? 'Automática: $suggested'
        : department != null
            ? 'Automática: según la planta ($department)'
            : 'Elegir ciudad…';
    final selected = options.contains(controller.city) ? controller.city : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('ciudades-${options.length}'),
        initialValue: selected,
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        decoration: serviceInputDeco(
          controller.cityRequired
              ? 'Ciudad del prospecto'
              : 'Ciudad del prospecto (opcional)',
          isDark,
          prefixIcon: const Icon(Icons.location_city_outlined),
        ).copyWith(errorText: controller.fieldErrors['city']),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(automatic)),
          for (final city in options)
            DropdownMenuItem<String?>(value: city, child: Text(city)),
        ],
        onChanged: controller.selectCity,
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final BitrixContact contact;

  const _ContactOption({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            contact.isPrimary
                ? '${contact.fullName} (principal)'
                : contact.fullName,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          if (contact.details.isNotEmpty)
            Text(contact.details, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _OpportunityFields extends StatelessWidget {
  final OpportunityFormController controller;
  final bool isDark;

  const _OpportunityFields({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final errors = controller.fieldErrors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<OpportunityType>(
          initialValue: controller.type,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          decoration: serviceInputDeco(
            'Tipo de oportunidad',
            isDark,
            prefixIcon: const Icon(Icons.sell_outlined),
          ).copyWith(errorText: errors['type']),
          items: [
            for (final type in OpportunityTypeCatalog.all)
              DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Icon(type.icon, size: 18),
                    const SizedBox(width: 10),
                    Flexible(child: Text(type.label)),
                  ],
                ),
              ),
          ],
          onChanged: controller.selectType,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller.titleController,
          maxLength: OpportunityFormController.titleMaxLength,
          textCapitalization: TextCapitalization.sentences,
          onChanged: controller.onTitleChanged,
          decoration: serviceInputDeco('Título', isDark)
              .copyWith(errorText: errors['title'], counterText: ''),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller.descriptionController,
          minLines: 4,
          maxLines: 8,
          maxLength: OpportunityFormController.descriptionMaxLength,
          textCapitalization: TextCapitalization.sentences,
          onChanged: controller.onDescriptionChanged,
          decoration: serviceInputDeco(
            'Descripción',
            isDark,
            hintText: 'Ej.: El indicador presenta fallas intermitentes y el '
                'cliente solicita cotización para su reemplazo.',
          ).copyWith(
            errorText: errors['description'],
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        Text('Prioridad (opcional)',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<OpportunityPriority>(
          segments: [
            for (final priority in OpportunityPriority.values)
              ButtonSegment(value: priority, label: Text(priority.label)),
          ],
          selected: {
            if (controller.priority != null) controller.priority!,
          },
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (selection) => controller.selectPriority(
            selection.isEmpty ? null : selection.first,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.notesController,
          minLines: 2,
          maxLines: 5,
          maxLength: OpportunityFormController.notesMaxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: serviceInputDeco(
                  'Observaciones adicionales (opcional)', isDark)
              .copyWith(errorText: errors['notes'], alignLabelWithHint: true),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.actionNegative.withValues(alpha: 0.1),
        borderRadius: AppDesign.mediumRadius,
        border: Border.all(
          color: AppColors.actionNegative.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.actionNegative),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
