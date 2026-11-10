import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saludconecta/domain/process/case_workflow.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/shared/case_detail/case_timeline.dart';

import '../../support/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('estado de cada paso en la línea de tiempo', () {
    final c = caseAt(ProcessStep.consultation);
    expect(CaseTimeline.stateOf(c, ProcessStep.consentAdmission), TimelineStepState.done);
    expect(CaseTimeline.stateOf(c, ProcessStep.consultation), TimelineStepState.current);
    expect(CaseTimeline.stateOf(c, ProcessStep.followUp), TimelineStepState.pending);
    final refused = CaseWorkflow.applyInsuranceResult(
      caseAt(ProcessStep.insuranceValidation),
      staffName: ana,
      result: rejected(start),
    );
    expect(CaseTimeline.stateOf(refused, ProcessStep.insuranceValidation), TimelineStepState.blocked);
  });

  testWidgets('muestra los 10 pasos y los eventos del caso', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: CaseTimeline(telemedicineCase: caseAt(ProcessStep.consultation))),
        ),
      ),
    );
    for (final step in ProcessStep.values) {
      expect(find.text(step.title), findsOneWidget);
    }
    expect(find.text('Consentimiento firmado'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
  });
}
