import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import 'chart_palette.dart';

class ShareSegment {
  const ShareSegment({
    required this.label,
    required this.value,
    required this.valueText,
    required this.color,
    this.details,
  });

  final String label;
  final double value;

  /// Formatted value (e.g. "R$ 11.950,40").
  final String valueText;
  final Color color;

  /// Extra line in the legend and tooltip (e.g. "39 vendas · 101 itens").
  final String? details;
}

/// Part-to-whole as one horizontal stacked bar, with direct labels above each
/// segment and a legend (swatch + name + value + share) below.
class ShareBarChart extends StatelessWidget {
  const ShareBarChart({super.key, required this.segments});

  final List<ShareSegment> segments;

  static double _textWidth(
    String text,
    TextStyle? style,
    BuildContext context,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    final visible = segments.where((s) => s.value > 0).toList();

    if (total == 0) {
      return Text('Sem dados.', style: theme.textTheme.bodyMedium);
    }

    double share(ShareSegment s) => s.value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Direct labels, aligned to the segment they name. Only what fits is drawn
        // (name + %, then just %); the legend below always has everything.
        LayoutBuilder(
          builder: (context, constraints) {
            final style = theme.textTheme.labelMedium;
            String fitting(ShareSegment s) {
              final room = constraints.maxWidth * share(s) - 8;
              final percent = Formatters.percent(share(s));
              for (final text in ['${s.label} $percent', percent]) {
                if (_textWidth(text, style, context) <= room) return text;
              }
              return '';
            }

            return Row(
              children: [
                for (final s in visible)
                  Expanded(
                    flex: (share(s) * 1000).round().clamp(1, 1000),
                    child: Text(fitting(s), maxLines: 1, style: style),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 24,
          child: Row(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(width: ChartPalette.segmentGap),
                Expanded(
                  flex: (share(visible[i]) * 1000).round().clamp(1, 1000),
                  child: Tooltip(
                    message: _tooltip(visible[i], share(visible[i])),
                    child: Container(
                      decoration: BoxDecoration(
                        color: visible[i].color,
                        borderRadius: BorderRadius.horizontal(
                          left: i == 0 ? ChartPalette.markRadius : Radius.zero,
                          right: i == visible.length - 1
                              ? ChartPalette.markRadius
                              : Radius.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final s in segments) _LegendRow(segment: s, share: share(s)),
      ],
    );
  }

  static String _tooltip(ShareSegment s, double share) => [
    '${s.label}: ${s.valueText} (${Formatters.percent(share)})',
    if (s.details != null) s.details!,
  ].join('\n');
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.segment, required this.share});

  final ShareSegment segment;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: segment.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(segment.label, style: theme.textTheme.titleSmall),
                if (segment.details != null)
                  Text(segment.details!, style: muted),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(segment.valueText, style: theme.textTheme.titleSmall),
              Text(Formatters.percent(share), style: muted),
            ],
          ),
        ],
      ),
    );
  }
}
