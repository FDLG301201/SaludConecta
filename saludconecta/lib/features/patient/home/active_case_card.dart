import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/case_records.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../shared/case_detail/next_action.dart';

/// Tarjeta de un caso en curso: avance "Paso X de 10", la cita y el botón de lo que le toca al paciente.
class ActiveCaseCard extends StatelessWidget {
  const ActiveCaseCard({super.key, required this.telemedicineCase, this.action});

  final TelemedicineCase telemedicineCase;

  /// Lo que puede hacer ahora el paciente; `null` si le toca a otro actor.
  final NextAction? action;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final service = catalog.serviceById(c.serviceId);
    final appointment = c.appointment;
    final step = c.currentStep;
    final next = action;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
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
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: Icon(AppIcons.service(service.iconKey), color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(c.id, style: muted),
                      ],
                    ),
                  ),
                  StatusChip(status: c.status),
                ],
              ),
              const SizedBox(height: 14),
              Text('Paso ${step.number} de 10: ${step.title}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: c.completedSteps.length / 10,
                  minHeight: 8,
                  color: AppColors.forActor(step.actor),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                ),
              ),
              if (appointment != null) ...[
                const SizedBox(height: 10),
                Text(_appointmentText(catalog, appointment), style: muted),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (next != null)
                    FilledButton.icon(
                      onPressed: () => context.push(next.route),
                      icon: Icon(next.icon),
                      label: Text(next.label),
                    )
                  else
                    Text(waitingText(c), style: muted),
                  if (c.results != null)
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.caseAction(c.id, CaseAction.results)),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Ver mis resultados'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _appointmentText(CatalogRepository catalog, Appointment appointment) =>
      '${Formatters.dateTime(appointment.dateTime)} · ${catalog.doctorById(appointment.doctorId).displayName}';
}
