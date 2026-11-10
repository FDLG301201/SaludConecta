import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';

void main() {
  final catalog = SeedCatalog.repository();

  test('los 24 servicios de la infografía, en 3 grupos de 8', () {
    expect(catalog.services, hasLength(24));
    for (final group in ServiceGroup.values) {
      expect(catalog.services.where((s) => s.group == group), hasLength(8), reason: group.label);
    }
    final requestable = catalog.services.where((s) => s.requestable).toList();
    expect(requestable, hasLength(13));
    expect(requestable.every((s) => s.fee != null && s.specialty != null), isTrue);
    expect(catalog.serviceById(SeedIds.generalConsult).fee, 1500);
    expect(catalog.serviceById(SeedIds.nutrition).reducedCoverage, isTrue);
  });

  test('un médico por especialidad; el Dr. Méndez también trabaja el sábado', () {
    expect(catalog.doctors, hasLength(7));
    for (final specialty in Specialty.values) {
      expect(catalog.doctorsFor(specialty), hasLength(1), reason: specialty.label);
    }
    expect(catalog.doctorById(SeedIds.mendez).workDays, {1, 2, 3, 4, 5, 6});
    expect(catalog.doctorById(SeedIds.jimenez).displayName, 'Dra. Laura Jiménez');
  });

  test('pacientes de demostración y búsqueda por número de carnet', () {
    expect(catalog.demoPatients, hasLength(6));
    expect(catalog.patients, hasLength(46));
    expect(catalog.patientByAffiliateNumber(' sp-100245 ')!.id, SeedIds.maria);
    expect(catalog.patientByAffiliateNumber('XX-0'), isNull);
    expect(catalog.patientById(SeedIds.maria).affiliation.plan, 'Plus');
    expect(catalog.patientById(SeedIds.pedro).affiliation.active, isFalse);
  });

  test('aseguradoras ficticias y personal', () {
    expect(catalog.insurers.map((i) => i.name), ['ARS Salud Plena', 'ARS Vida Segura', 'ARS Familia Sana']);
    expect(catalog.staffFor(Actor.admission).fullName, 'Ana Peña');
    expect(catalog.staffFor(Actor.billing).fullName, 'Roberto Díaz');
    expect(catalog.staffFor(Actor.support).phone, '809-555-0199');
    expect(() => catalog.serviceById('no-existe'), throwsArgumentError);
  });
}
