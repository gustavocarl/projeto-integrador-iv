import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_export_repository_impl.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_period.dart';
import 'package:univesp_project/features/sales/presentation/pages/sales_exports_page.dart';

import '../../helpers/fakes.dart';

Future<(FakeSalesExportRepository, FakeFileService)> _pump(
  WidgetTester tester, {
  FakeSalesExportRepository? repository,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  addTearDown(tester.view.reset);

  final repo = repository ?? FakeSalesExportRepository();
  final files = FakeFileService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loggedInStore,
        salesExportRepositoryProvider.overrideWithValue(repo),
        fileServiceProvider.overrideWithValue(files),
      ],
      child: const MaterialApp(home: SalesExportsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, files);
}

void main() {
  testWidgets('shows the empty state', (tester) async {
    await _pump(tester);

    expect(find.text('Nenhuma planilha gerada'), findsOneWidget);
  });

  testWidgets('lists the generated spreadsheets and downloads one again', (
    tester,
  ) async {
    final (repo, files) = await _pump(
      tester,
      repository: FakeSalesExportRepository([fakeExport()]),
    );

    expect(find.text('novembro/2026'), findsOneWidget);
    expect(find.textContaining('42 vendas'), findsOneWidget);
    expect(find.textContaining('maria@exemplo.com'), findsOneWidget);

    await tester.tap(find.byTooltip('Baixar'));
    await tester.pumpAndSettle();

    expect(repo.downloads, ['exp-1']);
    expect(files.saved, ['vendas-2026-11.xlsx']);
  });

  testWidgets('generates the spreadsheet of the chosen week', (tester) async {
    final (repo, files) = await _pump(tester);

    await tester.tap(find.text('Gerar planilha'));
    await tester.pumpAndSettle();
    // The month is the default.
    expect(
      tester.widget<Text>(find.byKey(const Key('salesSpreadsheetPeriod'))).data,
      SalesPeriod.of(PeriodKind.month, DateTime.now()).label,
    );

    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();
    expect(find.text('Semana de segunda a domingo.'), findsOneWidget);
    await tester.tap(find.text('Baixar'));
    await tester.pumpAndSettle();

    final week = SalesPeriod.of(PeriodKind.week, DateTime.now());
    expect(repo.createdPeriods, [week]);
    expect(files.saved, [week.fileName]);
    expect(find.textContaining('Ela fica em Exportações'), findsOneWidget);
    expect(find.text(week.label), findsOneWidget);
  });

  testWidgets('a period without sales shows the backend message', (
    tester,
  ) async {
    final repo = FakeSalesExportRepository()
      ..createFailure = const Failure(
        'Não há vendas em novembro/2026.',
        statusCode: 404,
        errors: [FieldError('', 'Não há vendas em novembro/2026.')],
      );
    final (_, files) = await _pump(tester, repository: repo);

    await tester.tap(find.text('Gerar planilha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baixar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não há vendas em novembro/2026.'),
      findsWidgets,
    );
    expect(files.saved, isEmpty);
    expect(find.text('Nenhuma planilha gerada'), findsOneWidget);
  });

  testWidgets('deleting asks first and keeps the sales', (tester) async {
    final (repo, _) = await _pump(
      tester,
      repository: FakeSalesExportRepository([fakeExport()]),
    );

    await tester.tap(find.byTooltip('Excluir'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('As vendas continuam no sistema'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['exp-1']);
    expect(find.text('Nenhuma planilha gerada'), findsOneWidget);
  });
}
