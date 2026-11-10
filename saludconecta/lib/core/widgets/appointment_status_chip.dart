import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_step.dart';
import '../theme/app_colors.dart';

/// Estado de una cita en las agendas de Admisión y del médico.
class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  /// Texto del estado según el paso pendiente del caso.
  static String labelOf(TelemedicineCase c) {
    if (c.status == CaseStatus.cancelled) return 'Cancelada';
    if (c.status == CaseStatus.completed) return 'Atendida';
    return switch (c.currentStep) {
      ProcessStep.patientConfirmation => 'Por confirmar',
      ProcessStep.consentAdmission => 'Esperando consentimiento',
      ProcessStep.consultation => 'Paciente en sala de espera',
      ProcessStep.consultationResult => 'Resultados pendientes',
      ProcessStep.administrativeClosure || ProcessStep.followUp => 'Atendida',
      _ => c.currentStep.title,
    };
  }

  static Color colorOf(TelemedicineCase c) {
    if (c.status == CaseStatus.cancelled) return AppColors.danger;
    if (c.status == CaseStatus.completed || c.currentStep.number >= ProcessStep.administrativeClosure.number) {
      return AppColors.done;
    }
    return AppColors.forActor(c.currentStep.actor);
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(telemedicineCase);
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          labelOf(telemedicineCase),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
