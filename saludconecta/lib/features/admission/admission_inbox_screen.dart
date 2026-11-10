import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/case_card.dart';
import '../../core/widgets/page_body.dart';
import '../../state/case_provider.dart';
import 'admission_filter.dart';

/// Bandeja de Admisión (§6): solicitudes con los pasos 2 a 5 pendientes, con filtros y su tiempo de espera.
class AdmissionInboxScreen extends StatefulWidget {
  const AdmissionInboxScreen({super.key});

  @override
  State<AdmissionInboxScreen> createState() => _AdmissionInboxScreenState();
}

class _AdmissionInboxScreenState extends State<AdmissionInboxScreen> {
  AdmissionFilter _filter = AdmissionFilter.all;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final inbox = cases.admissionInbox();
    final shown = [
      for (final c in inbox)
        if (_filter.matches(c)) c,
    ];
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Bandeja de Admisión', style: theme.textTheme.headlineSmall),
          Text('Solicitudes con los pasos 2 a 5 pendientes; primero la más antigua', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in AdmissionFilter.values)
                ChoiceChip(
                  label: Text('${f.label} (${inbox.where(f.matches).length})'),
                  selected: f == _filter,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay solicitudes con este filtro.', textAlign: TextAlign.center),
              ),
            )
          else
            for (final c in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CaseCard(
                  telemedicineCase: c,
                  onTap: () => context.push(AppRoutes.caseDetail(c.id)),
                  trailing: Text(
                    'Hace ${Formatters.duration(cases.now.difference(c.updatedAt))}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
