import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/empty_state.dart';
import '../../state/session_provider.dart';

/// "Página no encontrada" (ruta desconocida) o "Caso no encontrado", con un botón para volver al inicio.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({
    super.key,
    this.title = 'Página no encontrada',
    this.message = 'Esa dirección no existe en SaludConecta.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<SessionProvider>().role;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        illustration: AppIllustrations.emptyResults,
        title: title,
        message: message,
        action: FilledButton.icon(
          onPressed: () => context.go(role == null ? AppRoutes.login : AppRoutes.home(role)),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Volver al inicio'),
        ),
      ),
    );
  }
}
