import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/constants/app_info.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/role_switcher_sheet.dart';
import '../../domain/models/enums.dart';
import '../../state/session_provider.dart';

/// Una pestaña de la navegación de un rol.
class RoleDestination {
  const RoleDestination({required this.label, required this.icon, required this.selectedIcon});

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Estructura común de cada rol (§6): barra superior con "Diagrama del proceso", "Acerca de" y
/// "Cambiar de rol"; navegación inferior por debajo de 800 px y lateral desde 800 px.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.role, required this.navigationShell, required this.destinations});

  static const wideBreakpoint = 800.0;

  final UserRole role;
  final StatefulNavigationShell navigationShell;
  final List<RoleDestination> destinations;

  /// Cambia de pestaña; si ya estaba en ella, vuelve a su pantalla inicial.
  void _select(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final theme = Theme.of(context);
    final appBar = AppBar(
      title: Row(
        children: [
          const AppIllustration(AppIllustrations.logo, width: 32, height: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(AppInfo.appName),
                Text(
                  '${role.label} · ${session.displayName}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Diagrama del proceso',
          icon: const Icon(Icons.account_tree_outlined),
          onPressed: () => context.push(AppRoutes.process),
        ),
        IconButton(
          tooltip: 'Acerca de',
          icon: const Icon(Icons.info_outline),
          onPressed: () => context.push(AppRoutes.about),
        ),
        IconButton(
          tooltip: 'Cambiar de rol',
          icon: const Icon(Icons.switch_account_outlined),
          onPressed: () => RoleSwitcherSheet.show(context),
        ),
      ],
    );
    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}
