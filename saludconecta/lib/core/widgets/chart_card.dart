import 'package:flutter/material.dart';

/// Una entrada de la leyenda: color y texto.
class LegendEntry {
  const LegendEntry(this.label, this.color);

  final String label;
  final Color color;
}

/// Tarjeta para una gráfica (§8 del spec): título, subtítulo, la gráfica con alto fijo y la leyenda.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.legend = const [],
    this.height = 220,
    this.icon = Icons.insights_outlined,
  });

  final String title;
  final String? subtitle;
  final List<LegendEntry> legend;
  final Widget child;

  /// Alto del área de la gráfica; `null` deja que el contenido decida (filas de barras horizontales).
  final double? height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 16),
            if (height == null) child else SizedBox(height: height, child: child),
            if (legend.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [for (final entry in legend) _LegendChip(entry)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip(this.entry);

  final LegendEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: entry.color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(entry.label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
