import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../state/session_provider.dart';

/// Ingreso del personal (§6): se elige el usuario de demostración del rol (7 médicos para Médico).
class StaffLoginScreen extends StatelessWidget {
  const StaffLoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogRepository>();
    final session = context.read<SessionProvider>();
    final router = GoRouter.of(context);

    void enter(VoidCallback login) {
      login();
      router.go(AppRoutes.home(role));
    }

    final users = <Widget>[
      if (role == UserRole.doctor)
        for (final d in catalog.doctors)
          _UserTile(
            name: d.displayName,
            subtitle: '${d.specialty.label} · Exequátur ${d.exequatur}',
            avatar: d.avatarAsset,
            onTap: () => enter(() => session.loginDoctor(d)),
          )
      else
        for (final s in catalog.staff.where((s) => s.actor == role.actor))
          _UserTile(
            name: s.fullName,
            subtitle: role.label,
            avatar: s.avatarAsset,
            onTap: () => enter(() => session.loginStaff(s)),
          ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('Ingreso de ${role.label}')),
      body: PageBody(
        child: ListView(
          children: [
            AppIllustration(AppIllustrations.forRole(role), height: 130),
            const SizedBox(height: 12),
            Text(
              'Elige tu usuario de demostración',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ...users,
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.name, required this.subtitle, required this.onTap, this.avatar});

  final String name;
  final String subtitle;
  final String? avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: AvatarImage(name: name, asset: avatar, size: 44),
          title: Text(name),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
