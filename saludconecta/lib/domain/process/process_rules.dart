import '../models/enums.dart';
import '../models/telemedicine_case.dart';
import 'process_exception.dart';
import 'process_step.dart';

/// Acciones auxiliares: ocurren dentro de un paso, pero no lo completan.
enum AssistAction {
  startConsultation(ProcessStep.consultation, UserRole.doctor, 'iniciar la consulta'),
  submitClaim(ProcessStep.administrativeClosure, UserRole.billing, 'enviar la reclamación'),
  registerPayment(ProcessStep.administrativeClosure, UserRole.billing, 'registrar el pago'),
  logFollowUpCall(ProcessStep.followUp, UserRole.admission, 'registrar una llamada de seguimiento');

  const AssistAction(this.step, this.role, this.label);

  final ProcessStep step;
  final UserRole role;
  final String label;
}

/// Reglas del proceso. Si algo no está permitido, lanzan [ProcessException].
class ProcessRules {
  const ProcessRules._();

  /// [role] quiere completar [step] en el caso [c].
  static void ensureCanPerform(TelemedicineCase c, ProcessStep step, UserRole role) {
    _ensureActive(c);
    if (c.currentStep != step) {
      throw ProcessException(
        'El caso ${c.id} está en el paso ${c.currentStep.number} (${c.currentStep.title}), '
        'no en el paso ${step.number}.',
      );
    }
    if (!step.isOwnedBy(role)) {
      throw ProcessException('${role.label} no puede completar el paso ${step.number} (${step.title}).');
    }
  }

  /// [role] quiere hacer una acción auxiliar del paso actual.
  static void ensureCanAssist(TelemedicineCase c, AssistAction action, UserRole role) {
    _ensureActive(c);
    if (c.currentStep != action.step) {
      throw ProcessException('Solo se puede ${action.label} en el paso ${action.step.number} (${action.step.title}).');
    }
    if (role != action.role) {
      throw ProcessException('${role.label} no puede ${action.label}.');
    }
  }

  /// El paciente puede cancelar mientras el caso esté abierto y no haya pasado del paso 6.
  static bool canPatientCancel(TelemedicineCase c) =>
      c.status.isOpen && c.currentStep.number <= ProcessStep.consentAdmission.number;

  static void ensureCanCancel(TelemedicineCase c, UserRole role) {
    switch (role) {
      case UserRole.patient:
        if (!canPatientCancel(c)) {
          throw const ProcessException('La cita ya no se puede cancelar: la consulta está en curso o ya terminó.');
        }
      case UserRole.admission:
        if (c.status != CaseStatus.insuranceRejected) {
          throw const ProcessException('Admisión solo cancela solicitudes rechazadas por el seguro.');
        }
      case UserRole.doctor || UserRole.billing:
        throw ProcessException('${role.label} no puede cancelar solicitudes.');
    }
  }

  /// Continuar como privado o cancelar tras el rechazo es decisión de Admisión.
  static void ensureCanResolveRejection(TelemedicineCase c, UserRole role) {
    if (c.status != CaseStatus.insuranceRejected) {
      throw const ProcessException('El caso no tiene un rechazo del seguro pendiente.');
    }
    if (role != UserRole.admission) {
      throw ProcessException('${role.label} no puede resolver el rechazo del seguro.');
    }
  }

  static void _ensureActive(TelemedicineCase c) {
    if (c.status != CaseStatus.active) {
      throw ProcessException('El caso ${c.id} está "${c.status.label}" y no admite este cambio.');
    }
  }
}
