import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/stats_calculator.dart';

import '../support/fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 20, 12);
  // Conjunto pequeño y fijo. Todos los casos son de María y se crearon el 9 de noviembre de 2026:
  // A, D y E completados; B pendiente de recepción; C cancelado por el paciente.
  final a = caseAt(null, id: 'TM-2026-0001', rating: 5, nps: 10);
  final b = newCase(id: 'TM-2026-0002', channel: RequestChannel.email);
  final c =
      CaseWorkflow.cancel(newCase(id: 'TM-2026-0003'), role: UserRole.patient, actorName: maria.fullName, at: start);
  final d = caseAt(null, id: 'TM-2026-0004', channel: RequestChannel.webPortal, rating: 4, nps: 9);
  final e = caseAt(null, id: 'TM-2026-0005', channel: RequestChannel.phone, rating: 2, nps: 3);
  final cases = [a, b, c, d, e];

  test('solicitudes por canal', () {
    final byChannel = StatsCalculator.requestsByChannel(cases);
    expect(byChannel[RequestChannel.whatsapp], 2);
    expect(byChannel[RequestChannel.email], 1);
    expect(byChannel[RequestChannel.webPortal], 1);
    expect(byChannel[RequestChannel.phone], 1);
    expect(byChannel[RequestChannel.mobile], 0);
  });

  test('embudo: cuántos casos completaron cada paso', () {
    final funnel = StatsCalculator.funnel(cases);
    expect(funnel[ProcessStep.requestAppointment], 5);
    expect(funnel[ProcessStep.reception], 3);
    expect(funnel[ProcessStep.followUp], 3);
  });

  test('tiempo promedio por etapa', () {
    final hours = StatsCalculator.averageHoursPerStage(cases);
    expect(hours[ProcessStep.reception], 1.0);
    // Consentimiento en h5, fin de la consulta en h7.
    expect(hours[ProcessStep.consultation], 2.0);
    expect(hours.containsKey(ProcessStep.requestAppointment), isFalse);
  });

  test('NPS = % de promotores − % de detractores', () {
    // 10 y 9 son promotores, 3 es detractor: (2 − 1) / 3 = 33%.
    expect(StatsCalculator.nps(cases), 33);
    expect(StatsCalculator.averageRating(cases), closeTo(3.67, 0.01));
    expect(StatsCalculator.ratingDistribution(cases), {1: 0, 2: 1, 3: 0, 4: 1, 5: 1});
  });

  test('facturación mensual: monto del seguro y copago', () {
    final months = StatsCalculator.monthlyBilling(cases, now);
    expect(months, hasLength(12));
    expect(months.last.month, DateTime(2026, 11));
    expect(months.last.insurerAmount, 3600, reason: '3 casos × RD\$1,200');
    expect(months.last.copay, 900, reason: '3 casos × RD\$300');
    expect(months.first.insurerAmount, 0);
  });

  test('indicadores de operación', () {
    final kpis = StatsCalculator.operationKpis(cases, now);
    expect(kpis.requestsThisMonth, 5);
    expect(kpis.casesInProcess, 1);
    expect(kpis.rejectionRate, 0);
    expect(kpis.averageDaysToConsultation, closeTo(7 / 24, 0.001));
  });

  test('consultas por especialidad, plataformas y resultados emitidos', () {
    final servicesById = {for (final s in catalog.services) s.id: s};
    expect(StatsCalculator.consultationsBySpecialty(cases, servicesById)[Specialty.generalMedicine], 3);
    expect(StatsCalculator.platformUsage(cases)[VideoPlatform.teams], 3);
    final results = StatsCalculator.resultsIssued(cases);
    expect(results.prescriptions, 3);
    expect(results.labOrders, 0);
  });

  test('reclamaciones por estado y facturación por aseguradora', () {
    expect(
      StatsCalculator.claimsByStatus(cases),
      {ClaimStatus.approved: 3, ClaimStatus.pending: 0, ClaimStatus.objected: 0},
    );
    final patientsById = {for (final p in catalog.patients) p.id: p};
    expect(StatsCalculator.billingByInsurer(cases, patientsById), {'salud-plena': 3600});
  });

  test('lo que cubrió el seguro y lo que pagó la paciente', () {
    final split = StatsCalculator.coverageSplit(cases);
    expect(split.covered, 3600);
    expect(split.paid, 900);
  });

  test('ventana de 12 meses, actividad y satisfacción por mes', () {
    final months = StatsCalculator.monthsUpTo(now);
    expect(months.first, DateTime(2025, 12));
    expect(months.last, DateTime(2026, 11));
    final activity = StatsCalculator.monthlyActivity(cases, now);
    expect(activity.last.requests, 5);
    expect(activity.last.consultations, 3);
    final ratings = StatsCalculator.monthlyRating(cases, now);
    expect(ratings.last.average, closeTo(3.67, 0.01));
    expect(ratings.first.average, isNull);
  });
}
