import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/chart_card.dart';
import '../../core/widgets/kpi_tile.dart';
import '../../core/widgets/page_body.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/telemedicine_case.dart';
import '../../domain/process/process_step.dart';
import '../../domain/services/stats_calculator.dart';
import '../../state/case_provider.dart';
import '../../state/session_provider.dart';
import 'charts.dart';

/// Pestañas de Indicadores (§7 del spec).
enum IndicatorsTab {
  operation('Operación', Icons.speed_outlined),
  clinical('Clínico', Icons.medical_information_outlined),
  financial('Financiero', Icons.payments_outlined),
  satisfaction('Satisfacción', Icons.sentiment_satisfied_alt_outlined);

  const IndicatorsTab(this.label, this.icon);

  final String label;
  final IconData icon;

  /// La pestaña con la que abre cada rol: Admisión → Operación, Médico → Clínico, Facturación → Financiero.
  static IndicatorsTab initialFor(UserRole? role) => switch (role) {
        UserRole.doctor => clinical,
        UserRole.billing => financial,
        _ => operation,
      };
}

/// "Indicadores": pantalla compartida por el personal. Todas las gráficas salen de `StatsCalculator`
/// sobre los mismos casos (históricos + en vivo), así que cambian en cuanto avanza un caso.
class IndicatorsScreen extends StatelessWidget {
  const IndicatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final initial = IndicatorsTab.initialFor(context.read<SessionProvider>().role);
    return DefaultTabController(
      length: IndicatorsTab.values.length,
      initialIndex: initial.index,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                for (final tab in IndicatorsTab.values) Tab(icon: Icon(tab.icon, size: 20), text: tab.label),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [_OperationTab(), _ClinicalTab(), _FinancialTab(), _SatisfactionTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Los casos de la ventana de 12 meses y la hora actual, leídos del estado (se reconstruye al cambiar).
class _Data {
  _Data(BuildContext context) {
    final provider = context.watch<CaseProvider>();
    now = provider.now;
    all = provider.cases;
    window = StatsCalculator.inWindow(all, now);
  }

  late final DateTime now;
  late final List<TelemedicineCase> all;
  late final List<TelemedicineCase> window;

  List<String> get monthLabels => [for (final m in StatsCalculator.monthsUpTo(now)) Formatters.monthLabel(m)];
}

/// Lista de la pestaña: los indicadores arriba y las gráficas en 1 columna (2 en pantallas anchas).
class _TabBody extends StatelessWidget {
  const _TabBody({this.kpis, required this.charts});

  final KpiGrid? kpis;
  final List<Widget> charts;

  @override
  Widget build(BuildContext context) {
    return PageBody(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 900;
          final width = twoColumns ? (constraints.maxWidth - 4) / 2 : constraints.maxWidth;
          return ListView(
            children: [
              if (kpis != null) ...[kpis!, const SizedBox(height: 4)],
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [for (final chart in charts) SizedBox(width: width, child: chart)],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

String _hours(double value) => '${compactNumber(value)} h';

// ----- Operación -----

class _OperationTab extends StatelessWidget {
  const _OperationTab();

  @override
  Widget build(BuildContext context) {
    final data = _Data(context);
    final kpis = StatsCalculator.operationKpis(data.window, data.now);
    final channels = StatsCalculator.requestsByChannel(data.window);
    final channelData = [
      for (final channel in RequestChannel.values)
        ChartDatum(channel.label, channels[channel]!.toDouble(), ChartPalette.at(channel.index)),
    ];
    final activity = StatsCalculator.monthlyActivity(data.all, data.now);
    final funnel = StatsCalculator.funnel(data.window);
    final hours = StatsCalculator.averageHoursPerStage(data.window);
    return _TabBody(
      kpis: KpiGrid(
        tiles: [
          KpiTile(
            label: 'Solicitudes del mes',
            value: '${kpis.requestsThisMonth}',
            icon: Icons.event_note,
            color: AppColors.primary,
          ),
          KpiTile(
            label: 'Casos en proceso',
            value: '${kpis.casesInProcess}',
            icon: Icons.pending_actions,
            color: AppColors.currentText,
          ),
          KpiTile(
            label: 'Días de la solicitud a la consulta',
            value: kpis.averageDaysToConsultation.toStringAsFixed(1),
            icon: Icons.timelapse,
            color: AppColors.secondary,
          ),
          KpiTile(
            label: 'Rechazo del seguro',
            value: '${kpis.rejectionRate.toStringAsFixed(1)}%',
            icon: Icons.gpp_bad_outlined,
            color: AppColors.danger,
          ),
        ],
      ),
      charts: [
        ChartCard(
          title: 'Solicitudes por canal',
          subtitle: 'Últimos 12 meses',
          icon: Icons.donut_large,
          legend: legendOf(channelData),
          child: DonutChart(data: channelData, centerLabel: 'solicitudes'),
        ),
        ChartCard(
          title: 'Solicitudes vs. consultas realizadas',
          subtitle: 'Por mes',
          icon: Icons.show_chart,
          legend: const [
            LegendEntry('Solicitudes', AppColors.primary),
            LegendEntry('Consultas', AppColors.secondary),
          ],
          child: MultiLineChart(
            labels: data.monthLabels,
            series: [
              ChartSeries('Solicitudes', AppColors.primary, [for (final m in activity) m.requests.toDouble()]),
              ChartSeries('Consultas', AppColors.secondary, [for (final m in activity) m.consultations.toDouble()]),
            ],
          ),
        ),
        ChartCard(
          title: 'Embudo del proceso',
          subtitle: 'Casos que completaron cada paso',
          icon: Icons.filter_alt_outlined,
          height: null,
          child: HorizontalBars(
            data: [
              for (final step in ProcessStep.values)
                ChartDatum('${step.number}. ${step.title}', funnel[step]!.toDouble(), AppColors.forActor(step.actor)),
            ],
          ),
        ),
        ChartCard(
          title: 'Tiempo promedio por etapa',
          subtitle: 'Horas desde el paso anterior (pasos 2–10)',
          icon: Icons.bar_chart,
          child: SimpleBarChart(
            format: _hours,
            data: [
              for (final step in ProcessStep.values.skip(1))
                ChartDatum(
                  'Paso ${step.number}: ${step.title}',
                  hours[step]!,
                  AppColors.forActor(step.actor),
                  shortLabel: 'P${step.number}',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----- Clínico -----

class _ClinicalTab extends StatelessWidget {
  const _ClinicalTab();

  @override
  Widget build(BuildContext context) {
    final data = _Data(context);
    final servicesById = {for (final s in context.read<CatalogRepository>().services) s.id: s};
    final specialties = StatsCalculator.consultationsBySpecialty(data.window, servicesById);
    final platforms = StatsCalculator.platformUsage(data.window);
    final platformData = [
      for (final p in VideoPlatform.values) ChartDatum(p.label, platforms[p]!.toDouble(), ChartPalette.at(p.index)),
    ];
    final results = StatsCalculator.resultsIssued(data.window);
    final consultations = specialties.values.fold<int>(0, (sum, n) => sum + n);
    return _TabBody(
      kpis: KpiGrid(
        tiles: [
          KpiTile(
            label: 'Consultas realizadas',
            value: '$consultations',
            icon: Icons.video_camera_front_outlined,
            color: AppColors.doctor,
          ),
          KpiTile(
            label: 'Recetas emitidas',
            value: '${results.prescriptions}',
            icon: Icons.medication_outlined,
            color: AppColors.primary,
          ),
        ],
      ),
      charts: [
        ChartCard(
          title: 'Consultas por especialidad',
          subtitle: 'Últimos 12 meses',
          icon: Icons.bar_chart,
          legend: [for (final d in specialtyBars(specialties)) LegendEntry('${d.shortLabel} ${d.label}', d.color)],
          child: SimpleBarChart(data: specialtyBars(specialties)),
        ),
        ChartCard(
          title: 'Plataforma usada',
          subtitle: 'Consultas por plataforma de videoconferencia',
          icon: Icons.donut_large,
          legend: legendOf(platformData),
          child: DonutChart(data: platformData, centerLabel: 'consultas'),
        ),
        ChartCard(
          title: 'Resultados emitidos',
          subtitle: 'Casos con cada tipo de resultado',
          icon: Icons.assignment_outlined,
          child: SimpleBarChart(
            data: [
              ChartDatum('Recetas', results.prescriptions.toDouble(), AppColors.primary),
              ChartDatum('Órdenes de laboratorio', results.labOrders.toDouble(), AppColors.secondary,
                  shortLabel: 'Lab.'),
              ChartDatum('Órdenes de imágenes', results.imagingOrders.toDouble(), AppColors.support,
                  shortLabel: 'Imág.'),
              ChartDatum('Referimientos', results.referrals.toDouble(), AppColors.current, shortLabel: 'Ref.'),
            ],
          ),
        ),
      ],
    );
  }
}

// ----- Financiero -----

class _FinancialTab extends StatelessWidget {
  const _FinancialTab();

  @override
  Widget build(BuildContext context) {
    final data = _Data(context);
    final catalog = context.read<CatalogRepository>();
    final billing = StatsCalculator.monthlyBilling(data.all, data.now);
    final insurerTotal = billing.fold<int>(0, (sum, m) => sum + m.insurerAmount);
    final copayTotal = billing.fold<int>(0, (sum, m) => sum + m.copay);
    final claims = StatsCalculator.claimsByStatus(data.window);
    final claimColors = {
      ClaimStatus.approved: AppColors.done,
      ClaimStatus.pending: AppColors.current,
      ClaimStatus.objected: AppColors.danger,
    };
    final claimData = [
      for (final entry in claims.entries) ChartDatum(entry.key.label, entry.value.toDouble(), claimColors[entry.key]!),
    ];
    final patientsById = {for (final p in catalog.patients) p.id: p};
    final byInsurer = StatsCalculator.billingByInsurer(data.window, patientsById).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _TabBody(
      kpis: KpiGrid(
        tiles: [
          KpiTile(
            label: 'A cargo de los seguros',
            value: Formatters.money(insurerTotal),
            icon: Icons.shield_outlined,
            color: AppColors.billing,
          ),
          KpiTile(
            label: 'Copagos cobrados',
            value: Formatters.money(copayTotal),
            icon: Icons.payments_outlined,
            color: AppColors.secondary,
          ),
        ],
      ),
      charts: [
        ChartCard(
          title: 'Facturación mensual',
          subtitle: 'RD\$ por mes de cierre: seguro vs. copago',
          icon: Icons.stacked_bar_chart,
          legend: const [
            LegendEntry('Seguro', AppColors.billing),
            LegendEntry('Copago', AppColors.current),
          ],
          child: StackedBarChart(
            labels: data.monthLabels,
            series: [
              ChartSeries('Seguro', AppColors.billing, [for (final m in billing) m.insurerAmount.toDouble()]),
              ChartSeries('Copago', AppColors.current, [for (final m in billing) m.copay.toDouble()]),
            ],
          ),
        ),
        ChartCard(
          title: 'Reclamaciones por estado',
          subtitle: 'Sin los casos privados',
          icon: Icons.donut_large,
          legend: legendOf(claimData),
          child: DonutChart(data: claimData, centerLabel: 'reclamaciones'),
        ),
        ChartCard(
          title: 'Facturación por aseguradora',
          subtitle: 'Monto a cargo del seguro en los casos cerrados',
          icon: Icons.account_balance_outlined,
          height: null,
          child: HorizontalBars(
            format: (v) => Formatters.money(v),
            data: [
              for (var i = 0; i < byInsurer.length; i++)
                ChartDatum(
                    catalog.insurerById(byInsurer[i].key).name, byInsurer[i].value.toDouble(), ChartPalette.at(i)),
            ],
          ),
        ),
      ],
    );
  }
}

// ----- Satisfacción -----

class _SatisfactionTab extends StatelessWidget {
  const _SatisfactionTab();

  @override
  Widget build(BuildContext context) {
    final data = _Data(context);
    final surveys = StatsCalculator.surveysOf(data.window).length;
    final nps = StatsCalculator.nps(data.window);
    final distribution = StatsCalculator.ratingDistribution(data.window);
    const starColors = [AppColors.danger, Color(0xFFEF6C00), AppColors.current, Color(0xFF7CB342), AppColors.done];
    final monthly = StatsCalculator.monthlyRating(data.all, data.now);
    return _TabBody(
      kpis: KpiGrid(
        tiles: [
          KpiTile(
            label: 'Calificación promedio',
            value: '${StatsCalculator.averageRating(data.window).toStringAsFixed(1)} ★',
            icon: Icons.star_outline,
            color: AppColors.currentText,
          ),
          KpiTile(
            label: 'NPS',
            value: nps > 0 ? '+$nps' : '$nps',
            icon: Icons.thumb_up_alt_outlined,
            color: nps >= 0 ? AppColors.done : AppColors.danger,
          ),
          KpiTile(
            label: 'Encuestas respondidas',
            value: '$surveys',
            icon: Icons.rate_review_outlined,
            color: AppColors.primary,
          ),
        ],
      ),
      charts: [
        ChartCard(
          title: 'Distribución de calificaciones',
          subtitle: 'Encuestas por número de estrellas',
          icon: Icons.bar_chart,
          child: SimpleBarChart(
            data: [
              for (var stars = 1; stars <= 5; stars++)
                ChartDatum(
                  '$stars ${stars == 1 ? 'estrella' : 'estrellas'}',
                  distribution[stars]!.toDouble(),
                  starColors[stars - 1],
                  shortLabel: '$stars★',
                ),
            ],
          ),
        ),
        ChartCard(
          title: 'Satisfacción promedio por mes',
          subtitle: 'Estrellas (1–5)',
          icon: Icons.show_chart,
          child: MultiLineChart(
            labels: data.monthLabels,
            minY: 0,
            maxY: 5,
            format: (v) => v.toStringAsFixed(1),
            series: [
              ChartSeries('Promedio', AppColors.currentText, [for (final m in monthly) m.average]),
            ],
          ),
        ),
      ],
    );
  }
}
