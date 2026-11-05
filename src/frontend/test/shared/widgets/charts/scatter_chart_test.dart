import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/shared/widgets/charts/scatter_chart.dart';

void main() {
  test(
    'log ticks: 1, 2 and 5 of each power of ten, the range rounded to powers',
    () {
      final axis = ScatterChart.logTicks([3, 40, 700], maxTicks: 12);

      expect((axis.min, axis.max), (1.0, 1000.0));
      expect(axis.ticks, [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]);
    },
  );

  test('log ticks: only the powers of ten when there is no room for more', () {
    final axis = ScatterChart.logTicks([30, 5000], maxTicks: 4);

    expect(axis.ticks, [10, 100, 1000, 10000]);
  });

  test('log ticks: a single value still gets a range around it', () {
    final axis = ScatterChart.logTicks([10, 10]);

    expect((axis.min, axis.max), (1.0, 100.0));
  });
}
