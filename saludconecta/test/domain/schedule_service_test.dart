import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/schedule_service.dart';

import '../support/fixtures.dart';

void main() {
  // Lunes 9 de noviembre de 2026, 8:00.
  final monday8 = DateTime(2026, 11, 9, 8);
  final thursday = DateTime(2026, 11, 12);

  test('turnos de 30 minutos, sin la pausa de 12:00 a 13:00', () {
    final slots = ScheduleService.availableSlots(doctor: mendez, day: thursday, cases: const [], now: monday8);
    expect(slots, hasLength(16));
    expect(slots.first, DateTime(2026, 11, 12, 8));
    expect(slots.last, DateTime(2026, 11, 12, 16, 30));
    expect(slots.where((slot) => slot.hour == 12), isEmpty);
  });

  test('excluye los turnos ocupados por otros casos', () {
    // Este caso tiene cita el jueves a las 10:30 con el Dr. Méndez.
    final booked = caseAt(ProcessStep.patientConfirmation);
    final slots = ScheduleService.availableSlots(doctor: mendez, day: thursday, cases: [booked], now: monday8);
    expect(slots, isNot(contains(DateTime(2026, 11, 12, 10, 30))));
    expect(slots, hasLength(15));
  });

  test('excluye el pasado y la hora mínima de anticipación', () {
    final slots = ScheduleService.availableSlots(
      doctor: mendez,
      day: DateTime(2026, 11, 9),
      cases: const [],
      now: DateTime(2026, 11, 9, 10, 10),
    );
    expect(slots.first, DateTime(2026, 11, 9, 11, 30));
  });

  test('respeta los días laborables de cada médico', () {
    final saturday = DateTime(2026, 11, 14);
    final sunday = DateTime(2026, 11, 15);
    final jimenez = catalog.doctorById(SeedIds.jimenez);
    expect(ScheduleService.availableSlots(doctor: mendez, day: sunday, cases: const [], now: monday8), isEmpty);
    expect(ScheduleService.availableSlots(doctor: mendez, day: saturday, cases: const [], now: monday8), hasLength(8));
    expect(ScheduleService.availableSlots(doctor: jimenez, day: saturday, cases: const [], now: monday8), isEmpty);
  });

  test('días disponibles en los próximos 14 días, sin domingos', () {
    final days = ScheduleService.availableDays(doctor: mendez, cases: const [], now: monday8);
    expect(days, hasLength(12), reason: '14 días menos 2 domingos');
    expect(days.where((day) => day.weekday == DateTime.sunday), isEmpty);
    expect(days.first, DateTime(2026, 11, 9));
  });
}
