import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/billing_calculator.dart';

import '../support/fixtures.dart';

void main() {
  test('copago con la cobertura del plan (Salud Plena Plus 80%)', () {
    final invoice = BillingCalculator.invoiceFor(caseAt(ProcessStep.administrativeClosure), generalConsult);
    expect(invoice.fee, 1500);
    expect(invoice.coveragePercent, 80);
    expect(invoice.insurerAmount, 1200);
    expect(invoice.copay, 300);
  });

  test('los servicios de cobertura reducida pierden 20 puntos', () {
    final insurer = catalog.insurerById('salud-plena');
    expect(insurer.coverageFor('Plus', catalog.serviceById(SeedIds.nutrition)), 60);
    expect(insurer.coverageFor('Plus', generalConsult), 80);
  });

  test('el paciente privado paga el 100% y la reclamación no aplica', () {
    final rejectedCase = CaseWorkflow.applyInsuranceResult(
      caseAt(ProcessStep.insuranceValidation),
      staffName: ana,
      result: rejected(start),
    );
    final privateCase = CaseWorkflow.continueAsPrivate(rejectedCase, staffName: ana, at: start);
    final invoice = BillingCalculator.invoiceFor(privateCase, generalConsult);
    expect(invoice.coveragePercent, 0);
    expect(invoice.insurerAmount, 0);
    expect(invoice.copay, 1500);
    expect(BillingCalculator.claimStatusOf(privateCase, invoice), ClaimStatus.notApplicable);
  });

  test('la parte del seguro se redondea', () {
    const service = MedicalService(
      id: 'prueba',
      name: 'Servicio de prueba',
      group: ServiceGroup.clinical,
      description: '',
      iconKey: 'stethoscope',
      requestable: true,
      fee: 1250,
    );
    final c = CaseWorkflow.applyInsuranceResult(
      caseAt(ProcessStep.insuranceValidation),
      staffName: ana,
      result: approved('TM-2026-0100', start, coverage: 65),
    );
    final invoice = BillingCalculator.invoiceFor(c, service);
    expect(invoice.insurerAmount, 813, reason: '1250 × 65% = 812.5, que se redondea a 813');
    expect(invoice.copay, 437);
  });

  test('antes de la reclamación la auditoría está incompleta', () {
    final c = caseAt(ProcessStep.administrativeClosure);
    final invoice = BillingCalculator.invoiceFor(c, generalConsult);
    final failing = BillingCalculator.auditChecklist(c, invoice).where((item) => !item.ok).map((item) => item.label);
    expect(failing, ['Reclamación aprobada o no aplica']);
    expect(BillingCalculator.canClose(c, invoice), isFalse);
  });

  test('con la reclamación aprobada y el pago registrado se puede cerrar', () {
    var c = caseAt(ProcessStep.administrativeClosure);
    c = CaseWorkflow.recordClaim(
      c,
      service: generalConsult,
      claimNumber: 'REC-10100',
      status: ClaimStatus.approved,
      staffName: roberto,
      at: start,
    );
    final invoice = BillingCalculator.invoiceFor(c, generalConsult);
    expect(BillingCalculator.auditChecklist(c, invoice).every((item) => item.ok), isTrue);
    expect(BillingCalculator.paymentPending(c, invoice), isTrue);
    expect(BillingCalculator.canClose(c, invoice), isFalse);
    c = CaseWorkflow.registerPayment(c,
        service: generalConsult, method: PaymentMethod.cash, staffName: roberto, at: start);
    expect(BillingCalculator.paymentPending(c, invoice), isFalse);
    expect(BillingCalculator.canClose(c, invoice), isTrue);
  });
}
