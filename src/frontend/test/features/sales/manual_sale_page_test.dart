import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_export_repository_impl.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/sales/domain/entities/sale.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_period.dart';
import 'package:univesp_project/features/sales/presentation/pages/sales_imports_page.dart';

import '../../helpers/fakes.dart';

Future<FakeSalesRepository> _openForm(
  WidgetTester tester, {
  FakeSalesRepository? repository,
  FakeSalesExportRepository? exports,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  addTearDown(tester.view.reset);

  final repo = repository ?? FakeSalesRepository([fakeImport()]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        salesRepositoryProvider.overrideWithValue(repo),
        fileServiceProvider.overrideWithValue(FakeFileService()),
        salesExportRepositoryProvider.overrideWithValue(
          exports ?? FakeSalesExportRepository(),
        ),
        // An admin: generating spreadsheets (Exportar) is allowed.
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(sessionUser: FakeAuthRepository.maria),
        ),
      ],
      child: const MaterialApp(home: SalesImportsPage()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lançar venda'));
  await tester.pumpAndSettle();
  return repo;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  testWidgets('saves a sale in a new manual batch and shows it in the list', (
    tester,
  ) async {
    final repo = await _openForm(tester);

    await tester.enterText(_field('Produto'), 'Mouse sem fio');
    await tester.enterText(_field('Quantidade'), '2');
    await tester.enterText(_field('Preço unitário'), '1.234,50');
    await tester.pump();
    expect(find.text('Total: R\$ 2.469,00'), findsOneWidget);

    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Marketplace (opcional)'), 'Amazon');
    await tester.tap(find.text('Salvar venda'));
    await tester.pumpAndSettle();

    final input = repo.manualInputs.single;
    expect(input.importId, isNull);
    expect(input.importName, startsWith('Vendas manuais - '));
    expect(
      (input.productName, input.quantity, input.unitPrice, input.channel),
      ('Mouse sem fio', 2, 1234.5, SalesChannel.online),
    );
    expect(input.marketplace, 'Amazon');

    // Back on the list, with the new batch on top.
    expect(find.textContaining('Venda lançada em "Vendas manuais'), findsOne);
    expect(find.byIcon(Icons.edit_note), findsWidgets);
  });

  testWidgets('marketplace is only asked for online sales', (tester) async {
    await _openForm(tester);

    expect(_field('Marketplace (opcional)'), findsNothing);
    await tester.tap(find.text('Presencial'));
    await tester.pumpAndSettle();
    expect(_field('Marketplace (opcional)'), findsNothing);
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    expect(_field('Marketplace (opcional)'), findsOneWidget);
  });

  testWidgets('backend errors appear under their fields', (tester) async {
    final repo = FakeSalesRepository([fakeImport()])
      ..manualFailure = const Failure(
        'Dados inválidos.',
        statusCode: 400,
        errors: [
          FieldError('productName', 'O produto é obrigatório.'),
          FieldError(
            'channel',
            'O canal é obrigatório (Presencial ou Online).',
          ),
        ],
      );
    await _openForm(tester, repository: repo);

    await tester.tap(find.text('Salvar venda'));
    await tester.pumpAndSettle();

    expect(find.text('O produto é obrigatório.'), findsOneWidget);
    expect(
      find.text('O canal é obrigatório (Presencial ou Online).'),
      findsOneWidget,
    );
    expect(find.text('Lançar venda'), findsOneWidget); // still on the form
  });

  testWidgets(
    '"Salvar e lançar outra" keeps the batch and clears the product',
    (tester) async {
      final repo = await _openForm(tester);

      await tester.enterText(_field('Produto'), 'Cabo USB-C');
      await tester.enterText(_field('Preço unitário'), '29,90');
      await tester.tap(find.text('Presencial'));
      await tester.tap(find.text('Salvar e lançar outra'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Lance a próxima'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('Produto')).controller!.text,
        isEmpty,
      );

      await tester.enterText(_field('Produto'), 'Pen drive');
      await tester.tap(find.text('Salvar e lançar outra'));
      await tester.pumpAndSettle();

      // The second sale goes to the batch the first one created.
      expect(repo.manualInputs[1].importId, 'manual-1');
      expect(repo.manualInputs[1].channel, SalesChannel.inPerson);
    },
  );

  testWidgets('after a sale, "Gerar planilha" generates the day of the sale', (
    tester,
  ) async {
    final exports = FakeSalesExportRepository();
    await _openForm(tester, exports: exports);

    await tester.enterText(_field('Produto'), 'Cabo USB-C');
    await tester.enterText(_field('Preço unitário'), '29,90');
    await tester.tap(find.text('Presencial'));
    await tester.tap(find.text('Salvar e lançar outra'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gerar planilha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baixar'));
    await tester.pumpAndSettle();

    expect(exports.createdPeriods, [
      SalesPeriod.of(PeriodKind.day, DateTime.now()),
    ]);
    expect(find.textContaining('Ela fica em Exportações'), findsOneWidget);
  });

  testWidgets('the form also generates spreadsheets from its app bar', (
    tester,
  ) async {
    final exports = FakeSalesExportRepository();
    await _openForm(tester, exports: exports);

    await tester.tap(find.byTooltip('Gerar planilha de vendas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baixar'));
    await tester.pumpAndSettle();

    expect(exports.createdPeriods, [
      SalesPeriod.of(PeriodKind.month, DateTime.now()),
    ]);
  });

  testWidgets('can add the sale to an existing batch', (tester) async {
    final repo = await _openForm(tester);

    await tester.tap(find.text('+ Novo lote manual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vendas-outubro.xlsx').last);
    await tester.pumpAndSettle();
    expect(_field('Nome do novo lote'), findsNothing);

    await tester.enterText(_field('Produto'), 'Boné');
    await tester.tap(find.text('Salvar venda'));
    await tester.pumpAndSettle();

    expect(repo.manualInputs.single.importId, 'imp-1');
    expect(repo.manualInputs.single.importName, isNull);
  });
}
