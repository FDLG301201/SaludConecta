import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/case_records.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/schedule_service.dart';
import 'package:saludconecta/domain/services/stats_calculator.dart';
import 'package:saludconecta/features/indicators/indicators_screen.dart';

import '../support/app_harness.dart';
import '../support/fixtures.dart' show notes, signature;

/// El guion de demo del README (§14) entre roles: lo que hace un rol se ve en las pantallas del otro.
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('la solicitud de María llega a "Nuevas" de Admisión y, al cerrarse, se refleja en Indicadores',
      (tester) async {
    final deps = patientDependencies(SeedIds.maria);
    final cases = deps.cases;
    final catalog = deps.catalog;
    final maria = catalog.patientById(SeedIds.maria);
    final mendez = catalog.doctorById(SeedIds.mendez);
    final ana = catalog.staffFor(Actor.admission);
    final roberto = catalog.staffFor(Actor.billing);
    final newBefore = cases.admissionInbox().where((c) => c.currentStep == ProcessStep.reception).length;

    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();

    // 1–2. María solicita la cita (el asistente se prueba en request_appointment_test).
    final id = cases
        .requestAppointment(
          patient: maria,
          service: catalog.serviceById(SeedIds.generalConsult),
          channel: RequestChannel.whatsapp,
          reason: 'Fiebre y dolor de garganta desde ayer',
          preferredDate: DateTime(2026, 11, 12),
        )
        .id;

    // 3. Cambia a Admisión: la solicitud aparece en "Nuevas".
    deps.session.loginStaff(ana);
    deps.router.go(AppRoutes.admissionInbox);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevas (${newBefore + 1})'));
    await tester.pumpAndSettle();
    expect(find.text(maria.fullName), findsOneWidget);

    // 3–7. El resto del recorrido (cada pantalla tiene su propia prueba).
    final funnelBefore = StatsCalculator.funnel(StatsCalculator.inWindow(cases.cases, testNow));
    await tester.runAsync(() async {
      cases.registerReception(id, staff: ana);
      await cases.validateInsurance(id, staff: ana);
      final day = ScheduleService.availableDays(doctor: mendez, cases: cases.cases, now: testNow).first;
      final slot = ScheduleService.availableSlots(doctor: mendez, day: day, cases: cases.cases, now: testNow).first;
      cases.scheduleAppointment(id, staff: ana, doctor: mendez, dateTime: slot, platform: VideoPlatform.teams);
      await cases.sendConfirmation(id, staff: ana, via: RequestChannel.whatsapp);
      cases.signConsent(
        id,
        patient: maria,
        acceptedTerms: true,
        acceptedDataUse: true,
        identityConfirmed: true,
        signature: signature,
      );
      cases.startConsultation(id, doctor: mendez);
      cases.finishConsultation(id, doctor: mendez, notes: notes);
      cases.issueResults(
        id,
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
      );
      await cases.submitClaim(id, staff: roberto);
      cases.registerPayment(id, staff: roberto, method: PaymentMethod.card);
      cases.closeAdministratively(id, staff: roberto);
      cases.submitSurvey(id, patient: maria, rating: 5, nps: 10);
    });
    expect(cases.caseById(id)!.status, CaseStatus.completed);

    // 8. Admisión → Indicadores: el embudo cuenta un caso más en el paso 10.
    deps.router.go(AppRoutes.admissionIndicators);
    await tester.pumpAndSettle();
    final completedBefore = funnelBefore[ProcessStep.followUp]!;
    final list = find
        .descendant(
          of: find.byType(IndicatorsScreen),
          matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
        )
        .first;
    final lastStep = find.text('${ProcessStep.followUp.number}. ${ProcessStep.followUp.title}');
    await tester.scrollUntilVisible(lastStep, 300, scrollable: list);
    await tester.pumpAndSettle();
    expect(find.text('${completedBefore + 1}'), findsWidgets);
  });
}
