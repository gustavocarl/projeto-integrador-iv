import '../entities/product_groups.dart';
import '../entities/sales_forecast.dart';

/// Machine learning over the sales history of every batch. Methods throw Failure; without
/// enough history, Failure 404 with the backend's explanation.
abstract interface class AnalyticsRepository {
  /// Sales of the [months] (1 to 6) after the current one.
  Future<SalesForecast> forecast(int months);

  /// [groups]: 2 to 6; null = the number with the best silhouette.
  Future<ProductGroups> productGroups(int? groups);
}
