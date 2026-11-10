import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/loading_button.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/people.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_exception.dart';
import '../../domain/services/schedule_service.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';
import '../patient/patient_case_builder.dart';
import '../shared/not_found_screen.dart';

/// "Procesar solicitud" (§6 Admisión): `Stepper` vertical de los pasos 2 a 5.
/// Abre en el paso pendiente del caso; cada botón confirma una transición.
class ProcessCaseScreen extends StatelessWidget {
  const ProcessCaseScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CaseProvider>().caseById(caseId);
    if (c == null) {
      return const NotFoundScreen(title: 'Caso no encontrado', message: 'El caso que buscas no existe.');
    }
    final step = c.currentStep.number;
    if (!c.isOpen || step < 2 || step > 5) {
      return CaseNotice(
        screenTitle: 'Procesar solicitud',
        title: 'Esta solicitud ya fue procesada',
        message: 'El caso ${c.id} está en el paso $step: ${c.currentStep.title}.',
      );
    }
    return _ProcessForm(telemedicineCase: c);
  }
}

class _ProcessForm extends StatefulWidget {
  const _ProcessForm({required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  @override
  State<_ProcessForm> createState() => _ProcessFormState();
}

class _ProcessFormState extends State<_ProcessForm> {
  final _notes = TextEditingController();
  Doctor? _doctor;
  DateTime? _day;
  DateTime? _slot;
  VideoPlatform _platform = VideoPlatform.teams;
  RequestChannel _via = RequestChannel.whatsapp;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  TelemedicineCase get _case => widget.telemedicineCase;

  StaffMember get _staff => context.read<SessionProvider>().currentStaff!;

  /// Ejecuta una transición y avisa el resultado (o el error de la regla) en un `SnackBar`.
  void _run(void Function() action, String success) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    try {
      action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _validateInsurance() async {
    final cases = context.read<CaseProvider>();
    final staff = _staff;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await cases.validateInsurance(_case.id, staff: staff);
      messenger.showSnackBar(SnackBar(
        content: Text(r.approved
            ? 'Seguro aprobado: ${r.coveragePercent}% de cobertura (${r.authorizationNumber}).'
            : 'El seguro rechazó la cobertura: ${r.message}.'),
      ));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _sendConfirmation() async {
    final cases = context.read<CaseProvider>();
    final staff = _staff;
    final via = _via;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final link = await cases.sendConfirmation(_case.id, staff: staff, via: via);
      messenger.showSnackBar(SnackBar(content: Text('Enlace enviado por ${via.label}: $link')));
      router.go(AppRoutes.admissionInbox);
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _case.currentStep.number - 2;
    Step step(int index, String title, Widget Function() content) => Step(
          title: Text(title),
          isActive: index <= current,
          state: index < current ? StepState.complete : StepState.indexed,
          // Solo se construye el paso actual: los demás no tienen nada que hacer.
          content: index == current ? content() : const SizedBox.shrink(),
        );
    return Scaffold(
      appBar: AppBar(title: Text('Procesar ${_case.id}')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Stepper(
            currentStep: current,
            controlsBuilder: (context, details) => const SizedBox.shrink(),
            steps: [
              step(0, 'Registrar', _register),
              step(1, 'Validar seguro', _validate),
              step(2, 'Agendar', _schedule),
              step(3, 'Confirmar', _confirm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _register() {
    final catalog = context.read<CatalogRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Info('Paciente', catalog.patientById(_case.patientId).fullName),
        _Info('Servicio', catalog.serviceById(_case.serviceId).name),
        _Info('Canal', _case.channel.label),
        _Info('Motivo', _case.reason),
        _Info('Fecha preferida', Formatters.date(_case.preferredDate)),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notas de recepción (opcional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _run(
            () => context.read<CaseProvider>().registerReception(_case.id, staff: _staff, notes: _notes.text.trim()),
            'Solicitud registrada.',
          ),
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Registrar solicitud'),
        ),
      ],
    );
  }

  Widget _validate() {
    final catalog = context.read<CatalogRepository>();
    final patient = catalog.patientById(_case.patientId);
    final affiliation = patient.affiliation;
    final busy = context.watch<CaseProvider>().isBusy(_case.id);
    final result = _case.insurance;
    final rejected = _case.status == CaseStatus.insuranceRejected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Info('Aseguradora', catalog.insurerById(affiliation.insurerId).name),
        _Info('Plan', affiliation.plan),
        _Info('Carnet', affiliation.affiliateNumber),
        _Info('Afiliación', affiliation.active ? 'Activa' : 'Inactiva'),
        const SizedBox(height: 12),
        if (!rejected)
          LoadingButton(
            label: busy ? 'Consultando al seguro…' : 'Consultar al seguro',
            icon: Icons.verified_user_outlined,
            loading: busy,
            onPressed: _validateInsurance,
          ),
        if (rejected && result != null) ...[
          Card(
            color: AppColors.danger.withOpacity(0.08),
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.gpp_bad_outlined, color: AppColors.danger),
              title: const Text('Rechazado por el seguro'),
              subtitle: Text(result.message),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _run(
                  () => context.read<CaseProvider>().continueAsPrivate(_case.id, staff: _staff),
                  'El paciente continúa como privado (100%).',
                ),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Continuar como privado'),
              ),
              OutlinedButton.icon(
                onPressed: () => _run(
                  () => context.read<CaseProvider>().cancelCase(
                        _case.id,
                        role: UserRole.admission,
                        actorName: _staff.fullName,
                        reason: 'Rechazo del seguro',
                      ),
                  'La solicitud fue cancelada.',
                ),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar solicitud'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _schedule() {
    final cases = context.read<CaseProvider>();
    final catalog = context.read<CatalogRepository>();
    final theme = Theme.of(context);
    final service = catalog.serviceById(_case.serviceId);
    final specialty = service.specialty;
    final doctors = specialty == null ? const <Doctor>[] : catalog.doctorsFor(specialty);
    final doctor = _doctor ?? (doctors.isEmpty ? null : doctors.first);
    final days = doctor == null
        ? const <DateTime>[]
        : ScheduleService.availableDays(doctor: doctor, cases: cases.cases, now: cases.now);
    final chosenDay = _day;
    final day = chosenDay != null && days.any((d) => DateUtils.isSameDay(d, chosenDay))
        ? chosenDay
        : (days.isEmpty ? null : days.first);
    final slots = doctor == null || day == null
        ? const <DateTime>[]
        : ScheduleService.availableSlots(doctor: doctor, day: day, cases: cases.cases, now: cases.now);
    final slot = slots.contains(_slot) ? _slot : null;
    final dayFormat = DateFormat('EEE d MMM', 'es');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Médico (${specialty?.label ?? 'sin especialidad'})', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in doctors)
              ChoiceChip(
                avatar: AvatarImage(name: d.displayName, asset: d.avatarAsset, size: 24),
                label: Text(d.displayName),
                selected: d.id == doctor?.id,
                onSelected: (_) => setState(() {
                  _doctor = d;
                  _day = null;
                  _slot = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Día (próximos ${ScheduleService.horizonDays} días con turnos libres)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in days)
              ChoiceChip(
                label: Text(dayFormat.format(d)),
                selected: day != null && DateUtils.isSameDay(d, day),
                onSelected: (_) => setState(() {
                  _day = d;
                  _slot = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Hora', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          const Text('No hay turnos libres para ese médico.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < slots.length; i++)
                ChoiceChip(
                  key: ValueKey('slot_$i'),
                  label: Text(Formatters.time(slots[i])),
                  selected: slots[i] == slot,
                  onSelected: (_) => setState(() => _slot = slots[i]),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Text('Plataforma', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<VideoPlatform>(
          showSelectedIcon: false,
          segments: [
            for (final p in VideoPlatform.values)
              ButtonSegment(value: p, label: Text(p.label), icon: Icon(AppIcons.platform(p))),
          ],
          selected: {_platform},
          onSelectionChanged: (selection) => setState(() => _platform = selection.first),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: doctor == null || slot == null
              ? null
              : () => _run(
                    () => cases.scheduleAppointment(
                      _case.id,
                      staff: _staff,
                      doctor: doctor,
                      dateTime: slot,
                      platform: _platform,
                    ),
                    'Cita agendada: ${Formatters.dateTime(slot)} con ${doctor.displayName}.',
                  ),
          icon: const Icon(Icons.event_available),
          label: const Text('Agendar cita'),
        ),
      ],
    );
  }

  Widget _confirm() {
    final catalog = context.read<CatalogRepository>();
    final busy = context.watch<CaseProvider>().isBusy(_case.id);
    final appointment = _case.appointment!;
    final patient = catalog.patientById(_case.patientId);
    final doctor = catalog.doctorById(appointment.doctorId);
    final theme = Theme.of(context);
    final message = 'Hola, ${patient.firstName}. Tu cita de ${catalog.serviceById(_case.serviceId).name} es el '
        '${Formatters.dateTime(appointment.dateTime)} con ${doctor.displayName} por ${appointment.platform.label}. '
        'Ingresa 10 minutos antes con el enlace de este mensaje y firma tu consentimiento en la app SaludConecta.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vista previa del mensaje', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(padding: const EdgeInsets.all(14), child: Text(message)),
        ),
        const SizedBox(height: 16),
        Text('Enviar por', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<RequestChannel>(
          showSelectedIcon: false,
          segments: [
            for (final channel in [RequestChannel.whatsapp, RequestChannel.email])
              ButtonSegment(value: channel, label: Text(channel.label), icon: Icon(AppIcons.channel(channel))),
          ],
          selected: {_via},
          onSelectionChanged: (selection) => setState(() => _via = selection.first),
        ),
        const SizedBox(height: 16),
        LoadingButton(
          label: busy ? 'Enviando…' : 'Enviar confirmación',
          icon: Icons.send,
          loading: busy,
          onPressed: _sendConfirmation,
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
