import 'sales_import.dart';

/// A month with sales, to choose from.
class SalesMonth implements SalesTotals {
  const SalesMonth({
    required this.month,
    required this.label,
    required this.sales,
    required this.quantity,
    required this.revenue,
  });

  /// "2026-01": the value sent to the comparison.
  final String month;

  /// "janeiro/2026".
  final String label;
  @override
  final int sales;
  @override
  final int quantity;
  @override
  final double revenue;

  int get year => int.parse(month.substring(0, 4));
  int get monthNumber => int.parse(month.substring(5, 7));
}

/// Totals of one side of a comparison.
class PeriodTotals implements SalesTotals {
  const PeriodTotals({
    required this.sales,
    required this.quantity,
    required this.revenue,
  });

  static const zero = PeriodTotals(sales: 0, quantity: 0, revenue: 0);

  @override
  final int sales;
  @override
  final int quantity;
  @override
  final double revenue;
}

/// One of the compared months.
class MonthSummary implements SalesTotals {
  const MonthSummary({
    required this.month,
    required this.label,
    required this.days,
    required this.elapsedDays,
    required this.sales,
    required this.quantity,
    required this.revenue,
    this.profit = ProfitSummary.none,
  });

  final String month;
  final String label;

  /// Days in the month.
  final int days;

  /// Days already gone by: less than [days] for the current month.
  final int elapsedDays;
  @override
  final int sales;
  @override
  final int quantity;
  @override
  final double revenue;

  /// Only the sales whose cost is known (checkout sales).
  final ProfitSummary profit;

  bool get isInProgress => elapsedDays < days;

  /// Revenue per sale; 0 without sales.
  double get averageTicket => sales == 0 ? 0 : revenue / sales;
}

/// A channel, marketplace or product in both months (zeros where it had no sales).
class ComparisonItem {
  const ComparisonItem({
    required this.key,
    required this.name,
    this.sku,
    required this.base,
    required this.target,
  });

  final String key;
  final String name;
  final String? sku;
  final PeriodTotals base;
  final PeriodTotals target;

  ComparisonItem renamed(String name) => ComparisonItem(
    key: key,
    name: name,
    sku: sku,
    base: base,
    target: target,
  );
}

/// A day of the month in both months; null on the side whose month is shorter.
class DayComparison {
  const DayComparison({required this.day, this.base, this.target});

  final int day;
  final PeriodTotals? base;
  final PeriodTotals? target;
}

/// Two months side by side over every batch. Growth = (target - base) / base.
class MonthComparison {
  const MonthComparison({
    required this.base,
    required this.target,
    required this.byChannel,
    required this.byMarketplace,
    required this.products,
    required this.byDay,
  });

  final MonthSummary base;
  final MonthSummary target;

  /// Presencial and Online.
  final List<ComparisonItem> byChannel;

  /// Online sales only, per marketplace (including "Fora de marketplace", key "none").
  final List<ComparisonItem> byMarketplace;

  /// Every product sold in either month, highest target revenue first.
  final List<ComparisonItem> products;

  /// Day 1 up to the longer month's last day.
  final List<DayComparison> byDay;
}
