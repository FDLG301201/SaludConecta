import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/models/case_records.dart';
import 'package:saludconecta/domain/models/catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/people.dart';
import 'package:saludconecta/domain/models/process_event.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/process_step.dart';

void main() {
  test('los 10 pasos están en orden y conocen su siguiente y su anterior', () {
    expect(ProcessStep.values, hasLength(10));
    expect(ProcessStep.fromNumber(3), ProcessStep.insuranceValidation);
    expect(ProcessStep.reception.next, ProcessStep.insuranceValidation);
    expect(ProcessStep.reception.previous, ProcessStep.requestAppointment);
    expect(ProcessStep.followUp.next, isNull);
    expect(ProcessStep.consultation.isOwnedBy(UserRole.doctor), isTrue);
    expect(ProcessStep.followUp.isOwnedBy(UserRole.patient), isTrue);
    expect(ProcessStep.followUp.actor, Actor.admission);
  });

  test('roles por segmento de URL', () {
    expect(UserRole.fromSlug('admision'), UserRole.admission);
    expect(UserRole.fromSlug('otro'), isNull);
    expect(UserRole.billing.actor, Actor.billing);
  });

  test('cobertura del plan, con y sin cobertura reducida', () {
    const insurer = Insurer(id: 'x', name: 'ARS X', symbolAsset: '', planCoverage: {'Plus': 80});
    const normal = MedicalService(id: 'a', name: 'A', group: ServiceGroup.clinical, description: '', iconKey: '');
    const reduced = MedicalService(
      id: 'b',
      name: 'B',
      group: ServiceGroup.clinical,
      description: '',
      iconKey: '',
      reducedCoverage: true,
    );
    expect(insurer.coverageFor('Plus', normal), 80);
    expect(insurer.coverageFor('Plus', reduced), 60);
    expect(insurer.coverageFor('Otro', normal), 0);
  });

  test('edad cumplida y primer nombre', () {
    final patient = Patient(
      id: 'p',
      fullName: 'María Fernández',
      cedula: '',
      birthDate: DateTime(1990, 3, 14),
      gender: Gender.female,
      phone: '',
      email: '',
      affiliation: const InsuranceAffiliation(insurerId: 'x', plan: 'Plus', affiliateNumber: 'SP-1', active: true),
    );
    expect(patient.ageOn(DateTime(2026, 3, 13)), 35);
    expect(patient.ageOn(DateTime(2026, 3, 14)), 36);
    expect(patient.firstName, 'María');
  });

  test('copyWith conserva lo demás y los pasos completados salen de los eventos', () {
    final at = DateTime(2026, 11, 9, 9);
    final c = TelemedicineCase(
      id: 'TM-2026-0001',
      patientId: 'p',
      serviceId: 's',
      channel: RequestChannel.whatsapp,
      reason: 'Motivo de prueba',
      preferredDate: at,
      createdAt: at,
      currentStep: ProcessStep.reception,
      status: CaseStatus.active,
      events: [
        ProcessEvent(
            step: ProcessStep.requestAppointment, actor: Actor.patient, actorName: 'María', at: at, title: 'Solicitud'),
      ],
    );
    final updated = c.copyWith(
      currentStep: ProcessStep.insuranceValidation,
      reception: const ReceptionData(registeredBy: 'Ana Peña'),
    );
    expect(updated.id, c.id);
    expect(updated.reason, 'Motivo de prueba');
    expect(updated.currentStep, ProcessStep.insuranceValidation);
    expect(updated.reception!.registeredBy, 'Ana Peña');
    expect(c.reception, isNull, reason: 'el original no cambia');
    expect(c.completedSteps, {ProcessStep.requestAppointment});
    expect(c.completedAt(ProcessStep.requestAppointment), at);
    expect(c.completedAt(ProcessStep.reception), isNull);
    expect(c.isOpen, isTrue);
    expect(c.updatedAt, at);
  });

  test('solo los eventos "completed" completan el paso', () {
    final at = DateTime(2026, 11, 9);
    final call = ProcessEvent(
      step: ProcessStep.followUp,
      actor: Actor.admission,
      actorName: 'Ana Peña',
      at: at,
      title: 'Llamada',
      kind: EventKind.call,
    );
    expect(call.completesStep, isFalse);
    expect(CaseStatus.insuranceRejected.isOpen, isTrue);
    expect(CaseStatus.cancelled.isOpen, isFalse);
  });
}
