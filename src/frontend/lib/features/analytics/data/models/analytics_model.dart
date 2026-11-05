import '../../domain/entities/product_groups.dart';
import '../../domain/entities/sales_forecast.dart';

/// JSON mapping of the backend's analytics DTOs.
abstract final class AnalyticsModel {
  static SalesForecast forecastFromJson(Map<String, dynamic> json) =>
      SalesForecast(
        history: _list(json['history'], _month),
        months: _list(json['months'], _month),
        products: _list(
          json['products'],
          (p) => ProductForecast(
            key: p['key'] as String,
            name: p['name'] as String,
            sku: p['sku'] as String?,
            productId: p['productId'] as String?,
            price: _double(p['price']),
            quantities: [
              for (final q in p['quantities'] as List<dynamic>) q as int,
            ],
            quantity: p['quantity'] as int,
            revenue: _double(p['revenue']),
            stock: p['stock'] as int?,
            minimumStock: p['minimumStock'] as int?,
            suggestedPurchase: p['suggestedPurchase'] as int?,
          ),
        ),
        validation: switch (json['validation']) {
          final Map<String, dynamic> v => ForecastValidation(
            month: v['month'] as String,
            label: v['label'] as String,
            actualQuantity: v['actualQuantity'] as int,
            predictedQuantity: v['predictedQuantity'] as int,
            baselineQuantity: v['baselineQuantity'] as int,
            modelError: _double(v['modelError']),
            baselineError: _double(v['baselineError']),
          ),
          _ => null,
        },
        ignoredMonths: _list(json['ignoredMonths'], _ignored),
      );

  static ProductGroups groupsFromJson(Map<String, dynamic> json) =>
      ProductGroups(
        groups: json['groups'] as int,
        automatic: json['automatic'] as bool,
        silhouette: _double(json['silhouette']),
        candidates: _list(
          json['candidates'],
          (c) => GroupingQuality(
            groups: c['groups'] as int,
            silhouette: _double(c['silhouette']),
          ),
        ),
        clusters: _list(
          json['clusters'],
          (g) => ProductGroup(
            number: g['number'] as int,
            name: g['name'] as String,
            description: g['description'] as String,
            monthlyQuantity: _double(g['monthlyQuantity']),
            averagePrice: _double(g['averagePrice']),
            regularity: _double(g['regularity']),
            quantity: g['quantity'] as int,
            revenue: _double(g['revenue']),
            revenueShare: _double(g['revenueShare']),
            products: _list(
              g['products'],
              (p) => GroupedProduct(
                key: p['key'] as String,
                name: p['name'] as String,
                sku: p['sku'] as String?,
                monthlyQuantity: _double(p['monthlyQuantity']),
                averagePrice: _double(p['averagePrice']),
                regularity: _double(p['regularity']),
                quantity: p['quantity'] as int,
                revenue: _double(p['revenue']),
              ),
            ),
          ),
        ),
        months: _list(json['months'], _month),
        ignoredMonths: _list(json['ignoredMonths'], _ignored),
      );

  static MonthTotal _month(Map<String, dynamic> m) => MonthTotal(
    month: m['month'] as String,
    label: m['label'] as String,
    quantity: m['quantity'] as int,
    revenue: _double(m['revenue']),
  );

  static IgnoredMonth _ignored(Map<String, dynamic> m) => IgnoredMonth(
    month: m['month'] as String,
    label: m['label'] as String,
    reason: m['reason'] as String,
  );

  static double _double(Object? value) => (value as num).toDouble();

  static List<T> _list<T>(Object? json, T Function(Map<String, dynamic>) map) =>
      (json as List<dynamic>).cast<Map<String, dynamic>>().map(map).toList();
}
