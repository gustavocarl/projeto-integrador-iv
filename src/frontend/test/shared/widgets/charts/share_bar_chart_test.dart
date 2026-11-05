import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/shared/widgets/charts/share_bar_chart.dart';

Future<void> _pump(WidgetTester tester, double width) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: const ShareBarChart(
            segments: [
              ShareSegment(
                label: 'Presencial',
                value: 25,
                valueText: '25',
                color: Colors.blue,
              ),
              ShareSegment(
                label: 'Online',
                value: 75,
                valueText: '75',
                color: Colors.orange,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('wide: direct label with name and percentage', (tester) async {
    tester.view.physicalSize = const Size(3000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, 2000);

    expect(find.text('Presencial 25,0%'), findsOneWidget);
    expect(find.text('Online 75,0%'), findsOneWidget);
  });

  testWidgets('narrow: only what fits, never a cut-off label', (tester) async {
    await _pump(tester, 300);

    // 25% of 300px can't hold the name, but holds the percentage.
    expect(find.text('Presencial 25,0%'), findsNothing);
    expect(find.text('25,0%'), findsWidgets);
    // The legend still names every segment.
    expect(find.text('Presencial'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
