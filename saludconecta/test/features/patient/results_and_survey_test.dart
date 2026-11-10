import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/core/utils/formatters.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('Ramón ve su receta con QR y pide la cita de seguimiento', (tester) async {
    final deps = patientDependencies(SeedIds.ramon);
    final c = openCaseOf(deps, SeedIds.ramon, ProcessStep.administrativeClosure);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver mis resultados'));
    await tester.pump();
    await tester.tap(find.text('Ver mis resultados'));
    await tester.pumpAndSettle();

    expect(find.text('Metformina 850 mg'), findsOneWidget);
    expect(find.text('Losartán 50 mg'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(c.results!.prescription!.verificationCode), findsOneWidget);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Hemograma'), 200, scrollable: list);
    await tester.scrollUntilVisible(find.text('Solicitar cita de seguimiento'), 200, scrollable: list);
    await tester.pump();
    await tester.tap(find.text('Solicitar cita de seguimiento'));
    await tester.pumpAndSettle();

    // El asistente abre con "Seguimiento postconsulta" y la fecha que indicó el médico (30 días).
    expect(find.text('¿Por qué canal nos contactas?'), findsOneWidget);
    await tester.tap(find.text('WhatsApp'));
    await tester.enterText(find.byType(TextFormField), 'Control mensual de la glicemia');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final issued = c.completedAt(ProcessStep.consultationResult)!;
    expect(find.text(Formatters.date(DateTime(issued.year, issued.month, issued.day + 30))), findsOneWidget);
    expect(find.text('Seguimiento postconsulta'), findsWidgets);
  });

  testWidgets('"Mis resultados" del Inicio abre los resultados más recientes de María', (tester) async {
    final deps = patientDependencies(SeedIds.maria);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis resultados'));
    await tester.pumpAndSettle();

    final latest = deps.cases.casesOfPatient(SeedIds.maria).firstWhere((c) => c.results != null);
    expect(find.text('Mis resultados'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(latest.results!.instructions),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Indicaciones'), findsOneWidget);
  });

  testWidgets('el detalle del caso abre los resultados de José, que no tienen receta', (tester) async {
    final deps = patientDependencies(SeedIds.jose);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.followUp);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseDetail(c.id));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Ver mis resultados'), 300, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text('Ver mis resultados'));
    await tester.pumpAndSettle();
    expect(find.text('Tu médico no indicó medicamentos en esta consulta.'), findsOneWidget);
    expect(find.text(c.results!.instructions), findsOneWidget);
  });

  testWidgets('José responde la encuesta y su caso queda completado', (tester) async {
    final deps = patientDependencies(SeedIds.jose);
    final c = openCaseOf(deps, SeedIds.jose, ProcessStep.followUp);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Responder la encuesta'));
    await tester.pumpAndSettle();

    // Sin estrellas ni recomendación, el botón está deshabilitado.
    await tester.tap(find.text('Enviar encuesta'));
    await tester.pump();
    expect(deps.cases.caseById(c.id)!.status, CaseStatus.active);

    await tester.tap(find.byTooltip('5 de 5'));
    await tester.tap(find.text('10'));
    await tester.enterText(find.byType(TextField), 'Muy buena orientación');
    await tester.pump();
    await tester.ensureVisible(find.text('Enviar encuesta'));
    await tester.pump();
    await tester.tap(find.text('Enviar encuesta'));
    await tester.pumpAndSettle();

    final updated = deps.cases.caseById(c.id)!;
    expect(updated.status, CaseStatus.completed);
    expect(updated.followUp!.survey!.rating, 5);
    expect(updated.followUp!.survey!.nps, 10);
    expect(find.text('¡Gracias por tu opinión!'), findsOneWidget);
  });
}
