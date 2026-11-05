/// A catalog item the store sells at the checkout.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    this.category,
    required this.salePrice,
    this.costPrice,
    this.margin,
    required this.stockQuantity,
    required this.minimumStock,
    required this.isLowStock,
    required this.isActive,
    this.imageUrl,
  });

  final String id;
  final String name;

  /// Unique code, upper case ("NB-PRO-14").
  final String sku;
  final String? category;
  final double salePrice;

  /// Null when unknown: the product's sales have no profit.
  final double? costPrice;

  /// (sale price - cost) / sale price; null without cost.
  final double? margin;
  final int stockQuantity;

  /// At or below it the product is flagged to be restocked.
  final int minimumStock;
  final bool isLowStock;

  /// Inactive products stay in the catalog but can't be sold.
  final bool isActive;

  /// Link to the product photo; null when there is none.
  final String? imageUrl;

  bool get isOutOfStock => stockQuantity <= 0;
}

/// What the form sends to create or replace a product. Values left empty or typed
/// wrong are null: the backend reports them.
class ProductInput {
  const ProductInput({
    this.name,
    this.sku,
    this.category,
    this.salePrice,
    this.costPrice,
    this.stockQuantity,
    this.minimumStock,
    required this.isActive,
    this.imageUrl,
  });

  final String? name;
  final String? sku;
  final String? category;
  final double? salePrice;
  final double? costPrice;
  final int? stockQuantity;
  final int? minimumStock;
  final bool isActive;
  final String? imageUrl;
}

/// What the catalog list shows.
class ProductFilter {
  const ProductFilter({
    this.search = '',
    this.category,
    this.includeInactive = false,
  });

  final String search;

  /// Null = every category.
  final String? category;
  final bool includeInactive;

  ProductFilter copyWith({
    String? search,
    String? Function()? category,
    bool? includeInactive,
  }) => ProductFilter(
    search: search ?? this.search,
    category: category == null ? this.category : category(),
    includeInactive: includeInactive ?? this.includeInactive,
  );

  bool get isEmpty => search.isEmpty && category == null;
}
