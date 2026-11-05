import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/charts/chart_palette.dart';
import '../../../../shared/widgets/charts/horizontal_bar_chart.dart';
import '../../../../shared/widgets/charts/share_bar_chart.dart';
import '../../domain/entities/sales_import.dart';
import '../../domain/services/sales_analysis.dart';
import '../sales_metric.dart';
import 'metric_selector.dart';
import 'section_card.dart';
import 'stat_card.dart';

/// Totals of the import, the channel split and the ranking of platforms.
class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.detail,
    required this.metric,
    required this.onMetricChanged,
  });

  final SalesImportDetail detail;
  final SalesMetric metric;
  final ValueChanged<SalesMetric> onMetricChanged;

  /// Colors follow the channel, never its position in the list.
  static const _channelColors = {'InPerson': 0, 'Online': 1};

  @override
  Widget build(BuildContext context) {
    final i = detail.salesImport;
    final period = i.periodStart == null
        ? '-'
        : '${Formatters.date(i.periodStart!)} a ${Formatters.date(i.periodEnd!)}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatGrid(
          stats: [
            StatCard(
              label: 'Faturamento',
              value: Formatters.currency(i.totalRevenue),
              icon: Icons.payments_outlined,
              highlight: true,
            ),
            StatCard(
              label: 'Vendas',
              value: Formatters.integer(i.salesCount),
              icon: Icons.receipt_long_outlined,
            ),
            StatCard(
              label: 'Itens vendidos',
              value: Formatters.integer(i.totalQuantity),
              icon: Icons.shopping_bag_outlined,
            ),
            StatCard(
              label: 'Período',
              value: period,
              icon: Icons.date_range_outlined,
            ),
            if (detail.profit case final p when p.isAvailable)
              StatCard(
                label: 'Lucro',
                value: Formatters.currency(p.profit),
                icon: Icons.savings_outlined,
                caption: p.salesWithCost == i.salesCount
                    ? p.margin == null
                          ? null
                          : 'margem de ${Formatters.percent(p.margin!)}'
                    : 'de ${Formatters.integer(p.salesWithCost)} vendas com custo',
              ),
          ],
        ),
        const SizedBox(height: 16),
        MetricSelector(metric: metric, onChanged: onMetricChanged),
        const SizedBox(height: 16),
        SectionCard(
          title: '${metric.label} por canal',
          subtitle: 'Loja física (Presencial) x loja virtual (Online)',
          child: ShareBarChart(
            segments: [
              for (final item in detail.byChannel)
                ShareSegment(
                  label: item.name,
                  value: metric.valueOf(item),
                  valueText: metric.formatOf(item),
                  color:
                      ChartPalette.categorical[_channelColors[item.key] ?? 0],
                  details: metric.others(item),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '${metric.label} por plataforma',
          subtitle: 'Onde a loja mais vende: loja física, cada marketplace e a loja virtual própria',
          child: HorizontalBarChart(
            data: _ranked(SalesAnalysis.platforms(detail)),
            axisLabel: metric.formatAxis,
          ),
        ),
      ],
    );
  }

  List<BarDatum> _ranked(List<BreakdownItem> items) {
    final total = items.fold<double>(0, (sum, i) => sum + metric.valueOf(i));
    final sorted = [...items]
      ..sort((a, b) => metric.valueOf(b).compareTo(metric.valueOf(a)));
    return [
      for (final item in sorted)
        BarDatum(
          label: item.name,
          value: metric.valueOf(item),
          valueText: metric.formatOf(item),
          caption: total == 0
              ? null
              : Formatters.percent(metric.valueOf(item) / total),
          tooltip: '${item.name}\n${SalesMetric.all(item)}',
        ),
    ];
  }
}
