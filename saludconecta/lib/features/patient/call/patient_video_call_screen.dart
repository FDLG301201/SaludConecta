import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/process/process_step.dart';
import '../../shared/video_call/video_call_view.dart';
import '../patient_case_builder.dart';

/// Videollamada del paciente (paso 7). Es solo visual: el médico es quien finaliza la consulta.
class PatientVideoCallScreen extends StatelessWidget {
  const PatientVideoCallScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        final appointment = c.appointment;
        if (appointment == null || c.status != CaseStatus.active || c.currentStep != ProcessStep.consultation) {
          return const CaseNotice(
            screenTitle: 'Videollamada',
            title: 'La videollamada no está disponible',
            message: 'Tu consulta ya terminó o todavía no está lista.',
          );
        }
        return VideoCallView(
          perspective: CallPerspective.patient,
          doctor: context.read<CatalogRepository>().doctorById(appointment.doctorId),
          patient: patient,
          platform: appointment.platform,
          onHangUp: () => _confirmLeave(context),
        );
      },
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final router = GoRouter.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir de la videollamada?'),
        content: const Text('Tu médico finalizará la consulta y te avisaremos cuando tus resultados estén listos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Seguir en la llamada')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salir')),
        ],
      ),
    );
    if (leave != true) return;
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.caseDetail(caseId));
    }
  }
}
