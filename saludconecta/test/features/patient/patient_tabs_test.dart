import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/core/widgets/case_card.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<AppDependencies> openTab(WidgetTester tester, String patientId, String route) async {
    final deps = patientDependencies(patientId);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(route);
    await tester.pumpAndSettle();
    return deps;
  }

  testWidgets('Mis citas separa las activas del historial', (tester) async {
    await openTab(tester, SeedIds.maria, AppRoutes.patientAppointments);
    expect(find.text('Activas (0)'), findsOneWidget);
    expect(find.text('No tienes citas en curso'), findsOneWidget);

    await tester.tap(find.text('Historial (4)'));
    await tester.pumpAndSettle();
    expect(find.byType(CaseCard), findsNWidgets(4));
  });

  testWidgets('Servicios muestra los canales y los 3 grupos con sus chips', (tester) async {
    await openTab(tester, SeedIds.maria, AppRoutes.patientServices);
    expect(find.text('Canales disponibles'), findsOneWidget);
    expect(find.text('Videoconferencia'), findsOneWidget);
    expect(find.text('Servicios clínicos'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Encuesta de satisfacción'), 300, scrollable: list);
    expect(find.text('Incluido en el proceso'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Receta médica'), 300, scrollable: list);
    expect(find.text('Se genera en tu consulta'), findsWidgets);
  });

  testWidgets('"Solicitar" en un servicio abre el asistente con ese servicio', (tester) async {
    await openTab(tester, SeedIds.maria, AppRoutes.patientServices);
    await tester.tap(find.text('Solicitar').first);
    await tester.pumpAndSettle();
    expect(find.text('¿Por qué canal nos contactas?'), findsOneWidget);
  });

  testWidgets('Perfil muestra el carnet y cierra la sesión', (tester) async {
    final deps = await openTab(tester, SeedIds.maria, AppRoutes.patientProfile);
    expect(find.text('ARS Salud Plena'), findsOneWidget);
    expect(find.text('Plan Plus'), findsOneWidget);
    expect(find.text('SP-100245'), findsOneWidget);
    expect(find.text('Activa'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200, scrollable: find.byType(Scrollable).first);
    // Un cuadro más para que `tap` use la posición nueva, ya desplazada.
    await tester.pump();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(deps.session.isLoggedIn, isFalse);
    expect(find.text('¿Quién usa la app?'), findsOneWidget);
  });

  testWidgets('el carnet de Pedro muestra la afiliación inactiva', (tester) async {
    await openTab(tester, SeedIds.pedro, AppRoutes.patientProfile);
    expect(find.text('Inactiva'), findsOneWidget);
  });
}
