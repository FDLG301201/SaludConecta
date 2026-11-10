import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('la agenda de hoy agrupa las citas por médico con su estado', (tester) async {
    final deps = staffDependencies(UserRole.admission);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.admissionAgenda);
    await tester.pumpAndSettle();
    expect(find.text('Agenda'), findsWidgets);
    expect(find.text('Dr. Carlos Méndez'), findsOneWidget);
    expect(find.text('Paciente en sala de espera'), findsWidgets);
  });

  testWidgets('Admisión registra una llamada de seguimiento a José', (tester) async {
    final deps = staffDependencies(UserRole.admission);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.followUp);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.admissionFollowUp);
    await tester.pumpAndSettle();
    expect(find.text('Encuesta pendiente'), findsWidgets);

    await tester.tap(find.text('Registrar llamada').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Se siente mejor; recordó su vacuna');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final calls = deps.cases.caseById(c.id)!.followUp!.calls;
    expect(calls.last.note, 'Se siente mejor; recordó su vacuna');
    expect(find.textContaining('Se siente mejor'), findsOneWidget);
  });
}
