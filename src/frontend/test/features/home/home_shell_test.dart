import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/home/presentation/pages/home_shell.dart';
import 'package:univesp_project/features/products/domain/entities/product.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_export_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/settings/domain/entities/user_settings.dart';
import 'package:univesp_project/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:univesp_project/features/store/data/repositories/store_repository_impl.dart';

import '../../helpers/fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  List<Product>? products,
  UserSettings settings = UserSettings.defaults,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        productRepositoryProvider.overrideWithValue(
          FakeProductRepository(products ?? [fakeCatalogProduct()]),
        ),
        salesRepositoryProvider.overrideWithValue(
          FakeSalesRepository([fakeImport()]),
        ),
        fileServiceProvider.overrideWithValue(FakeFileService()),
        salesExportRepositoryProvider.overrideWithValue(
          FakeSalesExportRepository([fakeExport()]),
        ),
        analyticsRepositoryProvider.overrideWithValue(
          FakeAnalyticsRepository(),
        ),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
        ),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(settings),
        ),
      ],
      child: MaterialApp(home: HomeShell(user: FakeAuthRepository.maria)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone: bottom bar switches between the six screens', (
    tester,
  ) async {
    // A small phone: six labels must fit.
    await _pump(tester, const Size(360, 740));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.widgetWithText(AppBar, 'Produtos'), findsOneWidget);
    expect(find.text('Mouse sem fio'), findsOneWidget);

    await tester.tap(find.text('Vender'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Venda de produtos'), findsOneWidget);
    expect(find.text('Carrinho vazio.'), findsOneWidget);

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Importações de vendas'),
      findsOneWidget,
    );
    // On the narrow phone the import card is taller: the batch is below it.
    await tester.scrollUntilVisible(
      find.text('vendas-outubro.xlsx'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('vendas-outubro.xlsx'), findsOneWidget);

    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Exportações de vendas'),
      findsOneWidget,
    );
    expect(find.text('novembro/2026'), findsOneWidget);
    // The period dialog fits the small phone too (an overflow fails the test).
    await tester.tap(find.text('Gerar planilha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Período'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher o período'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Comparativo de meses'), findsOneWidget);
    expect(
      find.text(
        'Para comparar, é preciso ter vendas em pelo menos dois meses.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Prever'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Previsão e grupos de produtos'),
      findsOneWidget,
    );
    expect(
      find.text('Previsão para dezembro/2026 a fevereiro/2027'),
      findsOneWidget,
    );
    await tester.tap(find.text('Grupos de produtos'));
    await tester.pumpAndSettle();
    expect(find.text('4 produtos em 2 grupos'), findsOneWidget);
  });

  testWidgets('wide screen: the menu is a side rail', (tester) async {
    await _pump(tester, const Size(1200, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('the cart survives switching screens', (tester) async {
    await _pump(tester, const Size(400, 800));
    await tester.tap(find.text('Vender'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar produto'),
      'mouse',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MOU-280 · 10 em estoque'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Produtos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vender'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remover do carrinho'), findsOneWidget);
  });

  group('restock badge on Produtos', () {
    final catalog = [
      fakeCatalogProduct(stock: 2, minimumStock: 2), // at the minimum
      fakeCatalogProduct(id: 'p-2', name: 'Teclado', sku: 'TEC', stock: 0),
      fakeCatalogProduct(id: 'p-3', name: 'Monitor', sku: 'MON', stock: 9),
    ];

    testWidgets('counts the products to restock (on by default)', (
      tester,
    ) async {
      await _pump(tester, const Size(360, 740), products: catalog);

      expect(find.byKey(const Key('restockBadge')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('restockBadge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip('2 produtos precisam de reposição'),
        findsOneWidget,
      );
    });

    testWidgets('also on the side rail', (tester) async {
      await _pump(tester, const Size(1200, 800), products: catalog);

      expect(find.byKey(const Key('restockBadge')), findsOneWidget);
    });

    testWidgets('hidden when the user turned the warnings off', (tester) async {
      await _pump(
        tester,
        const Size(360, 740),
        products: catalog,
        settings: const UserSettings(notifyRestock: false),
      );

      expect(find.byKey(const Key('restockBadge')), findsNothing);
    });

    testWidgets('no badge when nothing needs restocking', (tester) async {
      await _pump(tester, const Size(360, 740));

      expect(find.byKey(const Key('restockBadge')), findsNothing);
    });
  });
}
