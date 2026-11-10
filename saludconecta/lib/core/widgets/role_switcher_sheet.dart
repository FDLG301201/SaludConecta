import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../state/session_provider.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'avatar_image.dart';

/// Hoja "Cambiar de rol" (§6): los 4 roles con sus usuarios de demostración. Un toque cambia la sesión.
class RoleSwitcherSheet extends StatelessWidget {
  const RoleSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => const RoleSwitcherSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogRepository>();
    final session = context.read<SessionProvider>();
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final admission = catalog.staffFor(Actor.admission);
    final billing = catalog.staffFor(Actor.billing);

    // Cierra la hoja, cambia la sesión y abre el inicio del nuevo rol.
    void switchTo(UserRole role, VoidCallback login) {
      navigator.pop();
      login();
      router.go(AppRoutes.home(role));
    }

    Widget person(String name, String subtitle, String? avatar, UserRole role, VoidCallback login) => ListTile(
          leading: AvatarImage(name: name, asset: avatar, size: 40),
          title: Text(name),
          subtitle: Text(subtitle),
          onTap: () => switchTo(role, login),
        );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            title: Text('Cambiar de rol', style: Theme.of(context).textTheme.titleLarge),
            subtitle: const Text('Modo demostración: elige quién usa la app.'),
          ),
          const _RoleHeader(role: UserRole.patient),
          for (final p in catalog.demoPatients)
            person(
              p.fullName,
              'Carnet ${p.affiliation.affiliateNumber}',
              p.avatarAsset,
              UserRole.patient,
              () => session.loginPatient(p),
            ),
          const _RoleHeader(role: UserRole.admission),
          person(admission.fullName, 'Admisión', admission.avatarAsset, UserRole.admission, () {
            session.loginStaff(admission);
          }),
          const _RoleHeader(role: UserRole.doctor),
          for (final d in catalog.doctors)
            person(d.displayName, d.specialty.label, d.avatarAsset, UserRole.doctor, () => session.loginDoctor(d)),
          const _RoleHeader(role: UserRole.billing),
          person(billing.fullName, 'Facturación', billing.avatarAsset, UserRole.billing, () {
            session.loginStaff(billing);
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              navigator.pop();
              session.logout();
              router.go(AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }
}

class _RoleHeader extends StatelessWidget {
  const _RoleHeader({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forActor(role.actor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(AppIcons.role(role), color: color, size: 20),
          const SizedBox(width: 8),
          Text(role.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
