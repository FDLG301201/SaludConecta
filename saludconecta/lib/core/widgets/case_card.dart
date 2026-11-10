import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'avatar_image.dart';
import 'status_chip.dart';
import 'step_badge.dart';

/// Tarjeta de caso para las listas: paciente (o servicio), paso actual y estado.
class CaseCard extends StatelessWidget {
  const CaseCard({super.key, required this.telemedicineCase, this.onTap, this.showPatient = true, this.trailing});

  final TelemedicineCase telemedicineCase;
  final VoidCallback? onTap;

  /// En las listas del personal se muestra el paciente; en las del paciente, el servicio.
  final bool showPatient;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final patient = catalog.patientById(c.patientId);
    final service = catalog.serviceById(c.serviceId);
    final theme = Theme.of(context);
    final step = c.currentStep;
    final progress = c.status == CaseStatus.completed ? 'Proceso completo' : 'Paso ${step.number} de 10: ${step.title}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (showPatient)
                AvatarImage(name: patient.fullName, asset: patient.avatarAsset, size: 44)
              else
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Icon(AppIcons.service(service.iconKey), color: AppColors.primary),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showPatient ? patient.fullName : service.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      showPatient ? '${service.name} · ${c.id}' : c.id,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StepBadge(
                          step: step,
                          size: 22,
                          color: c.status == CaseStatus.active ? null : AppColors.forStatus(c.status),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            progress,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(status: c.status),
                  if (trailing != null) ...[const SizedBox(height: 6), trailing!],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
