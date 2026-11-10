import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/appointment_status_chip.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/people.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_exception.dart';
import '../../domain/process/process_step.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';

/// Agenda del médico (§6): sus citas con los pasos 6 a 8 pendientes, hoy y próximas.
class DoctorAgendaScreen extends StatelessWidget {
  const DoctorAgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctor = context.watch<SessionProvider>().currentDoctor;
    if (doctor == null) return const SizedBox.shrink();
    final cases = context.watch<CaseProvider>();
    final items = cases.doctorAgenda(doctor.id);
    final today = DateUtils.dateOnly(cases.now);
    bool isToday(TelemedicineCase c) => DateUtils.isSameDay(c.appointment!.dateTime, today);
    final todays = [
      for (final c in items)
        if (isToday(c)) c,
    ];
    final upcoming = [
      for (final c in items)
        if (!isToday(c)) c,
    ];
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Mi agenda', style: theme.textTheme.headlineSmall),
          Text('${doctor.displayName} · ${doctor.specialty.label}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final (title, group) in [('Hoy', todays), ('Próximas', upcoming)]) ...[
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (group.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Sin citas.', style: theme.textTheme.bodyMedium),
              )
            else
              for (final c in group) _AgendaCard(telemedicineCase: c, doctor: doctor),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.telemedicineCase, required this.doctor});

  final TelemedicineCase telemedicineCase;
  final Doctor doctor;

  /// Abre la consulta; antes la marca como iniciada (en modo demo no espera la hora agendada).
  void _startConsultation(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    try {
      context.read<CaseProvider>().startConsultation(telemedicineCase.id, doctor: doctor);
      context.push(AppRoutes.caseAction(telemedicineCase.id, CaseAction.consultation));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final patient = catalog.patientById(c.patientId);
    final appointment = c.appointment!;
    final theme = Theme.of(context);
    final Widget? action = switch (c.currentStep) {
      ProcessStep.consultation => FilledButton.icon(
          onPressed: () => _startConsultation(context),
          icon: const Icon(Icons.video_call),
          label: const Text('Iniciar consulta'),
        ),
      ProcessStep.consultationResult => FilledButton.icon(
          onPressed: () => context.push(AppRoutes.caseAction(c.id, CaseAction.issueResults)),
          icon: const Icon(Icons.receipt_long),
          label: const Text('Emitir resultados'),
        ),
      _ => null,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.caseDetail(c.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarImage(name: patient.fullName, asset: patient.avatarAsset, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient.fullName, style: theme.textTheme.titleMedium),
                        Text(
                          '${catalog.serviceById(c.serviceId).name} · ${c.id}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // El estado va junto a la fecha: en el teléfono el nombre del paciente usa toda la fila.
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppointmentStatusChip(telemedicineCase: c),
                  Text(
                    '${Formatters.dateTime(appointment.dateTime)} · ${appointment.platform.label}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
