import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/models/process_event.dart';
import '../../../domain/models/telemedicine_case.dart';
import '../../../domain/process/process_step.dart';

/// Estado visual de un paso en la línea de tiempo.
enum TimelineStepState { done, current, blocked, pending }

/// Línea de tiempo del caso (§10.3 del spec): los 10 pasos en vertical, unidos por un conector
/// pintado con `CustomPainter`. Cada paso muestra su actor y sus eventos con fecha, hora y detalle.
class CaseTimeline extends StatelessWidget {
  const CaseTimeline({super.key, required this.telemedicineCase});

  final TelemedicineCase telemedicineCase;

  /// Completado (verde), actual (ámbar), detenido por rechazo o cancelación (rojo) o pendiente (gris).
  static TimelineStepState stateOf(TelemedicineCase c, ProcessStep step) {
    if (c.isStepCompleted(step)) return TimelineStepState.done;
    if (step == c.currentStep && c.status != CaseStatus.completed) {
      return c.status == CaseStatus.active ? TimelineStepState.current : TimelineStepState.blocked;
    }
    return TimelineStepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final c = telemedicineCase;
    return Column(
      children: [
        for (final step in ProcessStep.values)
          _TimelineRow(
            step: step,
            state: stateOf(c, step),
            events: [
              for (final e in c.events)
                if (e.step == step) e,
            ],
            isLast: step == ProcessStep.followUp,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.state, required this.events, required this.isLast});

  final ProcessStep step;
  final TimelineStepState state;
  final List<ProcessEvent> events;
  final bool isLast;

  Color get _color => switch (state) {
        TimelineStepState.done => AppColors.done,
        TimelineStepState.current => AppColors.current,
        TimelineStepState.blocked => AppColors.danger,
        TimelineStepState.pending => AppColors.pending,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = state == TimelineStepState.current || state == TimelineStepState.blocked;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: CustomPaint(
              painter: _ConnectorPainter(color: AppColors.pending.withOpacity(0.45), visible: !isLast),
              child: Align(alignment: Alignment.topCenter, child: _StepDot(step: step, state: state, color: _color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: highlighted ? const EdgeInsets.all(10) : const EdgeInsets.only(top: 5),
                decoration: highlighted
                    ? BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(12))
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: state == TimelineStepState.pending ? AppColors.pending : null,
                      ),
                    ),
                    Text(
                      step.actor.label,
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.forActor(step.actor)),
                    ),
                    for (final e in events) _EventLine(event: e),
                    if (events.isEmpty && state == TimelineStepState.current)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('En curso', style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step, required this.state, required this.color});

  final ProcessStep step;
  final TimelineStepState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = state != TimelineStepState.pending;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: switch (state) {
        TimelineStepState.done => const Icon(Icons.check, size: 18, color: Colors.white),
        TimelineStepState.blocked => const Icon(Icons.priority_high, size: 18, color: Colors.white),
        _ => Text(
            '${step.number}',
            style: TextStyle(color: filled ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
      },
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({required this.event});

  final ProcessEvent event;

  IconData get _icon => switch (event.kind) {
        EventKind.completed => Icons.check_circle_outline,
        EventKind.rejected => Icons.block,
        EventKind.cancelled => Icons.cancel_outlined,
        EventKind.started => Icons.play_circle_outline,
        EventKind.claim => Icons.receipt_long_outlined,
        EventKind.payment => Icons.payments_outlined,
        EventKind.call => Icons.call_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: theme.textTheme.bodyMedium),
                if (event.detail.isNotEmpty) Text(event.detail, style: muted),
                Text('${Formatters.dateTime(event.at)} · ${event.actorName}', style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta la línea vertical que une un paso con el siguiente.
class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({required this.color, required this.visible});

  final Color color;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width / 2, 34), Offset(size.width / 2, size.height), paint);
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) => oldDelegate.color != color || oldDelegate.visible != visible;
}
