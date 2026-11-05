import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/services/month_comparison_analysis.dart';

/// Growth as text: "+12,3%", "novo" (no sales in the base month), "—" (none in either).
String growthLabel(double base, double target) {
  if (base == 0) return target == 0 ? '—' : 'novo';
  return Formatters.signedPercent(
    MonthComparisonAnalysis.growth(base, target)!,
  );
}

/// Up, down or flat arrow, so the direction never depends on reading the sign alone.
IconData growthIcon(double base, double target) => target > base
    ? Icons.arrow_upward
    : target < base
    ? Icons.arrow_downward
    : Icons.remove;

class ComparisonRow {
  const ComparisonRow({
    required this.label,
    this.caption,
    required this.base,
    required this.target,
    required this.baseText,
    required this.targetText,
  });

  final String label;

  /// Small text under the label (e.g. the SKU).
  final String? caption;
  final double base;
  final double target;
  final String baseText;
  final String targetText;
}

/// Groups in two months: name, base value, target value and growth. A table on wide
/// screens; on phones each row stacks the name over "de base para target".
class ComparisonTable extends StatelessWidget {
  const ComparisonTable({
    super.key,
    required this.rows,
    required this.baseLabel,
    required this.targetLabel,
  });

  final List<ComparisonRow> rows;
  final String baseLabel;
  final String targetLabel;

  static const _compactBreakpoint = 520.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return Text(
        'Sem vendas nos dois meses.',
        style: theme.textTheme.bodyMedium,
      );
    }
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;
        if (compact) {
          return Column(
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0) const Divider(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.label, style: theme.textTheme.bodyMedium),
                          if (row.caption != null)
                            Text(row.caption!, style: muted),
                          Text(
                            'de ${row.baseText} para ${row.targetText}',
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Growth(base: row.base, target: row.target),
                  ],
                ),
              ],
            ],
          );
        }

        Widget cell(String text, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(text, textAlign: TextAlign.right, style: style),
        );

        return Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
            3: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                cell(baseLabel, style: theme.textTheme.labelMedium),
                cell(targetLabel, style: theme.textTheme.labelMedium),
                cell('Variação', style: theme.textTheme.labelMedium),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.label, style: theme.textTheme.bodyMedium),
                        if (row.caption != null)
                          Text(row.caption!, style: muted),
                      ],
                    ),
                  ),
                  cell(row.baseText, style: theme.textTheme.bodyMedium),
                  cell(row.targetText, style: theme.textTheme.bodyMedium),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _Growth(base: row.base, target: row.target),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _Growth extends StatelessWidget {
  const _Growth({required this.base, required this.target});

  final double base;
  final double target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          growthIcon(base, target),
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 2),
        Text(growthLabel(base, target), style: theme.textTheme.labelLarge),
      ],
    );
  }
}
