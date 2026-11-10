import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carga los nombres de días y meses en español para `intl`.
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';
  runApp(SaludConectaApp(router: AppRouter.create()));
}
