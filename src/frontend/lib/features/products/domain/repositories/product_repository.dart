import '../../../../core/files/file_service.dart';
import '../entities/product.dart';

/// Product catalog contract. Methods throw [Failure] on error.
abstract interface class ProductRepository {
  /// Sorted by name.
  Future<List<Product>> list({ProductFilter filter = const ProductFilter()});

  Future<Product> create(ProductInput input);

  Future<Product> update(String id, ProductInput input);

  /// Only products never sold can be deleted (409 otherwise: deactivate them).
  Future<void> delete(String id);

  /// Uploads a photo and returns its path on the API ("/uploads/products/…"), to be saved
  /// as the product's `imageUrl`. Errors come under the key `file`.
  Future<String> uploadImage(PickedFile file);

  /// Categories in use, sorted.
  Future<List<String>> listCategories();
}
