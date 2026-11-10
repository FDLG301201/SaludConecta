import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/enums.dart';
import '../../domain/process/process_step.dart';
import 'diagram_paint.dart';

/// Un nodo secundario punteado: otro actor que participa en el paso.
class SwimlaneHelper {
  const SwimlaneHelper(this.step, this.actor, this.label);

  final ProcessStep step;
  final Actor actor;
  final String label;
}

/// Posiciones del diagrama de carriles (§10.2): un carril por actor y una columna por paso.
class SwimlaneLayout {
  const SwimlaneLayout();

  static const labelWidth = 120.0;
  static const columnWidth = 150.0;
  static const laneHeight = 110.0;
  static const nodeWidth = 128.0;
  static const nodeHeight = 70.0;
  static const headerHeight = 34.0;

  /// Carriles, de arriba abajo.
  static const lanes = [Actor.patient, Actor.admission, Actor.doctor, Actor.support, Actor.billing];

  /// Participaciones de otros actores: el paciente en la consulta y en el seguimiento, y Soporte TI en 5–7.
  static const helpers = [
    SwimlaneHelper(ProcessStep.patientConfirmation, Actor.support, 'Enlace y plataforma'),
    SwimlaneHelper(ProcessStep.consentAdmission, Actor.support, 'Prueba de conexión'),
    SwimlaneHelper(ProcessStep.consultation, Actor.support, 'Soporte en consulta'),
    SwimlaneHelper(ProcessStep.consultation, Actor.patient, 'Paciente en la videollamada'),
    SwimlaneHelper(ProcessStep.followUp, Actor.patient, 'Responde la encuesta'),
  ];

  Size get size => Size(
        labelWidth + columnWidth * ProcessStep.values.length,
        headerHeight + laneHeight * lanes.length,
      );

  Rect laneRect(Actor actor) =>
      Rect.fromLTWH(0, headerHeight + lanes.indexOf(actor) * laneHeight, size.width, laneHeight);

  Rect cellNode(ProcessStep step, Actor actor) {
    final lane = laneRect(actor);
    final cx = labelWidth + (step.number - 0.5) * columnWidth;
    return Rect.fromCenter(center: Offset(cx, lane.center.dy), width: nodeWidth, height: nodeHeight);
  }

  /// Nodo principal de cada paso: en el carril de su actor.
  Rect nodeOf(ProcessStep step) => cellNode(step, step.actor);

  /// El paso cuyo nodo principal contiene [point], o `null`.
  ProcessStep? stepAt(Offset point) {
    for (final step in ProcessStep.values) {
      if (nodeOf(step).contains(point)) return step;
    }
    return null;
  }
}

/// Dibuja el diagrama de carriles: fondos por actor, encabezados de paso, nodos, flechas ortogonales entre
/// pasos consecutivos y nodos secundarios punteados.
class SwimlanePainter extends CustomPainter {
  const SwimlanePainter({this.layout = const SwimlaneLayout()});

  final SwimlaneLayout layout;

  static const _white = TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600);

  @override
  void paint(Canvas canvas, Size size) {
    final full = layout.size;
    // Carriles.
    for (final actor in SwimlaneLayout.lanes) {
      final lane = layout.laneRect(actor);
      final color = AppColors.forActor(actor);
      canvas.drawRect(lane, DiagramPaint.fill(color.withOpacity(0.06)));
      final label = Rect.fromLTWH(0, lane.top, SwimlaneLayout.labelWidth, lane.height);
      canvas.drawRect(label, DiagramPaint.fill(color.withOpacity(0.18)));
      canvas.drawLine(lane.bottomLeft, lane.bottomRight, DiagramPaint.stroke(color.withOpacity(0.3), width: 1));
      DiagramPaint.text(
        canvas,
        actor.label,
        label.deflate(8),
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
      );
    }
    // Encabezados de columna.
    for (final step in ProcessStep.values) {
      final x = SwimlaneLayout.labelWidth + (step.number - 1) * SwimlaneLayout.columnWidth;
      DiagramPaint.text(
        canvas,
        'Paso ${step.number}',
        Rect.fromLTWH(x, 0, SwimlaneLayout.columnWidth, SwimlaneLayout.headerHeight),
        style: const TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w700),
        maxLines: 1,
      );
      if (step.number > 1) {
        canvas.drawLine(
          Offset(x, SwimlaneLayout.headerHeight),
          Offset(x, full.height),
          DiagramPaint.stroke(const Color(0x14000000), width: 1),
        );
      }
    }
    // Flechas entre pasos consecutivos.
    final edgePaint = DiagramPaint.stroke(const Color(0xFF607D8B));
    for (final step in ProcessStep.values) {
      final next = step.next;
      if (next == null) continue;
      final from = layout.nodeOf(step);
      final to = layout.nodeOf(next);
      if ((from.center.dy - to.center.dy).abs() < 1) {
        DiagramPaint.arrow(canvas, [from.centerRight, to.centerLeft], edgePaint);
      } else {
        final midX = (from.right + to.left) / 2;
        DiagramPaint.arrow(
          canvas,
          [from.centerRight, Offset(midX, from.center.dy), Offset(midX, to.center.dy), to.centerLeft],
          edgePaint,
        );
      }
    }
    // Nodos secundarios punteados, unidos con una línea punteada al nodo principal del paso.
    for (final helper in SwimlaneLayout.helpers) {
      final rect = layout.cellNode(helper.step, helper.actor);
      final main = layout.nodeOf(helper.step);
      final color = AppColors.forActor(helper.actor);
      final link =
          rect.center.dy < main.center.dy ? [rect.bottomCenter, main.topCenter] : [rect.topCenter, main.bottomCenter];
      canvas.drawPath(
        DiagramPaint.dash(Path()
          ..moveTo(link[0].dx + 20, link[0].dy)
          ..lineTo(link[1].dx + 20, link[1].dy)),
        DiagramPaint.stroke(color.withOpacity(0.7), width: 1.5),
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(rrect, DiagramPaint.fill(Colors.white));
      DiagramPaint.dashedRRect(canvas, rrect, DiagramPaint.stroke(color));
      DiagramPaint.text(canvas, helper.label, rect.deflate(8),
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600));
    }
    // Nodos principales.
    for (final step in ProcessStep.values) {
      final rect = layout.nodeOf(step);
      final color = AppColors.forActor(step.actor);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), DiagramPaint.fill(color));
      DiagramPaint.text(
        canvas,
        '${step.number}. ${step.title}',
        rect.deflate(8),
        style: _white,
        maxLines: 3,
      );
    }
  }

  @override
  bool shouldRepaint(SwimlanePainter oldDelegate) => false;
}
