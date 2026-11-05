import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/charts/scatter_chart.dart';
import '../../../sales/presentation/widgets/section_card.dart';
import '../../../sales/presentation/widgets/stat_card.dart';
import '../../domain/entities/product_groups.dart';
import '../controllers/analytics_providers.dart';
import 'analysis_parts.dart';

/// Products split into groups that sell alike (Análises → Grupos de produtos).
class ProductGroupsTab extends ConsumerStatefulWidget {
  const ProductGroupsTab({super.key});

  /// The numbers of groups the user can force (null = automatic).
  static const choices = <int?>[null, 2, 3, 4, 5, 6];

  @override
  ConsumerState<ProductGroupsTab> createState() => _ProductGroupsTabState();
}

class _ProductGroupsTabState extends ConsumerState<ProductGroupsTab>
    with AutomaticKeepAliveClientMixin {
  int? _groups;

  /// Group highlighted on the chart (its number).
  int _highlighted = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final result = ref.watch(productGroupsProvider(_groups));

    return AnalysisList(
      onRefresh: () => ref.refresh(productGroupsProvider(_groups).future),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final groups in ProductGroupsTab.choices)
              ChoiceChip(
                key: Key('productGroups${groups ?? 'Auto'}'),
                label: Text(groups == null ? 'Automático' : '$groups grupos'),
                selected: _groups == groups,
                onSelected: (_) => setState(() {
                  _groups = groups;
                  _highlighted = 1;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...switch (result) {
          AsyncValue(:final value?) => _content(context, value),
          AsyncError(:final error) => [
            AnalysisError(
              error: error,
              icon: Icons.bubble_chart_outlined,
              title: 'Ainda não dá para agrupar',
              onRetry: () => ref.invalidate(productGroupsProvider(_groups)),
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

  List<Widget> _content(BuildContext context, ProductGroups result) {
    final theme = Theme.of(context);
    final highlighted = result.clusters.firstWhere(
      (g) => g.number == _highlighted,
      orElse: () => result.clusters.first,
    );

    return [
      Text(
        '${Formatters.integer(result.productCount)} produtos em '
        '${result.groups} grupos',
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Text(
        'Produtos que vendem de forma parecida ficam juntos: quantidade por mês, '
        'preço e regularidade (em quantos meses venderam).',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      StatGrid(
        stats: [
          StatCard(
            label: 'Grupos',
            icon: Icons.bubble_chart_outlined,
            value: '${result.groups}',
            caption: result.automatic
                ? 'escolhido automaticamente'
                : 'escolhido por você',
            highlight: true,
          ),
          StatCard(
            label: 'Separação (silhueta)',
            icon: Icons.straighten,
            value: Formatters.amount(result.silhouette),
            caption: _silhouetteMeaning(result.silhouette),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Preço x vendas por mês',
        subtitle:
            'Cada ponto é um produto (escala logarítmica). Toque em um ponto para '
            'ver o nome; escolha o grupo em destaque abaixo.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final group in result.clusters)
                  ChoiceChip(
                    label: Text('${group.number} · ${group.name}'),
                    selected: group.number == highlighted.number,
                    onSelected: (_) =>
                        setState(() => _highlighted = group.number),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ScatterChart(
              points: [
                for (final group in result.clusters)
                  for (final p in group.products)
                    ScatterPoint(
                      x: p.averagePrice,
                      y: p.monthlyQuantity,
                      highlighted: group.number == highlighted.number,
                      tooltip:
                          '${p.name}\nGrupo ${group.number} · ${group.name}\n'
                          '${Formatters.decimal(p.monthlyQuantity)} un./mês · '
                          '${Formatters.currency(p.averagePrice)}',
                    ),
              ],
              xTitle: 'Preço médio',
              yTitle: 'Itens por mês',
              xTickLabel: _priceTick,
              yTickLabel: Formatters.compactInteger,
              highlightLabel: 'Grupo ${highlighted.number}',
              othersLabel: 'Outros grupos',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      for (final group in result.clusters) ...[
        _GroupCard(group: group),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 4),
      AnalysisMonthsCard(used: result.months, ignored: result.ignoredMonths),
      const SizedBox(height: 16),
      _HowItWorks(result: result),
    ];
  }
}

/// "R$ 10", "R$ 100", "R$ 1 mil": whole reais on the price axis (no "R$ 10,00").
String _priceTick(double value) => value < 1000
    ? 'R\$ ${Formatters.integer(value)}'
    : Formatters.compactCurrency(value);

String _silhouetteMeaning(double silhouette) => switch (silhouette) {
  >= 0.5 => 'grupos bem separados',
  >= 0.25 => 'grupos razoavelmente separados',
  _ => 'grupos parecidos entre si',
};

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final ProductGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final count = group.products.length;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text('${group.number}'),
        ),
        title: Text(group.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(group.description),
            const SizedBox(height: 4),
            Text(
              '$count ${count == 1 ? 'produto' : 'produtos'} · '
              '${Formatters.percent(group.revenueShare)} do faturamento · '
              '${Formatters.decimal(group.monthlyQuantity)} un./mês · '
              'preço médio ${Formatters.currency(group.averagePrice)}',
              style: muted,
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final (i, p) in group.products.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: theme.textTheme.bodyMedium),
                        Text(
                          [
                            if (p.sku != null) 'SKU ${p.sku}',
                            'vendeu em ${Formatters.percent(p.regularity)} dos meses',
                          ].join(' · '),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${Formatters.decimal(p.monthlyQuantity)} un./mês',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(Formatters.currency(p.averagePrice), style: muted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.result});

  final ProductGroups result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.psychology_outlined),
        title: const Text('Como os grupos são formados'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aprendizado de máquina com ML.NET: o k-means junta os produtos mais '
            'próximos em três medidas — itens por mês e preço (em escala '
            'logarítmica, para um cabo e um notebook serem comparáveis) e '
            'regularidade — todas na mesma escala. O nome de cada grupo compara '
            'o seu centro com o produto mediano.',
            style: muted,
          ),
          const SizedBox(height: 12),
          Text('Silhueta de cada tentativa', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'De −1 a 1: quanto maior, mais compactos e separados os grupos. '
            'No automático, fica o número de grupos com a maior silhueta.',
            style: muted,
          ),
          const SizedBox(height: 8),
          for (final c in result.candidates)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(width: 96, child: Text('${c.groups} grupos')),
                  Text(Formatters.amount(c.silhouette)),
                  if (c.groups == result.groups) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
