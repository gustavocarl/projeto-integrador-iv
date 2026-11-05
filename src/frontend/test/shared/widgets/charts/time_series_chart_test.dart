import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/shared/widgets/charts/time_series_chart.dart';

Future<void> _pump(WidgetTester tester, Widget chart, {double width = 400}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: chart),
          ),
        ),
      ),
    );

List<TimePoint> _days(int count) => [
  for (var i = 1; i <= count; i++)
    TimePoint(
      label: i.toString().padLeft(2, '0'),
      value: i.toDouble(),
      tooltip: 'dia $i',
    ),
];

void main() {
  testWidgets('one tooltip per day and legend for bars and trend', (
    tester,
  ) async {
    await _pump(
      tester,
      TimeSeriesChart(
        points: _days(5),
        trend: const [1, 2, 3, 4, 5],
        axisLabel: (v) => v.toStringAsFixed(0),
        barsLabel: 'Por dia',
        trendLabel: 'Média',
      ),
    );

    expect(find.byType(Tooltip), findsNWidgets(5));
    expect(find.text('Por dia'), findsOneWidget);
    expect(find.text('Média'), findsOneWidget);
    // Wide enough: every day is labeled.
    for (final day in ['01', '02', '03', '04', '05']) {
      expect(find.text(day), findsOneWidget);
    }
  });

  testWidgets('skips x labels when days are too narrow', (tester) async {
    await _pump(
      tester,
      TimeSeriesChart(
        points: _days(30),
        axisLabel: (v) => v.toStringAsFixed(0),
        barsLabel: 'Por dia',
      ),
      width: 336, // a 400px phone, minus page and card padding
    );

    // 268px of plot for 30 days = 8,9px each; labels need 56px, so one a week.
    expect(find.text('01'), findsOneWidget);
    expect(find.text('07'), findsNothing);
    expect(find.text('08'), findsOneWidget);
    expect(find.text('02'), findsNothing);
    expect(find.text('Média'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty data shows a message', (tester) async {
    await _pump(
      tester,
      TimeSeriesChart(points: const [], axisLabel: (v) => '', barsLabel: ''),
    );
    expect(find.text('Sem dados.'), findsOneWidget);
  });
}
