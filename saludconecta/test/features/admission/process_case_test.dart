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

  /// Ana abre "Procesar solicitud" del caso de [patientId] que tiene [step] pendiente.
  Future<(AppDependencies, String)> openProcess(WidgetTester tester, String patientId, ProcessStep step) async {
    final deps = staffDependencies(UserRole.admission);
    final c = openCaseOf(deps, patientId, step);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.process));
    await tester.pumpAndSettle();
    return (deps, c.id);
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 100, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('paso 2: Admisión registra la solicitud de José', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.jose, ProcessStep.reception);
    expect(find.text('Procesar $id'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Paciente confirma síntomas por teléfono');
    await tapButton(tester, 'Registrar solicitud');
    final c = deps.cases.caseById(id)!;
    expect(c.currentStep, ProcessStep.insuranceValidation);
    expect(c.reception!.notes, 'Paciente confirma síntomas por teléfono');
    expect(find.text('Consultar al seguro'), findsOneWidget);
  });

  testWidgets('paso 3: el seguro aprueba la cobertura de Carmen', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.carmen, ProcessStep.insuranceValidation);
    await tapButton(tester, 'Consultar al seguro');
    expect(deps.cases.caseById(id)!.currentStep, ProcessStep.scheduling);
    expect(find.textContaining('Seguro aprobado'), findsOneWidget);
  });

  testWidgets('paso 3: el seguro rechaza a Pedro y continúa como privado', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.pedro, ProcessStep.insuranceValidation);
    await tapButton(tester, 'Consultar al seguro');
    expect(deps.cases.caseById(id)!.status, CaseStatus.insuranceRejected);
    expect(find.text('Afiliación inactiva'), findsWidgets);

    await tapButton(tester, 'Continuar como privado');
    final c = deps.cases.caseById(id)!;
    expect(c.privatePay, isTrue);
    expect(c.currentStep, ProcessStep.scheduling);
  });

  testWidgets('paso 4: Admisión agenda la cita de Luisa en el primer turno libre', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.luisa, ProcessStep.scheduling);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('slot_0')), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('slot_0')));
    await tester.pump();
    await tapButton(tester, 'Agendar cita');
    final c = deps.cases.caseById(id)!;
    expect(c.currentStep, ProcessStep.patientConfirmation);
    expect(c.appointment!.platform, VideoPlatform.teams);
    expect(find.text('Vista previa del mensaje'), findsOneWidget);
  });

  testWidgets('paso 5: Admisión envía el enlace a Ramón y vuelve a la bandeja', (tester) async {
    final (deps, id) = await openProcess(tester, SeedIds.ramon, ProcessStep.patientConfirmation);
    await tapButton(tester, 'Enviar confirmación');
    final c = deps.cases.caseById(id)!;
    expect(c.currentStep, ProcessStep.consentAdmission);
    expect(c.confirmation!.sentVia, RequestChannel.whatsapp);
    expect(find.text('Bandeja de Admisión'), findsOneWidget);
  });

  testWidgets('un caso ya procesado muestra un aviso', (tester) async {
    await openProcess(tester, SeedIds.jose, ProcessStep.consentAdmission);
    expect(find.text('Esta solicitud ya fue procesada'), findsOneWidget);
  });
}
