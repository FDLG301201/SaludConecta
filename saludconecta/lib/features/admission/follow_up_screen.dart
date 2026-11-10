import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/avatar_image.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_exception.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';

/// Seguimiento (§6 Admisión): casos con el paso 10 pendiente, sus llamadas y el estado de la encuesta.
class FollowUpScreen extends StatelessWidget {
  const FollowUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<CaseProvider>().followUpCases();
    final theme = Theme.of(context);
    return PageBody(
      child: ListView(
        children: [
          Text('Seguimiento', style: theme.textTheme.headlineSmall),
          Text('Casos con el paso 10 pendiente: llamadas y encuesta', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay casos en seguimiento.', textAlign: TextAlign.center),
              ),
            )
          else
            for (final c in items) _FollowUpCard(telemedicineCase: c),
        ],
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  Future<void> _logCall(BuildContext context) async {
    final cases = context.read<CaseProvider>();
    final staff = context.read<SessionProvider>().currentStaff!;
    final messenger = ScaffoldMessenger.of(context);
    final note = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => const _CallDialog(),
    );
    if (note == null) return;
    try {
      cases.logFollowUpCall(telemedicineCase.id, staff: staff, note: note);
      messenger.showSnackBar(const SnackBar(content: Text('Llamada registrada.')));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final patient = catalog.patientById(c.patientId);
    final calls = c.followUp?.calls ?? const [];
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarImage(name: patient.fullName, asset: patient.avatarAsset, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.fullName, style: theme.textTheme.titleMedium),
                      Text('${catalog.serviceById(c.serviceId).name} · ${c.id}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.current.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      'Encuesta pendiente',
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.currentText),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (calls.isEmpty)
              Text('Sin llamadas registradas.', style: theme.textTheme.bodySmall)
            else
              for (final call in calls)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${Formatters.dateTime(call.at)} · ${call.byName}: ${call.note}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _logCall(context),
                  icon: const Icon(Icons.call),
                  label: const Text('Registrar llamada'),
                ),
                TextButton(onPressed: () => context.push(AppRoutes.caseDetail(c.id)), child: const Text('Ver caso')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para escribir la nota de la llamada; devuelve el texto o `null` si se cancela.
class _CallDialog extends StatefulWidget {
  const _CallDialog();

  @override
  State<_CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<_CallDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar llamada'),
      content: TextField(
        controller: _note,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Nota de la llamada', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _note.text.trim()), child: const Text('Guardar')),
      ],
    );
  }
}
