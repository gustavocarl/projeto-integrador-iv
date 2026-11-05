import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/charts/horizontal_bar_chart.dart';
import '../../domain/entities/sales_import.dart';
import '../sales_metric.dart';
import 'metric_selector.dart';
import 'section_card.dart';

extension StockActionView on StockAction {
  String get label => switch (this) {
    StockAction.prioritize => 'Priorizar',
    StockAction.keep => 'Manter',
    StockAction.reviewRemoval => 'Avaliar saída',
  };

  String get reason => switch (this) {
    StockAction.prioritize =>
      'Curva A: sustenta o faturamento, não deixe faltar',
    StockAction.keep => 'Vende de forma consistente',
    StockAction.reviewRemoval =>
      'Curva C e menos unidades vendidas que a maioria',
  };

  IconData get icon => switch (this) {
    StockAction.prioritize => Icons.star_outline,
    StockAction.keep => Icons.check_circle_outline,
    StockAction.reviewRemoval => Icons.warning_amber_outlined,
  };
}

/// Best and worst sellers, ABC curve and the stock suggestion per product.
class ProductsTab extends StatelessWidget {
  const ProductsTab({
    super.key,
    required this.detail,
    required this.metric,
    required this.onMetricChanged,
  });

  final SalesImportDetail detail;
  final SalesMetric metric;
  final ValueChanged<SalesMetric> onMetricChanged;

  /// Top and bottom lists only make sense when they don't overlap.
  static const _rankSize = 5;

  @override
  Widget build(BuildContext context) {
    final products = detail.products;
    final ranked = [...products]
      ..sort((a, b) => metric.valueOf(b).compareTo(metric.valueOf(a)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MetricSelector(metric: metric, onChanged: onMetricChanged),
        const SizedBox(height: 16),
        if (ranked.length <= _rankSize * 2)
          SectionCard(
            title: 'Produtos por ${metric.label.toLowerCase()}',
            subtitle: 'Todos os ${ranked.length} produtos do lote',
            child: _chart(ranked),
          )
        else ...[
          SectionCard(
            title: 'Mais vendidos',
            subtitle:
                'Os $_rankSize primeiros em ${metric.label.toLowerCase()}',
            child: _chart(ranked.take(_rankSize).toList()),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Menos vendidos',
            subtitle:
                'Os $_rankSize últimos em ${metric.label.toLowerCase()}, do menor para o maior',
            child: _chart(ranked.reversed.take(_rankSize).toList()),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: 'Curva ABC',
          subtitle: 'Pelo faturamento: A = produtos que somam 80%, B = os próximos 15%, C = os últimos 5%',
          child: _AbcSummary(products: products),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Sugestão de estoque',
          subtitle: 'Curva C só é sugerida para sair se também vendeu menos unidades que a maioria (produto barato que vende muito fica)',
          child: _StockList(products: products),
        ),
      ],
    );
  }

  Widget _chart(List<ProductItem> items) => HorizontalBarChart(
    data: [
      for (final p in items)
        BarDatum(
          label: p.name,
          value: metric.valueOf(p),
          valueText: metric.formatOf(p),
          caption: 'Curva ${p.abcClass.label}',
          tooltip:
              '${p.name}\n${SalesMetric.all(p)}\n'
              'Curva ${p.abcClass.label} · ${p.recommendation.label}',
        ),
    ],
    axisLabel: metric.formatAxis,
  );
}

class _AbcSummary extends StatelessWidget {
  const _AbcSummary({required this.products});

  final List<ProductItem> products;

  static const _meaning = {
    AbcClass.a: 'Principais produtos: priorizar no estoque',
    AbcClass.b: 'Importância intermediária: manter e acompanhar',
    AbcClass.c: 'Pouco faturamento: veja a sugestão de cada um abaixo',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final abc in AbcClass.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _ClassBadge(abc),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_summary(abc), style: theme.textTheme.titleSmall),
                      Text(
                        _meaning[abc]!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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

  String _summary(AbcClass abc) {
    final items = products.where((p) => p.abcClass == abc).toList();
    final share = items.fold<double>(0, (sum, p) => sum + p.revenueShare);
    final count = items.length == 1 ? '1 produto' : '${items.length} produtos';
    return '$count · ${Formatters.percent(share)} do faturamento';
  }
}

class _ClassBadge extends StatelessWidget {
  const _ClassBadge(this.abcClass);

  final AbcClass abcClass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(abcClass.label, style: theme.textTheme.titleSmall),
    );
  }
}

class _StockList extends StatelessWidget {
  const _StockList({required this.products});

  final List<ProductItem> products;

  /// Removal candidates first: they are the decision to make.
  static const _order = [
    StockAction.reviewRemoval,
    StockAction.prioritize,
    StockAction.keep,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final action in _order)
          if (products.where((p) => p.recommendation == action).toList()
              case final items when items.isNotEmpty)
            ExpansionTile(
              key: PageStorageKey(action),
              initiallyExpanded: action == StockAction.reviewRemoval,
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(action.icon, color: _color(theme, action)),
              title: Text('${action.label} (${items.length})'),
              subtitle: Text(action.reason),
              children: [
                for (final p in items)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 40),
                    title: Text(p.name),
                    subtitle: Text(
                      [
                        'Curva ${p.abcClass.label}',
                        if (p.sku != null) p.sku!,
                        '${Formatters.integer(p.quantity)} itens',
                        Formatters.currency(p.revenue),
                        'última venda ${Formatters.dayMonth(p.lastSaleDate)}',
                      ].join(' · '),
                    ),
                  ),
              ],
            ),
      ],
    );
  }

  static Color _color(ThemeData theme, StockAction action) => switch (action) {
    StockAction.prioritize => theme.colorScheme.primary,
    StockAction.keep => theme.colorScheme.onSurfaceVariant,
    StockAction.reviewRemoval => theme.colorScheme.error,
  };
}
