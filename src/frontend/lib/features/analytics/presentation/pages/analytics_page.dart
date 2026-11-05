import 'package:flutter/material.dart';

import '../widgets/forecast_tab.dart';
import '../widgets/product_groups_tab.dart';

/// Machine learning over the sales: the coming months' forecast and the product groups,
/// each in its own tab.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: const Column(
          children: [
            TabBar(
              tabs: [
                Tab(icon: Icon(Icons.trending_up), text: 'Próximos meses'),
                Tab(
                  icon: Icon(Icons.bubble_chart_outlined),
                  text: 'Grupos de produtos',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(children: [ForecastTab(), ProductGroupsTab()]),
            ),
          ],
        ),
      ),
    );
  }
}
