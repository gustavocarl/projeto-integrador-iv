import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/product_repository_impl.dart';
import '../../domain/entities/product.dart';

/// The catalog list with its filter. Actions throw [Failure] so the screen's
/// [BaseState.runSafely] shows them.
class ProductsController extends AsyncNotifier<List<Product>> {
  ProductFilter _filter = const ProductFilter();

  /// Ignores answers to filters the user already replaced by typing more.
  int _request = 0;

  ProductFilter get filter => _filter;

  @override
  Future<List<Product>> build() => _load();

  Future<void> setFilter(ProductFilter filter) async {
    _filter = filter;
    final request = ++_request;
    // The current list stays on screen until the new one arrives.
    final result = await AsyncValue.guard(_load);
    if (request == _request) state = result;
  }

  Future<Product> save(ProductInput input, {String? id}) async {
    final repository = ref.read(productRepositoryProvider);
    final saved = id == null
        ? await repository.create(input)
        : await repository.update(id, input);
    await _catalogChanged();
    return saved;
  }

  Future<void> delete(String id) async {
    await ref.read(productRepositoryProvider).delete(id);
    await _catalogChanged();
  }

  /// Reloads without showing a loading state (e.g. after a sale changed the stock).
  /// Never throws: a failure becomes the error state.
  Future<void> reload() async {
    state = await AsyncValue.guard(_load);
  }

  Future<List<Product>> _load() =>
      ref.read(productRepositoryProvider).list(filter: _filter);

  Future<void> _catalogChanged() async {
    ref.invalidate(productCategoriesProvider);
    ref.invalidate(sellableProductsProvider);
    await reload();
  }
}

final productsControllerProvider =
    AsyncNotifierProvider<ProductsController, List<Product>>(
      ProductsController.new,
    );

final productCategoriesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.read(productRepositoryProvider).listCategories(),
);

/// Every active product: what the checkout can sell (searched on the device).
final sellableProductsProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.read(productRepositoryProvider).list(),
);
