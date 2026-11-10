import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_illustrations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_illustration.dart';
import '../../../core/widgets/page_body.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/people.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_exception.dart';
import '../../../domain/process/process_step.dart';
import '../../../state/case_provider.dart';
import '../patient_case_builder.dart';

/// Encuesta de satisfacción (paso 10): estrellas, recomendación de 0 a 10 y comentario opcional.
/// Al enviarla, el caso queda completado y la pantalla muestra el agradecimiento.
class SurveyScreen extends StatelessWidget {
  const SurveyScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return PatientCaseBuilder(
      caseId: caseId,
      builder: (context, c, patient) {
        final survey = c.followUp?.survey;
        if (survey != null) {
          return CaseNotice(
            screenTitle: 'Encuesta de satisfacción',
            title: '¡Gracias por tu opinión!',
            message: 'Calificaste tu atención con ${survey.rating} de 5 estrellas.',
            illustration: AppIllustrations.onboardingFollowUp,
          );
        }
        if (c.status != CaseStatus.active || c.currentStep != ProcessStep.followUp) {
          return const CaseNotice(
            screenTitle: 'Encuesta de satisfacción',
            title: 'La encuesta aún no está disponible',
            message: 'Podrás responderla cuando se cierre tu atención.',
          );
        }
        return _SurveyForm(telemedicineCase: c, patient: patient);
      },
    );
  }
}

class _SurveyForm extends StatefulWidget {
  const _SurveyForm({required this.telemedicineCase, required this.patient});

  final TelemedicineCase telemedicineCase;
  final Patient patient;

  @override
  State<_SurveyForm> createState() => _SurveyFormState();
}

class _SurveyFormState extends State<_SurveyForm> {
  final _comment = TextEditingController();
  int _rating = 0;
  int? _nps;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    final nps = _nps;
    if (_rating == 0 || nps == null) return;
    final cases = context.read<CaseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      cases.submitSurvey(
        widget.telemedicineCase.id,
        patient: widget.patient,
        rating: _rating,
        nps: nps,
        comment: _comment.text.trim(),
      );
      messenger.showSnackBar(const SnackBar(content: Text('¡Gracias! Tu atención quedó completada.')));
    } on ProcessException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.telemedicineCase;
    final catalog = context.read<CatalogRepository>();
    final appointment = c.appointment;
    final doctorName = appointment == null ? '' : ' con ${catalog.doctorById(appointment.doctorId).displayName}';
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Encuesta de satisfacción')),
      body: PageBody(
        child: ListView(
          children: [
            Row(
              children: [
                const AppIllustration(AppIllustrations.onboardingFollowUp, width: 96, height: 72),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿Cómo fue tu atención?', style: theme.textTheme.titleLarge),
                      Text('${catalog.serviceById(c.serviceId).name}$doctorName', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Califica tu experiencia', style: theme.textTheme.titleMedium),
            Row(
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    tooltip: '$star de 5',
                    iconSize: 40,
                    onPressed: () => setState(() => _rating = star),
                    icon: Icon(
                      star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.current,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('¿Qué tan probable es que nos recomiendes?', style: theme.textTheme.titleMedium),
            Text('0 = nada probable · 10 = muy probable', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var score = 0; score <= 10; score++)
                  ChoiceChip(
                    label: Text('$score'),
                    selected: _nps == score,
                    onSelected: (_) => setState(() => _nps = score),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _rating > 0 && _nps != null ? _submit : null,
              icon: const Icon(Icons.send),
              label: const Text('Enviar encuesta'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
