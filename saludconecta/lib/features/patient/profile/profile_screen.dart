import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/role_switcher_sheet.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../state/case_provider.dart';
import '../../../state/session_provider.dart';
import 'insurance_card.dart';
import 'my_summary.dart';

/// "Perfil": carnet del seguro, datos personales, "Mi resumen" (gráficas) y enlaces (Acerca de, Cambiar de rol, Cerrar sesión).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final patient = session.currentPatient;
    if (patient == null) return const SizedBox.shrink();
    final insurer = context.read<CatalogRepository>().insurerById(patient.affiliation.insurerId);
    final age = patient.ageOn(context.read<CaseProvider>().now);
    final birth = '${Formatters.shortDate(patient.birthDate)} ($age años)';
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Mi perfil', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: InsuranceCard(patient: patient, insurer: insurer)),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Datos personales',
            icon: Icons.badge_outlined,
            child: Column(
              children: [
                _DataRow(Icons.person_outline, 'Nombre', patient.fullName),
                _DataRow(Icons.credit_card, 'Cédula', patient.cedula),
                _DataRow(Icons.cake_outlined, 'Nacimiento', birth),
                _DataRow(Icons.wc, 'Sexo', patient.gender.label),
                _DataRow(Icons.phone_outlined, 'Teléfono', patient.phone),
                _DataRow(Icons.email_outlined, 'Correo', patient.email),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Mi resumen', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          MySummary(patientId: patient.id),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Acerca de SaludConecta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.about),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.switch_account_outlined),
                  title: const Text('Cambiar de rol'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => RoleSwitcherSheet.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.danger)),
                  onTap: () {
                    session.logout();
                    context.go(AppRoutes.login);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: Text(label, style: theme.textTheme.bodyMedium)),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
