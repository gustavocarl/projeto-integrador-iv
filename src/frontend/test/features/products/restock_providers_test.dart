import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/products/presentation/controllers/restock_providers.dart';

import '../../helpers/fakes.dart';

void main() {
  final mouse = fakeCatalogProduct(stock: 5, minimumStock: 2);
  final notebook = fakeCatalogProduct(
    id: 'p-2',
    name: 'Notebook',
    sku: 'NB',
    stock: 10,
    minimumStock: 1,
  );

  test('lists the sold products left at or below the minimum', () {
    final restock = productsToRestock([
      (product: mouse, quantity: 3), // 2 left = minimum
      (product: notebook, quantity: 1), // 9 left
    ]);

    expect(
      [for (final r in restock) (r.product.id, r.stockLeft)],
      [('p-1', 2)],
    );
  });

  test('a product on several lines adds up its units', () {
    final restock = productsToRestock([
      (product: mouse, quantity: 2),
      (product: notebook, quantity: 1),
      (product: mouse, quantity: 3),
    ]);

    expect(
      [for (final r in restock) (r.product.id, r.stockLeft)],
      [('p-1', 0)],
    );
  });

  test('nothing to restock', () {
    expect(productsToRestock([(product: mouse, quantity: 1)]), isEmpty);
  });
}
