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

  Future<AppDependencies> openWizard(WidgetTester tester, {String? serviceId}) async {
    final deps = patientDependencies(SeedIds.maria);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.requestAppointment(serviceId: serviceId));
    await tester.pumpAndSettle();
    return deps;
  }

  testWidgets('valida cada paso, crea la solicitud y esta llega a la bandeja de Admisión', (tester) async {
    final deps = await openWizard(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Elige un servicio.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consulta médica general').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Fiebre');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Elige un canal.'), findsOneWidget);
    expect(find.text('Describe el motivo de consulta con al menos 10 caracteres.'), findsOneWidget);

    await tester.tap(find.text('WhatsApp'));
    await tester.enterText(find.byType(TextFormField), 'Fiebre y dolor de garganta desde ayer');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('80% con ARS Salud Plena (plan Plus), sujeto a validación'), findsOneWidget);

    // El resumen es largo: se desplaza la lista hasta ver el botón.
    await tester.scrollUntilVisible(find.text('Enviar solicitud'), 100, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();
    final created = deps.cases.casesOfPatient(SeedIds.maria).first;
    expect(created.isOpen, isTrue);
    expect(find.text('Caso ${created.id}'), findsOneWidget);
    expect(find.text('Esperando a Admisión: Recepción en Hospital / PSS'), findsOneWidget);

    // La solicitud nueva aparece en la bandeja de Admisión (al final: la bandeja va de la más antigua a la más nueva).
    deps.session.loginStaff(deps.catalog.staffFor(Actor.admission));
    deps.router.go(AppRoutes.admissionInbox);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('María Fernández'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('María Fernández'), findsOneWidget);
  });

  testWidgets('con un servicio en la URL, el asistente abre en "Canal y motivo"', (tester) async {
    await openWizard(tester, serviceId: SeedIds.nutrition);
    expect(find.text('¿Por qué canal nos contactas?'), findsOneWidget);

    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    final field = tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>));
    expect(field.initialValue, SeedIds.nutrition);
  });

  testWidgets('en un teléfono el asistente es vertical y empieza arriba', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openWizard(tester);
    expect(tester.widget<Stepper>(find.byType(Stepper)).type, StepperType.vertical);
    expect(tester.getTopLeft(find.text('¿Qué servicio necesitas?')).dy, lessThan(200));
  });
}
