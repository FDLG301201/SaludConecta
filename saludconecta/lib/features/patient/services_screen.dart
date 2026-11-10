import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/enums.dart';
import '../../domain/process/process_step.dart';

/// "Servicios": los 24 servicios de la infografía 2 en sus 3 grupos, y los canales de atención.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  /// Canales de la infografía de servicios.
  static const _channels = [
    (Icons.smartphone, 'Celular'),
    (Icons.email_outlined, 'Correo'),
    (Icons.chat_outlined, 'WhatsApp'),
    (Icons.language, 'Portal web'),
    (Icons.videocam_outlined, 'Videoconferencia'),
  ];

  @override
  Widget build(BuildContext context) {
    final services = context.read<CatalogRepository>().services;
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Servicios', style: theme.textTheme.headlineSmall),
          Text('${services.length} servicios de telemedicina en 3 grupos', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Canales disponibles', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (icon, label) in _channels) Chip(avatar: Icon(icon, size: 18), label: Text(label)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          for (final group in ServiceGroup.values) ...[
            const SizedBox(height: 16),
            Text(group.label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final service in services)
              if (service.group == group) _ServiceCard(service: service),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Un servicio con su ícono, su descripción y lo que el paciente puede hacer con él.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final MedicalService service;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final fee = s.fee;
    final theme = Theme.of(context);
    final Widget chip;
    if (s.requestable) {
      chip = ActionChip(
        avatar: const Icon(Icons.add, size: 18),
        label: const Text('Solicitar'),
        onPressed: () => context.push(AppRoutes.requestAppointment(serviceId: s.id)),
      );
    } else if (s.relatedStep == ProcessStep.consultationResult) {
      chip = const Chip(avatar: Icon(Icons.receipt_long, size: 18), label: Text('Se genera en tu consulta'));
    } else {
      chip = const Chip(avatar: Icon(Icons.check_circle_outline, size: 18), label: Text('Incluido en el proceso'));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(AppIcons.service(s.iconKey), color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(s.description, style: theme.textTheme.bodyMedium),
                  if (fee != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${s.specialty?.label ?? ''} · ${Formatters.money(fee)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 8),
                  chip,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
