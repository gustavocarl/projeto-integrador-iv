import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'horizontal_bar_chart.dart';

/// One line of a [ComparisonLineChart].
class LineSeries {
  const LineSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;

  /// One value per x position; null where the series has no data (the line stops).
  final List<double?> values;
}

/// Two (or a few) series over the same x positions, e.g. the running total of two months
/// day by day. One y-axis, 2px lines, a marker on each line's last point, a legend and
/// one tooltip per x position covering the full height.
class ComparisonLineChart extends StatelessWidget {
  const ComparisonLineChart({
    super.key,
    required this.series,
    required this.xLabels,
    required this.tooltips,
    required this.axisLabel,
  });

  final List<LineSeries> series;

  /// One per x position (e.g. the day "15"); only some are drawn when space is short.
  final List<String> xLabels;

  /// One per x position.
  final List<String> tooltips;

  /// Formats y-axis ticks (compact, e.g. "R$ 5 mil").
  final String Function(double value) axisLabel;

  static const _plotHeight = 192.0;
  static const _topPadding = 8.0;
  static const _axisWidth = 68.0;
  static const _minLabelSpacing = 32.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [for (final s in series) ...s.values.whereType<double>()];
    if (xLabels.isEmpty || values.isEmpty) {
      return Text('Sem dados.', style: theme.textTheme.bodyMedium);
    }

    final mutedText = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final ticks = HorizontalBarChart.niceTicks(values.reduce(math.max));
    final axisMax = ticks.last;

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = constraints.maxWidth - _axisWidth;
        final slot = plotWidth / xLabels.length;
        final labelEvery = math.max(1, (_minLabelSpacing / slot).ceil());

        double yOf(double value) =>
            _topPadding + _plotHeight * (1 - value / axisMax);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _topPadding + _plotHeight,
              child: Stack(
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
                      painter: _LinesPainter(
                        series: series,
                        count: xLabels.length,
                        axisMax: axisMax,
                        ticks: ticks,
                        gridColor: theme.colorScheme.outlineVariant,
                        haloColor: theme.colorScheme.surfaceContainerLow,
                      ),
                    ),
                  ),
                  Positioned(
                    left: _axisWidth,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final tooltip in tooltips)
                          Expanded(
                            child: Tooltip(
                              message: tooltip,
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
                    for (final (i, label) in xLabels.indexed)
                      if (i % labelEvery == 0)
                        Positioned(
                          left: i * slot + slot / 2 - _minLabelSpacing / 2,
                          width: _minLabelSpacing,
                          child: Text(
                            label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: mutedText,
                          ),
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
                for (final s in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 16, height: 2, color: s.color),
                      const SizedBox(width: 6),
                      Text(s.label, style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter({
    required this.series,
    required this.count,
    required this.axisMax,
    required this.ticks,
    required this.gridColor,
    required this.haloColor,
  });

  final List<LineSeries> series;
  final int count;
  final double axisMax;
  final List<double> ticks;
  final Color gridColor;
  final Color haloColor;

  @override
  void paint(Canvas canvas, Size size) {
    double yOf(double v) => size.height * (1 - v / axisMax);
    final slot = size.width / count;
    double xOf(int i) => i * slot + slot / 2;

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

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    for (final s in series) {
      final path = Path();
      Offset? last;
      for (final (i, v) in s.values.indexed) {
        if (v == null) continue;
        final point = Offset(xOf(i), yOf(v));
        last == null
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
        last = point;
      }
      if (last == null) continue;

      // Surface halo where the lines cross, then the 2px line.
      canvas.drawPath(
        path,
        stroke
          ..color = haloColor
          ..strokeWidth = 5,
      );
      canvas.drawPath(
        path,
        stroke
          ..color = s.color
          ..strokeWidth = 2,
      );
      // 8px marker with a 2px surface ring on the last value.
      canvas.drawCircle(last, 6, Paint()..color = haloColor);
      canvas.drawCircle(last, 4, Paint()..color = s.color);
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) =>
      old.series != series || old.axisMax != axisMax || old.count != count;
}
