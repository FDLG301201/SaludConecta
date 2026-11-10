import 'package:flutter/foundation.dart';

import '../data/gateways/confirmation_gateway.dart';
import '../data/gateways/insurance_gateway.dart';
import '../data/repositories/case_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../domain/models/case_records.dart';
import '../domain/models/catalog.dart';
import '../domain/models/enums.dart';
import '../domain/models/people.dart';
import '../domain/models/telemedicine_case.dart';
import '../domain/process/case_workflow.dart';
import '../domain/process/process_exception.dart';
import '../domain/process/process_rules.dart';
import '../domain/process/process_step.dart';
import '../domain/services/billing_calculator.dart';
import '../domain/services/clock.dart';
import '../domain/services/schedule_service.dart';

/// Estado de los casos de telemedicina (§5 del spec).
///
/// La UI lee los casos y llama a una acción por cada transición. Cada acción:
/// 1. valida con las reglas del dominio (lanza `ProcessException` si no se puede);
/// 2. obtiene el caso nuevo con `CaseWorkflow` (los modelos son inmutables);
/// 3. lo guarda en el repositorio;
/// 4. llama a `notifyListeners()` para que las pantallas se vuelvan a dibujar.
class CaseProvider extends ChangeNotifier {
  CaseProvider({
    required this.catalog,
    required CaseRepository repository,
    required InsuranceGateway insurance,
    required ConfirmationGateway confirmation,
    Clock clock = DateTime.now,
  })  : _repository = repository,
        _insurance = insurance,
        _confirmation = confirmation,
        _clock = clock;

  final CatalogRepository catalog;
  final CaseRepository _repository;
  final InsuranceGateway _insurance;
  final ConfirmationGateway _confirmation;
  final Clock _clock;

  /// Casos con una operación lenta en curso (seguro, envío del enlace, reclamación).
  final _busy = <String>{};

  static const _admissionSteps = {
    ProcessStep.reception,
    ProcessStep.insuranceValidation,
    ProcessStep.scheduling,
    ProcessStep.patientConfirmation,
  };
  static const _doctorSteps = {ProcessStep.consentAdmission, ProcessStep.consultation, ProcessStep.consultationResult};

  // ----- Lectura -----

  List<TelemedicineCase> get cases => _repository.getAll();

  TelemedicineCase? caseById(String id) => _repository.getById(id);

  /// Hora actual según el reloj de la app (fija en las pruebas).
  DateTime get now => _clock();

  /// `true` mientras una operación lenta está en curso: la UI muestra carga y deshabilita botones.
  bool isBusy(String caseId) => _busy.contains(caseId);

  /// Casos que le toca atender a cada rol.
  List<TelemedicineCase> inboxFor(UserRole role, {String? patientId, String? doctorId}) => switch (role) {
        UserRole.patient => casesOfPatient(patientId ?? ''),
        UserRole.admission => admissionInbox(),
        UserRole.doctor => doctorAgenda(doctorId ?? ''),
        UserRole.billing => billingInbox(),
      };

  /// Casos del paciente, del movimiento más reciente al más antiguo.
  List<TelemedicineCase> casesOfPatient(String patientId) {
    final result = [
      for (final c in cases)
        if (c.patientId == patientId) c,
    ];
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  /// Admisión: pasos 2 a 5 pendientes (incluye los rechazados por el seguro), el más antiguo primero.
  List<TelemedicineCase> admissionInbox() => _oldestFirst([
        for (final c in cases)
          if (c.isOpen && _admissionSteps.contains(c.currentStep)) c,
      ]);

  /// Admisión: casos en el paso 10 (llamadas de seguimiento y encuesta pendiente).
  List<TelemedicineCase> followUpCases() => _oldestFirst([
        for (final c in cases)
          if (c.status == CaseStatus.active && c.currentStep == ProcessStep.followUp) c,
      ]);

  /// Médico: sus citas con los pasos 6, 7 u 8 pendientes, por fecha de la cita.
  List<TelemedicineCase> doctorAgenda(String doctorId) {
    final result = [
      for (final c in cases)
        if (c.status == CaseStatus.active &&
            _doctorSteps.contains(c.currentStep) &&
            c.appointment?.doctorId == doctorId)
          c,
    ];
    result.sort((a, b) => a.appointment!.dateTime.compareTo(b.appointment!.dateTime));
    return result;
  }

  /// Facturación: casos con el paso 9 pendiente.
  List<TelemedicineCase> billingInbox() => _oldestFirst([
        for (final c in cases)
          if (c.status == CaseStatus.active && c.currentStep == ProcessStep.administrativeClosure) c,
      ]);

  /// Factura del caso según la tarifa del servicio y la cobertura del seguro.
  Invoice invoiceFor(TelemedicineCase c) => BillingCalculator.invoiceFor(c, catalog.serviceById(c.serviceId));

  // ----- Acciones: una por transición del proceso -----

  /// Paso 1: el paciente pide una cita. Devuelve el caso creado.
  TelemedicineCase requestAppointment({
    required Patient patient,
    required MedicalService service,
    required RequestChannel channel,
    required String reason,
    required DateTime preferredDate,
  }) {
    final at = _clock();
    return _save(CaseWorkflow.request(
      id: _repository.nextId(at),
      patient: patient,
      service: service,
      channel: channel,
      reason: reason,
      preferredDate: preferredDate,
      at: at,
    ));
  }

  /// Paso 2: Admisión registra la solicitud.
  TelemedicineCase registerReception(String caseId, {required StaffMember staff, String notes = ''}) => _update(
        caseId,
        (c) => CaseWorkflow.registerReception(c, staffName: staff.fullName, notes: notes, at: _clock()),
      );

  /// Paso 3: consulta al seguro (operación lenta). Si rechaza, el caso queda "Rechazado por el seguro".
  Future<InsuranceValidation> validateInsurance(String caseId, {required StaffMember staff}) async {
    final c = _require(caseId);
    ProcessRules.ensureCanPerform(c, ProcessStep.insuranceValidation, UserRole.admission);
    return _whileBusy(caseId, () async {
      final result = await _insurance.validate(
        patient: catalog.patientById(c.patientId),
        service: catalog.serviceById(c.serviceId),
        caseId: caseId,
      );
      _update(caseId, (latest) => CaseWorkflow.applyInsuranceResult(latest, result: result, staffName: staff.fullName));
      return result;
    });
  }

  /// Paso 3, tras el rechazo: el paciente continúa como privado (paga el 100%).
  TelemedicineCase continueAsPrivate(String caseId, {required StaffMember staff}) =>
      _update(caseId, (c) => CaseWorkflow.continueAsPrivate(c, staffName: staff.fullName, at: _clock()));

  /// Cancela la solicitud: el paciente (hasta el paso 6) o Admisión (tras un rechazo del seguro).
  TelemedicineCase cancelCase(
    String caseId, {
    required UserRole role,
    required String actorName,
    String reason = '',
  }) =>
      _update(caseId, (c) => CaseWorkflow.cancel(c, role: role, actorName: actorName, at: _clock(), reason: reason));

  /// Paso 4: agenda la cita. El médico debe atender la especialidad del servicio y el turno debe seguir libre.
  TelemedicineCase scheduleAppointment(
    String caseId, {
    required StaffMember staff,
    required Doctor doctor,
    required DateTime dateTime,
    required VideoPlatform platform,
  }) {
    return _update(caseId, (c) {
      ProcessRules.ensureCanPerform(c, ProcessStep.scheduling, UserRole.admission);
      final service = catalog.serviceById(c.serviceId);
      if (service.specialty != doctor.specialty) {
        throw ProcessException('${doctor.displayName} no atiende ${service.name}.');
      }
      final free = ScheduleService.availableSlots(doctor: doctor, day: dateTime, cases: cases, now: _clock());
      if (!free.contains(dateTime)) {
        throw const ProcessException('Ese horario ya no está disponible. Elige otro.');
      }
      return CaseWorkflow.schedule(
        c,
        doctor: doctor,
        dateTime: dateTime,
        platform: platform,
        staffName: staff.fullName,
        at: _clock(),
      );
    });
  }

  /// Paso 5: envía el enlace por WhatsApp o correo (operación lenta). Devuelve el enlace.
  Future<String> sendConfirmation(String caseId, {required StaffMember staff, required RequestChannel via}) async {
    final c = _require(caseId);
    ProcessRules.ensureCanPerform(c, ProcessStep.patientConfirmation, UserRole.admission);
    return _whileBusy(caseId, () async {
      final link = await _confirmation.send(caseId: caseId, platform: c.appointment!.platform, via: via);
      _update(
        caseId,
        (latest) => CaseWorkflow.confirm(latest, link: link, via: via, staffName: staff.fullName, at: _clock()),
      );
      return link;
    });
  }

  /// Paso 6: el paciente firma el consentimiento.
  TelemedicineCase signConsent(
    String caseId, {
    required Patient patient,
    required bool acceptedTerms,
    required bool acceptedDataUse,
    required bool identityConfirmed,
    required List<List<SignaturePoint>> signature,
  }) =>
      _update(
        caseId,
        (c) => CaseWorkflow.signConsent(
          c,
          patient: patient,
          acceptedTerms: acceptedTerms,
          acceptedDataUse: acceptedDataUse,
          identityConfirmed: identityConfirmed,
          signature: signature,
          at: _clock(),
        ),
      );

  /// Paso 7 (auxiliar): el médico abre la consulta. En modo demo no espera la hora agendada.
  TelemedicineCase startConsultation(String caseId, {required Doctor doctor}) =>
      _update(caseId, (c) => CaseWorkflow.startConsultation(c, doctor: doctor, at: _clock()));

  /// Paso 7: el médico finaliza la consulta con sus notas clínicas.
  TelemedicineCase finishConsultation(String caseId, {required Doctor doctor, required ClinicalNotes notes}) =>
      _update(caseId, (c) => CaseWorkflow.finishConsultation(c, doctor: doctor, notes: notes, at: _clock()));

  /// Paso 8: el médico emite receta, órdenes, referimiento e indicaciones.
  TelemedicineCase issueResults(
    String caseId, {
    required Doctor doctor,
    required String instructions,
    List<PrescriptionItem> medications = const [],
    List<MedicalOrder> orders = const [],
    Referral? referral,
    int? followUpInDays,
  }) =>
      _update(
        caseId,
        (c) => CaseWorkflow.issueResults(
          c,
          doctor: doctor,
          instructions: instructions,
          medications: medications,
          orders: orders,
          referral: referral,
          followUpInDays: followUpInDays,
          at: _clock(),
        ),
      );

  /// Paso 9 (auxiliar, operación lenta): envía la reclamación al seguro. En vivo siempre se aprueba.
  Future<String> submitClaim(String caseId, {required StaffMember staff}) async {
    final c = _require(caseId);
    ProcessRules.ensureCanAssist(c, AssistAction.submitClaim, UserRole.billing);
    if (invoiceFor(c).insurerAmount == 0) {
      throw const ProcessException('No aplica reclamación: el paciente es privado.');
    }
    return _whileBusy(caseId, () async {
      final number = await _insurance.submitClaim(caseId: caseId);
      _update(
        caseId,
        (latest) => CaseWorkflow.recordClaim(
          latest,
          service: catalog.serviceById(latest.serviceId),
          claimNumber: number,
          status: ClaimStatus.approved,
          staffName: staff.fullName,
          at: _clock(),
        ),
      );
      return number;
    });
  }

  /// Paso 9 (auxiliar): registra el pago del copago (solo el método, nunca datos de tarjeta).
  TelemedicineCase registerPayment(String caseId, {required StaffMember staff, required PaymentMethod method}) =>
      _update(
        caseId,
        (c) => CaseWorkflow.registerPayment(
          c,
          service: catalog.serviceById(c.serviceId),
          method: method,
          staffName: staff.fullName,
          at: _clock(),
        ),
      );

  /// Paso 9: cierre administrativo (requiere auditoría completa, reclamación y pago).
  TelemedicineCase closeAdministratively(String caseId, {required StaffMember staff}) => _update(
        caseId,
        (c) => CaseWorkflow.closeAdministratively(
          c,
          service: catalog.serviceById(c.serviceId),
          staffName: staff.fullName,
          at: _clock(),
        ),
      );

  /// Paso 10 (auxiliar): Admisión registra una llamada de seguimiento.
  TelemedicineCase logFollowUpCall(String caseId, {required StaffMember staff, required String note}) =>
      _update(caseId, (c) => CaseWorkflow.logFollowUpCall(c, staffName: staff.fullName, note: note, at: _clock()));

  /// Paso 10: el paciente responde la encuesta y el caso queda completado.
  TelemedicineCase submitSurvey(
    String caseId, {
    required Patient patient,
    required int rating,
    required int nps,
    String comment = '',
  }) =>
      _update(
        caseId,
        (c) => CaseWorkflow.submitSurvey(c, patient: patient, rating: rating, nps: nps, comment: comment, at: _clock()),
      );

  // ----- Ayudantes -----

  TelemedicineCase _require(String caseId) {
    final c = _repository.getById(caseId);
    if (c == null) {
      throw ProcessException('No existe el caso $caseId.');
    }
    return c;
  }

  /// Aplica [change] al caso actual, lo guarda y notifica. Si [change] lanza, no se guarda nada.
  TelemedicineCase _update(String caseId, TelemedicineCase Function(TelemedicineCase current) change) =>
      _save(change(_require(caseId)));

  TelemedicineCase _save(TelemedicineCase c) {
    _repository.save(c);
    notifyListeners();
    return c;
  }

  List<TelemedicineCase> _oldestFirst(List<TelemedicineCase> items) =>
      items..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Marca el caso como ocupado mientras corre [operation].
  Future<T> _whileBusy<T>(String caseId, Future<T> Function() operation) async {
    if (!_busy.add(caseId)) {
      throw const ProcessException('Ya hay una operación en curso para este caso.');
    }
    notifyListeners();
    try {
      return await operation();
    } finally {
      _busy.remove(caseId);
      notifyListeners();
    }
  }
}
