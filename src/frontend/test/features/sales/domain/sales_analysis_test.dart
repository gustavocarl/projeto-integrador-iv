import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_import.dart';
import 'package:univesp_project/features/sales/domain/services/sales_analysis.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('movingAverage', () {
    test('centers a 7-day window and shrinks it at the edges', () {
      final avg = SalesAnalysis.movingAverage([7, 0, 0, 0, 0, 0, 0, 7]);

      expect(avg.length, 8);
      expect(avg.first, 7 / 4); // days 1-4
      expect(avg[3], 1); // days 1-7
      expect(avg[4], 1); // days 2-8
      expect(avg.last, 7 / 4); // days 5-8
    });

    test('a constant series stays constant', () {
      expect(SalesAnalysis.movingAverage([5, 5, 5]), [5, 5, 5]);
    });
  });

  group('compareHalves', () {
    test('compares the average per day of each half', () {
      final c = SalesAnalysis.compareHalves([100, 100, 200, 300])!;

      expect((c.firstDays, c.firstAverage, c.secondAverage), (2, 100, 250));
      expect(c.change, 1.5);
      expect(c.direction, TrendDirection.up);
    });

    test('an odd day goes to the second half', () {
      final c = SalesAnalysis.compareHalves([10, 10, 10])!;
      expect(c.firstDays, 1);
      expect(c.direction, TrendDirection.stable);
    });

    test('small changes are stable, bigger drops are down', () {
      expect(
        SalesAnalysis.compareHalves([100, 97])!.direction,
        TrendDirection.stable,
      );
      expect(
        SalesAnalysis.compareHalves([100, 90])!.direction,
        TrendDirection.down,
      );
    });

    test('starting from zero has no percentage', () {
      final c = SalesAnalysis.compareHalves([0, 50])!;
      expect(c.change, isNull);
      expect(c.direction, TrendDirection.up);
    });

    test('needs at least two days', () {
      expect(SalesAnalysis.compareHalves([10]), isNull);
    });
  });

  test(
    'platforms = physical store + marketplaces + own online store',
    () async {
      final repository = FakeSalesRepository([fakeImport()]);
      final detail = await repository.getImport('imp-1');

      final platforms = SalesAnalysis.platforms(detail);

      expect(platforms.map((p) => p.name), [
        'Loja física',
        'Mercado Livre',
        'Loja virtual própria',
      ]);
      // Together they are the whole import.
      final total = platforms.fold<double>(0, (s, p) => s + p.revenue);
      expect(total, closeTo(38015.6, 0.01));
      expect(platforms.first, isA<BreakdownItem>());
    },
  );
}
