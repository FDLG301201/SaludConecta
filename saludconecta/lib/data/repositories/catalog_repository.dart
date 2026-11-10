import '../../domain/models/catalog.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/people.dart';

/// Catálogo: aseguradoras, servicios, médicos, pacientes y personal.
abstract class CatalogRepository {
  List<Insurer> get insurers;
  List<MedicalService> get services;
  List<Doctor> get doctors;

  /// Todos los pacientes: los 6 de demostración y los de fondo.
  List<Patient> get patients;

  /// Los 6 pacientes de demostración (chips de la pantalla de ingreso).
  List<Patient> get demoPatients;
  List<StaffMember> get staff;

  Insurer insurerById(String id);
  MedicalService serviceById(String id);
  Doctor doctorById(String id);
  Patient patientById(String id);

  /// Paciente por número de carnet (ignora mayúsculas y espacios); `null` si no existe.
  Patient? patientByAffiliateNumber(String affiliateNumber);

  /// Primer miembro del personal con ese actor (Admisión, Facturación o Soporte TI).
  StaffMember staffFor(Actor actor);

  /// Médicos de una especialidad.
  List<Doctor> doctorsFor(Specialty specialty);
}

/// Implementación en memoria; los datos vienen de `SeedCatalog`.
class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository({
    required List<Insurer> insurers,
    required List<MedicalService> services,
    required List<Doctor> doctors,
    required List<Patient> demoPatients,
    required List<StaffMember> staff,
    List<Patient> otherPatients = const [],
  })  : insurers = List.unmodifiable(insurers),
        services = List.unmodifiable(services),
        doctors = List.unmodifiable(doctors),
        demoPatients = List.unmodifiable(demoPatients),
        patients = List.unmodifiable([...demoPatients, ...otherPatients]),
        staff = List.unmodifiable(staff);

  @override
  final List<Insurer> insurers;

  @override
  final List<MedicalService> services;

  @override
  final List<Doctor> doctors;

  @override
  final List<Patient> demoPatients;

  @override
  final List<Patient> patients;

  @override
  final List<StaffMember> staff;

  @override
  Insurer insurerById(String id) => _find(insurers, (i) => i.id == id, 'aseguradora', id);

  @override
  MedicalService serviceById(String id) => _find(services, (s) => s.id == id, 'servicio', id);

  @override
  Doctor doctorById(String id) => _find(doctors, (d) => d.id == id, 'médico', id);

  @override
  Patient patientById(String id) => _find(patients, (p) => p.id == id, 'paciente', id);

  @override
  Patient? patientByAffiliateNumber(String affiliateNumber) {
    final wanted = _normalize(affiliateNumber);
    for (final p in patients) {
      if (_normalize(p.affiliation.affiliateNumber) == wanted) return p;
    }
    return null;
  }

  @override
  StaffMember staffFor(Actor actor) => _find(staff, (s) => s.actor == actor, 'personal', actor.name);

  @override
  List<Doctor> doctorsFor(Specialty specialty) => [
        for (final d in doctors)
          if (d.specialty == specialty) d,
      ];

  static T _find<T>(List<T> items, bool Function(T item) test, String kind, String id) {
    for (final item in items) {
      if (test(item)) return item;
    }
    throw ArgumentError('No existe $kind con id "$id".');
  }

  static String _normalize(String value) => value.replaceAll(RegExp(r'\s'), '').toUpperCase();
}
