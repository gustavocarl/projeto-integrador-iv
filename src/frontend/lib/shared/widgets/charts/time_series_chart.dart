import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_palette.dart';
import 'horizontal_bar_chart.dart';

class TimePoint {
  const TimePoint({
    required this.label,
    required this.value,
    required this.tooltip,
  });

  /// X-axis label (e.g. "01/09"); only some are drawn when space is short.
  final String label;
  final double value;
  final String tooltip;
}

/// Change over time: one recessive column per period and, optionally, a trend line
/// (e.g. a moving average) in the accent color, so the direction reads at a glance
/// while the daily ups and downs stay visible.
///
/// [highlightFrom]: columns from this index on are drawn in the accent color and get their
/// own legend entry ([highlightLabel]), e.g. predicted months after the sold ones.
class TimeSeriesChart extends StatelessWidget {
  const TimeSeriesChart({
    super.key,
    required this.points,
    required this.axisLabel,
    required this.barsLabel,
    this.trend,
    this.trendLabel,
    this.highlightFrom,
    this.highlightLabel,
  }) : assert(trend == null || trend.length == points.length),
       assert((highlightFrom == null) == (highlightLabel == null));

  final List<TimePoint> points;

  /// Same length as [points].
  final List<double>? trend;

  /// Formats y-axis ticks (compact, e.g. "R$ 5 mil").
  final String Function(double value) axisLabel;
  final String barsLabel;
  final String? trendLabel;
  final int? highlightFrom;
  final String? highlightLabel;

  static const _plotHeight = 192.0;

  /// Room above the plot so the top tick label isn't clipped.
  static const _topPadding = 8.0;
  static const _axisWidth = 68.0;

  /// Room per x label ("01/09" plus a gap); on a phone month this lands on weekly labels.
  static const _minLabelSpacing = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return Text('Sem dados.', style: theme.textTheme.bodyMedium);
    }

    final barColor = theme.colorScheme.outline.withValues(alpha: 0.6);
    const lineColor = ChartPalette.magnitude;
    final mutedText = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final maxValue = [
      ...points.map((p) => p.value),
      ...?trend,
    ].reduce(math.max);
    final ticks = HorizontalBarChart.niceTicks(maxValue);
    final axisMax = ticks.last;

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = constraints.maxWidth - _axisWidth;
        final slot = plotWidth / points.length;
        final labelEvery = math.max(1, (_minLabelSpacing / slot).ceil());

        double yOf(double value) =>
            _topPadding + _plotHeight * (1 - value / axisMax);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _topPadding + _plotHeight,
              child: Stack(
                // The 0 label sits half below the plot, beside the x labels.
                clipBehavior: Clip.none,
                children: [
                  for (final tick in ticks)
                    Positioned(
                      left: 0,
                      width: _axisWidth - 8,
                      top: yOf(tick) - 8,
                      child: Text(
                        axisLabel(tick),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: mutedText,
                      ),
                    ),
                  Positioned(
                    left: _axisWidth,
                    right: 0,
                    top: _topPadding,
                    bottom: 0,
                    child: CustomPaint(
                      painter: _SeriesPainter(
                        values: [for (final p in points) p.value],
                        trend: trend,
                        ticks: ticks,
                        gridColor: theme.colorScheme.outlineVariant,
                        barColor: barColor,
                        highlightColor: lineColor,
                        highlightFrom: highlightFrom,
                        lineColor: lineColor,
                        haloColor: theme.colorScheme.surfaceContainerLow,
                      ),
                    ),
                  ),
                  // One hit target per period, the full plot height (bigger than the column).
                  Positioned(
                    left: _axisWidth,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final p in points)
                          Expanded(
                            child: Tooltip(
                              message: p.tooltip,
                              child: const ColoredBox(
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: _axisWidth),
              child: SizedBox(
                height: 16,
                child: Stack(
                  children: [
                    for (final (i, p) in points.indexed)
                      if (i % labelEvery == 0)
                        _xLabel(
                          p.label,
                          i * slot + slot / 2,
                          plotWidth,
                          mutedText,
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _LegendEntry(
                  swatch: Container(
                    width: 10,
                    height: 12,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                      ),
                    ),
                  ),
                  label: barsLabel,
                ),
                if (highlightFrom != null)
                  _LegendEntry(
                    swatch: Container(
                      width: 10,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                    label: highlightLabel!,
                  ),
                if (trend != null && trendLabel != null)
                  _LegendEntry(
                    swatch: Container(width: 16, height: 2, color: lineColor),
                    label: trendLabel!,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Centered under its column; at the edges it aligns to the side instead of being
/// pushed inward, so it stays under its own day and clear of the next label.
Widget _xLabel(String text, double center, double plotWidth, TextStyle? style) {
  const width = TimeSeriesChart._minLabelSpacing;
  var left = center - width / 2;
  var align = TextAlign.center;
  if (left < 0) {
    left = math.max(0, center - 4);
    align = TextAlign.left;
  } else if (left + width > plotWidth) {
    left = math.min(plotWidth, center + 4) - width;
    align = TextAlign.right;
  }
  return Positioned(
    left: left,
    width: width,
    child: Text(text, maxLines: 1, textAlign: align, style: style),
  );
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.swatch, required this.label});

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      swatch,
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({
    required this.values,
    required this.trend,
    required this.ticks,
    required this.gridColor,
    required this.barColor,
    required this.highlightColor,
    required this.highlightFrom,
    required this.lineColor,
    required this.haloColor,
  });

  final List<double> values;
  final List<double>? trend;
  final List<double> ticks;
  final Color gridColor;
  final Color barColor;
  final Color highlightColor;
  final int? highlightFrom;
  final Color lineColor;
  final Color haloColor;

  @override
  void paint(Canvas canvas, Size size) {
    final axisMax = ticks.last;
    double yOf(double v) => size.height * (1 - v / axisMax);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final tick in ticks) {
      canvas.drawLine(
        Offset(0, yOf(tick)),
        Offset(size.width, yOf(tick)),
        grid,
      );
    }

    final slot = size.width / values.length;
    // 2px gap between columns while they are wide enough to afford it.
    final barWidth = slot >= 6 ? slot - ChartPalette.segmentGap : slot * 0.8;
    final radius = Radius.circular(math.min(4, barWidth / 2));
    final bars = Paint();
    final from = highlightFrom;
    for (final (i, v) in values.indexed) {
      bars.color = from != null && i >= from ? highlightColor : barColor;
      if (v <= 0) continue;
      final rect = Rect.fromLTRB(
        i * slot + (slot - barWidth) / 2,
        yOf(v),
        i * slot + (slot + barWidth) / 2,
        size.height,
      );
      // Rounded data end, flat on the baseline.
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
        bars,
      );
    }

    final line = trend;
    if (line == null || line.length < 2) return;
    final path = Path();
    for (final (i, v) in line.indexed) {
      final point = Offset(i * slot + slot / 2, yOf(v));
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    // Surface-colored halo separates the line from the columns it crosses.
    canvas.drawPath(
      path,
      stroke
        ..color = haloColor
        ..strokeWidth = 5,
    );
    canvas.drawPath(
      path,
      stroke
        ..color = lineColor
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SeriesPainter old) =>
      old.values != values ||
      old.trend != trend ||
      old.ticks != ticks ||
      old.barColor != barColor ||
      old.highlightFrom != highlightFrom;
}
