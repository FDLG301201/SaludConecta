import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_body.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';
import '../shared/case_detail/next_action.dart';
import 'home/active_case_card.dart';
import 'home/health_tips_carousel.dart';
import 'home/notification_bell.dart';

/// Inicio del paciente (§6): saludo con avisos, citas en curso, accesos rápidos y consejos de salud.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<SessionProvider>().currentPatient;
    if (patient == null) return const SizedBox.shrink();
    final mine = context.watch<CaseProvider>().casesOfPatient(patient.id);
    NextAction? actionOf(TelemedicineCase c) => nextActionFor(c, UserRole.patient, patientId: patient.id);
    int priority(TelemedicineCase c) => actionOf(c) == null ? 1 : 0;
    final open = [
      for (final c in mine)
        if (c.isOpen) c,
    ];
    // Primero los casos en los que le toca actuar al paciente; después, el movimiento más reciente.
    open.sort((a, b) {
      final byAction = priority(a).compareTo(priority(b));
      return byAction != 0 ? byAction : b.updatedAt.compareTo(a.updatedAt);
    });
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
              NotificationBell(patient: patient),
            ],
          ),
          const SizedBox(height: 20),
          Text(open.isEmpty ? 'Tus citas' : 'Tus citas en curso', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (open.isEmpty)
            const _NoActiveCase()
          else
            for (final c in open)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ActiveCaseCard(telemedicineCase: c, action: actionOf(c)),
              ),
          const SizedBox(height: 16),
          Text('Accesos rápidos', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          _QuickActions(patientCases: mine),
          const SizedBox(height: 20),
          Text('Educación en salud', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const HealthTipsCarousel(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Aviso cuando el paciente no tiene citas en curso.
class _NoActiveCase extends StatelessWidget {
  const _NoActiveCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const AppIllustration(AppIllustrations.emptyCases, width: 80, height: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No tienes citas en curso', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('Pide una consulta virtual cuando la necesites.', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un acceso rápido del Inicio.
class _QuickAction {
  const _QuickAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Accesos rápidos: Solicitar cita, Mis resultados, Servicios y Acerca del proceso.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.patientCases});

  /// Casos del paciente, del más reciente al más antiguo.
  final List<TelemedicineCase> patientCases;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(Icons.edit_calendar, 'Solicitar cita', () => context.push(AppRoutes.requestAppointment())),
      _QuickAction(Icons.receipt_long, 'Mis resultados', () => _openLatestResults(context)),
      _QuickAction(Icons.medical_services_outlined, 'Servicios', () => context.go(AppRoutes.patientServices)),
      _QuickAction(Icons.account_tree_outlined, 'Acerca del proceso', () => context.push(AppRoutes.process)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth >= 560 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [for (final action in actions) _QuickActionTile(action: action)],
        );
      },
    );
  }

  /// Abre los resultados del caso más reciente que los tenga, o avisa que todavía no hay.
  void _openLatestResults(BuildContext context) {
    final withResults = patientCases.where((c) => c.results != null);
    if (withResults.isNotEmpty) {
      context.push(AppRoutes.caseAction(withResults.first.id, CaseAction.results));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => const EmptyState(
        illustration: AppIllustrations.emptyResults,
        title: 'Aún no tienes resultados',
        message: 'Aquí verás tu receta, tus órdenes y tus indicaciones cuando tu médico las emita.',
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Icon(action.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
