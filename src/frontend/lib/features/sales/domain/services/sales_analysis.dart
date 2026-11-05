import 'dart:math' as math;

import '../entities/sales_import.dart';

enum TrendDirection { up, down, stable }

/// Average per day of the first and second half of the period.
class HalfComparison {
  const HalfComparison({
    required this.firstDays,
    required this.firstAverage,
    required this.secondAverage,
  });

  /// Number of days in the first half (the second half has the rest).
  final int firstDays;
  final double firstAverage;
  final double secondAverage;

  /// Relative change (0.12 = +12%); null when the first half had nothing to compare with.
  double? get change =>
      firstAverage == 0 ? null : (secondAverage - firstAverage) / firstAverage;

  /// Changes under 5% either way are noise for a month of sales.
  static const stableThreshold = 0.05;

  TrendDirection get direction {
    final c = change;
    if (c == null) {
      return secondAverage > 0 ? TrendDirection.up : TrendDirection.stable;
    }
    if (c >= stableThreshold) return TrendDirection.up;
    if (c <= -stableThreshold) return TrendDirection.down;
    return TrendDirection.stable;
  }
}

/// Pure calculations for the analysis charts (no Flutter, easy to test).
abstract final class SalesAnalysis {
  /// Centered moving average; near the edges the window shrinks to the days available.
  static List<double> movingAverage(List<double> values, {int window = 7}) {
    final half = window ~/ 2;
    return [
      for (var i = 0; i < values.length; i++)
        _average(
          values.sublist(
            math.max(0, i - half),
            math.min(values.length, i + half + 1),
          ),
        ),
    ];
  }

  /// Null when there are fewer than 2 days.
  static HalfComparison? compareHalves(List<double> values) {
    if (values.length < 2) return null;
    final firstDays = values.length ~/ 2;
    return HalfComparison(
      firstDays: firstDays,
      firstAverage: _average(values.sublist(0, firstDays)),
      secondAverage: _average(values.sublist(firstDays)),
    );
  }

  /// Every way the store sells: physical store, each marketplace and the own online store.
  static List<BreakdownItem> platforms(SalesImportDetail detail) => [
    for (final channel in detail.byChannel)
      if (channel.key == 'InPerson') channel.renamed('Loja física'),
    for (final marketplace in detail.byMarketplace)
      marketplace.key == 'none'
          ? marketplace.renamed('Loja virtual própria')
          : marketplace,
  ];

  static double _average(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}
