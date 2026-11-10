import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/actor_chip.dart';
import '../../core/widgets/chart_card.dart';
import '../../core/widgets/step_badge.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/process/process_step.dart';
import 'flow_diagram_painter.dart';
import 'flow_layout.dart';
import 'swimlane_painter.dart';

/// Hoja con el detalle de un paso: actor, quién lo completa, descripción y servicios relacionados.
Future<void> showStepSheet(BuildContext context, ProcessStep step) {
  final services = [
    for (final s in context.read<CatalogRepository>().services)
      if (s.relatedStep == step) s,
  ];
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Row(
                children: [
                  StepBadge(step: step, size: 36),
                  const SizedBox(width: 12),
                  Expanded(child: Text(step.title, style: theme.textTheme.titleLarge)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [ActorChip(actor: step.actor)]),
              const SizedBox(height: 12),
              Text(step.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                'Lo completa: ${step.owners.map((r) => r.label).join(', ')}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (services.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Servicios relacionados', style: theme.textTheme.titleMedium),
                for (final s in services)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(AppIcons.service(s.iconKey), color: AppColors.forActor(step.actor)),
                    title: Text(s.name),
                    subtitle: Text(s.description),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Leyenda de colores de los actores.
List<LegendEntry> get actorLegend => [for (final a in Actor.values) LegendEntry(a.label, AppColors.forActor(a))];

/// Leyenda del modo caso.
const caseLegend = [
  LegendEntry('Completado', AppColors.done),
  LegendEntry('Actual', AppColors.current),
  LegendEntry('Pendiente', AppColors.pending),
];

/// Lienzo con zoom y desplazamiento que arranca ajustado al ancho disponible (y centrado si sobra espacio).
class _ZoomableCanvas extends StatefulWidget {
  const _ZoomableCanvas({required this.canvasSize, required this.child, this.fitWidth = true});

  final Size canvasSize;
  final Widget child;

  /// Si es `false`, se ajusta al alto (el diagrama de carriles se recorre a lo ancho).
  final bool fitWidth;

  @override
  State<_ZoomableCanvas> createState() => _ZoomableCanvasState();
}

class _ZoomableCanvasState extends State<_ZoomableCanvas> {
  final _controller = TransformationController();
  double? _fittedFor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (_fittedFor != width) {
          _fittedFor = width;
          final scale = widget.fitWidth
              ? math.min(1.0, (width - 16) / widget.canvasSize.width)
              : math.min(1.0, (height - 16) / widget.canvasSize.height);
          final dx = math.max(8.0, (width - widget.canvasSize.width * scale) / 2);
          _controller.value = Matrix4.identity()
            ..translate(dx, 8.0)
            ..scale(scale);
        }
        return InteractiveViewer(
          transformationController: _controller,
          constrained: false,
          minScale: 0.3,
          maxScale: 3,
          boundaryMargin: const EdgeInsets.all(200),
          child: widget.child,
        );
      },
    );
  }
}

/// Diagrama de flujo del proceso con zoom y toque sobre los pasos. Con [progress] es el modo caso,
/// y el paso actual late con un `AnimationController`.
class FlowDiagramView extends StatefulWidget {
  const FlowDiagramView({super.key, this.progress});

  final CaseProgress? progress;

  @override
  State<FlowDiagramView> createState() => _FlowDiagramViewState();
}

class _FlowDiagramViewState extends State<FlowDiagramView> with SingleTickerProviderStateMixin {
  final _layout = FlowLayout.build();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  bool get _animates => widget.progress?.states.containsValue(StepProgress.current) ?? false;

  @override
  void initState() {
    super.initState();
    if (_animates) _pulse.repeat();
  }

  @override
  void didUpdateWidget(FlowDiagramView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_animates && !_pulse.isAnimating) _pulse.repeat();
    if (!_animates && _pulse.isAnimating) _pulse.reset();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ZoomableCanvas(
      canvasSize: _layout.size,
      child: GestureDetector(
        onTapUp: (details) {
          final step = _layout.stepAt(details.localPosition);
          if (step != null) showStepSheet(context, step);
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => CustomPaint(
            key: const Key('flow-diagram'),
            size: _layout.size,
            painter: FlowDiagramPainter(layout: _layout, progress: widget.progress, pulse: _pulse.value),
          ),
        ),
      ),
    );
  }
}

/// Diagrama de carriles con desplazamiento horizontal y toque sobre los pasos.
class SwimlaneView extends StatelessWidget {
  const SwimlaneView({super.key});

  static const _layout = SwimlaneLayout();

  @override
  Widget build(BuildContext context) {
    return _ZoomableCanvas(
      canvasSize: _layout.size,
      fitWidth: false,
      child: GestureDetector(
        onTapUp: (details) {
          final step = _layout.stepAt(details.localPosition);
          if (step != null) showStepSheet(context, step);
        },
        child: CustomPaint(key: const Key('swimlane-diagram'), size: _layout.size, painter: const SwimlanePainter()),
      ),
    );
  }
}

/// Leyenda horizontal sobre un diagrama.
class DiagramLegend extends StatelessWidget {
  const DiagramLegend({super.key, required this.entries, this.hint});

  final List<LegendEntry> entries;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final e in entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: e.color, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 6),
                      Text(e.label, style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
