import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_illustrations.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/case_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_body.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';

/// Lista de casos de una bandeja (versión de la etapa 4). Las etapas 6 a 8 la reemplazan por las
/// pantallas de cada rol, con filtros y acciones.
class CaseListScreen extends StatelessWidget {
  const CaseListScreen({super.key, required this.title, required this.subtitle, required this.select});

  final String title;
  final String subtitle;

  /// Qué casos mostrar, según el estado de los casos y la sesión.
  final List<TelemedicineCase> Function(CaseProvider cases, SessionProvider session) select;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>();
    final session = context.watch<SessionProvider>();
    final items = select(cases, session);
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return EmptyState(illustration: AppIllustrations.emptyCases, title: title, message: 'No hay casos. $subtitle.');
    }
    return PageBody(
      child: ListView.separated(
        itemCount: items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                Text('${items.length} casos · $subtitle', style: theme.textTheme.bodyMedium),
              ],
            );
          }
          final c = items[index - 1];
          return CaseCard(
            telemedicineCase: c,
            onTap: () => context.push(AppRoutes.caseDetail(c.id)),
            trailing: Text(
              'Hace ${Formatters.duration(cases.now.difference(c.updatedAt))}',
              style: theme.textTheme.labelSmall,
            ),
          );
        },
      ),
    );
  }
}
