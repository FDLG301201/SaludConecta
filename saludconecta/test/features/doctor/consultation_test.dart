import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  /// La videollamada tiene animaciones que no terminan: se avanza el reloj a mano.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('la agenda del Dr. Méndez separa hoy y próximas, con el estado de cada cita', (tester) async {
    await tester.pumpWidget(appWith(staffDependencies(UserRole.doctor, doctorId: SeedIds.mendez)));
    await tester.pumpAndSettle();
    expect(find.text('Mi agenda'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Paciente en sala de espera'), findsOneWidget);
    expect(find.text('Iniciar consulta'), findsOneWidget);
    expect(find.text('Emitir resultados'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Esperando consentimiento'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Próximas'), findsOneWidget);
  });

  testWidgets('el médico atiende a Carmen: sin diagnóstico no puede finalizar; con él pasa a los resultados',
      (tester) async {
    final deps = staffDependencies(UserRole.doctor, doctorId: SeedIds.mendez);
    final c = openCaseOf(deps, SeedIds.carmen, ProcessStep.consultation);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar consulta'));
    await settle(tester);
    expect(deps.cases.caseById(c.id)!.consultation, isNotNull);
    expect(find.text('Carmen Reyes'), findsOneWidget);

    await tester.tap(find.byTooltip('Colgar'));
    await settle(tester);
    await tester.tap(find.text('Finalizar'));
    await settle(tester);
    expect(find.text('Escribe el motivo de consulta y el diagnóstico antes de finalizar.'), findsOneWidget);
    expect(deps.cases.caseById(c.id)!.currentStep, ProcessStep.consultation);

    // La hoja de notas se abrió sola: se completa el diagnóstico.
    await tester.enterText(find.widgetWithText(TextField, 'Diagnóstico *'), 'Lumbalgia mecánica');
    // Cierra la hoja con "atrás" (ocupa casi toda la pantalla y no deja tocar fuera).
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.byTooltip('Colgar'));
    await settle(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    final updated = deps.cases.caseById(c.id)!;
    expect(updated.currentStep, ProcessStep.consultationResult);
    expect(updated.consultation!.notes.diagnosis, 'Lumbalgia mecánica');
    expect(find.text('Emitir resultados'), findsWidgets);
  });
}
