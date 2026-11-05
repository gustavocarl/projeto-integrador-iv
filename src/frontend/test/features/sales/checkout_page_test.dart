import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/sales/domain/entities/sale.dart';
import 'package:univesp_project/features/sales/presentation/pages/checkout_page.dart';
import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/settings/domain/entities/user_settings.dart';

import '../../helpers/fakes.dart';

class _Harness {
  _Harness(this.products, this.sales);

  final FakeProductRepository products;
  final FakeSalesRepository sales;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  UserSettings settings = UserSettings.defaults,
}) async {
  tester.view.physicalSize = const Size(500, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final products = FakeProductRepository([
    fakeCatalogProduct(stock: 3),
    fakeCatalogProduct(
      id: 'p-2',
      name: 'Notebook Pro 14',
      sku: 'NB-14',
      salePrice: 6000,
      costPrice: null,
    ),
    fakeCatalogProduct(id: 'p-3', name: 'Mousepad', sku: 'MP-1', stock: 0),
  ]);
  final sales = FakeSalesRepository()
    ..onCheckout = (input) {
      for (final line in input.lines) {
        products.sell(line.productId, line.quantity ?? 0);
      }
    };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(products),
        salesRepositoryProvider.overrideWithValue(sales),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
        ),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(settings),
        ),
      ],
      child: const MaterialApp(home: CheckoutPage()),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(products, sales);
}

Future<void> _add(WidgetTester tester, String search, String option) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Adicionar produto'),
    search,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sells the cart and clears it', (tester) async {
    final h = await _pump(tester);
    expect(find.text('Carrinho vazio.'), findsOneWidget);

    await _add(tester, 'mou', 'MOU-280 · 3 em estoque');
    await tester.tap(find.byTooltip('Mais um'));
    await tester.pump();
    await _add(tester, 'nb', 'NB-14 · 10 em estoque');
    await tester.enterText(
      find.widgetWithText(TextField, 'Preço unitário').last,
      '5500',
    );
    await tester.pump();

    expect(find.text('3 itens'), findsOneWidget);
    expect(find.text(brl('5.660,00')), findsOneWidget);
    expect(
      find.text('Lucro dos itens com custo: ${brl('80,00')}'),
      findsOneWidget,
    );

    await tester.tap(find.text('Finalizar venda'));
    await tester.pumpAndSettle();

    final input = h.sales.checkouts.single;
    expect(input.channel, SalesChannel.inPerson);
    expect(
      [for (final l in input.lines) (l.productId, l.quantity, l.unitPrice)],
      [('p-1', 2, 80.0), ('p-2', 1, 5500.0)],
    );
    expect(
      find.textContaining('registrada em "Vendas - outubro/2026"'),
      findsOneWidget,
    );
    expect(find.text('Carrinho vazio.'), findsOneWidget);

    // The catalog was reloaded: the next sale sees the new stock.
    await _add(tester, 'mou', 'MOU-280 · 1 em estoque');
  });

  testWidgets('quantity can not go above the stock', (tester) async {
    await _pump(tester);
    await _add(tester, 'mou', 'MOU-280 · 3 em estoque');

    await tester.tap(find.byTooltip('Mais um'));
    await tester.tap(find.byTooltip('Mais um'));
    await tester.pump();

    final plus = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add),
    );
    expect(plus.onPressed, isNull);
    expect(find.text('3 itens'), findsOneWidget);
  });

  testWidgets('products without stock can not be picked', (tester) async {
    await _pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar produto'),
      'mousepad',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP-1 · sem estoque'));
    await tester.pumpAndSettle();

    expect(find.text('Carrinho vazio.'), findsOneWidget);
  });

  testWidgets('online sales send the marketplace', (tester) async {
    final h = await _pump(tester);
    await _add(tester, 'mou', 'MOU-280 · 3 em estoque');

    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Marketplace (opcional)'),
      'Shopee',
    );
    await tester.tap(find.text('Finalizar venda'));
    await tester.pumpAndSettle();

    final input = h.sales.checkouts.single;
    expect((input.channel, input.marketplace), (SalesChannel.online, 'Shopee'));
  });

  testWidgets('shows the backend error on the line it belongs to', (
    tester,
  ) async {
    final h = await _pump(tester);
    h.sales.checkoutFailure = Failure.fromResponse(400, {
      'errors': [
        {
          'key': 'items[0].quantity',
          'message':
              'Estoque insuficiente: há 3 unidade(s) de "Mouse sem fio".',
        },
      ],
    });
    await _add(tester, 'mou', 'MOU-280 · 3 em estoque');

    await tester.tap(find.text('Finalizar venda'));
    await tester.pumpAndSettle();

    expect(
      find.text('Estoque insuficiente: há 3 unidade(s) de "Mouse sem fio".'),
      findsWidgets,
    );
    expect(find.byTooltip('Remover do carrinho'), findsOneWidget); // cart kept
  });

  testWidgets('the price rules warn on the line while typing', (tester) async {
    await _pump(tester);
    await _add(
      tester,
      'mou',
      'MOU-280 · 3 em estoque',
    ); // R$ 80,00, cost R$ 40,00
    await _add(tester, 'nb', 'NB-14 · 10 em estoque'); // R$ 6.000,00, no cost
    final mousePrice = find.widgetWithText(TextField, 'Preço unitário').first;
    final notebookPrice = find.widgetWithText(TextField, 'Preço unitário').last;
    final belowCost =
        'O preço não pode ser menor que o custo (${brl('40,00')}): '
        'a venda daria prejuízo.';
    String maxDiscount(String minimum) =>
        'O desconto não pode passar de 15% do preço do produto: o mínimo é '
        '${brl(minimum)}.';

    // Below the cost: the cost rule comes first, as in the backend.
    await tester.enterText(mousePrice, '39,99');
    await tester.pump();
    expect(find.text(belowCost), findsOneWidget);
    expect(find.text(maxDiscount('68,00')), findsNothing);

    // Above the cost, but more than 15% off R$ 80,00.
    await tester.enterText(mousePrice, '67,99');
    await tester.pump();
    expect(find.text(belowCost), findsNothing);
    expect(find.text(maxDiscount('68,00')), findsOneWidget);

    // Exactly 15% off: accepted, with the discount shown.
    await tester.enterText(mousePrice, '68');
    await tester.pump();
    expect(find.textContaining('O desconto não pode'), findsNothing);
    expect(find.text('Desconto de 15,0% (máximo 15,0%)'), findsOneWidget);

    // The discount rule holds without a cost too; a higher price is not a discount.
    await tester.enterText(notebookPrice, '5099,99');
    await tester.pump();
    expect(find.text(maxDiscount('5.100,00')), findsOneWidget);
    await tester.enterText(notebookPrice, '6500');
    await tester.pump();
    expect(find.textContaining('O desconto não pode'), findsNothing);
    expect(
      find.textContaining('Desconto de'),
      findsOneWidget,
    ); // only the mouse
  });

  group('restock warning after a sale', () {
    Future<void> sellTwoMiceAndANotebook(WidgetTester tester) async {
      await _add(tester, 'mou', 'MOU-280 · 3 em estoque');
      await tester.tap(find.byTooltip('Mais um'));
      await tester.pump();
      await _add(tester, 'nb', 'NB-14 · 10 em estoque');
      await tester.tap(find.text('Finalizar venda'));
      await tester.pumpAndSettle();
    }

    testWidgets('names the products that reached the minimum (on by default)', (
      tester,
    ) async {
      await _pump(tester);
      await sellTwoMiceAndANotebook(tester);

      // Mouse: 3 - 2 = 1, minimum 2. Notebook: 10 - 1 = 9, still fine.
      expect(
        find.textContaining('Repor estoque: Mouse sem fio (restam 1).'),
        findsOneWidget,
      );
      expect(find.textContaining('Notebook Pro 14 ('), findsNothing);
    });

    testWidgets('selling the last unit says it is out of stock', (
      tester,
    ) async {
      await _pump(tester);
      await _add(tester, 'mou', 'MOU-280 · 3 em estoque');
      await tester.tap(find.byTooltip('Mais um'));
      await tester.pump();
      await tester.tap(find.byTooltip('Mais um'));
      await tester.pump();
      await tester.tap(find.text('Finalizar venda'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Repor estoque: Mouse sem fio (sem estoque).'),
        findsOneWidget,
      );
    });

    testWidgets('no warning when the user turned it off', (tester) async {
      await _pump(tester, settings: const UserSettings(notifyRestock: false));
      await sellTwoMiceAndANotebook(tester);

      expect(find.textContaining('registrada em'), findsOneWidget);
      expect(find.textContaining('Repor estoque'), findsNothing);
    });
  });
}
