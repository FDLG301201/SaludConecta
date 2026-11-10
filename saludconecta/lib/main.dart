import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carga los nombres de días y meses en español para `intl`.
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';
  // Raíz de composición: datos semilla, gateways simulados, providers (MultiProvider) y rutas.
  final dependencies = AppDependencies.create();
  runApp(dependencies.provide(SaludConectaApp(router: dependencies.router)));
}
