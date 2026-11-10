import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('la app arranca en la bienvenida con el nombre y el lema', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(find.text('SaludConecta'), findsOneWidget);
    expect(find.text('Más acceso, mejor salud'), findsOneWidget);
    expect(find.text('Solicita tu cita por el canal que prefieras'), findsOneWidget);
  });
}
