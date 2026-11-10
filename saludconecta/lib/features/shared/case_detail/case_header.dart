import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../domain/models/catalog.dart';
import '../../../domain/models/people.dart';
import '../../../domain/models/telemedicine_case.dart';

/// Encabezado del caso: paciente, servicio, ID, canal de la solicitud y estado.
class CaseHeader extends StatelessWidget {
  const CaseHeader({super.key, required this.telemedicineCase, required this.patient, required this.service});

  final TelemedicineCase telemedicineCase;
  final Patient patient;
  final MedicalService service;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AvatarImage(name: patient.fullName, asset: patient.avatarAsset, size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.fullName, style: theme.textTheme.titleLarge),
                  Text(service.name, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(icon: Icons.tag, text: c.id),
                      _Pill(icon: AppIcons.channel(c.channel), text: c.channel.label),
                      if (c.privatePay) const _Pill(icon: Icons.payments_outlined, text: 'Privado'),
                      StatusChip(status: c.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
