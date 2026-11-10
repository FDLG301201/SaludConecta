import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/shared/case_detail/next_action.dart';

import '../../support/fixtures.dart';

void main() {
  test('Admisión procesa los pasos 2 a 5', () {
    final action = nextActionFor(caseAt(ProcessStep.scheduling), UserRole.admission);
    expect(action!.label, 'Procesar solicitud');
    expect(action.route, '/caso/TM-2026-0100/procesar');
  });

  test('el paciente firma el consentimiento solo de su propio caso', () {
    final c = caseAt(ProcessStep.consentAdmission);
    expect(nextActionFor(c, UserRole.patient, patientId: maria.id)!.label, 'Firmar consentimiento');
    expect(nextActionFor(c, UserRole.patient, patientId: 'pac-otro'), isNull);
  });

  test('solo el médico asignado inicia la consulta', () {
    final c = caseAt(ProcessStep.consultation);
    expect(nextActionFor(c, UserRole.doctor, doctorId: mendez.id)!.label, 'Iniciar consulta');
    expect(nextActionFor(c, UserRole.doctor, doctorId: 'doc-otro'), isNull);
    expect(nextActionFor(c, UserRole.patient, patientId: maria.id)!.label, 'Ir a la sala de espera');
  });

  test('Facturación hace el cierre y nadie actúa sobre un caso completado', () {
    expect(
        nextActionFor(caseAt(ProcessStep.administrativeClosure), UserRole.billing)!.route, '/caso/TM-2026-0100/cierre');
    for (final role in UserRole.values) {
      expect(nextActionFor(caseAt(null), role, patientId: maria.id, doctorId: mendez.id), isNull);
    }
  });

  test('texto de espera según a quién le toca el paso', () {
    expect(
        waitingText(caseAt(ProcessStep.consentAdmission)), 'Esperando al paciente: Consentimiento y admisión virtual');
    expect(waitingText(caseAt(ProcessStep.reception)), 'Esperando a Admisión: Recepción en Hospital / PSS');
  });
}
