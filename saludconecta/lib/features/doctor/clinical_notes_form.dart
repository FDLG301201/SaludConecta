import 'package:flutter/material.dart';

/// Notas clínicas de la consulta. El motivo y el diagnóstico son obligatorios para finalizar (regla del paso 7).
class ClinicalNotesForm extends StatelessWidget {
  const ClinicalNotesForm({
    super.key,
    required this.complaint,
    required this.assessment,
    required this.diagnosis,
    required this.plan,
  });

  final TextEditingController complaint;
  final TextEditingController assessment;
  final TextEditingController diagnosis;
  final TextEditingController plan;

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController controller, String label, int lines) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines + 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(complaint, 'Motivo de consulta *', 2),
        field(assessment, 'Evaluación', 3),
        field(diagnosis, 'Diagnóstico *', 2),
        field(plan, 'Plan', 3),
        Text('* Obligatorios para finalizar la consulta.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
