import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/charts/time_series_chart.dart';
import '../../domain/entities/sales_import.dart';
import '../../domain/services/sales_analysis.dart';
import '../sales_metric.dart';
import 'metric_selector.dart';
import 'section_card.dart';
import 'stat_card.dart';

/// How sales rose and fell during the period.
class TrendTab extends StatelessWidget {
  const TrendTab({
    super.key,
    required this.detail,
    required this.metric,
    required this.onMetricChanged,
  });

  final SalesImportDetail detail;
  final SalesMetric metric;
  final ValueChanged<SalesMetric> onMetricChanged;

  /// Below this many days a 7-day average says nothing.
  static const _minDaysForAverage = 3;

  @override
  Widget build(BuildContext context) {
    final days = detail.byDay;
    final values = [for (final d in days) metric.valueOf(d)];
    final average = days.length >= _minDaysForAverage
        ? SalesAnalysis.movingAverage(values)
        : null;
    final comparison = SalesAnalysis.compareHalves(values);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MetricSelector(metric: metric, onChanged: onMetricChanged),
        const SizedBox(height: 16),
        SectionCard(
          title: '${metric.label} por dia',
          subtitle: average == null ? 'Cada barra é um dia' : 'Barras: cada dia · linha: média móvel de 7 dias (suaviza a oscilação diária)',
          child: TimeSeriesChart(
            points: [
              for (final (i, d) in days.indexed)
                TimePoint(
                  label: Formatters.dayMonth(d.date),
                  value: values[i],
                  tooltip: [
                    Formatters.weekdayDate(d.date),
                    SalesMetric.all(d),
                    if (average != null)
                      'Média 7 dias: ${metric.formatAverage(average[i])}',
                  ].join('\n'),
                ),
            ],
            trend: average,
            axisLabel: metric.formatAxis,
            barsLabel: 'Por dia',
            trendLabel: 'Média móvel (7 dias)',
          ),
        ),
        if (comparison != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Aumento ou queda',
            subtitle:
                '${metric.label} médio por dia: 1ª metade x 2ª metade do período',
            child: _Comparison(
              days: days,
              values: values,
              comparison: comparison,
              metric: metric,
            ),
          ),
        ],
      ],
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.days,
    required this.values,
    required this.comparison,
    required this.metric,
  });

  final List<DailyItem> days;
  final List<double> values;
  final HalfComparison comparison;
  final SalesMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = comparison.change;
    final changeText = change == null
        ? ''
        : ' de ${Formatters.percent(change.abs())}';
    // Icon + words carry the meaning; color only reinforces it.
    final (icon, color, text) = switch (comparison.direction) {
      TrendDirection.up => (
        Icons.trending_up,
        theme.colorScheme.primary,
        'Alta$changeText na 2ª metade',
      ),
      TrendDirection.down => (
        Icons.trending_down,
        theme.colorScheme.error,
        'Queda$changeText na 2ª metade',
      ),
      TrendDirection.stable => (
        Icons.trending_flat,
        theme.colorScheme.onSurfaceVariant,
        'Estável (variação$changeText)',
      ),
    };

    final split = comparison.firstDays;
    var best = 0;
    var worst = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
      if (values[i] < values[worst]) worst = i;
    }

    String range(int from, int to) =>
        '${Formatters.dayMonth(days[from].date)} a ${Formatters.dayMonth(days[to].date)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: theme.textTheme.titleMedium)),
          ],
        ),
        const SizedBox(height: 16),
        StatGrid(
          stats: [
            StatCard(
              label: '1ª metade · média/dia',
              icon: Icons.first_page_rounded,
              value: metric.formatAverage(comparison.firstAverage),
              caption: range(0, split - 1),
            ),
            StatCard(
              label: '2ª metade · média/dia',
              icon: Icons.last_page_rounded,
              value: metric.formatAverage(comparison.secondAverage),
              caption: range(split, days.length - 1),
            ),
            StatCard(
              label: 'Melhor dia',
              icon: Icons.emoji_events_outlined,
              value: metric.format(values[best]),
              caption: Formatters.weekdayDate(days[best].date),
            ),
            StatCard(
              label: 'Pior dia',
              icon: Icons.trending_down_rounded,
              value: metric.format(values[worst]),
              caption: Formatters.weekdayDate(days[worst].date),
            ),
          ],
        ),
      ],
    );
  }
}
