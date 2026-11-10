import 'enums.dart';

// Datos que cada paso agrega al caso. Todas las clases son inmutables.

/// Paso 2: recepción de la solicitud.
class ReceptionData {
  const ReceptionData({required this.registeredBy, this.notes = ''});

  final String registeredBy;
  final String notes;
}

/// Paso 3: respuesta del seguro.
class InsuranceValidation {
  const InsuranceValidation({
    required this.approved,
    required this.coveragePercent,
    required this.message,
    required this.at,
    this.authorizationNumber,
  });

  final bool approved;
  final int coveragePercent;
  final String message;
  final DateTime at;

  /// Número de autorización (solo si se aprobó), formato AUT-yyyyMMdd-NNNN.
  final String? authorizationNumber;
}

/// Paso 4: la cita agendada.
class Appointment {
  const Appointment({required this.doctorId, required this.dateTime, required this.platform});

  final String doctorId;
  final DateTime dateTime;
  final VideoPlatform platform;
}

/// Paso 5: confirmación enviada al paciente.
class Confirmation {
  const Confirmation({required this.link, required this.sentVia, required this.instructions, required this.at});

  /// Enlace de demostración de la videollamada (no se abre).
  final String link;

  /// WhatsApp o correo.
  final RequestChannel sentVia;
  final String instructions;
  final DateTime at;
}

/// Un punto de la firma, con coordenadas normalizadas entre 0 y 1.
class SignaturePoint {
  const SignaturePoint(this.x, this.y);

  final double x;
  final double y;
}

/// Paso 6: consentimiento informado y admisión virtual.
class ConsentRecord {
  const ConsentRecord({required this.at, required this.identityConfirmed, required this.signature});

  final DateTime at;
  final bool identityConfirmed;

  /// Trazos de la firma; cada trazo es una lista de puntos.
  final List<List<SignaturePoint>> signature;
}

/// Notas clínicas que escribe el médico durante la consulta.
class ClinicalNotes {
  const ClinicalNotes({this.chiefComplaint = '', this.assessment = '', this.diagnosis = '', this.plan = ''});

  /// Motivo de consulta.
  final String chiefComplaint;

  /// Evaluación.
  final String assessment;
  final String diagnosis;
  final String plan;

  /// El motivo y el diagnóstico son obligatorios para finalizar la consulta.
  bool get isComplete => chiefComplaint.trim().isNotEmpty && diagnosis.trim().isNotEmpty;
}

/// Paso 7: la consulta.
class ConsultationRecord {
  const ConsultationRecord({required this.startedAt, this.endedAt, this.notes = const ClinicalNotes()});

  final DateTime startedAt;
  final DateTime? endedAt;
  final ClinicalNotes notes;
}

class PrescriptionItem {
  const PrescriptionItem({
    required this.medication,
    required this.dose,
    required this.frequency,
    required this.duration,
  });

  final String medication;
  final String dose;
  final String frequency;
  final String duration;
}

class Prescription {
  const Prescription({required this.items, required this.verificationCode});

  final List<PrescriptionItem> items;

  /// Código que aparece en el QR de la receta.
  final String verificationCode;
}

class MedicalOrder {
  const MedicalOrder({required this.type, required this.description});

  final OrderType type;
  final String description;
}

/// Referimiento presencial a un especialista.
class Referral {
  const Referral({required this.specialty, required this.reason});

  final Specialty specialty;
  final String reason;
}

/// Paso 8: resultados de la consulta.
class ConsultationResults {
  const ConsultationResults({
    required this.instructions,
    this.prescription,
    this.orders = const [],
    this.referral,
    this.followUpInDays,
  });

  final String instructions;
  final Prescription? prescription;
  final List<MedicalOrder> orders;
  final Referral? referral;

  /// Días para la próxima cita de seguimiento (7, 15 o 30); `null` si no requiere.
  final int? followUpInDays;

  List<MedicalOrder> ordersOf(OrderType type) => orders.where((o) => o.type == type).toList();
}

/// Factura del caso. Los montos son pesos dominicanos enteros.
class Invoice {
  const Invoice({required this.fee, required this.coveragePercent, required this.insurerAmount, required this.copay});

  final int fee;
  final int coveragePercent;
  final int insurerAmount;
  final int copay;
}

class Payment {
  const Payment({required this.method, required this.amount, required this.at});

  final PaymentMethod method;
  final int amount;
  final DateTime at;
}

/// Paso 9: cierre administrativo.
class BillingRecord {
  const BillingRecord(
      {required this.invoice, required this.claimStatus, this.claimNumber, this.payment, this.closedAt});

  final Invoice invoice;
  final ClaimStatus claimStatus;
  final String? claimNumber;
  final Payment? payment;
  final DateTime? closedAt;

  BillingRecord copyWith({ClaimStatus? claimStatus, String? claimNumber, Payment? payment, DateTime? closedAt}) {
    return BillingRecord(
      invoice: invoice,
      claimStatus: claimStatus ?? this.claimStatus,
      claimNumber: claimNumber ?? this.claimNumber,
      payment: payment ?? this.payment,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}

class FollowUpCall {
  const FollowUpCall({required this.at, required this.byName, required this.note});

  final DateTime at;
  final String byName;
  final String note;
}

/// Encuesta de satisfacción.
class Survey {
  const Survey({required this.rating, required this.nps, required this.at, this.comment = ''});

  /// Estrellas, de 1 a 5.
  final int rating;

  /// "¿Qué tan probable es que nos recomiendes?", de 0 a 10.
  final int nps;
  final DateTime at;
  final String comment;
}

/// Paso 10: seguimiento.
class FollowUpRecord {
  const FollowUpRecord({this.calls = const [], this.survey});

  final List<FollowUpCall> calls;
  final Survey? survey;

  FollowUpRecord copyWith({List<FollowUpCall>? calls, Survey? survey}) {
    return FollowUpRecord(calls: calls ?? this.calls, survey: survey ?? this.survey);
  }
}
