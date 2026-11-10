import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/widgets/appointment_status_chip.dart';
import 'package:saludconecta/core/widgets/case_card.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/admission/admission_filter.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('los filtros reparten la bandeja por paso pendiente (los rechazados van en "Por validar")', () {
    final inbox = testDependencies().cases.admissionInbox();
    int count(AdmissionFilter f) => inbox.where(f.matches).length;
    expect(count(AdmissionFilter.all), 5);
    expect(count(AdmissionFilter.newRequests), 1);
    expect(count(AdmissionFilter.toValidate), 2);
    expect(count(AdmissionFilter.toSchedule), 1);
    expect(count(AdmissionFilter.toConfirm), 1);
  });

  test('el estado de la cita depende del paso pendiente', () {
    final deps = testDependencies();
    String label(String patientId, ProcessStep step) =>
        AppointmentStatusChip.labelOf(openCaseOf(deps, patientId, step));
    expect(label(SeedIds.ramon, ProcessStep.patientConfirmation), 'Por confirmar');
    expect(label(SeedIds.jose, ProcessStep.consentAdmission), 'Esperando consentimiento');
    expect(label(SeedIds.carmen, ProcessStep.consultation), 'Paciente en sala de espera');
    expect(label(SeedIds.luisa, ProcessStep.consultationResult), 'Resultados pendientes');
    expect(label(SeedIds.ramon, ProcessStep.administrativeClosure), 'Atendida');
  });

  testWidgets('la bandeja filtra por paso y muestra cuánto espera cada caso', (tester) async {
    await tester.pumpWidget(appWith(staffDependencies(UserRole.admission)));
    await tester.pumpAndSettle();
    expect(find.text('Bandeja de Admisión'), findsOneWidget);
    expect(find.text('Todas (5)'), findsOneWidget);
    expect(find.textContaining('Hace '), findsWidgets);

    await tester.tap(find.text('Por validar (2)'));
    await tester.pumpAndSettle();
    expect(find.byType(CaseCard), findsNWidgets(2));
    expect(find.text('Carmen Reyes'), findsOneWidget);
    expect(find.text('Pedro Almonte'), findsOneWidget);
  });
}
