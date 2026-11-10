import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/people.dart';
import '../../../domain/services/notification_builder.dart';
import '../../../state/case_provider.dart';
import '../../../state/session_provider.dart';
import '../patient_notifications.dart';

/// Campana del Inicio: cuenta los avisos que el paciente no ha leído y los abre en una hoja.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>().casesOfPatient(patient.id);
    final seenAt = context.watch<SessionProvider>().notificationsSeenAt(patient.id);
    final items = PatientNotifications.build(cases, context.read<CatalogRepository>());
    final unread = PatientNotifications.unreadCount(items, seenAt);
    return IconButton(
      tooltip: 'Avisos',
      onPressed: () => _open(context, items, seenAt),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  Future<void> _open(BuildContext context, List<PatientNotification> items, DateTime? seenAt) async {
    // Se capturan antes del await: después no se usa `context`.
    final session = context.read<SessionProvider>();
    final router = GoRouter.of(context);
    final caseId = await showModalBottomSheet<String>(
      context: context,
      // Sobre toda la app, no solo sobre la pestaña (cada pestaña del shell tiene su propio Navigator).
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _NotificationsSheet(items: items, seenAt: seenAt),
    );
    // Al cerrar la hoja, los avisos quedan leídos; si eligió uno, se abre su caso.
    session.markNotificationsSeen();
    if (caseId != null) router.push(AppRoutes.caseDetail(caseId));
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({required this.items, required this.seenAt});

  final List<PatientNotification> items;
  final DateTime? seenAt;

  bool _isNew(PatientNotification n) {
    final seen = seenAt;
    return seen == null || n.at.isAfter(seen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(title: Text('Avisos', style: theme.textTheme.titleLarge)),
          if (items.isEmpty)
            const ListTile(title: Text('Aún no tienes avisos.'))
          else
            for (final n in items)
              ListTile(
                leading: Icon(
                  _isNew(n) ? Icons.mark_email_unread_outlined : Icons.notifications_none,
                  color: _isNew(n) ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(n.title),
                subtitle: Text('${n.body}\n${Formatters.dateTime(n.at)}'),
                isThreeLine: true,
                onTap: () => Navigator.pop(context, n.caseId),
              ),
        ],
      ),
    );
  }
}
