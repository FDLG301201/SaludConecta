import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_step.dart';

/// Lo que un rol puede hacer ahora con un caso: el texto del botón, la ruta y el ícono.
class NextAction {
  const NextAction({required this.label, required this.route, required this.icon});

  final String label;
  final String route;
  final IconData icon;
}

/// Próxima acción de [role] sobre el caso, o `null` si le toca a otro actor o si el caso terminó.
/// [patientId] y [doctorId] son de quien tiene la sesión: solo actúa sobre sus propios casos.
NextAction? nextActionFor(TelemedicineCase c, UserRole role, {String? patientId, String? doctorId}) {
  String action(CaseAction a) => AppRoutes.caseAction(c.id, a);
  if (c.status == CaseStatus.insuranceRejected) {
    return role == UserRole.admission
        ? NextAction(label: 'Resolver el rechazo del seguro', route: action(CaseAction.process), icon: Icons.rule)
        : null;
  }
  if (c.status != CaseStatus.active) return null;
  final ownCase = patientId != null && c.patientId == patientId;
  final assigned = doctorId != null && c.appointment?.doctorId == doctorId;
  return switch ((role, c.currentStep)) {
    (
      UserRole.admission,
      ProcessStep.reception ||
          ProcessStep.insuranceValidation ||
          ProcessStep.scheduling ||
          ProcessStep.patientConfirmation
    ) =>
      NextAction(label: 'Procesar solicitud', route: action(CaseAction.process), icon: Icons.playlist_add_check),
    (UserRole.admission, ProcessStep.followUp) =>
      const NextAction(label: 'Registrar llamada de seguimiento', route: AppRoutes.admissionFollowUp, icon: Icons.call),
    (UserRole.patient, ProcessStep.consentAdmission) when ownCase =>
      NextAction(label: 'Firmar consentimiento', route: action(CaseAction.consent), icon: Icons.draw),
    (UserRole.patient, ProcessStep.consultation) when ownCase =>
      NextAction(label: 'Ir a la sala de espera', route: action(CaseAction.waitingRoom), icon: Icons.meeting_room),
    (UserRole.patient, ProcessStep.followUp) when ownCase =>
      NextAction(label: 'Responder la encuesta', route: action(CaseAction.survey), icon: Icons.star_rate),
    (UserRole.doctor, ProcessStep.consultation) when assigned =>
      NextAction(label: 'Iniciar consulta', route: action(CaseAction.consultation), icon: Icons.video_call),
    (UserRole.doctor, ProcessStep.consultationResult) when assigned =>
      NextAction(label: 'Emitir resultados', route: action(CaseAction.issueResults), icon: Icons.receipt_long),
    (UserRole.billing, ProcessStep.administrativeClosure) =>
      NextAction(label: 'Cierre administrativo', route: action(CaseAction.closure), icon: Icons.request_quote),
    _ => null,
  };
}

/// Texto cuando el paso le toca a otro actor, p. ej. "Esperando a Admisión: Agendamiento".
String waitingText(TelemedicineCase c) {
  final step = c.currentStep;
  final who = switch (step.owners.first) {
    UserRole.patient => 'al paciente',
    UserRole.admission => 'a Admisión',
    UserRole.doctor => 'al médico',
    UserRole.billing => 'a Facturación',
  };
  return 'Esperando $who: ${step.title}';
}
