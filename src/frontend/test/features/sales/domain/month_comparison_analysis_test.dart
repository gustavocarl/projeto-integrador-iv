import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/utils/formatters.dart';
import 'package:univesp_project/features/sales/domain/entities/month_comparison.dart';
import 'package:univesp_project/features/sales/domain/services/month_comparison_analysis.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('growth', () {
    test('is relative to the base month', () {
      expect(MonthComparisonAnalysis.growth(1000, 1500), 0.5);
      expect(MonthComparisonAnalysis.growth(1000, 800), closeTo(-0.2, 1e-9));
    });

    test('is null without a base to grow from', () {
      expect(MonthComparisonAnalysis.growth(0, 100), isNull);
    });

    test('formats with its sign', () {
      expect(Formatters.signedPercent(0.123), '+12,3%');
      expect(Formatters.signedPercent(-0.08), '−8,0%');
      expect(Formatters.signedPercent(0.00001), '0,0%');
    });
  });

  test('previous month and same month last year cross the year', () {
    expect(MonthComparisonAnalysis.previousMonth('2026-01'), '2025-12');
    expect(MonthComparisonAnalysis.previousMonth('2026-10'), '2026-09');
    expect(MonthComparisonAnalysis.sameMonthLastYear('2026-01'), '2025-01');
  });

  group('defaultPair', () {
    test('prefers the same month of the year before', () {
      final months = [
        fakeMonth('2026-01', 'janeiro/2026', 1),
        fakeMonth('2025-12', 'dezembro/2025', 1),
        fakeMonth('2025-01', 'janeiro/2025', 1),
      ];
      expect(MonthComparisonAnalysis.defaultPair(months), (
        base: '2025-01',
        target: '2026-01',
      ));
    });

    test('falls back to the previous month with sales', () {
      final months = [
        fakeMonth('2026-10', 'outubro/2026', 1),
        fakeMonth('2026-08', 'agosto/2026', 1),
      ];
      expect(MonthComparisonAnalysis.defaultPair(months), (
        base: '2026-08',
        target: '2026-10',
      ));
    });

    test('needs two months', () {
      expect(
        MonthComparisonAnalysis.defaultPair([
          fakeMonth('2026-10', 'outubro/2026', 1),
        ]),
        isNull,
      );
    });
  });

  test('cumulative stops past the month end and the elapsed days', () {
    const one = PeriodTotals(sales: 1, quantity: 1, revenue: 10);
    final days = [
      const DayComparison(day: 1, base: one, target: one),
      const DayComparison(day: 2, base: one, target: one),
      const DayComparison(day: 3, target: one),
    ];

    expect(
      MonthComparisonAnalysis.cumulative(
        days,
        (d) => d.base,
        (t) => t.revenue,
        elapsedDays: 31,
      ),
      [10, 20, null],
    );
    expect(
      MonthComparisonAnalysis.cumulative(
        days,
        (d) => d.target,
        (t) => t.revenue,
        elapsedDays: 2,
      ),
      [10, 20, null],
    );
  });

  test('movers split growth and decline, biggest change first', () {
    final movers = MonthComparisonAnalysis.movers(
      fakeComparison().products,
      (t) => t.revenue,
    );
    expect(movers.risers.map((p) => p.name), ['Tênis Corrida']);
    expect(movers.fallers.map((p) => p.name), ['Jaqueta']);
  });

  test('platforms rename the physical and the own online store', () {
    expect(
      MonthComparisonAnalysis.platforms(fakeComparison()).map((p) => p.name),
      ['Loja física', 'Mercado Livre', 'Loja virtual própria'],
    );
  });
}
