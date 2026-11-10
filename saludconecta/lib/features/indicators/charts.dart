import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/chart_card.dart';
import '../../domain/models/enums.dart';

/// Colores de las series, en orden (los colores de los actores y de los estados del tema).
class ChartPalette {
  const ChartPalette._();

  static const colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.current,
    AppColors.support,
    AppColors.patient,
    AppColors.danger,
    AppColors.billing,
  ];

  static Color at(int index) => colors[index % colors.length];
}

/// Un valor con nombre: una porción de la dona o una barra.
class ChartDatum {
  const ChartDatum(this.label, this.value, this.color, {String? shortLabel}) : shortLabel = shortLabel ?? label;

  final String label;

  /// Texto bajo la barra (más corto cuando el nombre no cabe).
  final String shortLabel;
  final double value;
  final Color color;
}

/// La leyenda de una lista de valores: "Nombre (valor)".
List<LegendEntry> legendOf(List<ChartDatum> data, {String Function(double value)? format}) => [
      for (final d in data) LegendEntry('${d.label} (${(format ?? compactNumber)(d.value)})', d.color),
    ];

/// "12", "1.5k", "45k", "1.2M".
String compactNumber(double value) {
  if (value.abs() >= 1000000) return '${_trim(value / 1000000)}M';
  if (value.abs() >= 1000) return '${_trim(value / 1000)}k';
  return _trim(value);
}

String _trim(double value) {
  final text = value.toStringAsFixed(value == value.roundToDouble() || value.abs() >= 10 ? 0 : 1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

const _tooltipColor = AppColors.navy;
const _tooltipText = TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12);
const _axisText = TextStyle(fontSize: 11, color: Color(0xFF5F6B76));

/// Mensaje cuando una gráfica no tiene datos.
class NoChartData extends StatelessWidget {
  const NoChartData({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Text('Sin datos todavía', style: Theme.of(context).textTheme.bodyMedium),
      );
}

/// Dona (`PieChart`) con el total en el centro; las porciones en cero no se dibujan.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.data, this.centerLabel = 'Total', this.format = compactNumber});

  final List<ChartDatum> data;
  final String centerLabel;
  final String Function(double value) format;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (sum, d) => sum + d.value);
    if (total == 0) return const NoChartData();
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 56,
            sections: [
              for (final d in data)
                if (d.value > 0)
                  PieChartSectionData(
                    value: d.value,
                    color: d.color,
                    radius: 40,
                    title: d.value / total >= 0.08 ? '${(d.value * 100 / total).round()}%' : '',
                    titleStyle: _tooltipText,
                  ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(format(total), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text(centerLabel, style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

/// Títulos del eje izquierdo con números compactos.
AxisTitles _leftTitles(String Function(double value) format) => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 36,
        getTitlesWidget: (value, meta) {
          if (value == meta.max && value != meta.min) return const SizedBox.shrink();
          return SideTitleWidget(axisSide: meta.axisSide, child: Text(format(value), style: _axisText));
        },
      ),
    );

/// Títulos del eje inferior: un texto por índice.
AxisTitles _bottomTitles(List<String> labels, {double reservedSize = 28}) => AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: reservedSize,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index != value || index < 0 || index >= labels.length) return const SizedBox.shrink();
          return SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(labels[index], style: _axisText, textAlign: TextAlign.center),
          );
        },
      ),
    );

const _noTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

FlGridData get _grid => FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (value) => const FlLine(color: Color(0x22000000), strokeWidth: 1),
    );

/// Máximo del eje: un poco por encima del valor mayor, para que la barra más alta no toque el borde.
double _niceMax(double max) => max <= 0 ? 1 : max * 1.15;

/// Barras verticales (`BarChart`), una por valor.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({super.key, required this.data, this.format = compactNumber});

  final List<ChartDatum> data;
  final String Function(double value) format;

  @override
  Widget build(BuildContext context) {
    if (data.every((d) => d.value == 0)) return const NoChartData();
    final max = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: _niceMax(max),
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: _leftTitles(format),
          bottomTitles: _bottomTitles([for (final d in data) d.shortLabel]),
          topTitles: _noTitles,
          rightTitles: _noTitles,
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => _tooltipColor,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem('${data[group.x].label}\n${format(rod.toY)}', _tooltipText),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].value,
                  color: data[i].color,
                  width: data.length > 8 ? 14 : 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Una serie de una gráfica de barras apiladas o de líneas.
class ChartSeries {
  const ChartSeries(this.label, this.color, this.values);

  final String label;
  final Color color;

  /// Un valor por punto del eje X; `null` deja un hueco en la línea.
  final List<double?> values;
}

/// Barras apiladas (`BarChart` con `rodStackItems`): una barra por punto del eje X.
class StackedBarChart extends StatelessWidget {
  const StackedBarChart({super.key, required this.labels, required this.series, this.format = compactNumber});

  final List<String> labels;
  final List<ChartSeries> series;
  final String Function(double value) format;

  double _total(int i) => series.fold<double>(0, (sum, s) => sum + (s.values[i] ?? 0));

  @override
  Widget build(BuildContext context) {
    final totals = [for (var i = 0; i < labels.length; i++) _total(i)];
    if (totals.every((t) => t == 0)) return const NoChartData();
    final max = totals.reduce((a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: _niceMax(max),
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: _leftTitles(format),
          bottomTitles: _bottomTitles(labels),
          topTitles: _noTitles,
          rightTitles: _noTitles,
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => _tooltipColor,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              [
                labels[group.x],
                for (final s in series) '${s.label}: ${format(s.values[group.x] ?? 0)}',
              ].join('\n'),
              _tooltipText,
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < labels.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: totals[i],
                  width: 14,
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  rodStackItems: _stack(i),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<BarChartRodStackItem> _stack(int i) {
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (final s in series) {
      final value = s.values[i] ?? 0;
      items.add(BarChartRodStackItem(from, from + value, s.color));
      from += value;
    }
    return items;
  }
}

/// Líneas (`LineChart`), una por serie, sobre los mismos puntos del eje X.
class MultiLineChart extends StatelessWidget {
  const MultiLineChart({
    super.key,
    required this.labels,
    required this.series,
    this.format = compactNumber,
    this.minY,
    this.maxY,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final String Function(double value) format;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final s in series)
        for (final v in s.values)
          if (v != null) v,
    ];
    if (values.isEmpty || values.every((v) => v == 0)) return const NoChartData();
    final max = values.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: minY ?? 0,
        maxY: maxY ?? _niceMax(max),
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: _leftTitles(format),
          bottomTitles: _bottomTitles(labels),
          topTitles: _noTitles,
          rightTitles: _noTitles,
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => _tooltipColor,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem('${series[spot.barIndex].label}: ${format(spot.y)}', _tooltipText),
            ],
          ),
        ),
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              isCurved: true,
              preventCurveOverShooting: true,
              color: s.color,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: s.color.withOpacity(0.08)),
              spots: [
                for (var i = 0; i < s.values.length; i++)
                  s.values[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), s.values[i]!),
              ],
            ),
        ],
      ),
    );
  }
}

/// Barras horizontales hechas con widgets (embudo, aseguradoras): el nombre arriba y la barra proporcional
/// al mayor valor, con su cifra a la derecha. Se leen bien en teléfono aunque los nombres sean largos.
class HorizontalBars extends StatelessWidget {
  const HorizontalBars({super.key, required this.data, this.format = compactNumber});

  final List<ChartDatum> data;
  final String Function(double value) format;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.every((d) => d.value == 0)) return const SizedBox(height: 120, child: NoChartData());
    final max = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final d in data)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(d.label, style: theme.textTheme.bodySmall)),
                    Text(format(d.value), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 12, color: d.color.withOpacity(0.12)),
                      FractionallySizedBox(
                        widthFactor: max == 0 ? 0 : d.value / max,
                        child: Container(height: 12, color: d.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Nombre corto de cada especialidad para el eje de las barras.
String _shortSpecialty(Specialty s) => switch (s) {
      Specialty.generalMedicine => 'Gral.',
      Specialty.internalMedicine => 'Int.',
      Specialty.pediatrics => 'Ped.',
      Specialty.gynecology => 'Gin.',
      Specialty.cardiology => 'Card.',
      Specialty.psychology => 'Psic.',
      Specialty.nutrition => 'Nutr.',
    };

/// Barras de consultas por especialidad (también las usa "Mi resumen" del paciente).
List<ChartDatum> specialtyBars(Map<Specialty, int> counts, {bool skipEmpty = false}) => [
      for (final s in Specialty.values)
        if (!skipEmpty || counts[s]! > 0)
          ChartDatum(s.label, counts[s]!.toDouble(), ChartPalette.at(s.index), shortLabel: _shortSpecialty(s)),
    ];
