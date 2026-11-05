import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/sales/domain/entities/sale.dart';
import 'package:univesp_project/features/sales/presentation/pages/sales_import_detail_page.dart';

import '../../helpers/fakes.dart';

Future<FakeSalesRepository> _openSalesTab(
  WidgetTester tester, {
  List<Sale>? sales,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  addTearDown(tester.view.reset);

  final repo = FakeSalesRepository([fakeImport()]);
  repo.sales['imp-1'] =
      sales ??
      [
        fakeSale(id: 's1', product: 'Camiseta', rowNumber: 2),
        fakeSale(
          id: 's2',
          product: 'Tênis Corrida',
          quantity: 2,
          unitPrice: 299,
        ),
      ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [salesRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: SalesImportDetailPage(salesImport: fakeImport()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Vendas').last);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('lists the sales with origin and total', (tester) async {
    await _openSalesTab(tester);

    expect(find.text('2 vendas'), findsOneWidget);
    expect(find.text('Camiseta'), findsOneWidget);
    expect(find.text('Linha 2 da planilha'), findsOneWidget);
    expect(find.text('Lançada por maria@exemplo.com'), findsOneWidget);
    expect(find.text('R\$ 598,00'), findsOneWidget);
  });

  testWidgets(
    'a typed-in sale linked to a product by SKU is not shown as a checkout sale',
    (tester) async {
      await _openSalesTab(
        tester,
        sales: [
          fakeSale(id: 's1', product: 'Mouse', productId: 'p-1'),
          fakeSale(
            id: 's2',
            product: 'Teclado',
            productId: 'p-2',
            isCheckout: true,
          ),
        ],
      );

      expect(find.text('Lançada por maria@exemplo.com'), findsOneWidget);
      expect(
        find.text('Vendida no caixa por maria@exemplo.com'),
        findsOneWidget,
      );
    },
  );

  testWidgets('deletes a single sale after confirmation', (tester) async {
    final repo = await _openSalesTab(tester);

    await tester.tap(find.byTooltip('Excluir venda').first);
    await tester.pumpAndSettle();
    expect(find.text('Excluir venda?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(repo.deletedSales, ['s1']);
    expect(find.text('Camiseta'), findsNothing);
    expect(find.text('1 venda'), findsOneWidget);
    expect(find.text('Venda excluída.'), findsOneWidget);
  });

  testWidgets('cancelling keeps the sale', (tester) async {
    final repo = await _openSalesTab(tester);

    await tester.tap(find.byTooltip('Excluir venda').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.deletedSales, isEmpty);
    expect(find.text('2 vendas'), findsOneWidget);
  });

  testWidgets('searches by product', (tester) async {
    await _openSalesTab(tester);

    await tester.enterText(find.byType(TextField), 'tênis');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('1 venda'), findsOneWidget);
    expect(find.text('Camiseta'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma venda encontrada para "xyz".'), findsOneWidget);
  });
}
