import '../entities/month_comparison.dart';
import '../entities/sales_import.dart';

/// Pure calculations behind the month comparison screen.
abstract final class MonthComparisonAnalysis {
  /// (target - base) / base: 0.25 = grew 25%. Null when the base is 0 (nothing to grow from).
  static double? growth(double base, double target) =>
      base == 0 ? null : (target - base) / base;

  /// "2026-01" → "2025-12".
  static String previousMonth(String month) {
    final year = int.parse(month.substring(0, 4));
    final number = int.parse(month.substring(5, 7));
    return number == 1 ? _key(year - 1, 12) : _key(year, number - 1);
  }

  /// "2026-01" → "2025-01".
  static String sameMonthLastYear(String month) => _key(
    int.parse(month.substring(0, 4)) - 1,
    int.parse(month.substring(5, 7)),
  );

  /// What the screen opens with: the most recent month against the same month of the
  /// year before when it has sales, otherwise against the previous month with sales.
  /// Null with fewer than two months. [months] is most recent first.
  static ({String base, String target})? defaultPair(List<SalesMonth> months) {
    if (months.length < 2) return null;
    final target = months.first.month;
    final lastYear = sameMonthLastYear(target);
    final base = months.any((m) => m.month == lastYear)
        ? lastYear
        : months[1].month;
    return (base: base, target: target);
  }

  /// Where the store sells: physical store, each marketplace and its own online store.
  static List<ComparisonItem> platforms(MonthComparison comparison) => [
    for (final channel in comparison.byChannel)
      if (channel.key == 'InPerson') channel.renamed('Loja física'),
    for (final marketplace in comparison.byMarketplace)
      marketplace.key == 'none'
          ? marketplace.renamed('Loja virtual própria')
          : marketplace,
  ];

  /// Running total of one month, day by day. Null past the month's end and past
  /// [elapsedDays] (a month in progress has no data yet for the days ahead).
  static List<double?> cumulative(
    List<DayComparison> days,
    PeriodTotals? Function(DayComparison day) side,
    double Function(SalesTotals totals) value, {
    required int elapsedDays,
  }) {
    var sum = 0.0;
    return [
      for (final day in days)
        if (side(day) case final totals? when day.day <= elapsedDays)
          sum += value(totals)
        else
          null,
    ];
  }

  /// Products that changed the most, by absolute difference: up to [limit] that grew
  /// and up to [limit] that fell, the biggest change first.
  static ({List<ComparisonItem> risers, List<ComparisonItem> fallers}) movers(
    List<ComparisonItem> products,
    double Function(SalesTotals totals) value, {
    int limit = 5,
  }) {
    double change(ComparisonItem p) => value(p.target) - value(p.base);
    final risers = products.where((p) => change(p) > 0).toList()
      ..sort((a, b) => change(b).compareTo(change(a)));
    final fallers = products.where((p) => change(p) < 0).toList()
      ..sort((a, b) => change(a).compareTo(change(b)));
    return (
      risers: risers.take(limit).toList(),
      fallers: fallers.take(limit).toList(),
    );
  }

  static String _key(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}
