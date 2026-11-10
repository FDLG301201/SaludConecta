import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Utilidades de dibujo compartidas por los diagramas (`CustomPainter`).
class DiagramPaint {
  const DiagramPaint._();

  /// Dibuja [text] dentro de [rect], centrado, con ajuste de línea y "…" si no cabe.
  static void text(
    Canvas canvas,
    String text,
    Rect rect, {
    required TextStyle style,
    TextAlign align = TextAlign.center,
    int maxLines = 2,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: rect.width);
    final dx = switch (align) {
      TextAlign.left || TextAlign.start => rect.left,
      _ => rect.left + (rect.width - painter.width) / 2,
    };
    painter.paint(canvas, Offset(dx, rect.top + (rect.height - painter.height) / 2));
  }

  /// Una línea quebrada por [points], continua o punteada, con punta de flecha en el último punto.
  static void arrow(Canvas canvas, List<Offset> points, Paint paint, {bool dashed = false, double head = 9}) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (dashed) {
      canvas.drawPath(dash(path), paint);
    } else {
      canvas.drawPath(path, paint);
    }
    final tip = points.last;
    final from = points[points.length - 2];
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - head * math.cos(angle - 0.45), tip.dy - head * math.sin(angle - 0.45))
      ..lineTo(tip.dx - head * math.cos(angle + 0.45), tip.dy - head * math.sin(angle + 0.45))
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill,
    );
  }

  /// El mismo trazo de [source], cortado en guiones.
  static Path dash(Path source, {double on = 6, double off = 4}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + on, metric.length);
        result.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + off;
      }
    }
    return result;
  }

  /// Contorno punteado de un rectángulo redondeado.
  static void dashedRRect(Canvas canvas, RRect rrect, Paint paint) =>
      canvas.drawPath(dash(Path()..addRRect(rrect)), paint);

  static Paint stroke(Color color, {double width = 2}) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  static Paint fill(Color color) => Paint()..color = color;
}
