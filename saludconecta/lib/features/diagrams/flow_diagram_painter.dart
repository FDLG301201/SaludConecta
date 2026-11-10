import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/enums.dart';
import '../../domain/process/process_step.dart';
import 'diagram_paint.dart';
import 'flow_layout.dart';

/// Estado de un paso en el modo caso.
enum StepProgress { done, current, pending }

/// Lo que el modo caso necesita saber de un caso: el estado de cada paso y cómo terminó.
class CaseProgress {
  const CaseProgress({required this.states, required this.status});

  final Map<ProcessStep, StepProgress> states;
  final CaseStatus status;
}

/// Dibuja el diagrama de flujo del proceso (§10.1). Sin [progress] cada paso lleva el color de su actor;
/// con [progress] (modo caso) los pasos van en verde con ✓, el actual en ámbar con un pulso y los
/// pendientes en gris. [pulse] (0–1) lo anima un `AnimationController`.
class FlowDiagramPainter extends CustomPainter {
  FlowDiagramPainter({required this.layout, this.progress, this.pulse = 0, super.repaint});

  final FlowLayout layout;
  final CaseProgress? progress;
  final double pulse;

  static const _white = TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600);
  static const _dark = TextStyle(color: AppColors.navy, fontSize: 13, fontWeight: FontWeight.w600);
  static const _edgeLabel = TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w700);

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = DiagramPaint.stroke(const Color(0xFF607D8B));
    for (final edge in layout.edges) {
      DiagramPaint.arrow(canvas, edge.points, edgePaint, dashed: edge.dashed);
      if (edge.label != null) {
        DiagramPaint.text(
          canvas,
          edge.label!,
          Rect.fromLTWH(edge.labelAt!.dx, edge.labelAt!.dy, 70, 18),
          style: _edgeLabel,
          align: TextAlign.left,
          maxLines: 1,
        );
      }
    }
    for (final node in layout.nodes) {
      switch (node.kind) {
        case FlowNodeKind.start:
          _oval(canvas, node, AppColors.patient);
        case FlowNodeKind.end:
          _oval(canvas, node, progress?.status == CaseStatus.completed ? AppColors.done : AppColors.navy);
        case FlowNodeKind.cancelled:
          final cancelled = progress?.status == CaseStatus.cancelled;
          _oval(canvas, node, cancelled ? AppColors.danger : AppColors.danger.withOpacity(0.55));
        case FlowNodeKind.decision:
          _diamond(canvas, node);
        case FlowNodeKind.alternative:
          _alternative(canvas, node);
        case FlowNodeKind.step:
          _step(canvas, node);
      }
    }
  }

  void _oval(Canvas canvas, FlowNode node, Color color) {
    final rrect = RRect.fromRectAndRadius(node.rect, Radius.circular(node.rect.height / 2));
    canvas.drawRRect(rrect, DiagramPaint.fill(color));
    DiagramPaint.text(canvas, node.label, node.rect.deflate(12), style: _white);
  }

  void _diamond(Canvas canvas, FlowNode node) {
    final r = node.rect;
    final path = Path()
      ..moveTo(r.center.dx, r.top)
      ..lineTo(r.right, r.center.dy)
      ..lineTo(r.center.dx, r.bottom)
      ..lineTo(r.left, r.center.dy)
      ..close();
    final rejected = progress?.status == CaseStatus.insuranceRejected;
    canvas.drawPath(path, DiagramPaint.fill(rejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1)));
    canvas.drawPath(path, DiagramPaint.stroke(rejected ? AppColors.danger : AppColors.current, width: 2.5));
    DiagramPaint.text(canvas, node.label, Rect.fromCenter(center: r.center, width: r.width * 0.6, height: 40),
        style: _dark);
  }

  void _alternative(Canvas canvas, FlowNode node) {
    final rrect = RRect.fromRectAndRadius(node.rect, const Radius.circular(10));
    canvas.drawRRect(rrect, DiagramPaint.fill(Colors.white));
    DiagramPaint.dashedRRect(canvas, rrect, DiagramPaint.stroke(AppColors.danger));
    DiagramPaint.text(canvas, node.label, node.rect.deflate(10), style: _dark);
  }

  void _step(Canvas canvas, FlowNode node) {
    final step = node.step!;
    final state = progress?.states[step];
    final color = switch (state) {
      null => AppColors.forActor(step.actor),
      StepProgress.done => AppColors.done,
      StepProgress.current => AppColors.current,
      StepProgress.pending => AppColors.pending,
    };
    final rrect = RRect.fromRectAndRadius(node.rect, const Radius.circular(12));
    if (state == StepProgress.current) {
      // Pulso: un halo que crece y se desvanece alrededor del paso actual.
      final halo = rrect.inflate(4 + pulse * 10);
      canvas.drawRRect(halo, DiagramPaint.stroke(AppColors.current.withOpacity(1 - pulse), width: 4));
    }
    canvas.drawRRect(rrect, DiagramPaint.fill(color));

    final badge = Offset(node.rect.left + 30, node.rect.center.dy);
    canvas.drawCircle(badge, 17, DiagramPaint.fill(Colors.white));
    DiagramPaint.text(
      canvas,
      state == StepProgress.done ? '✓' : '${step.number}',
      Rect.fromCenter(center: badge, width: 34, height: 22),
      style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
      maxLines: 1,
    );
    final textRect = Rect.fromLTRB(node.rect.left + 56, node.rect.top + 6, node.rect.right - 10, node.rect.bottom - 6);
    final titleStyle = state == StepProgress.current ? _dark.copyWith(fontSize: 14) : _white.copyWith(fontSize: 14);
    DiagramPaint.text(
      canvas,
      step.title,
      Rect.fromLTWH(textRect.left, textRect.top, textRect.width, 36),
      style: titleStyle,
      align: TextAlign.left,
    );
    DiagramPaint.text(
      canvas,
      step.actor.label,
      Rect.fromLTWH(textRect.left, textRect.bottom - 16, textRect.width, 16),
      style: titleStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
      align: TextAlign.left,
      maxLines: 1,
    );
  }

  @override
  bool shouldRepaint(FlowDiagramPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse || oldDelegate.layout != layout;
}
