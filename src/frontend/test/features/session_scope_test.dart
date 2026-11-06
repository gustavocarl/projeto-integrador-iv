import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/auth/presentation/controllers/auth_controller.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/products/domain/entities/product.dart';
import 'package:univesp_project/features/products/presentation/controllers/products_controller.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_export_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/sales/presentation/controllers/month_comparison_providers.dart';
import 'package:univesp_project/features/sales/presentation/controllers/sales_exports_controller.dart';
import 'package:univesp_project/features/sales/presentation/controllers/sales_imports_controller.dart';

import '../helpers/fakes.dart';

void main() {
  test(
    'logging out and in with another account reloads the store data',
    () async {
      final auth = FakeAuthRepository(sessionUser: FakeAuthRepository.maria)
        ..accounts['ana@exemplo.com'] = 'Senha123';
      final products = FakeProductRepository([fakeCatalogProduct()]);
      final sales = FakeSalesRepository([fakeImport()]);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          productRepositoryProvider.overrideWithValue(products),
          salesRepositoryProvider.overrideWithValue(sales),
          salesExportRepositoryProvider.overrideWithValue(
            FakeSalesExportRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Kept alive like the screens do.
      for (final provider in <ProviderListenable<Object?>>[
        productsControllerProvider,
        salesImportsControllerProvider,
        salesExportsControllerProvider,
        salesMonthsProvider,
      ]) {
        container.listen(provider, (_, _) {});
      }
      await container.read(authControllerProvider.future);
      await container
          .read(productsControllerProvider.notifier)
          .setFilter(const ProductFilter(search: 'mouse'));
      expect(container.read(productsControllerProvider).value, hasLength(1));
      final listsBefore = sales.listCalls;

      await container.read(authControllerProvider.notifier).logout();
      // Logged out: the lists are emptied without asking the backend.
      expect(await container.read(productsControllerProvider.future), isEmpty);
      expect(
        await container.read(salesImportsControllerProvider.future),
        isEmpty,
      );
      expect(sales.listCalls, listsBefore);

      // Another account, whose store has nothing yet.
      products.products.clear();
      await container
          .read(authControllerProvider.notifier)
          .login('ana@exemplo.com', 'Senha123');
      expect(await container.read(productsControllerProvider.future), isEmpty);
      await container.read(salesImportsControllerProvider.future);

      // A fresh start: the previous user's search is gone, and the batches were asked again.
      expect(products.filters.last.search, '');
      expect(sales.listCalls, listsBefore + 1);
    },
  );
}
