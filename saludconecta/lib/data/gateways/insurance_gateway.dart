import '../../domain/models/case_records.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/people.dart';
import '../../domain/services/case_codes.dart';
import '../../domain/services/clock.dart';
import '../repositories/catalog_repository.dart';

/// Conexión con la aseguradora. En esta demostración es simulada.
abstract class InsuranceGateway {
  /// Paso 3: valida afiliación, cobertura y autorización.
  Future<InsuranceValidation> validate({
    required Patient patient,
    required MedicalService service,
    required String caseId,
  });

  /// Paso 9: envía la reclamación y devuelve su número.
  Future<String> submitClaim({required String caseId});
}

/// Seguro simulado: responde después de una pausa, como lo haría un servicio real.
class SimulatedInsuranceGateway implements InsuranceGateway {
  SimulatedInsuranceGateway({
    required this.catalog,
    this.clock = DateTime.now,
    this.delay = const Duration(milliseconds: 1500),
  });

  final CatalogRepository catalog;
  final Clock clock;
  final Duration delay;

  @override
  Future<InsuranceValidation> validate({
    required Patient patient,
    required MedicalService service,
    required String caseId,
  }) async {
    await Future<void>.delayed(delay);
    final affiliation = patient.affiliation;
    final at = clock();
    if (!affiliation.active) {
      return InsuranceValidation(approved: false, coveragePercent: 0, message: 'Afiliación inactiva', at: at);
    }
    final insurer = catalog.insurerById(affiliation.insurerId);
    return InsuranceValidation(
      approved: true,
      coveragePercent: insurer.coverageFor(affiliation.plan, service),
      authorizationNumber: CaseCodes.authorization(caseId, at),
      message: 'Cobertura aprobada por ${insurer.name} (plan ${affiliation.plan})',
      at: at,
    );
  }

  @override
  Future<String> submitClaim({required String caseId}) async {
    await Future<void>.delayed(delay);
    // En vivo la reclamación siempre se aprueba; las glosadas solo existen en los datos históricos.
    return CaseCodes.claim(caseId);
  }
}
