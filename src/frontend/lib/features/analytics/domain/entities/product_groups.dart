import 'sales_forecast.dart';

/// A product with the features it was grouped by.
class GroupedProduct {
  const GroupedProduct({
    required this.key,
    required this.name,
    required this.sku,
    required this.monthlyQuantity,
    required this.averagePrice,
    required this.regularity,
    required this.quantity,
    required this.revenue,
  });

  final String key;
  final String name;
  final String? sku;

  /// Average units per month of the history.
  final double monthlyQuantity;
  final double averagePrice;

  /// Share of the months with sales, 0 to 1.
  final double regularity;
  final int quantity;
  final double revenue;
}

/// Products that sell alike (k-means in the backend).
class ProductGroup {
  const ProductGroup({
    required this.number,
    required this.name,
    required this.description,
    required this.monthlyQuantity,
    required this.averagePrice,
    required this.regularity,
    required this.quantity,
    required this.revenue,
    required this.revenueShare,
    required this.products,
  });

  /// 1 = the group with the highest revenue.
  final int number;
  final String name;
  final String description;
  final double monthlyQuantity;
  final double averagePrice;
  final double regularity;
  final int quantity;
  final double revenue;

  /// 0 to 1.
  final double revenueShare;

  /// Highest revenue first.
  final List<GroupedProduct> products;
}

/// How well a number of groups separates the products (silhouette, −1 to 1).
class GroupingQuality {
  const GroupingQuality({required this.groups, required this.silhouette});

  final int groups;
  final double silhouette;
}

class ProductGroups {
  const ProductGroups({
    required this.groups,
    required this.automatic,
    required this.silhouette,
    required this.candidates,
    required this.clusters,
    required this.months,
    required this.ignoredMonths,
  });

  final int groups;

  /// The number of groups was chosen by the best silhouette.
  final bool automatic;
  final double silhouette;
  final List<GroupingQuality> candidates;

  /// Highest revenue first.
  final List<ProductGroup> clusters;

  /// Months the features came from, oldest first.
  final List<MonthTotal> months;
  final List<IgnoredMonth> ignoredMonths;

  int get productCount => clusters.fold(0, (sum, g) => sum + g.products.length);
}
