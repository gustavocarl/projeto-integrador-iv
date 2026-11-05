import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/sales_import.dart';
import '../controllers/sales_imports_controller.dart';
import '../sales_metric.dart';
import '../widgets/overview_tab.dart';
import '../widgets/products_tab.dart';
import '../widgets/sales_tab.dart';
import '../widgets/trend_tab.dart';

class SalesImportDetailPage extends ConsumerStatefulWidget {
  const SalesImportDetailPage({super.key, required this.salesImport});

  /// Summary already loaded in the list (the title shows while the analysis loads).
  final SalesImport salesImport;

  @override
  ConsumerState<SalesImportDetailPage> createState() =>
      _SalesImportDetailPageState();
}

class _SalesImportDetailPageState extends BaseState<SalesImportDetailPage> {
  /// Shared by the tabs, so switching tabs keeps what is being measured.
  SalesMetric _metric = SalesMetric.revenue;

  void _setMetric(SalesMetric metric) => setState(() => _metric = metric);

  @override
  Widget build(BuildContext context) {
    final id = widget.salesImport.id;
    final detail = ref.watch(salesImportDetailProvider(id));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.salesImport.fileName),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Resumo'),
              Tab(text: 'Evolução'),
              Tab(text: 'Produtos'),
              Tab(text: 'Vendas'),
            ],
          ),
        ),
        // While reloading (after a sale is added or removed) the previous data stays on screen.
        body: switch (detail) {
          AsyncValue(:final value?) => TabBarView(
            children: [
              OverviewTab(
                detail: value,
                metric: _metric,
                onMetricChanged: _setMetric,
              ),
              TrendTab(
                detail: value,
                metric: _metric,
                onMetricChanged: _setMetric,
              ),
              ProductsTab(
                detail: value,
                metric: _metric,
                onMetricChanged: _setMetric,
              ),
              SalesTab(importId: id),
            ],
          ),
          AsyncError(:final error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is Failure
                      ? error.generalMessages.join('\n')
                      : 'Erro ao carregar.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(salesImportDetailProvider(id)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
