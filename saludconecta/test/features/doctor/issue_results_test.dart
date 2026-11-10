import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<(AppDependencies, String)> openForm(WidgetTester tester) async {
    final deps = staffDependencies(UserRole.doctor, doctorId: SeedIds.mendez);
    final c = openCaseOf(deps, SeedIds.luisa, ProcessStep.consultationResult);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.issueResults));
    await tester.pumpAndSettle();
    return (deps, c.id);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).first);
    // Espera a que la lista deje de moverse (el arrastre deja inercia) antes de tocar.
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('sin indicaciones no se pueden emitir los resultados', (tester) async {
    final (deps, id) = await openForm(tester);
    await tapVisible(tester, find.text('Emitir y notificar'));
    expect(find.text('Las indicaciones son obligatorias.'), findsOneWidget);
    expect(deps.cases.caseById(id)!.currentStep, ProcessStep.consultationResult);
  });

  testWidgets('el médico emite receta, una orden, indicaciones y cita a 15 días para Luisa', (tester) async {
    final (deps, id) = await openForm(tester);
    await tapVisible(tester, find.widgetWithText(ActionChip, 'Acetaminofén 500 mg'));
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Perfil lipídico'));
    final instructions = find.widgetWithText(TextField, 'Indicaciones para el paciente');
    await tester.scrollUntilVisible(instructions, 150, scrollable: find.byType(Scrollable).first);
    await tester.enterText(instructions, 'Dieta baja en grasas y control en 3 meses.');
    await tapVisible(tester, find.text('15 días'));
    await tapVisible(tester, find.text('Emitir y notificar'));

    final results = deps.cases.caseById(id)!.results!;
    expect(results.prescription!.items.single.medication, 'Acetaminofén 500 mg');
    expect(results.ordersOf(OrderType.lab).single.description, 'Perfil lipídico');
    expect(results.followUpInDays, 15);
    expect(deps.cases.caseById(id)!.currentStep, ProcessStep.administrativeClosure);
    expect(find.text('Mi agenda'), findsOneWidget);
  });
}
