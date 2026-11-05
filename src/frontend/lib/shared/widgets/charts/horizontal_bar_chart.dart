import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_palette.dart';

class BarDatum {
  const BarDatum({
    required this.label,
    required this.value,
    required this.valueText,
    this.caption,
    this.tooltip,
  });

  final String label;
  final double value;

  /// Formatted value shown with the bar (e.g. "R$ 6.132,80").
  final String valueText;

  /// Small text next to the value (e.g. "23,5%").
  final String? caption;
  final String? tooltip;
}

/// Horizontal bars for comparing magnitudes across named categories (long names fit).
/// One hue: the length carries the value. Recessive vertical grid with a value axis.
///
/// Wide: name | bar | value on one line. Narrow (< [compactBreakpoint]): name and value
/// above the bar, so the bar gets the full width.
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.data,
    required this.axisLabel,
    this.color = ChartPalette.magnitude,
  });

  final List<BarDatum> data;

  /// Formats axis ticks (compact, e.g. "R$ 5 mil").
  final String Function(double value) axisLabel;
  final Color color;

  static const compactBreakpoint = 520.0;

  static const _rowHeight = 44.0;
  static const _compactRowHeight = 52.0;
  static const _barThickness = 16.0;
  static const _valueWidth = 104.0;
  static const _gap = 12.0;

  /// Minimum horizontal space per axis label, so labels never collide.
  static const _minTickSpacing = 72.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return Text('Sem dados.', style: theme.textTheme.bodyMedium);
    }

    final maxValue = data.map((d) => d.value).reduce(math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final labelWidth = compact
            ? 0.0
            : math.min(constraints.maxWidth * 0.3, 140.0);
        final trackLeft = compact ? 0.0 : labelWidth + _gap;
        final trackWidth = compact
            ? constraints.maxWidth
            : math.max(
                constraints.maxWidth - labelWidth - _valueWidth - 2 * _gap,
                40.0,
              );
        final rowHeight = compact ? _compactRowHeight : _rowHeight;

        final ticks = niceTicks(
          maxValue,
          maxIntervals: (trackWidth / _minTickSpacing).floor().clamp(1, 4),
        );
        final axisMax = ticks.last;
        double ratio(BarDatum d) => axisMax == 0 ? 0 : d.value / axisMax;

        return Column(
          children: [
            SizedBox(
              height: rowHeight * data.length,
              child: Stack(
                children: [
                  // Gridlines sit behind the bars, only across the track.
                  Positioned(
                    left: trackLeft,
                    width: trackWidth,
                    top: 0,
                    bottom: 0,
                    child: CustomPaint(
                      painter: _GridPainter(
                        ticks: ticks,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      for (final d in data)
                        compact
                            ? _CompactBarRow(
                                datum: d,
                                color: color,
                                trackWidth: trackWidth,
                                ratio: ratio(d),
                              )
                            : _BarRow(
                                datum: d,
                                color: color,
                                labelWidth: labelWidth,
                                trackWidth: trackWidth,
                                ratio: ratio(d),
                              ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: trackLeft),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Axis(
                  ticks: ticks,
                  trackWidth: trackWidth,
                  label: axisLabel,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 0 and up to [maxIntervals] more evenly spaced "round" ticks covering [max].
  static List<double> niceTicks(double max, {int maxIntervals = 4}) {
    if (max <= 0) return [0, 1];

    final rawStep = max / maxIntervals;
    final magnitude = math
        .pow(10, (math.log(rawStep) / math.ln10).floor())
        .toDouble();
    final step = const [
      1.0,
      2.0,
      2.5,
      5.0,
      10.0,
    ].map((m) => m * magnitude).firstWhere((s) => s * maxIntervals >= max);

    final count = (max / step).ceil();
    return [for (var i = 0; i <= count; i++) i * step];
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: HorizontalBarChart._barThickness,
    decoration: BoxDecoration(
      color: color,
      // Rounded data end; the flat side sits on the baseline.
      borderRadius: const BorderRadius.horizontal(
        right: ChartPalette.markRadius,
      ),
    ),
  );
}

double _barWidth(BarDatum d, double trackWidth, double ratio) =>
    d.value > 0 ? math.max(trackWidth * ratio, 2.0) : 0.0;

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.datum,
    required this.color,
    required this.labelWidth,
    required this.trackWidth,
    required this.ratio,
  });

  final BarDatum datum;
  final Color color;
  final double labelWidth;
  final double trackWidth;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The whole row is the hit target, larger than the bar itself.
    return Tooltip(
      message: datum.tooltip ?? '${datum.label}: ${datum.valueText}',
      child: SizedBox(
        height: HorizontalBarChart._rowHeight,
        child: Row(
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                datum.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: HorizontalBarChart._gap),
            SizedBox(
              width: trackWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Bar(
                  width: _barWidth(datum, trackWidth, ratio),
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: HorizontalBarChart._gap),
            SizedBox(
              width: HorizontalBarChart._valueWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    datum.valueText,
                    maxLines: 1,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (datum.caption != null)
                    Text(
                      datum.caption!,
                      maxLines: 1,
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
    );
  }
}

class _CompactBarRow extends StatelessWidget {
  const _CompactBarRow({
    required this.datum,
    required this.color,
    required this.trackWidth,
    required this.ratio,
  });

  final BarDatum datum;
  final Color color;
  final double trackWidth;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: datum.tooltip ?? '${datum.label}: ${datum.valueText}',
      child: SizedBox(
        height: HorizontalBarChart._compactRowHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    datum.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(datum.valueText, style: theme.textTheme.titleSmall),
                if (datum.caption != null)
                  Text(
                    '  ${datum.caption!}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _Bar(width: _barWidth(datum, trackWidth, ratio), color: color),
          ],
        ),
      ),
    );
  }
}

class _Axis extends StatelessWidget {
  const _Axis({
    required this.ticks,
    required this.trackWidth,
    required this.label,
  });

  final List<double> ticks;
  final double trackWidth;
  final String Function(double value) label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const spacing = HorizontalBarChart._minTickSpacing;
    final max = ticks.last;

    return SizedBox(
      width: trackWidth,
      height: 16,
      child: Stack(
        children: [
          for (final (i, tick) in ticks.indexed)
            // First and last labels align to the track edges so they stay inside it.
            Positioned(
              left: i == 0
                  ? 0
                  : i == ticks.length - 1
                  ? trackWidth - spacing
                  : (tick / max) * trackWidth - spacing / 2,
              width: spacing,
              child: Text(
                label(tick),
                maxLines: 1,
                textAlign: i == 0
                    ? TextAlign.left
                    : i == ticks.length - 1
                    ? TextAlign.right
                    : TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.ticks, required this.color});

  final List<double> ticks;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final max = ticks.last;
    for (final tick in ticks) {
      final x = max == 0 ? 0.0 : (tick / max) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.color != color || old.ticks != ticks;
}
