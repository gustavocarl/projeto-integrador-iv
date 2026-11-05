import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/brand.dart';
import '../../domain/entities/sales_forecast.dart';

/// Layout shared by the analysis tabs: a centered column up to 960 px that can always be
/// pulled to refresh.
class AnalysisList extends StatelessWidget {
  const AnalysisList({
    super.key,
    required this.onRefresh,
    required this.children,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: children,
        ),
      ),
    ),
  );
}

/// Not enough history (404): the backend's explanation as an empty state, not an error.
/// Anything else: the message and a retry button.
class AnalysisError extends StatelessWidget {
  const AnalysisError({
    super.key,
    required this.error,
    required this.icon,
    required this.title,
    required this.onRetry,
  });

  final Object error;
  final IconData icon;

  /// Title of the empty state ("Ainda não dá para prever").
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error is Failure && error.statusCode == 404) {
      return EmptyState(
        icon: icon,
        title: title,
        message:
            '${error.generalMessages.join(' ')} Importe planilhas de meses '
            'anteriores para liberar a análise.',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(switch (error) {
            final Failure f when f.errors.isNotEmpty =>
              f.errors.map((e) => e.message).join('\n'),
            final Failure f => f.message,
            _ => 'Não foi possível carregar a análise.',
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
}

/// The months the analysis used and the ones it left out (with the reason).
class AnalysisMonthsCard extends StatelessWidget {
  const AnalysisMonthsCard({
    super.key,
    required this.used,
    required this.ignored,
  });

  final List<MonthTotal> used;
  final List<IgnoredMonth> ignored;

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
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text(
          '${used.length} ${used.length == 1 ? 'mês usado' : 'meses usados'}'
          '${ignored.isEmpty ? '' : ' · ${ignored.length} fora da análise'}',
        ),
        subtitle: Text(used.map((m) => m.label).join(', ')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contam só meses completos com vendas em pelo menos metade dos dias. '
            'Meses sem nenhuma venda não entram como zero: podem só não ter sido '
            'importados.',
            style: muted,
          ),
          for (final month in ignored) ...[
            const SizedBox(height: 8),
            Text(month.label, style: theme.textTheme.labelLarge),
            Text(month.reason, style: muted),
          ],
        ],
      ),
    );
  }
}
