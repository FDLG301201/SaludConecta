import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_step.dart';

/// Filtros de la bandeja de Admisión: uno por paso pendiente (los rechazados quedan en el paso 3).
enum AdmissionFilter {
  all('Todas', null),
  newRequests('Nuevas', ProcessStep.reception),
  toValidate('Por validar', ProcessStep.insuranceValidation),
  toSchedule('Por agendar', ProcessStep.scheduling),
  toConfirm('Por confirmar', ProcessStep.patientConfirmation);

  const AdmissionFilter(this.label, this.step);

  final String label;

  /// Paso pendiente que muestra el filtro; `null` = todos.
  final ProcessStep? step;

  bool matches(TelemedicineCase c) => step == null || c.currentStep == step;
}
