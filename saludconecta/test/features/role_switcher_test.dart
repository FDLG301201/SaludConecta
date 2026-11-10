import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/domain/models/enums.dart';

import '../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('"Cambiar de rol" abre la hoja y pasa de Admisión a María', (tester) async {
    await tester.pumpWidget(buildTestApp(initialLocation: AppRoutes.staffLogin(UserRole.admission)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Peña'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cambiar de rol'));
    await tester.pumpAndSettle();
    expect(find.text('Modo demostración: elige quién usa la app.'), findsOneWidget);

    await tester.tap(find.text('María Fernández'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, María'), findsOneWidget);
  });
}
