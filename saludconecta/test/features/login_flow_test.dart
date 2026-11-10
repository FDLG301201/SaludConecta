import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/domain/models/enums.dart';

import '../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('el ingreso como paciente lleva al Inicio', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paciente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('María Fernández'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, María'), findsOneWidget);
  });

  testWidgets('un carnet que no existe muestra un error en el campo', (tester) async {
    await tester.pumpWidget(buildTestApp(initialLocation: AppRoutes.patientLogin));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'XX-000');
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('No encontramos ese carnet. Revisa el número.'), findsOneWidget);
  });

  testWidgets('el personal elige su usuario y llega a su bandeja', (tester) async {
    await tester.pumpWidget(buildTestApp(initialLocation: AppRoutes.staffLogin(UserRole.admission)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Peña'));
    await tester.pumpAndSettle();
    expect(find.text('Bandeja de Admisión'), findsOneWidget);
  });
}
