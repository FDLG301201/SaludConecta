import '../models/case_records.dart';
import '../models/catalog.dart';
import '../models/enums.dart';
import '../models/telemedicine_case.dart';

/// Un punto de la auditoría del cierre administrativo.
class AuditItem {
  const AuditItem(this.label, this.ok);

  final String label;
  final bool ok;
}

/// Cálculos del paso 9: factura, copago, auditoría y regla de cierre.
class BillingCalculator {
  const BillingCalculator._();

  /// % que cubre el seguro: 0 si el paciente es privado o si el seguro no aprobó.
  static int coverageOf(TelemedicineCase c) {
    final insurance = c.insurance;
    if (c.privatePay || insurance == null || !insurance.approved) return 0;
    return insurance.coveragePercent;
  }

  /// Factura del caso: tarifa, parte del seguro (redondeada) y copago.
  static Invoice invoiceFor(TelemedicineCase c, MedicalService service) {
    final fee = service.fee ?? 0;
    final coverage = coverageOf(c);
    final insurerAmount = (fee * coverage / 100).round();
    return Invoice(fee: fee, coveragePercent: coverage, insurerAmount: insurerAmount, copay: fee - insurerAmount);
  }

  /// Estado de la reclamación: el registrado, o el inicial según la factura.
  static ClaimStatus claimStatusOf(TelemedicineCase c, Invoice invoice) =>
      c.billing?.claimStatus ?? (invoice.insurerAmount == 0 ? ClaimStatus.notApplicable : ClaimStatus.pending);

  /// Lista de auditoría. Todas las casillas deben estar en ✓ para cerrar.
  static List<AuditItem> auditChecklist(TelemedicineCase c, Invoice invoice) {
    final claim = claimStatusOf(c, invoice);
    final insurance = c.insurance;
    final authorized =
        c.privatePay || (insurance != null && insurance.approved && insurance.authorizationNumber != null);
    return [
      AuditItem('Consentimiento informado firmado', c.consent != null),
      AuditItem('Autorización del seguro o paciente privado', authorized),
      AuditItem('Notas clínicas completas', c.consultation?.notes.isComplete ?? false),
      AuditItem('Resultados de la consulta emitidos', c.results != null),
      AuditItem(
          'Reclamación aprobada o no aplica', claim == ClaimStatus.approved || claim == ClaimStatus.notApplicable),
    ];
  }

  /// ¿Falta cobrar el copago?
  static bool paymentPending(TelemedicineCase c, Invoice invoice) => invoice.copay > 0 && c.billing?.payment == null;

  /// Se puede cerrar cuando la auditoría está completa y el copago está pagado (o es 0).
  static bool canClose(TelemedicineCase c, Invoice invoice) =>
      auditChecklist(c, invoice).every((item) => item.ok) && !paymentPending(c, invoice);
}
