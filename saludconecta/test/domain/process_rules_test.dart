import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/case_records.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_exception.dart';
import 'package:saludconecta/domain/process/process_rules.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../support/fixtures.dart';

final throwsProcessException = throwsA(isA<ProcessException>());

void main() {
  group('recorrido del proceso', () {
    test('al crear la solicitud queda pendiente la recepción', () {
      final c = newCase();
      expect(c.status, CaseStatus.active);
      expect(c.currentStep, ProcessStep.reception);
      expect(c.completedSteps, {ProcessStep.requestAppointment});
      expect(c.events.single.title, 'Solicitud enviada por WhatsApp');
    });

    test('un caso recorre los 10 pasos y queda completado', () {
      final c = caseAt(null);
      expect(c.status, CaseStatus.completed);
      expect(c.currentStep, ProcessStep.followUp);
      expect(c.completedSteps, ProcessStep.values.toSet());
      expect(c.followUp!.survey!.rating, 5);
    });

    test('el motivo debe tener al menos 10 caracteres', () {
      expect(
        () => CaseWorkflow.request(
          id: 'TM-2026-0100',
          patient: maria,
          service: generalConsult,
          channel: RequestChannel.email,
          reason: 'Fiebre',
          preferredDate: start,
          at: start,
        ),
        throwsProcessException,
      );
    });

    test('no se puede completar un paso fuera de orden', () {
      expect(
        () => CaseWorkflow.schedule(
          newCase(),
          doctor: mendez,
          dateTime: appointmentTime,
          platform: VideoPlatform.zoom,
          staffName: ana,
          at: start,
        ),
        throwsProcessException,
      );
    });

    test('otro rol no puede completar el paso', () {
      expect(() => ProcessRules.ensureCanPerform(newCase(), ProcessStep.reception, UserRole.doctor),
          throwsProcessException);
      expect(
          () => ProcessRules.ensureCanPerform(newCase(), ProcessStep.reception, UserRole.admission), returnsNormally);
    });

    test('no se puede operar sobre un caso cancelado', () {
      final cancelled = CaseWorkflow.cancel(newCase(), role: UserRole.patient, actorName: maria.fullName, at: start);
      expect(cancelled.status, CaseStatus.cancelled);
      expect(cancelled.events.last.kind, EventKind.cancelled);
      expect(() => CaseWorkflow.registerReception(cancelled, staffName: ana, at: start), throwsProcessException);
    });
  });

  group('rechazo del seguro', () {
    TelemedicineCase rejectedCase() => CaseWorkflow.applyInsuranceResult(
          caseAt(ProcessStep.insuranceValidation),
          staffName: ana,
          result: rejected(start),
        );

    test('el caso queda rechazado y sigue en el paso 3', () {
      final c = rejectedCase();
      expect(c.status, CaseStatus.insuranceRejected);
      expect(c.currentStep, ProcessStep.insuranceValidation);
      expect(c.isStepCompleted(ProcessStep.insuranceValidation), isFalse);
      expect(c.events.last.kind, EventKind.rejected);
    });

    test('continuar como privado completa el paso 3 y pasa al agendamiento', () {
      final c = CaseWorkflow.continueAsPrivate(rejectedCase(), staffName: ana, at: start);
      expect(c.status, CaseStatus.active);
      expect(c.privatePay, isTrue);
      expect(c.currentStep, ProcessStep.scheduling);
      expect(c.isStepCompleted(ProcessStep.insuranceValidation), isTrue);
      expect(c.events.last.title, 'Paciente privado (100%)');
    });

    test('Admisión puede cancelar una solicitud rechazada', () {
      final c = CaseWorkflow.cancel(rejectedCase(), role: UserRole.admission, actorName: ana, at: start);
      expect(c.status, CaseStatus.cancelled);
    });

    test('Admisión no cancela solicitudes activas ni resuelve casos sin rechazo', () {
      expect(() => CaseWorkflow.cancel(newCase(), role: UserRole.admission, actorName: ana, at: start),
          throwsProcessException);
      expect(() => CaseWorkflow.continueAsPrivate(newCase(), staffName: ana, at: start), throwsProcessException);
    });
  });

  group('cancelación del paciente', () {
    test('puede cancelar hasta el paso 6', () {
      expect(ProcessRules.canPatientCancel(caseAt(ProcessStep.reception)), isTrue);
      expect(ProcessRules.canPatientCancel(caseAt(ProcessStep.consentAdmission)), isTrue);
    });

    test('no puede cancelar desde la consulta en adelante', () {
      final c = caseAt(ProcessStep.consultation);
      expect(ProcessRules.canPatientCancel(c), isFalse);
      expect(() => CaseWorkflow.cancel(c, role: UserRole.patient, actorName: maria.fullName, at: start),
          throwsProcessException);
    });
  });

  group('consulta y resultados', () {
    test('iniciar la consulta es una acción auxiliar: no completa el paso 7', () {
      final c = CaseWorkflow.startConsultation(caseAt(ProcessStep.consultation), doctor: mendez, at: start);
      expect(c.currentStep, ProcessStep.consultation);
      expect(c.consultation, isNotNull);
      expect(c.events.last.kind, EventKind.started);
      expect(c.events.last.completesStep, isFalse);
    });

    test('otro médico no puede atender la cita', () {
      final other = catalog.doctorById(SeedIds.jimenez);
      expect(
        () => CaseWorkflow.startConsultation(caseAt(ProcessStep.consultation), doctor: other, at: start),
        throwsProcessException,
      );
    });

    test('finalizar exige motivo y diagnóstico', () {
      final started = CaseWorkflow.startConsultation(caseAt(ProcessStep.consultation), doctor: mendez, at: start);
      expect(
        () => CaseWorkflow.finishConsultation(
          started,
          doctor: mendez,
          notes: const ClinicalNotes(chiefComplaint: 'Fiebre'),
          at: start,
        ),
        throwsProcessException,
      );
    });

    test('emitir resultados exige indicaciones y genera el código de la receta', () {
      final c = caseAt(ProcessStep.consultationResult);
      expect(() => CaseWorkflow.issueResults(c, doctor: mendez, instructions: '  ', at: start), throwsProcessException);
      final issued = caseAt(ProcessStep.administrativeClosure);
      expect(issued.results!.prescription!.verificationCode, startsWith('RX-2026-0100-'));
      expect(issued.results!.followUpInDays, 15);
      expect(issued.events.last.detail, 'Receta (1) · Seguimiento en 15 días');
    });
  });

  group('cierre administrativo', () {
    test('no se puede cerrar sin reclamación ni pago', () {
      final c = caseAt(ProcessStep.administrativeClosure);
      expect(
        () => CaseWorkflow.closeAdministratively(c, service: generalConsult, staffName: roberto, at: start),
        throwsProcessException,
      );
    });

    test('las acciones auxiliares del paso 9 son solo de Facturación', () {
      final c = caseAt(ProcessStep.administrativeClosure);
      expect(
          () => ProcessRules.ensureCanAssist(c, AssistAction.submitClaim, UserRole.admission), throwsProcessException);
      expect(() => ProcessRules.ensureCanAssist(c, AssistAction.submitClaim, UserRole.billing), returnsNormally);
    });

    test('con la reclamación aprobada y el copago pagado se cierra y pasa a seguimiento', () {
      final c = caseAt(ProcessStep.followUp);
      expect(c.billing!.closedAt, isNotNull);
      expect(c.billing!.claimStatus, ClaimStatus.approved);
      expect(c.billing!.payment!.amount, 300);
      expect(c.currentStep, ProcessStep.followUp);
      expect(c.status, CaseStatus.active);
    });
  });

  group('seguimiento', () {
    test('Admisión registra llamadas sin completar el paso 10', () {
      final c =
          CaseWorkflow.logFollowUpCall(caseAt(ProcessStep.followUp), staffName: ana, note: 'Paciente mejor', at: start);
      expect(c.followUp!.calls, hasLength(1));
      expect(c.status, CaseStatus.active);
      expect(c.events.last.kind, EventKind.call);
    });

    test('la encuesta valida el rango de estrellas y de recomendación', () {
      final c = caseAt(ProcessStep.followUp);
      expect(() => CaseWorkflow.submitSurvey(c, patient: maria, rating: 6, nps: 10, at: start), throwsProcessException);
      expect(() => CaseWorkflow.submitSurvey(c, patient: maria, rating: 5, nps: 11, at: start), throwsProcessException);
    });
  });
}
