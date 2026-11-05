import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/controllers/user_settings_controller.dart';
import '../../domain/entities/product.dart';
import 'products_controller.dart';

/// The user's "Avisar sobre reposição de estoque" preference (on by default).
/// Off while the settings load, so a user who turned it off never sees a warning flash.
final notifyRestockProvider = Provider<bool>(
  (ref) =>
      ref.watch(userSettingsProvider.select((s) => s.value?.notifyRestock)) ??
      false,
);

/// Active products at or below their minimum stock, for the menu badge.
/// Empty when the user turned the warnings off.
final restockProductsProvider = Provider<List<Product>>((ref) {
  if (!ref.watch(notifyRestockProvider)) return const [];
  final products = ref.watch(sellableProductsProvider).value ?? const [];
  return [
    for (final p in products)
      if (p.isActive && p.isLowStock) p,
  ];
});

/// The products of a sale that are now at or below their minimum stock, in the order sold.
/// [sold] holds each product as it was before the sale and the units sold (a product may
/// repeat: the units add up).
List<({Product product, int stockLeft})> productsToRestock(
  Iterable<({Product product, int quantity})> sold,
) {
  final units = <String, int>{};
  final products = <String, Product>{};
  for (final line in sold) {
    units[line.product.id] = (units[line.product.id] ?? 0) + line.quantity;
    products.putIfAbsent(line.product.id, () => line.product);
  }
  return [
    for (final MapEntry(key: id, value: product) in products.entries)
      if (product.stockQuantity - units[id]! <= product.minimumStock)
        (product: product, stockLeft: product.stockQuantity - units[id]!),
  ];
}
