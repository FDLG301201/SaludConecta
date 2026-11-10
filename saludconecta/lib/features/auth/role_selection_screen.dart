import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/app_illustration.dart';
import '../../core/widgets/page_body.dart';
import '../../domain/models/enums.dart';

/// Selección de rol (§6): 4 tarjetas ilustradas. Es una demostración: no hay contraseñas.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const _descriptions = {
    UserRole.patient: 'Pide citas, firma tu consentimiento, entra a la videollamada y revisa tu receta.',
    UserRole.admission: 'Registra solicitudes, valida el seguro, agenda las citas y da seguimiento.',
    UserRole.doctor: 'Atiende tus citas por videollamada, escribe notas clínicas y emite resultados.',
    UserRole.billing: 'Factura, envía reclamaciones al seguro, audita y cierra los casos.',
  };

  void _open(BuildContext context, UserRole role) =>
      context.go(role == UserRole.patient ? AppRoutes.patientLogin : AppRoutes.staffLogin(role));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Quién usa la app?')),
      body: PageBody(
        child: ListView(
          children: [
            Card(
              color: AppColors.current.withOpacity(0.12),
              child: const ListTile(
                leading: Icon(Icons.info_outline, color: AppColors.currentText),
                title: Text('Modo demostración: sin contraseñas'),
                subtitle: Text('Elige un rol y un usuario de prueba. Todos los datos son ficticios.'),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 2 : 1;
                final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final role in UserRole.values)
                      SizedBox(
                        width: width,
                        child: _RoleCard(
                          role: role,
                          description: _descriptions[role]!,
                          onTap: () => _open(context, role),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.description, required this.onTap});

  final UserRole role;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.forActor(role.actor);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AppIllustration(AppIllustrations.forRole(role), width: 110, height: 88),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(AppIcons.role(role), color: color, size: 20),
                        const SizedBox(width: 6),
                        // Flexible: en pantallas angostas el título se recorta en vez de desbordar.
                        Flexible(
                          child: Text(
                            role.label,
                            style: theme.textTheme.titleLarge?.copyWith(color: color),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
