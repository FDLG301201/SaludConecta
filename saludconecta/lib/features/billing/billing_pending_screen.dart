import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/case_card.dart';
import '../../core/widgets/page_body.dart';
import '../../state/case_provider.dart';

/// Pendientes de Facturación (§6): casos con el paso 9 (cierre administrativo) pendiente.
class BillingPendingScreen extends StatelessWidget {
  const BillingPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final items = cases.billingInbox();
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Pendientes de cierre', style: theme.textTheme.headlineSmall),
          Text('Casos con el paso 9 pendiente: factura, reclamación, auditoría y pago',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay casos pendientes de cierre.', textAlign: TextAlign.center),
              ),
            )
          else
            for (final c in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CaseCard(
                      telemedicineCase: c,
                      onTap: () => context.push(AppRoutes.caseDetail(c.id)),
                      trailing: Text(
                        'Copago ${Formatters.money(cases.invoiceFor(c).copay)}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.caseAction(c.id, CaseAction.closure)),
                      icon: const Icon(Icons.request_quote_outlined),
                      label: const Text('Cerrar caso'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
