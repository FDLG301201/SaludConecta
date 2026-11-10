import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/case_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_body.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';

/// "Mis citas": pestañas Activas e Historial con los casos del paciente.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<SessionProvider>().currentPatient;
    if (patient == null) return const SizedBox.shrink();
    final mine = context.watch<CaseProvider>().casesOfPatient(patient.id);
    final active = [
      for (final c in mine)
        if (c.isOpen) c,
    ];
    final history = [
      for (final c in mine)
        if (!c.isOpen) c,
    ];
    return DefaultTabController(
      length: 2,
      child: PageBody(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mis citas', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            TabBar(
              tabs: [
                Tab(text: 'Activas (${active.length})'),
                Tab(text: 'Historial (${history.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _CaseList(
                    cases: active,
                    empty: EmptyState(
                      illustration: AppIllustrations.emptyCases,
                      title: 'No tienes citas en curso',
                      message: 'Cuando solicites una cita, aquí verás cómo avanza.',
                      action: FilledButton.icon(
                        onPressed: () => context.push(AppRoutes.requestAppointment()),
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('Solicitar cita'),
                      ),
                    ),
                  ),
                  _CaseList(
                    cases: history,
                    empty: const EmptyState(
                      illustration: AppIllustrations.emptyResults,
                      title: 'Aún no tienes historial',
                      message: 'Aquí quedarán tus citas completadas y canceladas.',
                    ),
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

class _CaseList extends StatelessWidget {
  const _CaseList({required this.cases, required this.empty});

  final List<TelemedicineCase> cases;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) return empty;
    final dateStyle = Theme.of(context).textTheme.bodySmall;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: cases.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = cases[index];
        return CaseCard(
          telemedicineCase: c,
          showPatient: false,
          onTap: () => context.push(AppRoutes.caseDetail(c.id)),
          trailing: Text(Formatters.shortDate(c.updatedAt), style: dateStyle),
        );
      },
    );
  }
}
