import 'package:flutter_test/flutter_test.dart';
import 'package:saludconecta/domain/process/process_step.dart';
import 'package:saludconecta/features/diagrams/flow_layout.dart';
import 'package:saludconecta/features/diagrams/swimlane_painter.dart';

void main() {
  final layout = FlowLayout.build();

  test('el flujo tiene inicio, los 10 pasos, el rombo, la rama "No" y los dos finales', () {
    int count(FlowNodeKind kind) => layout.nodes.where((n) => n.kind == kind).length;
    expect(count(FlowNodeKind.step), 10);
    expect(count(FlowNodeKind.start), 1);
    expect(count(FlowNodeKind.decision), 1);
    expect(count(FlowNodeKind.alternative), 1);
    expect(count(FlowNodeKind.end), 1);
    expect(count(FlowNodeKind.cancelled), 1);
    expect(layout.edges.where((e) => e.label != null).map((e) => e.label),
        containsAll(['Sí', 'No', 'Privado', 'Cancelar']));
  });

  test('el rombo va entre el paso 3 y el 4, y los pasos bajan en orden', () {
    final decision = layout.nodes.firstWhere((n) => n.kind == FlowNodeKind.decision);
    expect(decision.rect.top, greaterThan(layout.nodeOf(ProcessStep.insuranceValidation).rect.bottom));
    expect(decision.rect.bottom, lessThan(layout.nodeOf(ProcessStep.scheduling).rect.top));
    for (final step in ProcessStep.values.skip(1)) {
      expect(layout.nodeOf(step).rect.top, greaterThan(layout.nodeOf(step.previous!).rect.bottom));
    }
    for (final node in layout.nodes) {
      expect((Offset.zero & layout.size).contains(node.rect.bottomRight), isTrue);
    }
  });

  test('un toque dentro de un paso lo encuentra; fuera de los pasos no', () {
    final consultation = layout.nodeOf(ProcessStep.consultation).rect;
    expect(layout.stepAt(consultation.center), ProcessStep.consultation);
    expect(layout.stepAt(consultation.topLeft + const Offset(2, 2)), ProcessStep.consultation);
    expect(layout.stepAt(const Offset(1, 1)), isNull);
  });

  test('carriles: cada paso va en el carril de su actor y el toque lo encuentra', () {
    const lanes = SwimlaneLayout();
    for (final step in ProcessStep.values) {
      final node = lanes.nodeOf(step);
      expect(lanes.laneRect(step.actor).contains(node.center), isTrue);
      expect(lanes.stepAt(node.center), step);
    }
    expect(lanes.stepAt(const Offset(10, 10)), isNull);
  });
}
