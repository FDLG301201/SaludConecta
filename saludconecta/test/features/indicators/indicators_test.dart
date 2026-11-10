import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/data/seed/seed_catalog.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/services/stats_calculator.dart';
import 'package:saludconecta/features/indicators/indicators_screen.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('cada rol abre Indicadores en su pestaña', () {
    expect(IndicatorsTab.initialFor(UserRole.admission), IndicatorsTab.operation);
    expect(IndicatorsTab.initialFor(UserRole.doctor), IndicatorsTab.clinical);
    expect(IndicatorsTab.initialFor(UserRole.billing), IndicatorsTab.financial);
  });

  testWidgets('Admisión ve Operación con sus indicadores y gráficas', (tester) async {
    final deps = staffDependencies(UserRole.admission);
    final kpis = StatsCalculator.operationKpis(StatsCalculator.inWindow(deps.cases.cases, testNow), testNow);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.admissionIndicators);
    await tester.pumpAndSettle();

    expect(find.text('Solicitudes del mes'), findsOneWidget);
    expect(find.text('${kpis.casesInProcess}'), findsWidgets);
    expect(find.text('Solicitudes por canal'), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('el Médico abre en Clínico y puede pasar a Satisfacción', (tester) async {
    final deps = staffDependencies(UserRole.doctor, doctorId: SeedIds.mendez);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.doctorIndicators);
    await tester.pumpAndSettle();
    expect(find.text('Consultas por especialidad'), findsOneWidget);

    await tester.tap(find.text('Satisfacción'));
    await tester.pumpAndSettle();
    expect(find.text('NPS'), findsOneWidget);
    expect(find.text('Distribución de calificaciones'), findsOneWidget);
  });

  testWidgets('Facturación abre en Financiero con la facturación mensual', (tester) async {
    final deps = staffDependencies(UserRole.billing);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.billingIndicators);
    await tester.pumpAndSettle();
    expect(find.text('Facturación mensual'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Reclamaciones por estado'), findsOneWidget);
  });

  testWidgets('el perfil del paciente muestra "Mi resumen" con lo cubierto y lo pagado', (tester) async {
    final deps = patientDependencies(SeedIds.maria);
    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.patientProfile);
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Mi resumen'), 200, scrollable: list);
    await tester.pumpAndSettle();
    expect(find.text('Mi resumen'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mis consultas por especialidad'), 200, scrollable: list);
    await tester.pumpAndSettle();
    expect(find.textContaining('Cubierto por el seguro ('), findsOneWidget);
    expect(find.textContaining('Pagado por mí ('), findsOneWidget);
  });
}
