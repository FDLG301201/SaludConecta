import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_cases.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/models/telemedicine_case.dart';
import 'package:saludconecta/domain/process/process_step.dart';

void main() {
  final catalog = SeedCatalog.repository();
  final now = DateTime(2026, 11, 9, 10);
  final cases = SeedCases.generate(now: now, catalog: catalog);

  String fingerprint(List<TelemedicineCase> list) => [
        for (final c in list)
          '${c.id}|${c.patientId}|${c.status.name}|${c.currentStep.name}|${c.events.length}|${c.updatedAt}',
      ].join('\n');

  test('es determinista: el mismo now produce los mismos casos', () {
    expect(fingerprint(SeedCases.generate(now: now, catalog: catalog)), fingerprint(cases));
  });

  test('genera unos 200 casos históricos, todos terminados y variados', () {
    final closed = cases.where((c) => !c.isOpen).toList();
    expect(closed.length, inInclusiveRange(150, 230));
    final completed = closed.where((c) => c.status == CaseStatus.completed).length;
    expect(completed / closed.length, greaterThan(0.8));
    expect(cases.any((c) => c.privatePay), isTrue, reason: 'hay rechazos que siguieron como privado');
    expect(cases.any((c) => c.billing?.claimStatus == ClaimStatus.objected), isTrue, reason: 'hay glosas');
  });

  test('hay 10 casos en vivo, uno por cada paso pendiente del 2 al 10', () {
    final open = cases.where((c) => c.isOpen).toList();
    expect(open, hasLength(10));
    expect(open.map((c) => c.currentStep.number).toList()..sort(), [2, 3, 3, 4, 5, 6, 7, 8, 9, 10]);
  });

  test('uno de los casos en vivo es del paciente con afiliación inactiva', () {
    final inactive = cases.where((c) => c.isOpen && !catalog.patientById(c.patientId).affiliation.active).toList();
    expect(inactive, hasLength(1));
    expect(inactive.single.patientId, SeedIds.pedro);
    expect(inactive.single.currentStep, ProcessStep.insuranceValidation);
  });

  test('María tiene 4 consultas completadas y ningún caso abierto', () {
    final maria = cases.where((c) => c.patientId == SeedIds.maria).toList();
    expect(maria.where((c) => c.status == CaseStatus.completed), hasLength(4));
    expect(maria.where((c) => c.isOpen), isEmpty);
  });

  test('los eventos están en orden y ninguno ocurre después de now', () {
    for (final c in cases) {
      for (var i = 1; i < c.events.length; i++) {
        expect(c.events[i].at.isBefore(c.events[i - 1].at), isFalse, reason: '${c.id}: evento $i fuera de orden');
      }
      expect(c.updatedAt.isAfter(now), isFalse, reason: c.id);
    }
  });

  test('funciona con fechas límite (inicio de año, fin de mes, año bisiesto)', () {
    for (final date in [DateTime(2026, 1, 1, 0, 5), DateTime(2026, 3, 31, 23, 59), DateTime(2028, 2, 29, 12)]) {
      final generated = SeedCases.generate(now: date, catalog: catalog);
      expect(generated.where((c) => c.isOpen), hasLength(10), reason: '$date');
    }
  });
}
