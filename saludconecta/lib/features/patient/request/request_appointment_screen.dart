import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/catalog.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/people.dart';
import '../../../domain/process/process_exception.dart';
import '../../../state/case_provider.dart';
import '../../../state/session_provider.dart';

/// Asistente "Solicitar cita" (paso 1 del proceso): servicio → canal y motivo → fecha y resumen.
///
/// Cada paso tiene su `Form` con validaciones (el servicio se elige en una lista desplegable).
/// En pantallas angostas el `Stepper` es vertical.
class RequestAppointmentScreen extends StatefulWidget {
  const RequestAppointmentScreen({super.key, this.initialServiceId, this.initialDate});

  /// Servicio ya elegido (desde Servicios o desde los resultados): el asistente abre en "Canal y motivo".
  final String? initialServiceId;

  /// Fecha preferida sugerida (cita de seguimiento).
  final DateTime? initialDate;

  @override
  State<RequestAppointmentScreen> createState() => _RequestAppointmentScreenState();
}

class _RequestAppointmentScreenState extends State<RequestAppointmentScreen> {
  static const _lastStep = 2;

  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];
  final _reason = TextEditingController();
  int _step = 0;
  String? _serviceId;
  RequestChannel? _channel;
  late DateTime _firstDate;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final catalog = context.read<CatalogRepository>();
    final now = context.read<CaseProvider>().now;
    // La fecha preferida va de mañana a 60 días.
    _firstDate = DateTime(now.year, now.month, now.day + 1);
    final preset = widget.initialServiceId;
    if (preset != null && catalog.services.any((s) => s.id == preset && s.requestable)) {
      _serviceId = preset;
      _step = 1;
    }
    final suggested = widget.initialDate;
    _date = suggested != null && !suggested.isBefore(_firstDate) ? DateUtils.dateOnly(suggested) : _nextWorkingDay();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Mañana, o el lunes si mañana es domingo.
  DateTime _nextWorkingDay() =>
      _firstDate.weekday == DateTime.sunday ? DateUtils.addDaysToDate(_firstDate, 1) : _firstDate;

  void _continue() {
    if (!(_formKeys[_step].currentState?.validate() ?? false)) return;
    if (_step < _lastStep) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _submit() {
    final patient = context.read<SessionProvider>().currentPatient;
    final serviceId = _serviceId;
    final channel = _channel;
    if (patient == null || serviceId == null || channel == null) return;
    final cases = context.read<CaseProvider>();
    final catalog = context.read<CatalogRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final c = cases.requestAppointment(
        patient: patient,
        service: catalog.serviceById(serviceId),
        channel: channel,
        reason: _reason.text.trim(),
        preferredDate: _date,
      );
      messenger.showSnackBar(SnackBar(content: Text('Solicitud ${c.id} enviada. Admisión la revisará pronto.')));
      // Reemplaza el asistente: al volver desde el detalle no se regresa al formulario ya enviado.
      context.pushReplacement(AppRoutes.caseDetail(c.id));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _firstDate,
      lastDate: DateUtils.addDaysToDate(_firstDate, 60),
      helpText: 'Fecha preferida',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogRepository>();
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar cita')),
      // Arriba y no al centro: el Stepper vertical se ajusta a su contenido y quedaría a media pantalla.
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Stepper(
            type: wide ? StepperType.horizontal : StepperType.vertical,
            currentStep: _step,
            onStepContinue: _continue,
            onStepCancel: _step == 0 ? null : () => setState(() => _step--),
            onStepTapped: (index) {
              // Solo se vuelve a pasos ya hechos; para avanzar hay que validar con "Continuar".
              if (index < _step) setState(() => _step = index);
            },
            controlsBuilder: _controls,
            steps: [
              Step(
                title: const Text('Servicio'),
                isActive: _step >= 0,
                state: _step > 0 ? StepState.complete : StepState.indexed,
                content: Form(key: _formKeys[0], child: _serviceStep(catalog)),
              ),
              Step(
                title: const Text('Canal y motivo'),
                isActive: _step >= 1,
                state: _step > 1 ? StepState.complete : StepState.indexed,
                content: Form(key: _formKeys[1], child: _channelStep()),
              ),
              Step(
                title: const Text('Fecha'),
                isActive: _step >= 2,
                content: Form(key: _formKeys[2], child: _dateStep(catalog)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, ControlsDetails details) {
    final last = details.stepIndex == _lastStep;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: details.onStepContinue,
            icon: Icon(last ? Icons.send : Icons.arrow_forward),
            label: Text(last ? 'Enviar solicitud' : 'Continuar'),
          ),
          const SizedBox(width: 12),
          if (details.onStepCancel != null) TextButton(onPressed: details.onStepCancel, child: const Text('Atrás')),
        ],
      ),
    );
  }

  Widget _serviceStep(CatalogRepository catalog) {
    final theme = Theme.of(context);
    final serviceId = _serviceId;
    final selected = serviceId == null ? null : catalog.serviceById(serviceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Qué servicio necesitas?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        // Una lista desplegable mantiene el paso compacto aunque haya 13 servicios.
        DropdownButtonFormField<String>(
          value: _serviceId,
          isExpanded: true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Servicio', border: OutlineInputBorder()),
          items: [
            for (final s in catalog.services)
              if (s.requestable)
                DropdownMenuItem(
                  value: s.id,
                  child: Row(
                    children: [
                      Icon(AppIcons.service(s.iconKey), size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
          ],
          onChanged: (value) => setState(() => _serviceId = value),
          validator: (value) => value == null ? 'Elige un servicio.' : null,
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(AppIcons.service(selected.iconKey), color: AppColors.primary),
              title: Text(selected.name),
              subtitle: Text(
                '${selected.specialty?.label ?? ''} · ${Formatters.money(selected.fee ?? 0)}\n${selected.description}',
              ),
              isThreeLine: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _channelStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Por qué canal nos contactas?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        FormField<RequestChannel>(
          validator: (_) => _channel == null ? 'Elige un canal.' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final channel in RequestChannel.values)
                    ChoiceChip(
                      avatar: Icon(AppIcons.channel(channel), size: 18),
                      label: Text(channel.label),
                      selected: _channel == channel,
                      onSelected: (_) {
                        setState(() => _channel = channel);
                        if (field.hasError) field.validate();
                      },
                    ),
                ],
              ),
              if (field.hasError) ...[
                const SizedBox(height: 6),
                Text(field.errorText!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _reason,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Motivo de consulta',
            hintText: 'Describe tus síntomas o lo que necesitas',
            border: OutlineInputBorder(),
          ),
          validator: (value) =>
              (value ?? '').trim().length < 10 ? 'Describe el motivo de consulta con al menos 10 caracteres.' : null,
        ),
      ],
    );
  }

  Widget _dateStep(CatalogRepository catalog) {
    final theme = Theme.of(context);
    final patient = context.read<SessionProvider>().currentPatient;
    final serviceId = _serviceId;
    final service = serviceId == null ? null : catalog.serviceById(serviceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Qué día prefieres?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.event),
            title: Text(Formatters.date(_date)),
            subtitle: const Text('Admisión confirmará la hora según la agenda del médico.'),
            trailing: TextButton(onPressed: _pickDate, child: const Text('Cambiar')),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Resumen',
          icon: Icons.fact_check_outlined,
          child: Column(
            children: [
              _SummaryRow('Servicio', service?.name ?? '-'),
              _SummaryRow('Tarifa', Formatters.money(service?.fee ?? 0)),
              _SummaryRow('Canal', _channel?.label ?? '-'),
              _SummaryRow('Motivo', _reason.text.trim()),
              if (patient != null && service != null) _SummaryRow('Cobertura', _coverage(catalog, patient, service)),
            ],
          ),
        ),
      ],
    );
  }

  /// Cobertura estimada del plan del paciente (Admisión la confirma al validar con el seguro).
  String _coverage(CatalogRepository catalog, Patient patient, MedicalService service) {
    final affiliation = patient.affiliation;
    if (!affiliation.active) return 'Afiliación inactiva: Admisión revisará tu caso';
    final insurer = catalog.insurerById(affiliation.insurerId);
    return '${insurer.coverageFor(affiliation.plan, service)}% con ${insurer.name} (plan ${affiliation.plan}), '
        'sujeto a validación';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: muted)),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
