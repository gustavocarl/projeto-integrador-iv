import '../../domain/entities/month_comparison.dart';
import '../../domain/entities/sales_import.dart';

/// JSON mapping of the backend's month comparison DTOs.
abstract final class MonthComparisonModel {
  static SalesMonth monthFromJson(Map<String, dynamic> json) => SalesMonth(
    month: json['month'] as String,
    label: json['label'] as String,
    sales: json['sales'] as int,
    quantity: json['quantity'] as int,
    revenue: (json['revenue'] as num).toDouble(),
  );

  static MonthComparison fromJson(Map<String, dynamic> json) => MonthComparison(
    base: _summary(json['base'] as Map<String, dynamic>),
    target: _summary(json['target'] as Map<String, dynamic>),
    byChannel: _list(json['byChannel'], _item),
    byMarketplace: _list(json['byMarketplace'], _item),
    products: _list(json['products'], _item),
    byDay: _list(
      json['byDay'],
      (e) => DayComparison(
        day: e['day'] as int,
        base: _totalsOrNull(e['base']),
        target: _totalsOrNull(e['target']),
      ),
    ),
  );

  static MonthSummary _summary(Map<String, dynamic> json) => MonthSummary(
    month: json['month'] as String,
    label: json['label'] as String,
    days: json['days'] as int,
    elapsedDays: json['elapsedDays'] as int,
    sales: json['sales'] as int,
    quantity: json['quantity'] as int,
    revenue: (json['revenue'] as num).toDouble(),
    profit: switch (json['profit']) {
      final Map<String, dynamic> p => ProfitSummary(
        salesWithCost: p['salesWithCost'] as int,
        revenue: (p['revenue'] as num).toDouble(),
        cost: (p['cost'] as num).toDouble(),
        profit: (p['profit'] as num).toDouble(),
        margin: (p['margin'] as num?)?.toDouble(),
      ),
      _ => ProfitSummary.none,
    },
  );

  static ComparisonItem _item(Map<String, dynamic> e) => ComparisonItem(
    key: e['key'] as String,
    name: e['name'] as String,
    sku: e['sku'] as String?,
    base: _totalsOrNull(e['base']) ?? PeriodTotals.zero,
    target: _totalsOrNull(e['target']) ?? PeriodTotals.zero,
  );

  static PeriodTotals? _totalsOrNull(Object? json) => switch (json) {
    final Map<String, dynamic> t => PeriodTotals(
      sales: t['sales'] as int,
      quantity: t['quantity'] as int,
      revenue: (t['revenue'] as num).toDouble(),
    ),
    _ => null,
  };

  static List<T> _list<T>(
    Object? json,
    T Function(Map<String, dynamic>) parse,
  ) => ((json as List<dynamic>?) ?? const [])
      .cast<Map<String, dynamic>>()
      .map(parse)
      .toList();
}
