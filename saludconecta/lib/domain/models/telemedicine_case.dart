import '../process/process_step.dart';
import 'case_records.dart';
import 'enums.dart';
import 'process_event.dart';

/// El caso de telemedicina: recorre los 10 pasos del proceso.
class TelemedicineCase {
  const TelemedicineCase({
    required this.id,
    required this.patientId,
    required this.serviceId,
    required this.channel,
    required this.reason,
    required this.preferredDate,
    required this.createdAt,
    required this.currentStep,
    required this.status,
    required this.events,
    this.privatePay = false,
    this.reception,
    this.insurance,
    this.appointment,
    this.confirmation,
    this.consent,
    this.consultation,
    this.results,
    this.billing,
    this.followUp,
  });

  /// Identificador, p. ej. "TM-2026-0001".
  final String id;
  final String patientId;
  final String serviceId;
  final RequestChannel channel;

  /// Motivo de consulta escrito por el paciente.
  final String reason;
  final DateTime preferredDate;
  final DateTime createdAt;

  /// Próximo paso PENDIENTE. Al completar el paso 10 se queda en `followUp`.
  final ProcessStep currentStep;
  final CaseStatus status;

  /// Línea de tiempo, en orden cronológico.
  final List<ProcessEvent> events;

  /// `true` si continuó como privado tras el rechazo del seguro.
  final bool privatePay;

  final ReceptionData? reception;
  final InsuranceValidation? insurance;
  final Appointment? appointment;
  final Confirmation? confirmation;
  final ConsentRecord? consent;
  final ConsultationRecord? consultation;
  final ConsultationResults? results;
  final BillingRecord? billing;
  final FollowUpRecord? followUp;

  /// Copia con los campos indicados cambiados; los demás se conservan.
  TelemedicineCase copyWith({
    ProcessStep? currentStep,
    CaseStatus? status,
    List<ProcessEvent>? events,
    bool? privatePay,
    ReceptionData? reception,
    InsuranceValidation? insurance,
    Appointment? appointment,
    Confirmation? confirmation,
    ConsentRecord? consent,
    ConsultationRecord? consultation,
    ConsultationResults? results,
    BillingRecord? billing,
    FollowUpRecord? followUp,
  }) {
    return TelemedicineCase(
      id: id,
      patientId: patientId,
      serviceId: serviceId,
      channel: channel,
      reason: reason,
      preferredDate: preferredDate,
      createdAt: createdAt,
      currentStep: currentStep ?? this.currentStep,
      status: status ?? this.status,
      events: events ?? this.events,
      privatePay: privatePay ?? this.privatePay,
      reception: reception ?? this.reception,
      insurance: insurance ?? this.insurance,
      appointment: appointment ?? this.appointment,
      confirmation: confirmation ?? this.confirmation,
      consent: consent ?? this.consent,
      consultation: consultation ?? this.consultation,
      results: results ?? this.results,
      billing: billing ?? this.billing,
      followUp: followUp ?? this.followUp,
    );
  }

  /// Pasos completados, según los eventos que completan paso.
  Set<ProcessStep> get completedSteps => {
        for (final e in events)
          if (e.completesStep) e.step,
      };

  bool isStepCompleted(ProcessStep step) => events.any((e) => e.completesStep && e.step == step);

  /// Momento en que se completó [step], o `null` si no se ha completado.
  DateTime? completedAt(ProcessStep step) {
    for (final e in events) {
      if (e.completesStep && e.step == step) return e.at;
    }
    return null;
  }

  bool get isOpen => status.isOpen;

  /// Momento del último cambio.
  DateTime get updatedAt => events.isEmpty ? createdAt : events.last.at;
}
