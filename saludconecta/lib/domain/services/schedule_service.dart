import '../models/enums.dart';
import '../models/people.dart';
import '../models/telemedicine_case.dart';

/// Calcula los turnos disponibles de los médicos (paso 4).
class ScheduleService {
  const ScheduleService._();

  static const slotMinutes = 30;
  static const horizonDays = 14;

  /// Hora de la pausa del mediodía (12:00–13:00), que no se agenda.
  static const breakHour = 12;

  /// No se agenda nada antes de una hora desde ahora.
  static const minimumLead = Duration(hours: 1);

  /// Turnos libres de [doctor] el día [day].
  static List<DateTime> availableSlots({
    required Doctor doctor,
    required DateTime day,
    required Iterable<TelemedicineCase> cases,
    required DateTime now,
  }) {
    final hours = doctor.schedule[day.weekday];
    if (hours == null) return const [];
    final booked = bookedSlots(doctor.id, cases);
    final earliest = now.add(minimumLead);
    final slots = <DateTime>[];
    for (var minute = hours.startHour * 60; minute < hours.endHour * 60; minute += slotMinutes) {
      if (minute ~/ 60 == breakHour) continue;
      final slot = DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
      if (slot.isBefore(earliest) || booked.contains(slot)) continue;
      slots.add(slot);
    }
    return slots;
  }

  /// Horas ya ocupadas por citas de casos no cancelados.
  static Set<DateTime> bookedSlots(String doctorId, Iterable<TelemedicineCase> cases) {
    return {
      for (final c in cases)
        if (c.status != CaseStatus.cancelled && c.appointment != null && c.appointment!.doctorId == doctorId)
          c.appointment!.dateTime,
    };
  }

  /// Días (desde hoy y dentro de los próximos 14) con al menos un turno libre.
  static List<DateTime> availableDays({
    required Doctor doctor,
    required Iterable<TelemedicineCase> cases,
    required DateTime now,
  }) {
    final days = <DateTime>[];
    for (var i = 0; i < horizonDays; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (availableSlots(doctor: doctor, day: day, cases: cases, now: now).isNotEmpty) {
        days.add(day);
      }
    }
    return days;
  }
}
