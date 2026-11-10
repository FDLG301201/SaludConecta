import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/chart_card.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/services/stats_calculator.dart';
import '../../../state/case_provider.dart';
import '../../indicators/charts.dart';

/// "Mi resumen" del perfil del paciente (§7): lo que cubrió el seguro frente a lo que pagó, y sus consultas
/// por especialidad. Sale de los mismos casos que Indicadores, así que se actualiza en vivo.
class MySummary extends StatelessWidget {
  const MySummary({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final cases = context.watch<CaseProvider>().casesOfPatient(patientId);
    final servicesById = {for (final s in context.read<CatalogRepository>().services) s.id: s};
    final split = StatsCalculator.coverageSplit(cases);
    final coverage = [
      ChartDatum('Cubierto por el seguro', split.covered.toDouble(), AppColors.secondary),
      ChartDatum('Pagado por mí', split.paid.toDouble(), AppColors.current),
    ];
    final specialties = specialtyBars(StatsCalculator.consultationsBySpecialty(cases, servicesById), skipEmpty: true);
    String money(double v) => Formatters.money(v);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final width = wide ? (constraints.maxWidth - 4) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            SizedBox(
              width: width,
              child: ChartCard(
                title: 'Cubierto por el seguro vs. pagado por mí',
                subtitle: 'Casos cerrados',
                icon: Icons.donut_large,
                legend: legendOf(coverage, format: money),
                child: DonutChart(data: coverage, centerLabel: 'facturado', format: compactNumber),
              ),
            ),
            SizedBox(
              width: width,
              child: ChartCard(
                title: 'Mis consultas por especialidad',
                icon: Icons.bar_chart,
                legend: [for (final d in specialties) LegendEntry(d.label, d.color)],
                child: specialties.isEmpty ? const NoChartData() : SimpleBarChart(data: specialties),
              ),
            ),
          ],
        );
      },
    );
  }
}
