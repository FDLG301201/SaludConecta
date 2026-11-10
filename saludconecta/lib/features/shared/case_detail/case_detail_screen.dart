import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/step_badge.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_exception.dart';
import '../../../domain/process/process_rules.dart';
import '../../../state/case_provider.dart';
import '../../../state/session_provider.dart';
import '../not_found_screen.dart';
import 'case_header.dart';
import 'case_sections.dart';
import 'case_timeline.dart';
import 'next_action.dart';

/// Detalle del caso (§6 del spec): encabezado, próxima acción según el rol, línea de tiempo,
/// datos de cada etapa, "Ver en el diagrama" y "Cancelar cita" cuando las reglas lo permiten.
class CaseDetailScreen extends StatelessWidget {
  const CaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final session = context.watch<SessionProvider>();
    final c = cases.caseById(caseId);
    if (c == null) {
      return const NotFoundScreen(title: 'Caso no encontrado', message: 'El caso que buscas no existe.');
    }
    final role = session.role;
    if (role == null) return const SizedBox.shrink();
    final catalog = context.read<CatalogRepository>();
    final canCancel =
        role == UserRole.patient && c.patientId == session.currentPatient?.id && ProcessRules.canPatientCancel(c);
    return Scaffold(
      appBar: AppBar(title: Text('Caso ${c.id}')),
      body: PageBody(
        child: ListView(
          children: [
            CaseHeader(
              telemedicineCase: c,
              patient: catalog.patientById(c.patientId),
              service: catalog.serviceById(c.serviceId),
            ),
            const SizedBox(height: 12),
            _NextActionCard(
              telemedicineCase: c,
              action: nextActionFor(
                c,
                role,
                patientId: session.currentPatient?.id,
                doctorId: session.currentDoctor?.id,
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(title: 'Línea de tiempo', icon: Icons.timeline, child: CaseTimeline(telemedicineCase: c)),
            const SizedBox(height: 12),
            CaseSections(telemedicineCase: c),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.caseDiagram(c.id)),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Ver en el diagrama'),
                ),
                if (canCancel)
                  TextButton.icon(
                    onPressed: () => _confirmCancel(context, c),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar cita'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, TelemedicineCase c) async {
    // Se capturan antes del await: después no se usa `context`.
    final cases = context.read<CaseProvider>();
    final session = context.read<SessionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar la cita?'),
        content: Text('El caso ${c.id} quedará cancelado. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      cases.cancelCase(
        c.id,
        role: UserRole.patient,
        actorName: session.displayName,
        reason: 'Cancelada por el paciente desde la app',
      );
      messenger.showSnackBar(const SnackBar(content: Text('La cita fue cancelada.')));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Tarjeta "Próxima acción": el botón de la acción que le toca al rol, o a quién se espera.
class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.telemedicineCase, required this.action});

  final TelemedicineCase telemedicineCase;
  final NextAction? action;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final theme = Theme.of(context);
    final step = c.currentStep;
    final next = action;
    final (title, message) = switch (c.status) {
      CaseStatus.completed => ('Proceso completado', 'El caso recorrió los 10 pasos.'),
      CaseStatus.cancelled => ('Solicitud cancelada', 'El caso se canceló en el paso ${step.number}.'),
      _ => ('Próxima acción', next == null ? waitingText(c) : 'Paso ${step.number} de 10: ${step.title}'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StepBadge(
              step: step,
              size: 40,
              color: c.status == CaseStatus.active ? null : AppColors.forStatus(c.status),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(message, style: theme.textTheme.bodyMedium),
                  if (next != null) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      // Las acciones sobre el caso se apilan; las secciones del rol se abren con `go`.
                      onPressed: () =>
                          next.route.startsWith('/caso/') ? context.push(next.route) : context.go(next.route),
                      icon: Icon(next.icon),
                      label: Text(next.label),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
