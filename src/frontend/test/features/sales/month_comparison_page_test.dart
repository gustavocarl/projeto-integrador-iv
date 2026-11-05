import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/sales/presentation/pages/month_comparison_page.dart';

import '../../helpers/fakes.dart';

Future<FakeSalesRepository> _pump(
  WidgetTester tester, {
  required List<String> months,
  double width = 1100,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = FakeSalesRepository()
    ..months = [for (final m in months) fakeMonth(m, 'mês $m', 1000)];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [salesRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: MonthComparisonPage())),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('opens with the same month of the year before', (tester) async {
    final repository = await _pump(
      tester,
      months: ['2026-10', '2026-09', '2025-10'],
    );

    expect(repository.compared, [('2025-10', '2026-10')]);
    expect(find.text('alvo 2026-10 comparado a base 2025-10'), findsOneWidget);
    // Revenue: R$ 1.000,00 → R$ 1.500,00.
    expect(
      find.text('+50,0% sobre base 2025-10 (${brl('1.000,00')})'),
      findsOneWidget,
    );
    expect(find.text('Tênis Corrida'), findsWidgets);
  });

  testWidgets('shortcut compares with the previous month', (tester) async {
    final repository = await _pump(
      tester,
      months: ['2026-10', '2026-09', '2025-10'],
    );

    await tester.tap(find.text('Mês anterior'));
    await tester.pumpAndSettle();

    expect(repository.compared.last, ('2026-09', '2026-10'));
  });

  testWidgets('swap inverts the months', (tester) async {
    final repository = await _pump(tester, months: ['2026-10', '2026-09']);

    await tester.tap(find.byTooltip('Inverter meses'));
    await tester.pumpAndSettle();

    expect(repository.compared.last, ('2026-10', '2026-09'));
  });

  testWidgets('shortcut without sales in that month is disabled', (
    tester,
  ) async {
    await _pump(tester, months: ['2026-10', '2026-09']);

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Mesmo mês do ano anterior'),
    );
    expect(chip.onSelected, isNull);
  });

  testWidgets('needs two months with sales', (tester) async {
    final repository = await _pump(tester, months: ['2026-10']);

    expect(
      find.text(
        'Para comparar, é preciso ter vendas em pelo menos dois meses.',
      ),
      findsOneWidget,
    );
    expect(find.text('Há vendas só em mês 2026-10.'), findsOneWidget);
    expect(repository.compared, isEmpty);
  });

  testWidgets('phone layout fits without overflow', (tester) async {
    await _pump(tester, months: ['2026-10', '2025-10'], width: 360);

    expect(tester.takeException(), isNull);
    expect(find.text('Comparar com'), findsOneWidget);
  });
}
