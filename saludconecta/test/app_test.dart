import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/app.dart';
import 'package:saludconecta/core/router/app_router.dart';

void main() {
  testWidgets('la app arranca en la bienvenida con el nombre y el lema', (tester) async {
    await tester.pumpWidget(SaludConectaApp(router: AppRouter.create()));
    await tester.pumpAndSettle();

    expect(find.text('SaludConecta'), findsOneWidget);
    expect(find.text('Más acceso, mejor salud'), findsOneWidget);
  });
}
