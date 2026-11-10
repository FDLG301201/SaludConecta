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

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  VoidCallback? onPressedOf(WidgetTester tester, String label) => tester
      .widget<ButtonStyleButton>(
        find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
      )
      .onPressed;

  testWidgets('Facturación ve los casos pendientes de cierre', (tester) async {
    await tester.pumpWidget(appWith(staffDependencies(UserRole.billing)));
    await tester.pumpAndSettle();
    expect(find.text('Pendientes de cierre'), findsOneWidget);
    expect(find.text('Ramón Ortiz'), findsOneWidget);
    expect(find.text('Cerrar caso'), findsOneWidget);
  });

  testWidgets('Roberto envía la reclamación, registra el pago y cierra el caso de Ramón', (tester) async {
    final deps = staffDependencies(UserRole.billing);
    final c = openCaseOf(deps, SeedIds.ramon, ProcessStep.administrativeClosure);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseAction(c.id, CaseAction.closure));
    await tester.pumpAndSettle();

    expect(find.text('Cierre administrativo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cerrar caso'), 150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(onPressedOf(tester, 'Cerrar caso'), isNull);

    // La reclamación está más arriba: se desplaza hacia arriba.
    final claim = find.textContaining('Enviar reclamación a');
    await tester.scrollUntilVisible(claim, -150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(claim);
    await tester.pumpAndSettle();
    expect(find.textContaining('Aprobada · REC-'), findsOneWidget);

    await tapVisible(tester, find.text('Tarjeta'));
    await tapVisible(tester, find.textContaining('Registrar pago de copago'));
    expect(find.textContaining('Pagado con Tarjeta'), findsOneWidget);

    await tapVisible(tester, find.text('Cerrar caso'));
    final closed = deps.cases.caseById(c.id)!;
    expect(closed.currentStep, ProcessStep.followUp);
    expect(closed.billing!.closedAt, isNotNull);
    expect(find.text('Pendientes de cierre'), findsOneWidget);
  });
}
