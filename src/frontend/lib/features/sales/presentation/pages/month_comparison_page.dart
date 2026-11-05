import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/charts/chart_palette.dart';
import '../../../../shared/widgets/charts/comparison_line_chart.dart';
import '../../domain/entities/month_comparison.dart';
import '../../domain/services/month_comparison_analysis.dart';
import '../controllers/month_comparison_providers.dart';
import '../sales_metric.dart';
import '../widgets/comparison_table.dart';
import '../widgets/metric_selector.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';

/// Compares two months over every batch: any month with any other (January with March)
/// or the same month across years (January 2025 with January 2026).
class MonthComparisonPage extends ConsumerStatefulWidget {
  const MonthComparisonPage({super.key});

  @override
  ConsumerState<MonthComparisonPage> createState() =>
      _MonthComparisonPageState();
}

class _MonthComparisonPageState extends ConsumerState<MonthComparisonPage> {
  /// Null until the user picks: the default pair is used.
  MonthPair? _pair;
  SalesMetric _metric = SalesMetric.revenue;

  /// Colors follow the side: base = slot 2 (orange), compared month = slot 1 (blue).
  static final _baseColor = ChartPalette.categorical[1];
  static final _targetColor = ChartPalette.categorical[0];

  MonthPair? _current(List<SalesMonth> months) {
    bool has(String month) => months.any((m) => m.month == month);
    final pair = _pair;
    if (pair != null && has(pair.base) && has(pair.target)) return pair;
    return MonthComparisonAnalysis.defaultPair(months);
  }

  void _select(MonthPair pair) => setState(() => _pair = pair);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = ref.watch(salesMonthsProvider);

    final child = switch (months) {
      AsyncValue(:final value?) => _content(value),
      AsyncError(:final error) => _ErrorMessage(
        error: error,
        onRetry: () => ref.invalidate(salesMonthsProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    // Pull to refresh: sales may have arrived from another device.
    return RefreshIndicator(
      onRefresh: () => ref.refresh(salesMonthsProvider.future),
      child: ColoredBox(color: theme.colorScheme.surface, child: child),
    );
  }

  Widget _content(List<SalesMonth> months) {
    final theme = Theme.of(context);
    final pair = _current(months);

    final children = <Widget>[
      if (pair == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(
                Icons.compare_arrows,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Para comparar, é preciso ter vendas em pelo menos dois meses.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                months.isEmpty
                    ? 'Ainda não há vendas. Importe uma planilha ou venda pelo caixa.'
                    : 'Há vendas só em ${months.first.label}.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        )
      else ...[
        _MonthPicker(months: months, pair: pair, onChanged: _select),
        const SizedBox(height: 16),
        ..._comparison(pair),
      ],
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: children,
        ),
      ),
    );
  }

  List<Widget> _comparison(MonthPair pair) {
    final comparison = ref.watch(monthComparisonProvider(pair));
    return switch (comparison) {
      AsyncValue(:final value?) => _ComparisonView(
        comparison: value,
        metric: _metric,
        onMetricChanged: (m) => setState(() => _metric = m),
        baseColor: _baseColor,
        targetColor: _targetColor,
      ).children(context),
      AsyncError(:final error) => [
        _ErrorMessage(
          error: error,
          onRetry: () => ref.invalidate(monthComparisonProvider(pair)),
        ),
      ],
      _ => [
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };
  }
}

/// The two month fields, a swap button and shortcuts for the usual comparisons.
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.months,
    required this.pair,
    required this.onChanged,
  });

  final List<SalesMonth> months;
  final MonthPair pair;
  final ValueChanged<MonthPair> onChanged;

  static const _rowBreakpoint = 600.0;

  bool _has(String month) => months.any((m) => m.month == month);

  Widget _field(
    String label,
    String value,
    String other,
    ValueChanged<String> onSelected,
  ) => DropdownButtonFormField<String>(
    // A new key resets the field when the value changes in code (swap, shortcuts).
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final m in months)
        DropdownMenuItem(
          value: m.month,
          // The other side's month can't be picked: a month compared with itself.
          enabled: m.month != other,
          child: Text(
            '${m.label} · ${Formatters.currency(m.revenue)}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (v) => v == null ? null : onSelected(v),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previous = MonthComparisonAnalysis.previousMonth(pair.target);
    final lastYear = MonthComparisonAnalysis.sameMonthLastYear(pair.target);

    final baseField = _field(
      'Mês base',
      pair.base,
      pair.target,
      (v) => onChanged((base: v, target: pair.target)),
    );
    final targetField = _field(
      'Comparar com',
      pair.target,
      pair.base,
      (v) => onChanged((base: pair.base, target: v)),
    );
    final swap = IconButton(
      tooltip: 'Inverter meses',
      icon: const Icon(Icons.swap_horiz),
      onPressed: () => onChanged((base: pair.target, target: pair.base)),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= _rowBreakpoint
                  ? Row(
                      children: [
                        Expanded(child: baseField),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: swap,
                        ),
                        Expanded(child: targetField),
                      ],
                    )
                  : Column(
                      children: [
                        baseField,
                        Align(alignment: Alignment.center, child: swap),
                        targetField,
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              'Comparar ${_labelOf(pair.target)} com:',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Shortcut(
                  label: 'Mês anterior',
                  month: previous,
                  available: _has(previous),
                  selected: pair.base == previous,
                  onSelected: () =>
                      onChanged((base: previous, target: pair.target)),
                ),
                _Shortcut(
                  label: 'Mesmo mês do ano anterior',
                  month: lastYear,
                  available: _has(lastYear),
                  selected: pair.base == lastYear,
                  onSelected: () =>
                      onChanged((base: lastYear, target: pair.target)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _labelOf(String month) =>
      months.firstWhere((m) => m.month == month).label;
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.label,
    required this.month,
    required this.available,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String month;
  final bool available;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final monthLabel = Formatters.monthYear(
      DateTime(int.parse(month.substring(0, 4)), int.parse(month.substring(5))),
    );
    return Tooltip(
      message: available ? monthLabel : 'Sem vendas em $monthLabel',
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: available ? (_) => onSelected() : null,
      ),
    );
  }
}

/// The comparison itself: totals, the month's running total and the groups.
class _ComparisonView {
  const _ComparisonView({
    required this.comparison,
    required this.metric,
    required this.onMetricChanged,
    required this.baseColor,
    required this.targetColor,
  });

  final MonthComparison comparison;
  final SalesMetric metric;
  final ValueChanged<SalesMetric> onMetricChanged;
  final Color baseColor;
  final Color targetColor;

  MonthSummary get _base => comparison.base;
  MonthSummary get _target => comparison.target;

  List<Widget> children(BuildContext context) {
    final theme = Theme.of(context);
    final inProgress = [_base, _target].where((m) => m.isInProgress).toList();
    final movers = MonthComparisonAnalysis.movers(
      comparison.products,
      metric.valueOf,
    );
    final newProducts = comparison.products
        .where((p) => p.base.sales == 0)
        .length;
    final goneProducts = comparison.products
        .where((p) => p.target.sales == 0)
        .length;
    final hasProfit = _base.profit.isAvailable || _target.profit.isAvailable;

    return [
      Text(
        '${_target.label} comparado a ${_base.label}',
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Text(
        'Todas as vendas dos dois meses, de todos os lotes (planilhas, lançamentos e caixa).',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      for (final month in inProgress) ...[
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.secondaryContainer,
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              '${month.label} ainda está em andamento '
              '(${month.elapsedDays} de ${month.days} dias).',
            ),
            subtitle: const Text(
              'Os totais vão mudar até o fim do mês; compare com cautela.',
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      StatGrid(
        stats: [
          _stat(
            'Faturamento',
            _base.revenue,
            _target.revenue,
            Formatters.currency,
            highlight: true,
            icon: Icons.payments_outlined,
          ),
          _stat(
            'Vendas',
            _base.sales.toDouble(),
            _target.sales.toDouble(),
            Formatters.integer,
            icon: Icons.receipt_long_outlined,
          ),
          _stat(
            'Itens vendidos',
            _base.quantity.toDouble(),
            _target.quantity.toDouble(),
            Formatters.integer,
            icon: Icons.shopping_bag_outlined,
          ),
          _stat(
            'Ticket médio',
            _base.averageTicket,
            _target.averageTicket,
            Formatters.currency,
            icon: Icons.sell_outlined,
          ),
          if (hasProfit)
            _stat(
              'Lucro (vendas com custo)',
              _base.profit.profit,
              _target.profit.profit,
              Formatters.currency,
              missingBase: _base.profit.isAvailable
                  ? null
                  : 'sem vendas com custo em ${_base.label}',
              icon: Icons.savings_outlined,
            ),
        ],
      ),
      const SizedBox(height: 16),
      MetricSelector(metric: metric, onChanged: onMetricChanged),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Acumulado no mês: ${metric.label.toLowerCase()}',
        subtitle: 'Soma dia a dia desde o dia 1: a linha mais alta tinha vendido mais até aquele dia',
        child: _cumulativeChart(),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: '${metric.label} por canal',
        subtitle: 'Loja física (Presencial) x loja virtual (Online)',
        child: _table(comparison.byChannel),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: '${metric.label} por plataforma',
        subtitle: 'Loja física, cada marketplace e a loja virtual própria',
        child: _table(
          [...MonthComparisonAnalysis.platforms(comparison)]..sort(
            (a, b) =>
                metric.valueOf(b.target).compareTo(metric.valueOf(a.target)),
          ),
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Produtos que mais cresceram',
        subtitle:
            'Maior aumento de ${metric.label.toLowerCase()} entre os meses',
        child: movers.risers.isEmpty
            ? Text('Nenhum produto cresceu.', style: theme.textTheme.bodyMedium)
            : _table(movers.risers, products: true),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Produtos que mais caíram',
        subtitle: 'Maior queda de ${metric.label.toLowerCase()} entre os meses',
        child: movers.fallers.isEmpty
            ? Text('Nenhum produto caiu.', style: theme.textTheme.bodyMedium)
            : _table(movers.fallers, products: true),
      ),
      const SizedBox(height: 16),
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          title: Text(
            'Todos os produtos (${Formatters.integer(comparison.products.length)})',
          ),
          subtitle: Text(
            '$newProducts vendido(s) só em ${_target.label} · '
            '$goneProducts sem vendas em ${_target.label}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [_table(comparison.products, products: true)],
        ),
      ),
    ];
  }

  StatCard _stat(
    String label,
    double base,
    double target,
    String Function(num value) format, {
    bool highlight = false,
    String? missingBase,
    IconData? icon,
  }) => StatCard(
    label: label,
    icon: icon,
    value: format(target),
    highlight: highlight,
    caption: base == 0 && target == 0
        ? 'sem valor nos dois meses'
        : base == 0 && missingBase != null
        ? missingBase
        : '${growthLabel(base, target)} sobre ${_base.label} (${format(base)})',
  );

  Widget _table(List<ComparisonItem> items, {bool products = false}) =>
      ComparisonTable(
        baseLabel: _base.label,
        targetLabel: _target.label,
        rows: [
          for (final item in items)
            ComparisonRow(
              label: item.name,
              caption: products ? item.sku : null,
              base: metric.valueOf(item.base),
              target: metric.valueOf(item.target),
              baseText: metric.formatOf(item.base),
              targetText: metric.formatOf(item.target),
            ),
        ],
      );

  Widget _cumulativeChart() {
    final days = comparison.byDay;
    final base = MonthComparisonAnalysis.cumulative(
      days,
      (d) => d.base,
      metric.valueOf,
      elapsedDays: _base.elapsedDays,
    );
    final target = MonthComparisonAnalysis.cumulative(
      days,
      (d) => d.target,
      metric.valueOf,
      elapsedDays: _target.elapsedDays,
    );

    String side(MonthSummary month, PeriodTotals? day, double? total) =>
        day == null || total == null
        ? '${month.label}: -'
        : '${month.label}: ${metric.formatOf(day)} no dia · '
              '${metric.format(total)} acumulado';

    return ComparisonLineChart(
      axisLabel: metric.formatAxis,
      xLabels: [for (final d in days) '${d.day}'],
      tooltips: [
        for (final (i, d) in days.indexed)
          'Dia ${d.day}\n'
              '${side(_target, d.target, target[i])}\n'
              '${side(_base, d.base, base[i])}',
      ],
      series: [
        LineSeries(label: _base.label, color: baseColor, values: base),
        LineSeries(label: _target.label, color: targetColor, values: target),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(switch (error) {
          // Field errors (base/target) are shown too: there are no fields to put them under.
          final Failure f when f.errors.isNotEmpty =>
            f.errors.map((e) => e.message).join('\n'),
          final Failure f => f.message,
          _ => 'Não foi possível carregar a comparação.',
        }, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}
