import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_illustrations.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/seed/seed_catalog.dart';
import '../../../domain/models/case_records.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/process/process_step.dart';
import '../patient_case_builder.dart';
import 'prescription_document.dart';

/// Resultados de la consulta (paso 8): receta con QR, órdenes, referimiento, indicaciones
/// y, si el médico la indicó, la cita de seguimiento.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        final results = c.results;
        final appointment = c.appointment;
        if (results == null || appointment == null) {
          return const CaseNotice(
            screenTitle: 'Mis resultados',
            title: 'Aún no hay resultados',
            message: 'Tu médico los emitirá al terminar la consulta.',
            illustration: AppIllustrations.emptyResults,
          );
        }
        final doctor = context.read<CatalogRepository>().doctorById(appointment.doctorId);
        final issuedAt = c.completedAt(ProcessStep.consultationResult) ?? c.updatedAt;
        final prescription = results.prescription;
        final labs = results.ordersOf(OrderType.lab);
        final imaging = results.ordersOf(OrderType.imaging);
        final referral = results.referral;
        final followUpDays = results.followUpInDays;
        return Scaffold(
          appBar: AppBar(title: const Text('Mis resultados')),
          body: PageBody(
            child: ListView(
              children: [
                if (prescription != null)
                  PrescriptionDocument(
                    caseId: c.id,
                    prescription: prescription,
                    doctor: doctor,
                    patient: patient,
                    issuedAt: issuedAt,
                  )
                else
                  const SectionCard(
                    title: 'Receta',
                    icon: Icons.medication_outlined,
                    child: Text('Tu médico no indicó medicamentos en esta consulta.'),
                  ),
                if (labs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _OrdersCard(title: 'Órdenes de laboratorio', icon: Icons.science_outlined, orders: labs),
                ],
                if (imaging.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _OrdersCard(title: 'Órdenes de imágenes', icon: Icons.image_search, orders: imaging),
                ],
                if (referral != null) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Referimiento',
                    icon: Icons.alt_route,
                    child: Text('${referral.specialty.label} (consulta presencial): ${referral.reason}'),
                  ),
                ],
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Indicaciones',
                  icon: Icons.assignment_outlined,
                  child: Text(results.instructions),
                ),
                if (followUpDays != null) ...[
                  const SizedBox(height: 12),
                  _FollowUpCard(days: followUpDays, issuedAt: issuedAt),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrdersCard extends StatelessWidget {
  const _OrdersCard({required this.title, required this.icon, required this.orders});

  final String title;
  final IconData icon;
  final List<MedicalOrder> orders;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      icon: icon,
      child: Column(
        children: [
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outlined, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.description)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// La cita de seguimiento que indicó el médico: abre el asistente con el servicio y la fecha sugerida.
class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.days, required this.issuedAt});

  final int days;
  final DateTime issuedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggested = DateTime(issuedAt.year, issuedAt.month, issuedAt.day + days);
    return Card(
      color: AppColors.secondary.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próxima cita', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Tu médico recomienda una cita de seguimiento en $days días.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              // "Seguimiento postconsulta" es el servicio de las citas de seguimiento.
              onPressed: () => context.push(
                AppRoutes.requestAppointment(serviceId: SeedIds.postConsultFollowUp, preferredDate: suggested),
              ),
              icon: const Icon(Icons.event_repeat),
              label: const Text('Solicitar cita de seguimiento'),
            ),
          ],
        ),
      ),
    );
  }
}
