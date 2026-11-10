// Datos y ayudantes compartidos por las pruebas del dominio y de los datos.
import 'package:saludconecta/data/repositories/catalog_repository.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/case_records.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/case_codes.dart';

final CatalogRepository catalog = SeedCatalog.repository();
final maria = catalog.patientById(SeedIds.maria);
final mendez = catalog.doctorById(SeedIds.mendez);
final generalConsult = catalog.serviceById(SeedIds.generalConsult);

const ana = 'Ana Peña';
const roberto = 'Roberto Díaz';

/// Lunes 9 de noviembre de 2026, 9:00: inicio de los casos de prueba.
final start = DateTime(2026, 11, 9, 9);

/// Cita de los casos de prueba: jueves 12 de noviembre de 2026, 10:30, con el Dr. Méndez por Teams.
final appointmentTime = DateTime(2026, 11, 12, 10, 30);

const signature = [
  [SignaturePoint(0.1, 0.5), SignaturePoint(0.5, 0.2), SignaturePoint(0.9, 0.6)],
];

const notes = ClinicalNotes(
  chiefComplaint: 'Fiebre y dolor de garganta',
  assessment: 'Paciente estable',
  diagnosis: 'Faringitis aguda',
  plan: 'Analgésico y reposo',
);

InsuranceValidation approved(String caseId, DateTime at, {int coverage = 80}) => InsuranceValidation(
      approved: true,
      coveragePercent: coverage,
      authorizationNumber: CaseCodes.authorization(caseId, at),
      message: 'Cobertura aprobada',
      at: at,
    );

InsuranceValidation rejected(DateTime at) =>
    InsuranceValidation(approved: false, coveragePercent: 0, message: 'Afiliación inactiva', at: at);

/// Caso nuevo de María (Consulta médica general, RD$1,500): queda pendiente el paso 2.
TelemedicineCase newCase({String id = 'TM-2026-0100', RequestChannel channel = RequestChannel.whatsapp}) {
  return CaseWorkflow.request(
    id: id,
    patient: maria,
    service: generalConsult,
    channel: channel,
    reason: 'Dolor de garganta y fiebre',
    preferredDate: DateTime(2026, 11, 12),
    at: start,
  );
}

/// Reclamación aprobada, copago con tarjeta y cierre administrativo, todo en el momento [at].
TelemedicineCase closeCase(TelemedicineCase c, DateTime at) {
  var closed = CaseWorkflow.recordClaim(
    c,
    service: generalConsult,
    claimNumber: CaseCodes.claim(c.id),
    status: ClaimStatus.approved,
    staffName: roberto,
    at: at,
  );
  closed = CaseWorkflow.registerPayment(
    closed,
    service: generalConsult,
    method: PaymentMethod.card,
    staffName: roberto,
    at: at,
  );
  return CaseWorkflow.closeAdministratively(closed, service: generalConsult, staffName: roberto, at: at);
}

/// Avanza un caso nuevo de María hasta que [pending] sea el paso pendiente.
/// Con `null` recorre los 10 pasos y el caso queda completado.
/// Cada evento ocurre una hora después del anterior (h0 solicitud … h6 inicio de la consulta,
/// h7 fin, h8 resultados, h9 cierre, h10 encuesta).
TelemedicineCase caseAt(
  ProcessStep? pending, {
  String id = 'TM-2026-0100',
  RequestChannel channel = RequestChannel.whatsapp,
  int rating = 5,
  int nps = 10,
}) {
  var c = newCase(id: id, channel: channel);
  var hours = 0;
  DateTime next() => start.add(Duration(hours: ++hours));
  for (final step in ProcessStep.values.skip(1)) {
    if (step == pending) return c;
    c = switch (step) {
      ProcessStep.requestAppointment => c,
      ProcessStep.reception => CaseWorkflow.registerReception(c, staffName: ana, at: next()),
      ProcessStep.insuranceValidation =>
        CaseWorkflow.applyInsuranceResult(c, staffName: ana, result: approved(c.id, next())),
      ProcessStep.scheduling => CaseWorkflow.schedule(
          c,
          doctor: mendez,
          dateTime: appointmentTime,
          platform: VideoPlatform.teams,
          staffName: ana,
          at: next(),
        ),
      ProcessStep.patientConfirmation => CaseWorkflow.confirm(
          c,
          link: CaseCodes.meetingLink(c.id, VideoPlatform.teams),
          via: RequestChannel.whatsapp,
          staffName: ana,
          at: next(),
        ),
      ProcessStep.consentAdmission => CaseWorkflow.signConsent(
          c,
          patient: maria,
          acceptedTerms: true,
          acceptedDataUse: true,
          identityConfirmed: true,
          signature: signature,
          at: next(),
        ),
      ProcessStep.consultation => CaseWorkflow.finishConsultation(
          CaseWorkflow.startConsultation(c, doctor: mendez, at: next()),
          doctor: mendez,
          notes: notes,
          at: next(),
        ),
      ProcessStep.consultationResult => CaseWorkflow.issueResults(
          c,
          doctor: mendez,
          instructions: 'Reposo e hidratación',
          medications: const [
            PrescriptionItem(
              medication: 'Acetaminofén 500 mg',
              dose: '1 tableta',
              frequency: 'Cada 8 horas',
              duration: '5 días',
            ),
          ],
          followUpInDays: 15,
          at: next(),
        ),
      ProcessStep.administrativeClosure => closeCase(c, next()),
      ProcessStep.followUp => CaseWorkflow.submitSurvey(c, patient: maria, rating: rating, nps: nps, at: next()),
    };
  }
  return c;
}
