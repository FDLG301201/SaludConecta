import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/repositories/case_repository.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../support/fixtures.dart';

void main() {
  test('el siguiente ID continúa la secuencia', () {
    final repo = InMemoryCaseRepository();
    expect(repo.nextId(DateTime(2026, 11, 9)), 'TM-2026-0001');
    repo.save(newCase(id: 'TM-2026-0007'));
    expect(repo.nextId(DateTime(2026, 11, 9)), 'TM-2026-0008');
  });

  test('guardar reemplaza el caso con el mismo ID', () {
    final c = newCase(id: 'TM-2026-0007');
    final repo = InMemoryCaseRepository([c]);
    expect(repo.getById('TM-2026-0007'), same(c));
    repo.save(CaseWorkflow.registerReception(c, staffName: ana, at: start));
    expect(repo.getAll(), hasLength(1));
    expect(repo.getById('TM-2026-0007')!.currentStep, ProcessStep.insuranceValidation);
    expect(repo.getById('TM-2026-9999'), isNull);
  });
}
