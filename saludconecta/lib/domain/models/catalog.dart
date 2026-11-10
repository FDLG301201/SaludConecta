import '../process/process_step.dart';
import 'enums.dart';

/// Aseguradora (ARS) ficticia con su cobertura por plan.
class Insurer {
  const Insurer({
    required this.id,
    required this.name,
    required this.symbolAsset,
    required this.planCoverage,
  });

  final String id;
  final String name;
  final String symbolAsset;

  /// % de cobertura por plan, p. ej. {'Básico': 70, 'Plus': 80, 'Premium': 90}.
  final Map<String, int> planCoverage;

  /// % que cubre el plan para el servicio; 20 puntos menos si el servicio tiene cobertura reducida.
  int coverageFor(String plan, MedicalService service) {
    final base = planCoverage[plan] ?? 0;
    final value = service.reducedCoverage ? base - 20 : base;
    return value < 0 ? 0 : value;
  }
}

/// Uno de los 24 servicios de la infografía 2.
class MedicalService {
  const MedicalService({
    required this.id,
    required this.name,
    required this.group,
    required this.description,
    required this.iconKey,
    this.requestable = false,
    this.specialty,
    this.fee,
    this.reducedCoverage = false,
    this.relatedStep,
  });

  final String id;
  final String name;
  final ServiceGroup group;
  final String description;

  /// Clave del ícono; `core/` la traduce a un `IconData` de Material.
  final String iconKey;

  /// Se puede pedir con el asistente "Solicitar cita".
  final bool requestable;
  final Specialty? specialty;

  /// Tarifa en pesos dominicanos (solo los servicios que se pueden solicitar).
  final int? fee;
  final bool reducedCoverage;

  /// Paso del proceso donde se genera el servicio (servicios derivados e incluidos).
  final ProcessStep? relatedStep;
}
