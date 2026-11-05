import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/core/utils/formatters.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_import.dart';
import 'package:univesp_project/features/sales/presentation/pages/sales_imports_page.dart';
import 'package:univesp_project/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:univesp_project/features/settings/domain/entities/user_settings.dart';
import 'package:univesp_project/shared/widgets/charts/horizontal_bar_chart.dart';
import 'package:univesp_project/shared/widgets/charts/share_bar_chart.dart';
import 'package:univesp_project/shared/widgets/charts/time_series_chart.dart';

import '../../helpers/fakes.dart';

class _Harness {
  _Harness(this.repository, this.files);

  final FakeSalesRepository repository;
  final FakeFileService files;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  FakeSalesRepository? repository,
  UserSettings settings = UserSettings.defaults,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  addTearDown(tester.view.reset);

  final harness = _Harness(
    repository ?? FakeSalesRepository(),
    FakeFileService(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        salesRepositoryProvider.overrideWithValue(harness.repository),
        fileServiceProvider.overrideWithValue(harness.files),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
        ),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(settings),
        ),
      ],
      child: const MaterialApp(home: SalesImportsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// The vertical list of the visible tab (the tab view itself also scrolls, sideways).
final _tabList = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  testWidgets('shows the empty state', (tester) async {
    await _pump(tester);

    expect(find.text('Nenhuma venda ainda.'), findsOneWidget);
  });

  testWidgets('lists imports with Brazilian formatting', (tester) async {
    await _pump(tester, repository: FakeSalesRepository([fakeImport()]));

    expect(find.text('vendas-outubro.xlsx'), findsOneWidget);
    expect(
      find.textContaining(
        'R\$ 38.015,60 · 112 vendas · 01/10/2026 a 28/10/2026',
      ),
      findsOneWidget,
    );
  });

  testWidgets('importing a valid spreadsheet adds it to the list', (
    tester,
  ) async {
    final h = await _pump(tester);
    h.files.fileToPick = PickedFile(name: 'novembro.xlsx', bytes: Uint8List(1));

    await tester.tap(find.text('Selecionar planilha'));
    await tester.pumpAndSettle();

    expect(find.text('novembro.xlsx'), findsOneWidget);
    expect(find.textContaining('Planilha importada: 3 vendas'), findsOneWidget);
    expect(find.textContaining('produtos cadastrados'), findsNothing);
  });

  testWidgets('says the setting is off by default and opens Preferências', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('SKUs novos não viram produtos.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Preferências'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Preferências'), findsOneWidget);
  });

  testWidgets('with the setting on, says how many products were registered', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      settings: const UserSettings(createProductsOnImport: true),
    );
    h.files.fileToPick = PickedFile(name: 'novembro.xlsx', bytes: Uint8List(1));
    h.repository.productsToCreate = 2;
    expect(find.text('SKUs novos viram produtos.'), findsOneWidget);

    await tester.tap(find.text('Selecionar planilha'));
    await tester.pumpAndSettle();

    expect(find.textContaining('; 2 produtos cadastrados.'), findsOneWidget);
  });

  testWidgets('row errors are listed in a dialog and nothing is added', (
    tester,
  ) async {
    final h = await _pump(tester);
    h.files.fileToPick = PickedFile(name: 'erros.xlsx', bytes: Uint8List(1));
    h.repository.importFailure = const Failure(
      'Dados inválidos.',
      statusCode: 400,
      errors: [
        FieldError('', 'Linha 3: Venda presencial não pode ter marketplace.'),
        FieldError('', 'Linha 4: O produto é obrigatório.'),
      ],
    );

    await tester.tap(find.text('Selecionar planilha'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Linha 3: Venda presencial não pode ter marketplace.'),
      findsOneWidget,
    );
    expect(find.text('Linha 4: O produto é obrigatório.'), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma venda ainda.'), findsOneWidget);
  });

  testWidgets('cancelling the file picker does nothing', (tester) async {
    final h = await _pump(tester);

    await tester.tap(find.text('Selecionar planilha'));
    await tester.pumpAndSettle();

    expect(h.repository.imports, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('downloads the template', (tester) async {
    final h = await _pump(tester);

    await tester.tap(find.text('Baixar modelo'));
    await tester.pumpAndSettle();

    expect(h.files.saved, ['modelo-vendas.xlsx']);
    expect(find.text('Modelo de planilha salvo.'), findsOneWidget);
  });

  test('the deletion message says what goes away', () {
    expect(
      deletionMessage(
        'outubro.xlsx',
        const BatchDeletionImpact(
          salesCount: 112,
          totalRevenue: 38015.6,
          linkedProducts: 8,
          stockReturned: 0,
        ),
      ),
      'As 112 vendas de "outubro.xlsx" (${Formatters.currency(38015.6)}) serão removidas e saem '
      'dos relatórios e do comparativo de meses.\n\n'
      'Elas estão ligadas a 8 produtos cadastrados. Os produtos continuam no '
      'catálogo, mas sem essas vendas no histórico.\n\n'
      'Esta ação não pode ser desfeita.',
    );
    expect(
      deletionMessage(
        'Vendas - novembro/2026',
        const BatchDeletionImpact(
          salesCount: 1,
          totalRevenue: 80,
          linkedProducts: 1,
          stockReturned: 1,
        ),
      ),
      'A venda de "Vendas - novembro/2026" (${Formatters.currency(80)}) será removida e sai '
      'dos relatórios e do comparativo de meses.\n\n'
      'Ela está ligada a 1 produto cadastrado. O produto continua no '
      'catálogo, mas sem essas vendas no histórico.\n\n'
      '1 unidade vendida no caixa volta para o estoque.\n\n'
      'Esta ação não pode ser desfeita.',
    );
  });

  testWidgets('the confirmation shows the linked products and the stock', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      repository: FakeSalesRepository([fakeImport()])
        ..deletionImpact = const BatchDeletionImpact(
          salesCount: 112,
          totalRevenue: 38015.6,
          linkedProducts: 8,
          stockReturned: 5,
        ),
    );

    await tester.tap(find.byTooltip('Excluir lote'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ligadas a 8 produtos cadastrados'),
      findsOneWidget,
    );
    expect(find.textContaining('5 unidades vendidas no caixa'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(h.repository.imports, hasLength(1));
  });

  testWidgets('if the impact cannot be loaded, nothing is removed', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      repository: FakeSalesRepository([fakeImport()])
        ..deletionImpactFailure = const Failure('Sem conexão com o servidor.'),
    );

    await tester.tap(find.byTooltip('Excluir lote'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir lote?'), findsNothing);
    expect(find.text('Sem conexão com o servidor.'), findsWidgets);
    expect(h.repository.imports, hasLength(1));
  });

  testWidgets('deletes after confirmation', (tester) async {
    final h = await _pump(
      tester,
      repository: FakeSalesRepository([fakeImport()]),
    );

    await tester.tap(find.byTooltip('Excluir lote'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(h.repository.imports, isEmpty);
    expect(find.text('Nenhuma venda ainda.'), findsOneWidget);
  });

  testWidgets('opens the detail with channel and platform charts', (
    tester,
  ) async {
    await _pump(tester, repository: FakeSalesRepository([fakeImport()]));

    await tester.tap(find.text('vendas-outubro.xlsx'));
    await tester.pumpAndSettle();

    expect(find.byType(ShareBarChart), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(HorizontalBarChart),
      200,
      scrollable: _tabList,
    );
    expect(find.byType(HorizontalBarChart), findsOneWidget);
    expect(find.text('Faturamento por canal'), findsOneWidget);
    // Direct label + legend: Presencial is 11.950,40 of 38.015,60.
    // Direct label (only the % fits at phone width in the test font).
    expect(find.textContaining('31,4%'), findsWidgets);
    // In the channel legend and on the "Loja física" platform bar.
    expect(find.text('R\$\u00a011.950,40'), findsNWidgets(2));
    // Platforms: physical store, marketplaces and own online store.
    expect(find.text('Faturamento por plataforma'), findsOneWidget);
    expect(find.text('Loja física'), findsOneWidget);
    expect(find.text('Mercado Livre'), findsOneWidget);
    expect(find.text('Loja virtual própria'), findsOneWidget);
  });

  testWidgets('trend tab shows the daily chart and the half comparison', (
    tester,
  ) async {
    await _pump(tester, repository: FakeSalesRepository([fakeImport()]));
    await tester.tap(find.text('vendas-outubro.xlsx'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Evolução'));
    await tester.pumpAndSettle();

    expect(find.byType(TimeSeriesChart), findsOneWidget);
    expect(find.text('Faturamento por dia'), findsOneWidget);
    // Days 1-2 average 100, days 3-4 average 250.
    await tester.scrollUntilVisible(
      find.text('Melhor dia'),
      200,
      scrollable: _tabList,
    );
    expect(find.text('Alta de 150,0% na 2ª metade'), findsOneWidget);
    expect(find.text('qui, 01/10'), findsOneWidget); // worst day
    expect(find.text('dom, 04/10'), findsOneWidget); // best day
  });

  testWidgets('products tab ranks products and suggests stock actions', (
    tester,
  ) async {
    await _pump(tester, repository: FakeSalesRepository([fakeImport()]));
    await tester.tap(find.text('vendas-outubro.xlsx'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Produtos'));
    await tester.pumpAndSettle();

    // 3 products: a single ranking instead of top/bottom lists.
    expect(find.text('Produtos por faturamento'), findsOneWidget);
    expect(find.text('Mais vendidos'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Avaliar saída (1)'),
      200,
      scrollable: _tabList,
    );
    expect(find.text('1 produto · 78,1% do faturamento'), findsOneWidget);
    // Removal candidates start expanded.
    expect(find.text('Meia (par)'), findsWidgets);
    expect(find.text('Priorizar (1)'), findsOneWidget);
  });

  testWidgets('switching the metric redraws the charts', (tester) async {
    await _pump(tester, repository: FakeSalesRepository([fakeImport()]));
    await tester.tap(find.text('vendas-outubro.xlsx'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Itens'));
    await tester.pumpAndSettle();

    expect(find.text('Itens por canal'), findsOneWidget);
    // Channel legend and the "Loja física" platform bar.
    expect(find.text('101 itens'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('Itens por plataforma'),
      200,
      scrollable: _tabList,
    );
    expect(find.text('Itens por plataforma'), findsOneWidget);

    // The metric is kept when switching tabs.
    await tester.tap(find.text('Evolução'));
    await tester.pumpAndSettle();
    expect(find.text('Itens por dia'), findsOneWidget);
  });
}
