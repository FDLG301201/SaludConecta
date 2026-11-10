import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'data/gateways/confirmation_gateway.dart';
import 'data/gateways/insurance_gateway.dart';
import 'data/repositories/case_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/seed/seed_cases.dart';
import 'data/seed/seed_catalog.dart';
import 'domain/services/clock.dart';
import 'state/case_provider.dart';
import 'state/session_provider.dart';

/// Raíz de composición: crea los datos semilla, los gateways simulados, el estado y las rutas,
/// y los publica para toda la app con `MultiProvider`.
class AppDependencies {
  AppDependencies._({required this.catalog, required this.session, required this.cases, required this.router});

  factory AppDependencies.create({
    Clock clock = DateTime.now,
    Duration insuranceDelay = const Duration(milliseconds: 1500),
    Duration confirmationDelay = const Duration(seconds: 1),
    String initialLocation = AppRoutes.welcome,
  }) {
    final catalog = SeedCatalog.repository();
    final session = SessionProvider(clock: clock);
    final cases = CaseProvider(
      catalog: catalog,
      repository: InMemoryCaseRepository(SeedCases.generate(now: clock(), catalog: catalog)),
      insurance: SimulatedInsuranceGateway(catalog: catalog, clock: clock, delay: insuranceDelay),
      confirmation: SimulatedConfirmationGateway(delay: confirmationDelay),
      clock: clock,
    );
    final router = AppRouter.create(session: session, initialLocation: initialLocation);
    return AppDependencies._(catalog: catalog, session: session, cases: cases, router: router);
  }

  final CatalogRepository catalog;
  final SessionProvider session;
  final CaseProvider cases;
  final GoRouter router;

  /// Publica las dependencias con Provider: las pantallas las leen con `context.watch` y `context.read`.
  Widget provide(Widget child) => MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
          ChangeNotifierProvider<CaseProvider>.value(value: cases),
        ],
        child: child,
      );
}
