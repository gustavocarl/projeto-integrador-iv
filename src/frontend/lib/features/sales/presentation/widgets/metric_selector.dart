import 'package:flutter/material.dart';

import '../sales_metric.dart';

class MetricSelector extends StatelessWidget {
  const MetricSelector({
    super.key,
    required this.metric,
    required this.onChanged,
  });

  final SalesMetric metric;
  final ValueChanged<SalesMetric> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SegmentedButton<SalesMetric>(
      segments: [
        for (final m in SalesMetric.values)
          ButtonSegment(value: m, label: Text(m.label)),
      ],
      selected: {metric},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    ),
  );
}
