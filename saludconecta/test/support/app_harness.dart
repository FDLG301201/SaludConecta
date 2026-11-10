import 'package:flutter/widgets.dart';
import 'package:saludconecta/app.dart';
import 'package:saludconecta/app_dependencies.dart';
import 'package:saludconecta/core/router/app_routes.dart';

/// Hora fija de las pruebas de widgets: lunes 9 de noviembre de 2026, 10:00.
final testNow = DateTime(2026, 11, 9, 10);

/// Dependencias de la app con la hora fija y sin pausas en los gateways.
AppDependencies testDependencies({String initialLocation = AppRoutes.welcome}) => AppDependencies.create(
      clock: () => testNow,
      insuranceDelay: Duration.zero,
      confirmationDelay: Duration.zero,
      initialLocation: initialLocation,
    );

/// La app completa, lista para `tester.pumpWidget`.
Widget appWith(AppDependencies dependencies) => dependencies.provide(SaludConectaApp(router: dependencies.router));

/// Atajo: la app desde la bienvenida (u otra ruta inicial).
Widget buildTestApp({String initialLocation = AppRoutes.welcome}) =>
    appWith(testDependencies(initialLocation: initialLocation));
