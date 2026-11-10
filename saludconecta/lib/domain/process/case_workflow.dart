import '../models/case_records.dart';
import '../models/catalog.dart';
import '../models/enums.dart';
import '../models/people.dart';
import '../models/process_event.dart';
import '../models/telemedicine_case.dart';
import '../services/billing_calculator.dart';
import '../services/case_codes.dart';
import 'process_exception.dart';
import 'process_rules.dart';
import 'process_step.dart';

/// Transiciones del proceso. Cada función valida con [ProcessRules] y devuelve un caso
/// NUEVO (los modelos son inmutables) con su evento al final de la línea de tiempo.
///
/// Las usan el `CaseProvider` (acciones en vivo) y el generador de datos semilla (históricos).
class CaseWorkflow {
  const CaseWorkflow._();

  /// Instrucciones que acompañan el enlace de la videollamada (paso 5).
  static const confirmationInstructions = 'Ingresa 10 minutos antes. Firma tu consentimiento en la app.';

  // ----- Paso 1: solicitud de cita -----

  static TelemedicineCase request({
    required String id,
    required Patient patient,
    required MedicalService service,
    required RequestChannel channel,
    required String reason,
    required DateTime preferredDate,
    required DateTime at,
  }) {
    if (!service.requestable) {
      throw ProcessException('"${service.name}" no se solicita directamente: se genera durante el proceso.');
    }
    if (reason.trim().length < 10) {
      throw const ProcessException('Describe el motivo de consulta con al menos 10 caracteres.');
    }
    return TelemedicineCase(
      id: id,
      patientId: patient.id,
      serviceId: service.id,
      channel: channel,
      reason: reason.trim(),
      preferredDate: preferredDate,
      createdAt: at,
      currentStep: ProcessStep.reception,
      status: CaseStatus.active,
      events: [
        ProcessEvent(
          step: ProcessStep.requestAppointment,
          actor: Actor.patient,
          actorName: patient.fullName,
          at: at,
          title: 'Solicitud enviada por ${channel.label}',
          detail: service.name,
        ),
      ],
    );
  }

  // ----- Paso 2: recepción -----

  static TelemedicineCase registerReception(
    TelemedicineCase c, {
    required String staffName,
    String notes = '',
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.reception, UserRole.admission);
    return c.copyWith(
      reception: ReceptionData(registeredBy: staffName, notes: notes.trim()),
      currentStep: ProcessStep.insuranceValidation,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.reception,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Solicitud registrada',
          detail: notes.trim(),
        ),
      ],
    );
  }

  // ----- Paso 3: validación con el seguro -----

  /// Aplica la respuesta del seguro. Si la rechaza, el caso queda en `insuranceRejected` en el paso 3.
  static TelemedicineCase applyInsuranceResult(
    TelemedicineCase c, {
    required InsuranceValidation result,
    required String staffName,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.insuranceValidation, UserRole.admission);
    if (result.approved) {
      return c.copyWith(
        insurance: result,
        currentStep: ProcessStep.scheduling,
        events: [
          ...c.events,
          ProcessEvent(
            step: ProcessStep.insuranceValidation,
            actor: Actor.admission,
            actorName: staffName,
            at: result.at,
            title: 'Seguro aprobado: ${result.coveragePercent}% de cobertura',
            detail: result.authorizationNumber ?? '',
          ),
        ],
      );
    }
    return c.copyWith(
      insurance: result,
      status: CaseStatus.insuranceRejected,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.insuranceValidation,
          actor: Actor.admission,
          actorName: staffName,
          at: result.at,
          title: 'Seguro rechazado',
          detail: result.message,
          kind: EventKind.rejected,
        ),
      ],
    );
  }

  /// Tras el rechazo: el paciente paga el 100% y el caso sigue al paso 4.
  static TelemedicineCase continueAsPrivate(TelemedicineCase c, {required String staffName, required DateTime at}) {
    ProcessRules.ensureCanResolveRejection(c, UserRole.admission);
    return c.copyWith(
      privatePay: true,
      status: CaseStatus.active,
      currentStep: ProcessStep.scheduling,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.insuranceValidation,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Paciente privado (100%)',
          detail: 'Continúa sin cobertura del seguro',
        ),
      ],
    );
  }

  /// Cancela la solicitud: el paciente, hasta el paso 6; Admisión, tras un rechazo del seguro.
  static TelemedicineCase cancel(
    TelemedicineCase c, {
    required UserRole role,
    required String actorName,
    required DateTime at,
    String reason = '',
  }) {
    ProcessRules.ensureCanCancel(c, role);
    return c.copyWith(
      status: CaseStatus.cancelled,
      events: [
        ...c.events,
        ProcessEvent(
          step: c.currentStep,
          actor: role.actor,
          actorName: actorName,
          at: at,
          title: 'Solicitud cancelada',
          detail: reason.trim(),
          kind: EventKind.cancelled,
        ),
      ],
    );
  }

  // ----- Paso 4: agendamiento -----

  static TelemedicineCase schedule(
    TelemedicineCase c, {
    required Doctor doctor,
    required DateTime dateTime,
    required VideoPlatform platform,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.scheduling, UserRole.admission);
    return c.copyWith(
      appointment: Appointment(doctorId: doctor.id, dateTime: dateTime, platform: platform),
      currentStep: ProcessStep.patientConfirmation,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.scheduling,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Cita agendada con ${doctor.displayName}',
          detail: platform.label,
        ),
      ],
    );
  }

  // ----- Paso 5: confirmación al paciente -----

  static TelemedicineCase confirm(
    TelemedicineCase c, {
    required String link,
    required RequestChannel via,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.patientConfirmation, UserRole.admission);
    if (via != RequestChannel.whatsapp && via != RequestChannel.email) {
      throw const ProcessException('La confirmación se envía por WhatsApp o por correo.');
    }
    return c.copyWith(
      confirmation: Confirmation(link: link, sentVia: via, instructions: confirmationInstructions, at: at),
      currentStep: ProcessStep.consentAdmission,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.patientConfirmation,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Enlace enviado por ${via.label}',
          detail: link,
        ),
      ],
    );
  }

  // ----- Paso 6: consentimiento y admisión virtual -----

  static TelemedicineCase signConsent(
    TelemedicineCase c, {
    required Patient patient,
    required bool acceptedTerms,
    required bool acceptedDataUse,
    required bool identityConfirmed,
    required List<List<SignaturePoint>> signature,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.consentAdmission, UserRole.patient);
    _ensureOwnPatient(c, patient);
    if (!acceptedTerms || !acceptedDataUse || !identityConfirmed) {
      throw const ProcessException('Marca las tres casillas del consentimiento.');
    }
    if (!signature.any((stroke) => stroke.length >= 2)) {
      throw const ProcessException('La firma es obligatoria.');
    }
    return c.copyWith(
      consent: ConsentRecord(at: at, identityConfirmed: true, signature: signature),
      currentStep: ProcessStep.consultation,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.consentAdmission,
          actor: Actor.patient,
          actorName: patient.fullName,
          at: at,
          title: 'Consentimiento firmado',
          detail: 'Identidad confirmada y admisión virtual completa',
        ),
      ],
    );
  }

  // ----- Paso 7: consulta de telemedicina -----

  /// Acción auxiliar: el médico abre la consulta (no completa el paso).
  static TelemedicineCase startConsultation(TelemedicineCase c, {required Doctor doctor, required DateTime at}) {
    ProcessRules.ensureCanAssist(c, AssistAction.startConsultation, UserRole.doctor);
    _ensureAssignedDoctor(c, doctor);
    if (c.consultation != null) return c; // Ya estaba iniciada.
    return c.copyWith(
      consultation: ConsultationRecord(startedAt: at),
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.consultation,
          actor: Actor.doctor,
          actorName: doctor.displayName,
          at: at,
          title: 'Consulta iniciada',
          detail: c.appointment!.platform.label,
          kind: EventKind.started,
        ),
      ],
    );
  }

  static TelemedicineCase finishConsultation(
    TelemedicineCase c, {
    required Doctor doctor,
    required ClinicalNotes notes,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.consultation, UserRole.doctor);
    _ensureAssignedDoctor(c, doctor);
    final started = c.consultation;
    if (started == null) {
      throw const ProcessException('Primero inicia la consulta.');
    }
    if (!notes.isComplete) {
      throw const ProcessException('Escribe el motivo de consulta y el diagnóstico antes de finalizar.');
    }
    return c.copyWith(
      consultation: ConsultationRecord(startedAt: started.startedAt, endedAt: at, notes: notes),
      currentStep: ProcessStep.consultationResult,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.consultation,
          actor: Actor.doctor,
          actorName: doctor.displayName,
          at: at,
          title: 'Consulta realizada',
          detail: 'Diagnóstico: ${notes.diagnosis.trim()}',
        ),
      ],
    );
  }

  // ----- Paso 8: resultado de la consulta -----

  static TelemedicineCase issueResults(
    TelemedicineCase c, {
    required Doctor doctor,
    required String instructions,
    List<PrescriptionItem> medications = const [],
    List<MedicalOrder> orders = const [],
    Referral? referral,
    int? followUpInDays,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.consultationResult, UserRole.doctor);
    _ensureAssignedDoctor(c, doctor);
    if (instructions.trim().isEmpty) {
      throw const ProcessException('Las indicaciones son obligatorias.');
    }
    final results = ConsultationResults(
      instructions: instructions.trim(),
      prescription:
          medications.isEmpty ? null : Prescription(items: medications, verificationCode: CaseCodes.prescription(c.id)),
      orders: orders,
      referral: referral,
      followUpInDays: followUpInDays,
    );
    return c.copyWith(
      results: results,
      currentStep: ProcessStep.administrativeClosure,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.consultationResult,
          actor: Actor.doctor,
          actorName: doctor.displayName,
          at: at,
          title: 'Resultados emitidos',
          detail: _resultsSummary(results),
        ),
      ],
    );
  }

  // ----- Paso 9: cierre administrativo -----

  /// Acción auxiliar: registra la reclamación al seguro y su respuesta.
  static TelemedicineCase recordClaim(
    TelemedicineCase c, {
    required MedicalService service,
    required String claimNumber,
    required ClaimStatus status,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanAssist(c, AssistAction.submitClaim, UserRole.billing);
    final invoice = BillingCalculator.invoiceFor(c, service);
    if (invoice.insurerAmount == 0) {
      throw const ProcessException('No aplica reclamación: el paciente es privado.');
    }
    final billing = (c.billing ?? BillingRecord(invoice: invoice, claimStatus: ClaimStatus.pending))
        .copyWith(claimStatus: status, claimNumber: claimNumber);
    return c.copyWith(
      billing: billing,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.administrativeClosure,
          actor: Actor.billing,
          actorName: staffName,
          at: at,
          title: 'Reclamación ${status.label.toLowerCase()}',
          detail: claimNumber,
          kind: EventKind.claim,
        ),
      ],
    );
  }

  /// Acción auxiliar: registra el pago del copago (solo el método; nunca datos de tarjeta).
  static TelemedicineCase registerPayment(
    TelemedicineCase c, {
    required MedicalService service,
    required PaymentMethod method,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanAssist(c, AssistAction.registerPayment, UserRole.billing);
    final invoice = BillingCalculator.invoiceFor(c, service);
    if (invoice.copay == 0) {
      throw const ProcessException('No hay copago que cobrar.');
    }
    if (c.billing?.payment != null) {
      throw const ProcessException('El pago ya está registrado.');
    }
    final billing =
        (c.billing ?? BillingRecord(invoice: invoice, claimStatus: BillingCalculator.claimStatusOf(c, invoice)))
            .copyWith(payment: Payment(method: method, amount: invoice.copay, at: at));
    return c.copyWith(
      billing: billing,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.administrativeClosure,
          actor: Actor.billing,
          actorName: staffName,
          at: at,
          title: 'Copago registrado',
          detail: 'Pagado con ${method.label.toLowerCase()}',
          kind: EventKind.payment,
        ),
      ],
    );
  }

  static TelemedicineCase closeAdministratively(
    TelemedicineCase c, {
    required MedicalService service,
    required String staffName,
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.administrativeClosure, UserRole.billing);
    final invoice = BillingCalculator.invoiceFor(c, service);
    if (!BillingCalculator.canClose(c, invoice)) {
      throw const ProcessException('Aún no se puede cerrar: revisa la auditoría, la reclamación y el pago.');
    }
    final billing =
        (c.billing ?? BillingRecord(invoice: invoice, claimStatus: BillingCalculator.claimStatusOf(c, invoice)))
            .copyWith(closedAt: at);
    return c.copyWith(
      billing: billing,
      currentStep: ProcessStep.followUp,
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.administrativeClosure,
          actor: Actor.billing,
          actorName: staffName,
          at: at,
          title: 'Cierre administrativo completado',
          detail: 'Factura, reclamación, auditoría y pago',
        ),
      ],
    );
  }

  // ----- Paso 10: seguimiento al paciente -----

  /// Acción auxiliar: Admisión registra una llamada de seguimiento.
  static TelemedicineCase logFollowUpCall(
    TelemedicineCase c, {
    required String staffName,
    required String note,
    required DateTime at,
  }) {
    ProcessRules.ensureCanAssist(c, AssistAction.logFollowUpCall, UserRole.admission);
    if (note.trim().isEmpty) {
      throw const ProcessException('Escribe una nota de la llamada.');
    }
    final record = c.followUp ?? const FollowUpRecord();
    return c.copyWith(
      followUp: record.copyWith(calls: [...record.calls, FollowUpCall(at: at, byName: staffName, note: note.trim())]),
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.followUp,
          actor: Actor.admission,
          actorName: staffName,
          at: at,
          title: 'Llamada de seguimiento',
          detail: note.trim(),
          kind: EventKind.call,
        ),
      ],
    );
  }

  /// El paciente responde la encuesta: completa el paso 10 y el caso.
  static TelemedicineCase submitSurvey(
    TelemedicineCase c, {
    required Patient patient,
    required int rating,
    required int nps,
    String comment = '',
    required DateTime at,
  }) {
    ProcessRules.ensureCanPerform(c, ProcessStep.followUp, UserRole.patient);
    _ensureOwnPatient(c, patient);
    if (rating < 1 || rating > 5) {
      throw const ProcessException('Elige de 1 a 5 estrellas.');
    }
    if (nps < 0 || nps > 10) {
      throw const ProcessException('La recomendación va de 0 a 10.');
    }
    final record = c.followUp ?? const FollowUpRecord();
    return c.copyWith(
      status: CaseStatus.completed,
      followUp: record.copyWith(survey: Survey(rating: rating, nps: nps, comment: comment.trim(), at: at)),
      events: [
        ...c.events,
        ProcessEvent(
          step: ProcessStep.followUp,
          actor: Actor.patient,
          actorName: patient.fullName,
          at: at,
          title: 'Encuesta respondida: $rating de 5 estrellas',
          detail: comment.trim(),
        ),
      ],
    );
  }

  // ----- Ayudantes -----

  static void _ensureOwnPatient(TelemedicineCase c, Patient patient) {
    if (patient.id != c.patientId) {
      throw const ProcessException('Este caso pertenece a otro paciente.');
    }
  }

  static void _ensureAssignedDoctor(TelemedicineCase c, Doctor doctor) {
    if (c.appointment?.doctorId != doctor.id) {
      throw const ProcessException('La cita está asignada a otro médico.');
    }
  }

  /// Resumen para la línea de tiempo, p. ej. "Receta (2) · Laboratorio (1) · Seguimiento en 15 días".
  static String _resultsSummary(ConsultationResults r) {
    final lab = r.ordersOf(OrderType.lab).length;
    final imaging = r.ordersOf(OrderType.imaging).length;
    final parts = <String>[
      if (r.prescription != null) 'Receta (${r.prescription!.items.length})',
      if (lab > 0) 'Laboratorio ($lab)',
      if (imaging > 0) 'Imágenes ($imaging)',
      if (r.referral != null) 'Referimiento a ${r.referral!.specialty.label}',
      if (r.followUpInDays != null) 'Seguimiento en ${r.followUpInDays} días',
    ];
    return parts.isEmpty ? 'Indicaciones' : parts.join(' · ');
  }
}
