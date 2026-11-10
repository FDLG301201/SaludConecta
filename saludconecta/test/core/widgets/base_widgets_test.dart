import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/core/constants/app_illustrations.dart';
import 'package:saludconecta/core/widgets/actor_chip.dart';
import 'package:saludconecta/core/widgets/empty_state.dart';
import 'package:saludconecta/core/widgets/loading_button.dart';
import 'package:saludconecta/core/widgets/status_chip.dart';
import 'package:saludconecta/core/widgets/step_badge.dart';
import 'package:saludconecta/domain/models/enums.dart';
import 'package:saludconecta/domain/process/process_step.dart';

void main() {
  testWidgets('StepBadge, StatusChip y ActorChip muestran su texto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StepBadge(step: ProcessStep.consultation),
              StatusChip(status: CaseStatus.insuranceRejected),
              ActorChip(actor: Actor.support),
            ],
          ),
        ),
      ),
    );
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Rechazado por el seguro'), findsOneWidget);
    expect(find.text('Soporte TI'), findsOneWidget);
  });

  testWidgets('LoadingButton se deshabilita y muestra carga mientras espera', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoadingButton(label: 'Consultar al seguro', loading: true, onPressed: () => taps++)),
      ),
    );
    await tester.tap(find.text('Consultar al seguro'));
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('EmptyState muestra el título, el mensaje y la acción', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            illustration: AppIllustrations.emptyCases,
            title: 'Aún no tienes citas',
            message: 'Solicita tu primera cita.',
            action: TextButton(onPressed: () {}, child: const Text('Solicitar cita')),
          ),
        ),
      ),
    );
    expect(find.text('Aún no tienes citas'), findsOneWidget);
    expect(find.text('Solicitar cita'), findsOneWidget);
  });
}
