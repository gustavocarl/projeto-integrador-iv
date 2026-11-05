import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:univesp_project/features/analytics/presentation/pages/analytics_page.dart';
import 'package:univesp_project/features/analytics/presentation/widgets/forecast_tab.dart';
import 'package:univesp_project/features/analytics/presentation/widgets/product_groups_tab.dart';
import 'package:univesp_project/shared/widgets/charts/scatter_chart.dart';
import 'package:univesp_project/shared/widgets/charts/time_series_chart.dart';

import '../../helpers/fakes.dart';

Future<FakeAnalyticsRepository> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 740),
  Failure? failure,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = FakeAnalyticsRepository()..failure = failure;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [analyticsRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: AnalyticsPage())),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// The vertical list of the forecast tab (the TabBarView scrolls sideways too).
Finder get _list => find
    .descendant(of: find.byType(ForecastTab), matching: find.byType(Scrollable))
    .first;

void main() {
  testWidgets(
    'forecast: the next 3 months by default, with totals, chart and what to buy',
    (tester) async {
      final repository = await _pump(tester);

      expect(repository.forecastCalls, [3]);
      expect(
        find.text('Previsão para dezembro/2026 a fevereiro/2027'),
        findsOneWidget,
      );
      // 33 mice + 15 cables + 6 cases.
      expect(find.text('54'), findsOneWidget);
      expect(find.text('12,0%'), findsOneWidget);

      // Below the fold on a phone: built once scrolled to.
      await tester.scrollUntilVisible(
        find.byType(TimeSeriesChart),
        300,
        scrollable: _list,
      );
      final chart = tester.widget<TimeSeriesChart>(
        find.byType(TimeSeriesChart),
      );
      expect(chart.points, hasLength(6));
      expect(chart.highlightFrom, 3);

      await tester.scrollUntilVisible(
        find.text('Mouse sem fio'),
        300,
        scrollable: _list,
      );
      expect(find.text('Comprar 30'), findsOneWidget);
      expect(find.text('dez/26: 10 · jan/27: 11 · fev/27: 12'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Estoque cobre'),
        300,
        scrollable: _list,
      );
      expect(
        find.text('Fora do cadastro: sem estoque para comparar'),
        findsOneWidget,
      );
    },
  );

  testWidgets('forecast: only the products to buy, and another horizon', (
    tester,
  ) async {
    final repository = await _pump(tester, size: const Size(1000, 900));

    await tester.scrollUntilVisible(
      find.byKey(const Key('forecastOnlyToBuy')),
      300,
      scrollable: _list,
    );
    await tester.tap(find.byKey(const Key('forecastOnlyToBuy')));
    await tester.pumpAndSettle();
    expect(find.text('Mouse sem fio'), findsOneWidget);
    expect(find.text('Cabo USB-C'), findsNothing);
    expect(find.text('Capa de celular'), findsNothing);

    await tester.drag(_list, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forecastMonths1')));
    await tester.pumpAndSettle();
    expect(repository.forecastCalls, [3, 1]);
    expect(find.text('Previsão para dezembro/2026'), findsOneWidget);
  });

  testWidgets('without enough history: the explanation, not an error', (
    tester,
  ) async {
    await _pump(
      tester,
      failure: const Failure(
        'Recurso não encontrado.',
        statusCode: 404,
        errors: [
          FieldError(
            '',
            'A previsão precisa de pelo menos 3 meses completos de vendas e há só 1.',
          ),
        ],
      ),
    );

    expect(find.text('Ainda não dá para prever'), findsOneWidget);
    expect(find.textContaining('há só 1. Importe planilhas'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets(
    'groups: automatic, the chart highlights the chosen group, another number',
    (tester) async {
      final repository = await _pump(tester);
      await tester.tap(find.text('Grupos de produtos'));
      await tester.pumpAndSettle();

      expect(repository.groupsCalls, [null]);
      expect(find.text('4 produtos em 2 grupos'), findsOneWidget);
      expect(find.text('0,58'), findsOneWidget);
      expect(find.text('escolhido automaticamente'), findsOneWidget);

      List<bool> highlighted() => tester
          .widget<ScatterChart>(find.byType(ScatterChart))
          .points
          .map((p) => p.highlighted)
          .toList();
      expect(highlighted(), [true, true, false, false]);

      final groupsList = find
          .descendant(
            of: find.byType(ProductGroupsTab),
            matching: find.byType(Scrollable),
          )
          .last;
      await tester.scrollUntilVisible(
        find.text('2 · Alto giro'),
        200,
        scrollable: groupsList,
      );
      await tester.ensureVisible(find.text('2 · Alto giro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 · Alto giro'));
      await tester.pumpAndSettle();
      expect(highlighted(), [false, false, true, true]);

      await tester.drag(groupsList, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('productGroups3')));
      await tester.pumpAndSettle();
      expect(repository.groupsCalls, [null, 3]);
      expect(find.text('5 produtos em 3 grupos'), findsOneWidget);
      expect(find.text('escolhido por você'), findsOneWidget);
    },
  );
}
