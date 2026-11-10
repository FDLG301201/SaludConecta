import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';

/// Reclamaciones al seguro (§6 Facturación): históricas y en vivo, con filtro por estado.
class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  /// `null` = todas.
  ClaimStatus? _filter;

  static const _statuses = [ClaimStatus.approved, ClaimStatus.pending, ClaimStatus.objected];

  static Color colorOf(ClaimStatus status) => switch (status) {
        ClaimStatus.approved => AppColors.done,
        ClaimStatus.pending => AppColors.currentText,
        ClaimStatus.objected => AppColors.danger,
        ClaimStatus.notApplicable => AppColors.pending,
      };

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final catalog = context.read<CatalogRepository>();
    final claims = [
      for (final c in cases.cases)
        if (_statuses.contains(c.billing?.claimStatus)) c,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final shown = [
      for (final c in claims)
        if (_filter == null || c.billing!.claimStatus == _filter) c,
    ];
    final total = shown.fold<int>(0, (sum, c) => sum + c.billing!.invoice.insurerAmount);
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Reclamaciones', style: theme.textTheme.headlineSmall),
          Text('${shown.length} reclamaciones · ${Formatters.money(total)} a cargo de los seguros',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('Todas (${claims.length})'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final status in _statuses)
                ChoiceChip(
                  label: Text('${status.label} (${claims.where((c) => c.billing!.claimStatus == status).length})'),
                  selected: _filter == status,
                  onSelected: (_) => setState(() => _filter = status),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final c in shown) _ClaimTile(telemedicineCase: c, catalog: catalog),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  const _ClaimTile({required this.telemedicineCase, required this.catalog});

  final TelemedicineCase telemedicineCase;
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final billing = c.billing!;
    final patient = catalog.patientById(c.patientId);
    final color = _ClaimsScreenState.colorOf(billing.claimStatus);
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => context.push(AppRoutes.caseDetail(c.id)),
      title: Text(patient.fullName),
      subtitle: Text(
        '${catalog.insurerById(patient.affiliation.insurerId).name} · ${billing.claimNumber ?? 'Sin número'} · ${c.id}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(Formatters.money(billing.invoice.insurerAmount), style: theme.textTheme.titleSmall),
          Text(
            billing.claimStatus.label,
            style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
