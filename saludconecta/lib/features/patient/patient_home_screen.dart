import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/case_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_body.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';

/// Inicio del paciente (versión de la etapa 4): saludo y sus citas.
/// La etapa 5 agrega los avisos, los accesos rápidos y los consejos de salud.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<SessionProvider>().currentPatient;
    if (patient == null) return const SizedBox.shrink();
    final items = context.watch<CaseProvider>().casesOfPatient(patient.id);
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Row(
            children: [
              AvatarImage(name: patient.fullName, asset: patient.avatarAsset, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hola, ${patient.firstName}', style: theme.textTheme.headlineSmall),
                    Text('Carnet ${patient.affiliation.affiliateNumber}', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Tus citas', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const EmptyState(
              illustration: AppIllustrations.emptyCases,
              title: 'Aún no tienes citas',
              message: 'Cuando solicites una cita aparecerá aquí.',
            )
          else
            for (final c in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CaseCard(
                  telemedicineCase: c,
                  showPatient: false,
                  onTap: () => context.push(AppRoutes.caseDetail(c.id)),
                ),
              ),
        ],
      ),
    );
  }
}
