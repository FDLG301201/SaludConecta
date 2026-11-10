import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/services/notification_builder.dart';
import 'package:saludconecta/features/patient/patient_notifications.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('cuenta como no leídos los avisos posteriores a la última lectura', () {
    final at = DateTime(2026, 11, 9, 10);
    final items = [
      PatientNotification(caseId: 'TM-1', at: at.add(const Duration(hours: 2)), title: 'Cita agendada', body: ''),
      PatientNotification(caseId: 'TM-1', at: at, title: 'Recibimos tu solicitud', body: ''),
    ];
    expect(PatientNotifications.unreadCount(items, null), 2);
    expect(PatientNotifications.unreadCount(items, at), 1);
    expect(PatientNotifications.unreadCount(items, at.add(const Duration(hours: 2))), 0);
  });

  test('arma los avisos de los casos del paciente con el nombre del médico', () {
    final deps = testDependencies();
    final items = PatientNotifications.build(deps.cases.casesOfPatient(SeedIds.ramon), deps.catalog);
    expect(
      items.where((n) => n.title == 'Cita agendada' && n.body.contains('Dra. Laura Jiménez')),
      isNotEmpty,
    );
  });
}
