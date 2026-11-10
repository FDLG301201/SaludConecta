import '../models/enums.dart';
import '../models/process_event.dart';
import '../models/telemedicine_case.dart';
import '../process/process_step.dart';

/// Un aviso para el paciente (campana del Inicio).
class PatientNotification {
  const PatientNotification({required this.caseId, required this.at, required this.title, required this.body});

  final String caseId;
  final DateTime at;
  final String title;
  final String body;
}

/// Convierte los eventos de los casos del paciente en avisos legibles.
class NotificationBuilder {
  const NotificationBuilder({required this.formatDateTime, required this.doctorName});

  /// Formatea fecha y hora (en la app: `Formatters.dateTime`).
  final String Function(DateTime) formatDateTime;

  /// Nombre del médico por su id.
  final String Function(String doctorId) doctorName;

  /// Avisos de los casos del paciente, del más reciente al más antiguo.
  List<PatientNotification> forPatient(Iterable<TelemedicineCase> cases, {int limit = 20}) {
    final items = <PatientNotification>[];
    for (final c in cases) {
      for (final e in c.events) {
        final notification = _describe(c, e);
        if (notification != null) items.add(notification);
      }
    }
    items.sort((a, b) => b.at.compareTo(a.at));
    return items.take(limit).toList();
  }

  PatientNotification? _describe(TelemedicineCase c, ProcessEvent e) {
    // Las acciones del propio paciente no generan aviso.
    if (e.actor == Actor.patient) return null;
    PatientNotification make(String title, String body) =>
        PatientNotification(caseId: c.id, at: e.at, title: title, body: body);

    switch (e.kind) {
      case EventKind.rejected:
        return make('Tu seguro no aprobó la cobertura', '${e.detail}. Admisión te contactará para continuar.');
      case EventKind.cancelled:
        return make('Tu solicitud fue cancelada', 'Caso ${c.id}.');
      case EventKind.call:
        return make('Te llamamos para dar seguimiento', e.detail);
      case EventKind.started || EventKind.claim || EventKind.payment:
        return null;
      case EventKind.completed:
        break;
    }

    final insurance = c.insurance;
    final appointment = c.appointment;
    switch (e.step) {
      case ProcessStep.reception:
        return make('Recibimos tu solicitud', 'Admisión registró tu caso ${c.id}.');
      case ProcessStep.insuranceValidation:
        if (c.privatePay) {
          return make('Continuarás como paciente privado', 'Tu atención no tendrá cobertura del seguro.');
        }
        return make(
          'Tu seguro aprobó ${insurance?.coveragePercent ?? 0}% de cobertura',
          'Autorización ${insurance?.authorizationNumber ?? '-'}.',
        );
      case ProcessStep.scheduling:
        if (appointment == null) return null;
        return make(
          'Cita agendada',
          '${formatDateTime(appointment.dateTime)} con ${doctorName(appointment.doctorId)} '
              'por ${appointment.platform.label}.',
        );
      case ProcessStep.patientConfirmation:
        return make(
          'Te enviamos el enlace por ${c.confirmation?.sentVia.label ?? 'WhatsApp'}',
          'Firma tu consentimiento en la app.',
        );
      case ProcessStep.consultationResult:
        return make('Tus resultados están listos', 'Revisa tu receta, tus órdenes y tus indicaciones.');
      case ProcessStep.administrativeClosure:
        return make('Tu atención fue cerrada', 'Cuéntanos cómo te fue en la encuesta de satisfacción.');
      case ProcessStep.requestAppointment ||
            ProcessStep.consentAdmission ||
            ProcessStep.consultation ||
            ProcessStep.followUp:
        return null;
    }
  }
}
