import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/constants/app_info.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/diagrams/case_diagram_screen.dart';
import 'package:saludconecta/features/diagrams/diagram_views.dart';
import 'package:saludconecta/features/diagrams/flow_diagram_painter.dart';
import 'package:saludconecta/features/diagrams/flow_layout.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('tocar un paso del flujo abre su detalle; "Por actor" muestra los carriles', (tester) async {
    final deps = patientDependencies(SeedIds.maria);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.process);
    await tester.pumpAndSettle();
    expect(find.text('Diagramas del proceso'), findsOneWidget);

    // Del lienzo a la pantalla: localToGlobal ya incluye el zoom inicial del InteractiveViewer.
    final canvas = tester.renderObject<RenderBox>(find.byKey(const Key('flow-diagram')));
    final reception = FlowLayout.build().nodeOf(ProcessStep.reception).rect.center;
    await tester.tapAt(canvas.localToGlobal(reception));
    await tester.pumpAndSettle();
    expect(find.text('Recepción en Hospital / PSS'), findsOneWidget);
    expect(find.textContaining('Lo completa: Admisión'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Por actor'));
    await tester.pumpAndSettle();
    expect(find.byType(SwimlaneView), findsOneWidget);
  });

  testWidgets('el diagrama del caso marca los pasos completados, el actual y los pendientes', (tester) async {
    final deps = patientDependencies(SeedIds.carmen);
    final c = openCaseOf(deps, SeedIds.carmen, ProcessStep.insuranceValidation);
    final progress = progressOf(c);
    expect(progress.states[ProcessStep.reception], StepProgress.done);
    expect(progress.states[ProcessStep.insuranceValidation], StepProgress.current);
    expect(progress.states[ProcessStep.scheduling], StepProgress.pending);

    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.caseDiagram(c.id));
    // El pulso se repite sin fin: se avanza el reloj en lugar de pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Diagrama del caso'), findsOneWidget);
    expect(find.textContaining(c.id), findsOneWidget);
    expect(find.text('Completado'), findsOneWidget);
    expect(find.textContaining('Paso 3 de 10'), findsOneWidget);
  });

  testWidgets('Acerca de muestra la arquitectura y el equipo', (tester) async {
    final deps = patientDependencies(SeedIds.maria);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.push(AppRoutes.about);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);

    await tester.tap(find.text('Arquitectura'));
    await tester.pumpAndSettle();
    expect(find.text('Arquitectura de Flutter'), findsOneWidget);
    expect(find.text('Rendering'), findsOneWidget);

    await tester.tap(find.text('Equipo'));
    await tester.pumpAndSettle();
    expect(find.text(AppInfo.slogan), findsOneWidget);
    expect(find.text(AppInfo.teamMembers.first), findsOneWidget);
  });
}
