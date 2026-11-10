import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('el paciente ve la próxima acción, la línea de tiempo y puede cancelar', (tester) async {
    final deps = testDependencies();
    final jose = deps.catalog.patientById(SeedIds.jose);
    final pending = deps.cases.casesOfPatient(jose.id).firstWhere((c) => c.currentStep == ProcessStep.consentAdmission);
    deps.session.loginPatient(jose);
    deps.router.go(AppRoutes.caseDetail(pending.id));
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    expect(find.text('Caso ${pending.id}'), findsOneWidget);
    expect(find.text('Firmar consentimiento'), findsOneWidget);
    expect(find.text('Línea de tiempo'), findsOneWidget);
    final cancel = find.text('Cancelar cita');
    await tester.scrollUntilVisible(cancel, 400, scrollable: find.byType(Scrollable).first);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();
    expect(deps.cases.caseById(pending.id)!.status, CaseStatus.cancelled);
    expect(find.text('Cancelar cita'), findsNothing);
    // La lista solo construye lo visible: se vuelve arriba para ver la tarjeta de la próxima acción.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('Solicitud cancelada'), findsWidgets);
  });

  testWidgets('un caso que no existe muestra "Caso no encontrado"', (tester) async {
    final deps = testDependencies(initialLocation: AppRoutes.caseDetail('TM-0000-0000'));
    deps.session.loginDoctor(deps.catalog.doctorById(SeedIds.mendez));
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    expect(find.text('Caso no encontrado'), findsWidgets);
    expect(find.text('Volver al inicio'), findsOneWidget);
  });
}
