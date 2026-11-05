import '../../domain/entities/product.dart';

/// JSON mapping of the backend's product DTOs.
abstract final class ProductModel {
  static Product fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    sku: json['sku'] as String,
    category: json['category'] as String?,
    salePrice: (json['salePrice'] as num).toDouble(),
    costPrice: (json['costPrice'] as num?)?.toDouble(),
    margin: (json['margin'] as num?)?.toDouble(),
    stockQuantity: json['stockQuantity'] as int,
    minimumStock: json['minimumStock'] as int,
    isLowStock: json['isLowStock'] as bool,
    isActive: json['isActive'] as bool,
    imageUrl: json['imageUrl'] as String?,
  );

  static Map<String, dynamic> toJson(ProductInput input) => {
    'name': input.name,
    'sku': input.sku,
    'category': input.category,
    'salePrice': input.salePrice,
    'costPrice': input.costPrice,
    'stockQuantity': input.stockQuantity,
    'minimumStock': input.minimumStock,
    'isActive': input.isActive,
    'imageUrl': input.imageUrl,
  };
}
