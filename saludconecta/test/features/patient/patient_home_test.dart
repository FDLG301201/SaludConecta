import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('José ve sus citas en curso con lo que le toca hacer', (tester) async {
    await tester.pumpWidget(appWith(patientDependencies(SeedIds.jose)));
    await tester.pumpAndSettle();
    expect(find.text('Hola, José'), findsOneWidget);
    expect(find.text('Tus citas en curso'), findsOneWidget);
    expect(find.text('Responder la encuesta'), findsOneWidget);
    expect(find.text('Firmar consentimiento'), findsOneWidget);
  });

  testWidgets('María, sin citas en curso, ve los accesos rápidos y los consejos de salud', (tester) async {
    await tester.pumpWidget(appWith(patientDependencies(SeedIds.maria)));
    await tester.pumpAndSettle();
    expect(find.text('No tienes citas en curso'), findsOneWidget);
    expect(find.text('Mis resultados'), findsOneWidget);
    expect(find.text('Acerca del proceso'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Toma agua durante el día'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Educación en salud'), findsOneWidget);
  });

  testWidgets('"Mis resultados" avisa cuando todavía no hay resultados', (tester) async {
    await tester.pumpWidget(appWith(patientDependencies(SeedIds.pedro)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis resultados'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes resultados'), findsOneWidget);
  });

  testWidgets('la campana cuenta los avisos nuevos y los marca como leídos al cerrar', (tester) async {
    var now = testNow;
    final deps = AppDependencies.create(
      clock: () => now,
      insuranceDelay: Duration.zero,
      confirmationDelay: Duration.zero,
      initialLocation: AppRoutes.patientHome,
    );
    final maria = deps.catalog.patientById(SeedIds.maria);
    deps.session.loginPatient(maria);
    final c = deps.cases.requestAppointment(
      patient: maria,
      service: deps.catalog.serviceById(SeedIds.generalConsult),
      channel: RequestChannel.whatsapp,
      reason: 'Dolor de cabeza desde hace días',
      preferredDate: testNow.add(const Duration(days: 1)),
    );
    // Una hora después, Admisión registra la solicitud: eso genera un aviso nuevo.
    now = testNow.add(const Duration(hours: 1));
    deps.cases.registerReception(c.id, staff: deps.catalog.staffFor(Actor.admission));
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();

    final unread = find.descendant(of: find.byType(Badge), matching: find.text('1'));
    expect(unread, findsOneWidget);
    await tester.tap(find.byTooltip('Avisos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Admisión registró tu caso ${c.id}'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(unread, findsNothing);
  });
}
