import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_step.dart';
import '../../state/case_provider.dart';
import '../shared/not_found_screen.dart';
import 'diagram_views.dart';
import 'flow_diagram_painter.dart';

/// Estado de cada paso de [c] para el modo caso: completados, el actual (si el caso sigue abierto) y pendientes.
CaseProgress progressOf(TelemedicineCase c) => CaseProgress(
      status: c.status,
      states: {
        for (final step in ProcessStep.values)
          step: c.isStepCompleted(step)
              ? StepProgress.done
              : (step == c.currentStep && c.isOpen ? StepProgress.current : StepProgress.pending),
      },
    );

/// "Diagrama del caso" (`/caso/:id/diagrama`): el diagrama de flujo en modo caso.
class CaseDiagramScreen extends StatelessWidget {
  const CaseDiagramScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CaseProvider>().caseById(caseId);
    if (c == null) {
      return const NotFoundScreen(title: 'Caso no encontrado', message: 'El caso que buscas no existe.');
    }
    final status = switch (c.status) {
      CaseStatus.completed => 'Caso completado',
      CaseStatus.cancelled => 'Caso cancelado',
      _ => 'Paso ${c.currentStep.number} de 10: ${c.currentStep.title}',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Diagrama del caso')),
      body: Column(
        children: [
          DiagramLegend(entries: caseLegend, hint: '${c.id} · $status. Toca un paso para ver su detalle.'),
          const Divider(height: 1),
          Expanded(child: ClipRect(child: FlowDiagramView(progress: progressOf(c)))),
        ],
      ),
    );
  }
}
