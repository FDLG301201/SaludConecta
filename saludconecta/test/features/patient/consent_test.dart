import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/patient/consent/signature_pad.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  /// Marca la casilla con ese texto (desplaza la lista hasta verla).
  Future<void> check(WidgetTester tester, String label) async {
    final box = find.text(label);
    await tester.scrollUntilVisible(box, 100, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(box);
    await tester.pump();
  }

  testWidgets('José firma el consentimiento y pasa a la sala de espera', (tester) async {
    final deps = patientDependencies(SeedIds.jose);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.consentAdmission);
    final jose = deps.catalog.patientById(SeedIds.jose);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.consent));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Firmar y continuar'));
    await tester.pump();
    expect(find.text('Marca las tres casillas del consentimiento.'), findsOneWidget);

    await check(tester, 'He leído y acepto el consentimiento informado');
    await check(tester, 'Autorizo el uso de mis datos de salud para esta atención');
    await check(tester, 'Confirmo mi identidad: ${jose.fullName}, cédula ${jose.cedula}');
    await tester.tap(find.text('Firmar y continuar'));
    await tester.pump();
    expect(find.text('La firma es obligatoria.'), findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(SignaturePad)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(15, 4));
    }
    await gesture.up();
    await tester.tap(find.text('Firmar y continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(deps.cases.caseById(c.id)!.currentStep, ProcessStep.consultation);
    expect(find.text('Sala de espera'), findsWidgets);
  });

  testWidgets('otro paciente no puede abrir el consentimiento de José', (tester) async {
    final deps = patientDependencies(SeedIds.carmen);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.consentAdmission);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.consent));
    await tester.pumpAndSettle();
    expect(find.text('Caso no encontrado'), findsWidgets);
  });
}
