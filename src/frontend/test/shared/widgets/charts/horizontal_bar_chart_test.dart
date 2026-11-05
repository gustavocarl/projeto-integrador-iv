import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/shared/widgets/charts/horizontal_bar_chart.dart';

void main() {
  group('niceTicks', () {
    test('covers the maximum with round steps', () {
      expect(HorizontalBarChart.niceTicks(7244.9), [0, 2000, 4000, 6000, 8000]);
      expect(HorizontalBarChart.niceTicks(45), [0, 20, 40, 60]);
      expect(HorizontalBarChart.niceTicks(100), [0, 25, 50, 75, 100]);
    });

    test('handles zero', () {
      expect(HorizontalBarChart.niceTicks(0), [0, 1]);
    });
  });

  testWidgets('bar length is proportional to the value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: HorizontalBarChart(
              data: const [
                BarDatum(label: 'A', value: 100, valueText: '100'),
                BarDatum(label: 'B', value: 50, valueText: '50'),
              ],
              axisLabel: (v) => v.toStringAsFixed(0),
            ),
          ),
        ),
      ),
    );

    final bars = tester
        .widgetList<Container>(
          find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        )
        .map((c) => (c.constraints?.maxWidth ?? 0))
        .toList();
    expect(bars.length, 2);
    expect(bars[0], closeTo(bars[1] * 2, 0.5));
  });
}
