import 'package:go_router/go_router.dart';

import '../../features/auth/welcome_screen.dart';

/// Rutas de la app. En la etapa 4 se agregan los shells por rol y el `redirect`.
class AppRouter {
  const AppRouter._();

  static const welcome = '/bienvenida';

  static GoRouter create() {
    return GoRouter(
      initialLocation: welcome,
      routes: [
        GoRoute(path: welcome, builder: (context, state) => const WelcomeScreen()),
      ],
    );
  }
}
