import '../../domain/models/enums.dart';
import 'app_routes.dart';

/// Reglas de acceso del `redirect` de go_router (§6 del spec). Es una función pura para poder probarla:
/// recibe la ruta pedida y el rol de la sesión, y devuelve a dónde redirigir (o `null` para seguir).
class RouteGuard {
  const RouteGuard._();

  static String? redirect(String path, UserRole? role) {
    final isLogin = path == AppRoutes.login || path.startsWith('${AppRoutes.login}/');
    final isPublic = isLogin || path == AppRoutes.welcome;

    // Sin sesión solo se ven la bienvenida y el ingreso.
    if (role == null) return isPublic ? null : AppRoutes.login;

    // Con sesión, el ingreso lleva al inicio del rol.
    if (isLogin) return AppRoutes.home(role);

    // Las secciones de otro rol llevan al inicio del rol actual.
    final owner = _sectionOwner(path);
    if (owner != null && owner != role) return AppRoutes.home(role);

    // Las acciones de otro rol sobre un caso llevan al detalle del caso.
    final segments = Uri.parse(path).pathSegments;
    if (segments.length == 3 && segments.first == 'caso') {
      final action = CaseAction.fromSegment(segments[2]);
      if (action != null && action.role != role) return AppRoutes.caseDetail(segments[1]);
    }
    return null;
  }

  /// Rol dueño de una sección (`/paciente…`, `/admision…`, `/medico…`, `/facturacion…`).
  static UserRole? _sectionOwner(String path) {
    for (final role in UserRole.values) {
      final home = AppRoutes.home(role);
      if (path == home || path.startsWith('$home/')) return role;
    }
    return null;
  }
}
