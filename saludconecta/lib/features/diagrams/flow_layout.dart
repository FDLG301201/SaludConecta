import 'dart:ui';

import '../../domain/process/process_step.dart';

/// Forma de un nodo del diagrama de flujo.
enum FlowNodeKind { start, step, decision, alternative, end, cancelled }

/// Un nodo: su forma, su rectángulo en el lienzo, su texto y, si es un paso, cuál.
class FlowNode {
  const FlowNode({required this.kind, required this.rect, required this.label, this.step});

  final FlowNodeKind kind;
  final Rect rect;
  final String label;
  final ProcessStep? step;
}

/// Una flecha: sus puntos (ortogonal cuando tiene más de 2), una etiqueta opcional y si es punteada.
class FlowEdge {
  const FlowEdge(this.points, {this.label, this.labelAt, this.dashed = false});

  final List<Offset> points;
  final String? label;
  final Offset? labelAt;
  final bool dashed;
}

/// Posiciones del diagrama de flujo del proceso (§10.1): inicio, los 10 pasos en columna, el rombo
/// "¿El seguro aprueba?" después del paso 3 con su rama "No" (privado o cancelar) y el fin.
/// Es Dart puro: el painter lo dibuja y la vista lo usa para saber qué nodo se tocó.
class FlowLayout {
  FlowLayout._(this.nodes, this.edges, this.size);

  factory FlowLayout.build() {
    const cx = 200.0;
    const stepW = 260.0;
    const stepH = 64.0;
    const gap = 34.0;
    final nodes = <FlowNode>[];
    final edges = <FlowEdge>[];
    var y = 16.0;

    Rect centered(double centerX, double top, double w, double h) => Rect.fromLTWH(centerX - w / 2, top, w, h);

    final start = FlowNode(
      kind: FlowNodeKind.start,
      rect: centered(cx, y, 240, 48),
      label: 'Paciente con carnet de seguro',
    );
    nodes.add(start);
    y = start.rect.bottom + gap;

    FlowNode? previous = start;
    late FlowNode decision;
    final stepNodes = <ProcessStep, FlowNode>{};
    for (final step in ProcessStep.values) {
      final node = FlowNode(
        kind: FlowNodeKind.step,
        rect: centered(cx, y, stepW, stepH),
        label: step.title,
        step: step,
      );
      nodes.add(node);
      stepNodes[step] = node;
      final from = previous!;
      final yes = from.kind == FlowNodeKind.decision;
      edges.add(FlowEdge(
        [from.rect.bottomCenter, node.rect.topCenter],
        label: yes ? 'Sí' : null,
        labelAt: yes ? from.rect.bottomCenter + const Offset(10, 4) : null,
      ));
      previous = node;
      y = node.rect.bottom + gap;
      if (step == ProcessStep.insuranceValidation) {
        decision = FlowNode(
          kind: FlowNodeKind.decision,
          rect: centered(cx, y, 220, 96),
          label: '¿El seguro aprueba?',
        );
        nodes.add(decision);
        edges.add(FlowEdge([node.rect.bottomCenter, decision.rect.topCenter]));
        previous = decision;
        y = decision.rect.bottom + gap;
      }
    }

    final end = FlowNode(kind: FlowNodeKind.end, rect: centered(cx, y, 200, 48), label: 'Paciente atendido');
    nodes.add(end);
    edges.add(FlowEdge([previous!.rect.bottomCenter, end.rect.topCenter]));

    // Rama "No": nodo punteado a la derecha del rombo; "Privado" vuelve al paso 4 y "Cancelar" termina.
    const altX = 490.0;
    final alternative = FlowNode(
      kind: FlowNodeKind.alternative,
      rect: Rect.fromCenter(center: Offset(altX, decision.rect.center.dy), width: 200, height: 56),
      label: '¿Privado o cancelar?',
    );
    nodes.add(alternative);
    edges.add(FlowEdge(
      [decision.rect.centerRight, alternative.rect.centerLeft],
      label: 'No',
      labelAt: decision.rect.centerRight + const Offset(14, -22),
      dashed: true,
    ));
    final scheduling = stepNodes[ProcessStep.scheduling]!;
    const privateX = altX - 50;
    edges.add(FlowEdge(
      [
        Offset(privateX, alternative.rect.bottom),
        Offset(privateX, scheduling.rect.center.dy),
        scheduling.rect.centerRight,
      ],
      label: 'Privado',
      labelAt: Offset(privateX + 6, alternative.rect.bottom + 6),
      dashed: true,
    ));
    const cancelX = altX + 50;
    final confirmation = stepNodes[ProcessStep.patientConfirmation]!;
    final cancelled = FlowNode(
      kind: FlowNodeKind.cancelled,
      rect: Rect.fromCenter(center: Offset(cancelX, confirmation.rect.center.dy), width: 160, height: 48),
      label: 'Solicitud cancelada',
    );
    nodes.add(cancelled);
    edges.add(FlowEdge(
      [Offset(cancelX, alternative.rect.bottom), cancelled.rect.topCenter],
      label: 'Cancelar',
      labelAt: Offset(cancelX + 6, alternative.rect.bottom + 6),
      dashed: true,
    ));

    return FlowLayout._(nodes, edges, Size(cancelled.rect.right + 16, end.rect.bottom + 16));
  }

  final List<FlowNode> nodes;
  final List<FlowEdge> edges;

  /// Tamaño del lienzo.
  final Size size;

  /// El nodo de [step].
  FlowNode nodeOf(ProcessStep step) => nodes.firstWhere((n) => n.step == step);

  /// El paso cuyo nodo contiene [point] (coordenadas del lienzo), o `null` si no se tocó un paso.
  ProcessStep? stepAt(Offset point) {
    for (final node in nodes) {
      if (node.step != null && node.rect.contains(point)) return node.step;
    }
    return null;
  }
}
