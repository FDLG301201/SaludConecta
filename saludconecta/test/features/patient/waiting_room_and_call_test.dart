import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  /// La videollamada tiene animaciones que no terminan: se avanza el reloj a mano.
  Future<void> settleCall(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('Carmen prueba su conexión, entra a la videollamada y sale', (tester) async {
    final deps = patientDependencies(SeedIds.carmen);
    final c = openCaseOf(deps, SeedIds.carmen, ProcessStep.consultation);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseDetail(c.id));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ir a la sala de espera'));
    await settleCall(tester);
    expect(find.text('Comprobando tu conexión…'), findsOneWidget);
    // La prueba de conexión termina en 2.4 s y entonces se detienen sus animaciones.
    await tester.pumpAndSettle();
    expect(find.text('Unirse a la consulta'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Luis Castillo'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('Llamar a soporte'), findsOneWidget);

    await tester.tap(find.text('Unirse a la consulta'));
    await settleCall(tester);
    expect(find.text('Dr. Carlos Méndez'), findsOneWidget);
    expect(find.text('Google Meet'), findsOneWidget);
    // La plataforma y el cronómetro van en la barra superior, no a media pantalla.
    expect(tester.getTopLeft(find.text('Google Meet')).dy, lessThan(100));

    await tester.tap(find.byTooltip('Apagar cámara'));
    await tester.pump();
    expect(find.text('CR'), findsOneWidget);

    await tester.tap(find.byTooltip('Chat'));
    await settleCall(tester);
    await tester.enterText(find.byType(TextField), 'Me duele al sentarme');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();
    expect(find.text('Me duele al sentarme'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await settleCall(tester);

    await tester.tap(find.byTooltip('Colgar'));
    await settleCall(tester);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('Caso ${c.id}'), findsOneWidget);
    // La vista del paciente es solo visual: el caso sigue en el paso 7.
    expect(deps.cases.caseById(c.id)!.currentStep, ProcessStep.consultation);
  });

  testWidgets('sin el consentimiento firmado, la sala de espera lo pide primero', (tester) async {
    final deps = patientDependencies(SeedIds.jose);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.consentAdmission);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.waitingRoom));
    await tester.pumpAndSettle();
    expect(find.text('Primero firma tu consentimiento'), findsOneWidget);
  });
}
