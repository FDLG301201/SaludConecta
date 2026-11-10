import '../../core/utils/formatters.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/services/notification_builder.dart';

/// Avisos del paciente (campana del Inicio) y cuántos no ha leído.
class PatientNotifications {
  const PatientNotifications._();

  /// Avisos de los casos del paciente, del más reciente al más antiguo.
  static List<PatientNotification> build(Iterable<TelemedicineCase> cases, CatalogRepository catalog) {
    final builder = NotificationBuilder(
      formatDateTime: Formatters.dateTime,
      doctorName: (doctorId) => catalog.doctorById(doctorId).displayName,
    );
    return builder.forPatient(cases);
  }

  /// Avisos posteriores a la última vez que el paciente abrió la campana ([seenAt]).
  static int unreadCount(List<PatientNotification> items, DateTime? seenAt) {
    if (seenAt == null) return items.length;
    return items.where((n) => n.at.isAfter(seenAt)).length;
  }
}
