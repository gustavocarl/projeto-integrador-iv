/// A month left out of the analyses and why ("Mês em andamento: ainda não terminou.").
class IgnoredMonth {
  const IgnoredMonth({
    required this.month,
    required this.label,
    required this.reason,
  });

  /// "2026-10".
  final String month;

  /// "outubro/2026".
  final String label;
  final String reason;
}

/// Units and revenue of a month, sold or predicted.
class MonthTotal {
  const MonthTotal({
    required this.month,
    required this.label,
    required this.quantity,
    required this.revenue,
  });

  /// "2026-12".
  final String month;

  /// "dezembro/2026".
  final String label;
  final int quantity;
  final double revenue;

  DateTime get date =>
      DateTime(int.parse(month.substring(0, 4)), int.parse(month.substring(5)));
}

/// A product's predicted sales for the coming months.
class ProductForecast {
  const ProductForecast({
    required this.key,
    required this.name,
    required this.sku,
    required this.productId,
    required this.price,
    required this.quantities,
    required this.quantity,
    required this.revenue,
    required this.stock,
    required this.minimumStock,
    required this.suggestedPurchase,
  });

  final String key;
  final String name;
  final String? sku;

  /// Null for sales without a registered product.
  final String? productId;

  /// Average price in the last month it sold: the predicted revenue uses it.
  final double price;

  /// One per predicted month, in the order of [SalesForecast.months].
  final List<int> quantities;
  final int quantity;
  final double revenue;

  /// Catalog products only.
  final int? stock;
  final int? minimumStock;

  /// Units to buy: forecast + minimum − stock, never below 0. Catalog products only.
  final int? suggestedPurchase;

  bool get needsPurchase => (suggestedPurchase ?? 0) > 0;
}

/// The model's test on a month it already knew: trained without it, it predicted it.
class ForecastValidation {
  const ForecastValidation({
    required this.month,
    required this.label,
    required this.actualQuantity,
    required this.predictedQuantity,
    required this.baselineQuantity,
    required this.modelError,
    required this.baselineError,
  });

  final String month;
  final String label;
  final int actualQuantity;
  final int predictedQuantity;

  /// The simple guess: each product's average of the previous months.
  final int baselineQuantity;

  /// Sum of |predicted − sold| / units sold (0.39 = 39%).
  final double modelError;
  final double baselineError;

  /// The model guessed better than the simple average.
  bool get beatsBaseline => modelError < baselineError;
}

/// Sales predicted for the coming months (ML.NET Poisson regression in the backend).
class SalesForecast {
  const SalesForecast({
    required this.history,
    required this.months,
    required this.products,
    required this.validation,
    required this.ignoredMonths,
  });

  /// Complete months the model learned from, oldest first.
  final List<MonthTotal> history;

  /// Predicted months, oldest first.
  final List<MonthTotal> months;

  /// Highest predicted revenue first.
  final List<ProductForecast> products;
  final ForecastValidation? validation;
  final List<IgnoredMonth> ignoredMonths;

  int get quantity => months.fold(0, (sum, m) => sum + m.quantity);
  double get revenue => months.fold(0, (sum, m) => sum + m.revenue);

  List<ProductForecast> get toBuy =>
      products.where((p) => p.needsPurchase).toList();
}
