import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/gateways/confirmation_gateway.dart';
import 'package:saludconecta/data/gateways/insurance_gateway.dart';
import 'package:saludconecta/data/repositories/case_repository.dart';
import 'package:saludconecta/data/seed/seed_cases.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/case_records.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_exception.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/schedule_service.dart';
import 'package:saludconecta/state/case_provider.dart';

import '../support/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 9, 10);
  final ana = catalog.staffFor(Actor.admission);
  final roberto = catalog.staffFor(Actor.billing);
  late CaseProvider provider;
  late int notifications;

  setUp(() {
    provider = CaseProvider(
      catalog: catalog,
      repository: InMemoryCaseRepository(SeedCases.generate(now: now, catalog: catalog)),
      insurance: SimulatedInsuranceGateway(catalog: catalog, clock: () => now, delay: Duration.zero),
      confirmation: SimulatedConfirmationGateway(delay: Duration.zero),
      clock: () => now,
    );
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  String requestForMaria() => provider
      .requestAppointment(
        patient: maria,
        service: generalConsult,
        channel: RequestChannel.whatsapp,
        reason: 'Fiebre y dolor de garganta',
        preferredDate: DateTime(2026, 11, 12),
      )
      .id;

  test('solicitar una cita crea el caso, notifica y aparece en "Nuevas" de Admisión', () {
    final id = requestForMaria();
    expect(notifications, 1);
    expect(provider.caseById(id)!.currentStep, ProcessStep.reception);
    expect(provider.admissionInbox().map((c) => c.id), contains(id));
    expect(provider.casesOfPatient(maria.id).first.id, id);
  });

  test('una acción no permitida lanza ProcessException y no cambia nada', () {
    final id = requestForMaria();
    notifications = 0;
    expect(() => provider.closeAdministratively(id, staff: roberto), throwsA(isA<ProcessException>()));
    expect(notifications, 0);
    expect(provider.caseById(id)!.currentStep, ProcessStep.reception);
  });

  test('mientras se consulta al seguro el caso queda ocupado', () async {
    final id = requestForMaria();
    provider.registerReception(id, staff: ana);
    final pending = provider.validateInsurance(id, staff: ana);
    expect(provider.isBusy(id), isTrue);
    await expectLater(provider.validateInsurance(id, staff: ana), throwsA(isA<ProcessException>()));
    final result = await pending;
    expect(result.approved, isTrue);
    expect(result.coveragePercent, 80);
    expect(provider.isBusy(id), isFalse);
    expect(provider.caseById(id)!.currentStep, ProcessStep.scheduling);
  });

  test('recorrido en vivo completo: de la solicitud a la encuesta', () async {
    final id = requestForMaria();
    provider.registerReception(id, staff: ana);
    await provider.validateInsurance(id, staff: ana);
    final day = ScheduleService.availableDays(doctor: mendez, cases: provider.cases, now: now).first;
    final slot = ScheduleService.availableSlots(doctor: mendez, day: day, cases: provider.cases, now: now).first;
    provider.scheduleAppointment(id, staff: ana, doctor: mendez, dateTime: slot, platform: VideoPlatform.teams);
    expect(
      await provider.sendConfirmation(id, staff: ana, via: RequestChannel.whatsapp),
      startsWith('https://teams.microsoft.com/'),
    );
    provider.signConsent(
      id,
      patient: maria,
      acceptedTerms: true,
      acceptedDataUse: true,
      identityConfirmed: true,
      signature: signature,
    );
    provider.startConsultation(id, doctor: mendez);
    provider.finishConsultation(id, doctor: mendez, notes: notes);
    provider.issueResults(
      id,
      doctor: mendez,
      instructions: 'Reposo e hidratación',
      medications: const [
        PrescriptionItem(
            medication: 'Acetaminofén 500 mg', dose: '1 tableta', frequency: 'Cada 8 horas', duration: '5 días'),
      ],
      followUpInDays: 15,
    );
    expect(await provider.submitClaim(id, staff: roberto), startsWith('REC-'));
    provider.registerPayment(id, staff: roberto, method: PaymentMethod.card);
    provider.closeAdministratively(id, staff: roberto);
    provider.submitSurvey(id, patient: maria, rating: 5, nps: 10);
    final done = provider.caseById(id)!;
    expect(done.status, CaseStatus.completed);
    expect(done.completedSteps, ProcessStep.values.toSet());
    expect(provider.invoiceFor(done).copay, 300);
  });

  test('el seguro rechaza a Pedro (afiliación inactiva) y Admisión continúa como privado', () async {
    final pedroCase = provider.admissionInbox().firstWhere((c) => c.patientId == SeedIds.pedro);
    final result = await provider.validateInsurance(pedroCase.id, staff: ana);
    expect(result.approved, isFalse);
    expect(provider.caseById(pedroCase.id)!.status, CaseStatus.insuranceRejected);
    expect(provider.admissionInbox().map((c) => c.id), contains(pedroCase.id));
    provider.continueAsPrivate(pedroCase.id, staff: ana);
    final updated = provider.caseById(pedroCase.id)!;
    expect(updated.privatePay, isTrue);
    expect(updated.currentStep, ProcessStep.scheduling);
  });

  test('no se agenda con un médico de otra especialidad ni en un turno ocupado', () async {
    final id = requestForMaria();
    provider.registerReception(id, staff: ana);
    await provider.validateInsurance(id, staff: ana);
    final day = ScheduleService.availableDays(doctor: mendez, cases: provider.cases, now: now).first;
    final slot = ScheduleService.availableSlots(doctor: mendez, day: day, cases: provider.cases, now: now).first;
    final jimenez = catalog.doctorById(SeedIds.jimenez);
    expect(
      () => provider.scheduleAppointment(id, staff: ana, doctor: jimenez, dateTime: slot, platform: VideoPlatform.zoom),
      throwsA(isA<ProcessException>()),
    );
    final booked = provider.doctorAgenda(SeedIds.mendez).first.appointment!.dateTime;
    expect(
      () =>
          provider.scheduleAppointment(id, staff: ana, doctor: mendez, dateTime: booked, platform: VideoPlatform.zoom),
      throwsA(isA<ProcessException>()),
    );
  });

  test('cada rol ve su bandeja', () {
    expect(provider.admissionInbox().map((c) => c.currentStep.number).toSet(), {2, 3, 4, 5});
    expect(provider.doctorAgenda(SeedIds.mendez).map((c) => c.currentStep.number).toList()..sort(), [6, 7, 8]);
    expect(provider.inboxFor(UserRole.doctor, doctorId: SeedIds.jimenez), isEmpty);
    expect(provider.billingInbox(), hasLength(1));
    expect(provider.followUpCases(), hasLength(1));
    expect(provider.inboxFor(UserRole.patient, patientId: SeedIds.jose).length, greaterThanOrEqualTo(3));
  });
}
