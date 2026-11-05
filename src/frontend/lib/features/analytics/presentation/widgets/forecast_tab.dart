import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/charts/time_series_chart.dart';
import '../../../sales/presentation/widgets/section_card.dart';
import '../../../sales/presentation/widgets/stat_card.dart';
import '../../domain/entities/sales_forecast.dart';
import '../controllers/analytics_providers.dart';
import 'analysis_parts.dart';

/// What the forecast chart and list show.
enum ForecastMetric {
  revenue('Faturamento'),
  quantity('Itens');

  const ForecastMetric(this.label);

  final String label;
}

/// Sales of the coming months, per product, with what to buy (Análises → Próximos meses).
class ForecastTab extends ConsumerStatefulWidget {
  const ForecastTab({super.key});

  /// The horizons offered: the next month, a quarter, a semester.
  static const horizons = [1, 3, 6];

  @override
  ConsumerState<ForecastTab> createState() => _ForecastTabState();
}

class _ForecastTabState extends ConsumerState<ForecastTab>
    with AutomaticKeepAliveClientMixin {
  int _months = 3;
  ForecastMetric _metric = ForecastMetric.revenue;
  bool _onlyToBuy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final forecast = ref.watch(salesForecastProvider(_months));

    return AnalysisList(
      onRefresh: () => ref.refresh(salesForecastProvider(_months).future),
      children: [
        _controls(context),
        const SizedBox(height: 16),
        ...switch (forecast) {
          AsyncValue(:final value?) => _content(context, value),
          AsyncError(:final error) => [
            AnalysisError(
              error: error,
              icon: Icons.trending_up,
              title: 'Ainda não dá para prever',
              onRetry: () => ref.invalidate(salesForecastProvider(_months)),
            ),
          ],
          _ => const [
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        },
      ],
    );
  }

  Widget _controls(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final months in ForecastTab.horizons)
        ChoiceChip(
          key: Key('forecastMonths$months'),
          label: Text(months == 1 ? 'Próximo mês' : 'Próximos $months meses'),
          selected: _months == months,
          onSelected: (_) => setState(() => _months = months),
        ),
    ],
  );

  List<Widget> _content(BuildContext context, SalesForecast forecast) {
    final theme = Theme.of(context);
    final period = forecast.months.length == 1
        ? forecast.months.first.label
        : '${forecast.months.first.label} a ${forecast.months.last.label}';
    final toBuy = forecast.toBuy;
    final validation = forecast.validation;
    final products = _onlyToBuy ? toBuy : forecast.products;

    return [
      Text('Previsão para $period', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        'Aprendida com as vendas de todos os lotes. É uma estimativa: '
        'use junto com o que você sabe da loja (promoções, datas especiais).',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      StatGrid(
        stats: [
          StatCard(
            label: 'Faturamento previsto',
            icon: Icons.payments_outlined,
            value: Formatters.currency(forecast.revenue),
            caption: period,
            highlight: true,
          ),
          StatCard(
            label: 'Itens previstos',
            icon: Icons.shopping_bag_outlined,
            value: Formatters.integer(forecast.quantity),
            caption: '${Formatters.integer(forecast.products.length)} produtos',
          ),
          StatCard(
            label: 'Produtos para comprar',
            icon: Icons.add_shopping_cart_outlined,
            value: Formatters.integer(toBuy.length),
            caption: toBuy.isEmpty
                ? 'o estoque cobre a previsão'
                : '${Formatters.integer(toBuy.fold(0, (s, p) => s + p.suggestedPurchase!))} unidades no total',
          ),
          if (validation != null)
            StatCard(
              label: 'Erro no teste',
              icon: Icons.fact_check_outlined,
              value: Formatters.percent(validation.modelError),
              caption:
                  'em ${validation.label}; média simples: '
                  '${Formatters.percent(validation.baselineError)}',
            ),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        children: [
          for (final metric in ForecastMetric.values)
            ChoiceChip(
              label: Text(metric.label),
              selected: _metric == metric,
              onSelected: (_) => setState(() => _metric = metric),
            ),
        ],
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Vendido x previsto: ${_metric.label.toLowerCase()}',
        subtitle: 'Meses completos que o modelo usou e os meses previstos',
        child: _chart(forecast),
      ),
      const SizedBox(height: 16),
      AnalysisMonthsCard(
        used: forecast.history,
        ignored: forecast.ignoredMonths,
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Previsão por produto',
        subtitle:
            'Do maior para o menor faturamento previsto. Comprar = previsto + '
            'estoque mínimo − estoque atual (só produtos do cadastro).',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterChip(
              key: const Key('forecastOnlyToBuy'),
              label: Text('Só os que precisam de compra (${toBuy.length})'),
              selected: _onlyToBuy,
              onSelected: (on) => setState(() => _onlyToBuy = on),
            ),
            const SizedBox(height: 8),
            if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhum produto precisa de compra para o período.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final (i, product) in products.indexed) ...[
              if (i > 0) const Divider(height: 1),
              _ProductRow(product: product, months: forecast.months),
            ],
          ],
        ),
      ),
      if (validation != null) ...[
        const SizedBox(height: 16),
        _HowItWorks(validation: validation),
      ],
    ];
  }

  Widget _chart(SalesForecast forecast) {
    double valueOf(MonthTotal m) => switch (_metric) {
      ForecastMetric.revenue => m.revenue,
      ForecastMetric.quantity => m.quantity.toDouble(),
    };
    String format(num v) => switch (_metric) {
      ForecastMetric.revenue => Formatters.currency(v),
      ForecastMetric.quantity => '${Formatters.integer(v)} itens',
    };

    TimePoint point(MonthTotal m, String kind) => TimePoint(
      label: Formatters.shortMonthYear(m.date),
      value: valueOf(m),
      tooltip: '${m.label} ($kind)\n${format(valueOf(m))}',
    );

    return TimeSeriesChart(
      points: [
        for (final m in forecast.history) point(m, 'vendido'),
        for (final m in forecast.months) point(m, 'previsto'),
      ],
      axisLabel: switch (_metric) {
        ForecastMetric.revenue => Formatters.compactCurrency,
        ForecastMetric.quantity => Formatters.compactInteger,
      },
      barsLabel: 'Vendido',
      highlightFrom: forecast.history.length,
      highlightLabel: 'Previsto',
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.months});

  final ProductForecast product;
  final List<MonthTotal> months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final perMonth = [
      for (final (i, m) in months.indexed)
        '${Formatters.shortMonthYear(m.date)}: ${product.quantities[i]}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: theme.textTheme.titleSmall),
                    if (product.sku != null)
                      Text('SKU ${product.sku}', style: muted),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${Formatters.integer(product.quantity)} un.',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(Formatters.currency(product.revenue), style: muted),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (months.length > 1) Text(perMonth, style: muted),
          const SizedBox(height: 6),
          _StockLine(product: product),
        ],
      ),
    );
  }
}

/// Stock against the forecast: buy N (tinted), covered, or not in the catalog.
class _StockLine extends StatelessWidget {
  const _StockLine({required this.product});

  final ProductForecast product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stock = product.stock;
    if (stock == null) {
      return Text(
        'Fora do cadastro: sem estoque para comparar',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    final buy = product.suggestedPurchase ?? 0;
    final stockText =
        'Estoque ${Formatters.integer(stock)} · mínimo ${Formatters.integer(product.minimumStock ?? 0)}';
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: buy > 0 ? colors.tertiaryContainer : colors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                buy > 0 ? Icons.add_shopping_cart : Icons.check,
                size: 14,
                color: buy > 0
                    ? colors.onTertiaryContainer
                    : colors.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                buy > 0
                    ? 'Comprar ${Formatters.integer(buy)}'
                    : 'Estoque cobre',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: buy > 0
                      ? colors.onTertiaryContainer
                      : colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        Text(
          stockText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The method in plain words, with the test result (useful for the project report too).
class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.validation});

  final ForecastValidation validation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final verdict = validation.beatsBaseline
        ? 'O modelo errou menos que a média simples.'
        : 'Neste teste, a média simples errou menos que o modelo: '
              'com mais meses de histórico ele tende a melhorar.';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.psychology_outlined),
        title: const Text('Como a previsão é feita'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aprendizado de máquina com ML.NET: uma regressão de Poisson (própria '
            'para contagens, como unidades vendidas) aprende quanto cada produto '
            'vende por mês, a tendência de alta ou queda e o efeito da época do '
            'ano. Um único modelo para todos os produtos: a tendência e a época '
            'são aprendidas com todos juntos.',
            style: muted,
          ),
          const SizedBox(height: 12),
          Text('Teste do modelo', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Treinado sem ${validation.label}, o modelo previu esse mês: '
            '${Formatters.integer(validation.predictedQuantity)} itens, e foram '
            'vendidos ${Formatters.integer(validation.actualQuantity)} '
            '(erro de ${Formatters.percent(validation.modelError)}). A média dos '
            'meses anteriores teria previsto '
            '${Formatters.integer(validation.baselineQuantity)} '
            '(erro de ${Formatters.percent(validation.baselineError)}). $verdict',
            style: muted,
          ),
        ],
      ),
    );
  }
}
