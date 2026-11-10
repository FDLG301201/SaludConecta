import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/domain/services/notification_builder.dart';

import '../support/fixtures.dart';

void main() {
  final builder = NotificationBuilder(
    formatDateTime: (d) => '${d.day}/${d.month} ${d.hour}:${d.minute}',
    doctorName: (id) => catalog.doctorById(id).displayName,
  );

  test('convierte los eventos del personal en avisos, del más reciente al más antiguo', () {
    final notifications = builder.forPatient([caseAt(ProcessStep.consentAdmission)]);
    expect(notifications.map((n) => n.title), [
      'Te enviamos el enlace por WhatsApp',
      'Cita agendada',
      'Tu seguro aprobó 80% de cobertura',
      'Recibimos tu solicitud',
    ]);
    expect(notifications[1].body, '12/11 10:30 con Dr. Carlos Méndez por MS Teams.');
    expect(notifications.first.caseId, 'TM-2026-0100');
  });

  test('las acciones de la propia paciente no generan avisos', () {
    expect(builder.forPatient([newCase()]), isEmpty);
  });
}
