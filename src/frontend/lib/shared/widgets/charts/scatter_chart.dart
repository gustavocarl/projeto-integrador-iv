import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_palette.dart';

class ScatterPoint {
  const ScatterPoint({
    required this.x,
    required this.y,
    required this.tooltip,
    this.highlighted = false,
  });

  /// Both must be positive: the axes are logarithmic.
  final double x;
  final double y;
  final String tooltip;

  /// Drawn in the accent color, on top of the others.
  final bool highlighted;
}

/// Two measures of the same items (e.g. price × units per month) on logarithmic axes, so a
/// R$ 30 cable and a R$ 5.000 notebook both fit. One group is highlighted in the accent
/// color and the rest stay gray: any number of groups reads the same way (more than three
/// colors could not be told apart in a scatter).
class ScatterChart extends StatelessWidget {
  const ScatterChart({
    super.key,
    required this.points,
    required this.xTitle,
    required this.yTitle,
    required this.xTickLabel,
    required this.yTickLabel,
    required this.highlightLabel,
    required this.othersLabel,
  });

  final List<ScatterPoint> points;
  final String xTitle;
  final String yTitle;
  final String Function(double value) xTickLabel;
  final String Function(double value) yTickLabel;
  final String highlightLabel;
  final String othersLabel;

  static const _plotHeight = 240.0;
  static const _topPadding = 8.0;
  static const _axisWidth = 56.0;

  /// Room per x tick label.
  static const _minTickSpacing = 64.0;

  /// Hit target around each dot, bigger than the dot.
  static const _hitSize = 24.0;

  /// Ticks at 1, 2 and 5 of each power of ten inside the range (only the powers when
  /// space is short), and the range itself rounded out to whole powers of ten.
  static ({double min, double max, List<double> ticks}) logTicks(
    Iterable<double> values, {
    int maxTicks = 8,
  }) {
    final positive = values.where((v) => v > 0);
    final low = positive.isEmpty ? 1.0 : positive.reduce(math.min);
    final high = positive.isEmpty ? 1.0 : positive.reduce(math.max);
    var first = (math.log(low) / math.ln10).floor();
    var last = (math.log(high) / math.ln10).ceil();
    if (first == last) {
      first -= 1;
      last += 1;
    }

    List<double> build(List<int> steps) => [
      for (var p = first; p <= last; p++)
        for (final step in steps)
          if (step * math.pow(10, p) <= math.pow(10, last))
            (step * math.pow(10, p)).toDouble(),
    ];

    var ticks = build(const [1, 2, 5]);
    if (ticks.length > maxTicks) ticks = build(const [1]);
    return (
      min: math.pow(10, first).toDouble(),
      max: math.pow(10, last).toDouble(),
      ticks: ticks,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return Text('Sem dados.', style: theme.textTheme.bodyMedium);
    }

    final otherColor = theme.colorScheme.outline.withValues(alpha: 0.7);
    const highlightColor = ChartPalette.magnitude;
    final mutedText = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final yAxis = logTicks(points.map((p) => p.y), maxTicks: 6);

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = constraints.maxWidth - _axisWidth;
        final xAxis = logTicks(
          points.map((p) => p.x),
          maxTicks: math.max(2, (plotWidth / _minTickSpacing).floor()),
        );

        double fraction(
          double v,
          ({double min, double max, List<double> ticks}) axis,
        ) {
          final value = math.max(v, axis.min);
          return (math.log(value) - math.log(axis.min)) /
              (math.log(axis.max) - math.log(axis.min));
        }

        double xOf(double v) => plotWidth * fraction(v, xAxis);
        double yOf(double v) =>
            _topPadding + _plotHeight * (1 - fraction(v, yAxis));

        // Highlighted last, so they are drawn (and tapped) on top.
        final ordered = [
          ...points.where((p) => !p.highlighted),
          ...points.where((p) => p.highlighted),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(yTitle, style: mutedText),
            const SizedBox(height: 4),
            SizedBox(
              height: _topPadding + _plotHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final tick in yAxis.ticks)
                    Positioned(
                      left: 0,
                      width: _axisWidth - 8,
                      top: yOf(tick) - 8,
                      child: Text(
                        yTickLabel(tick),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: mutedText,
                      ),
                    ),
                  Positioned(
                    left: _axisWidth,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: CustomPaint(
                      painter: _ScatterPainter(
                        xs: [for (final p in ordered) xOf(p.x)],
                        ys: [for (final p in ordered) yOf(p.y)],
                        highlighted: [for (final p in ordered) p.highlighted],
                        xGrid: [for (final t in xAxis.ticks) xOf(t)],
                        yGrid: [for (final t in yAxis.ticks) yOf(t)],
                        gridColor: theme.colorScheme.outlineVariant,
                        otherColor: otherColor,
                        highlightColor: highlightColor,
                        ringColor: theme.colorScheme.surfaceContainer,
                      ),
                    ),
                  ),
                  for (final p in ordered)
                    Positioned(
                      left: _axisWidth + xOf(p.x) - _hitSize / 2,
                      top: yOf(p.y) - _hitSize / 2,
                      width: _hitSize,
                      height: _hitSize,
                      child: Tooltip(
                        message: p.tooltip,
                        triggerMode: TooltipTriggerMode.tap,
                        child: const ColoredBox(color: Colors.transparent),
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
                  clipBehavior: Clip.none,
                  children: [
                    for (final tick in xAxis.ticks)
                      Positioned(
                        left: math.min(
                          math.max(0, xOf(tick) - _minTickSpacing / 2),
                          plotWidth - _minTickSpacing,
                        ),
                        width: _minTickSpacing,
                        child: Text(
                          xTickLabel(tick),
                          maxLines: 1,
                          textAlign: xOf(tick) < _minTickSpacing / 2
                              ? TextAlign.left
                              : xOf(tick) > plotWidth - _minTickSpacing / 2
                              ? TextAlign.right
                              : TextAlign.center,
                          style: mutedText,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: _axisWidth),
              child: Text(xTitle, style: mutedText),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _LegendDot(color: highlightColor, label: highlightLabel),
                _LegendDot(color: otherColor, label: othersLabel),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter({
    required this.xs,
    required this.ys,
    required this.highlighted,
    required this.xGrid,
    required this.yGrid,
    required this.gridColor,
    required this.otherColor,
    required this.highlightColor,
    required this.ringColor,
  });

  final List<double> xs;
  final List<double> ys;
  final List<bool> highlighted;
  final List<double> xGrid;
  final List<double> yGrid;
  final Color gridColor;
  final Color otherColor;
  final Color highlightColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final y in yGrid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (final x in xGrid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    final ring = Paint()..color = ringColor;
    final dot = Paint();
    for (var i = 0; i < xs.length; i++) {
      final center = Offset(xs[i], ys[i]);
      final radius = highlighted[i] ? 5.0 : 4.0;
      // 2px ring in the surface color keeps overlapping dots apart.
      canvas.drawCircle(center, radius + 2, ring);
      canvas.drawCircle(
        center,
        radius,
        dot..color = highlighted[i] ? highlightColor : otherColor,
      );
    }
  }

  @override
  bool shouldRepaint(_ScatterPainter old) =>
      old.xs != xs ||
      old.ys != ys ||
      old.highlighted != highlighted ||
      old.ringColor != ringColor;
}
