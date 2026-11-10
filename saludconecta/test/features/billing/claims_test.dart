import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/core/router/app_routes.dart';
import 'package:saludconecta/domain/models/enums.dart';

import '../../support/app_harness.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('las reclamaciones se filtran por estado y cada filtro dice cuántas hay', (tester) async {
    final deps = staffDependencies(UserRole.billing);
    int count(ClaimStatus status) => deps.cases.cases.where((c) => c.billing?.claimStatus == status).length;
    final approved = count(ClaimStatus.approved);
    final objected = count(ClaimStatus.objected);
    expect(objected, greaterThan(0));

    await tester.pumpWidget(appWith(deps));
    await tester.pumpAndSettle();
    deps.router.go(AppRoutes.billingClaims);
    await tester.pumpAndSettle();
    expect(find.text('Reclamaciones'), findsWidgets);
    expect(find.text('Aprobada ($approved)'), findsOneWidget);

    await tester.tap(find.text('Glosada ($objected)'));
    await tester.pumpAndSettle();
    expect(find.text('Aprobada'), findsNothing);
    expect(find.text('Glosada'), findsWidgets);
  });
}
