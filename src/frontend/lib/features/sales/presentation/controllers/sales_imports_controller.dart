import '../../../analytics/presentation/controllers/analytics_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_service.dart';
import '../../../products/presentation/controllers/products_controller.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sales_import.dart';
import 'month_comparison_providers.dart';

/// List of batches. Actions throw [Failure] so the screen's [BaseState.runSafely] shows them.
class SalesImportsController extends AsyncNotifier<List<SalesImport>> {
  @override
  Future<List<SalesImport>> build() =>
      ref.read(salesRepositoryProvider).listImports();

  Future<SalesImport> importSpreadsheet(PickedFile file) async {
    final created = await ref
        .read(salesRepositoryProvider)
        .importSpreadsheet(file);
    state = AsyncData([created, ...?state.value]);
    _salesChanged();
    if ((created.createdProducts ?? 0) > 0) _catalogChanged();
    return created;
  }

  Future<void> delete(String id) async {
    await ref.read(salesRepositoryProvider).deleteImport(id);
    state = AsyncData([...?state.value?.where((i) => i.id != id)]);
    ref.invalidate(salesImportDetailProvider(id));
    _salesChanged();
  }

  /// Saves a typed-in sale; its batch (new or updated totals) replaces the old summary.
  Future<ManualSaleResult> createManualSale(ManualSaleInput input) async {
    final result = await ref
        .read(salesRepositoryProvider)
        .createManualSale(input);
    _batchSaved(result.salesImport);
    return result;
  }

  /// Sells catalog products; the month's batch (new or updated) replaces the old summary.
  Future<CheckoutResult> checkout(CheckoutInput input) async {
    final result = await ref.read(salesRepositoryProvider).checkout(input);
    _batchSaved(result.salesImport);
    return result;
  }

  /// A batch was saved elsewhere (e.g. the checkout): the list shows the new summary.
  void batchSaved(SalesImport updated) => _batchSaved(updated);

  void _batchSaved(SalesImport updated) {
    final current = state.value ?? const <SalesImport>[];
    state = AsyncData(
      current.any((i) => i.id == updated.id)
          ? [for (final i in current) i.id == updated.id ? updated : i]
          : [updated, ...current],
    );
    batchChanged(updated.id);
  }

  /// Reloads the summaries without showing a loading state (e.g. after removing a sale).
  Future<void> reload() async {
    state = AsyncData(await ref.read(salesRepositoryProvider).listImports());
    _salesChanged();
  }

  /// The batch's sales changed: its analysis and sales list must be fetched again.
  void batchChanged(String id) {
    ref.invalidate(salesImportDetailProvider(id));
    ref.invalidate(batchSalesProvider(id));
    _salesChanged();
  }

  /// The import registered products: the catalog screens must show them.
  void _catalogChanged() {
    ref.invalidate(productCategoriesProvider);
    ref.invalidate(sellableProductsProvider);
    // Keeps the products screen's filter (invalidating would reset it).
    if (ref.exists(productsControllerProvider)) {
      ref.read(productsControllerProvider.notifier).reload();
    }
  }

  /// Month totals cover every batch, so any change in sales changes the comparison
  /// and the analyses (forecast, product groups).
  void _salesChanged() {
    ref.invalidate(salesMonthsProvider);
    ref.invalidate(monthComparisonProvider);
    ref.invalidate(salesForecastProvider);
    ref.invalidate(productGroupsProvider);
  }
}

/// After a sale saved outside the batches screen (the checkout, which a user may have without
/// the Imports area): updates the batch list only if it is already loaded — reading the
/// controller would fetch the batches, refused (403) to users without Imports — and drops the
/// stale month comparison and analyses.
void salesBatchSaved(WidgetRef ref, SalesImport batch) {
  if (ref.exists(salesImportsControllerProvider)) {
    ref.read(salesImportsControllerProvider.notifier).batchSaved(batch);
    return;
  }
  ref.invalidate(salesImportDetailProvider(batch.id));
  ref.invalidate(batchSalesProvider(batch.id));
  ref.invalidate(salesMonthsProvider);
  ref.invalidate(monthComparisonProvider);
  ref.invalidate(salesForecastProvider);
  ref.invalidate(productGroupsProvider);
}

final salesImportsControllerProvider =
    AsyncNotifierProvider<SalesImportsController, List<SalesImport>>(
      SalesImportsController.new,
    );

final salesImportDetailProvider = FutureProvider.autoDispose
    .family<SalesImportDetail, String>(
      (ref, id) => ref.read(salesRepositoryProvider).getImport(id),
    );

/// Known marketplace names, suggested while typing a sale.
final marketplacesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.read(salesRepositoryProvider).listMarketplaces(),
);

class BatchSalesState {
  const BatchSalesState({
    required this.items,
    required this.totalCount,
    this.search = '',
    this.page = 1,
  });

  final List<Sale> items;
  final int totalCount;
  final String search;
  final int page;

  bool get hasMore => items.length < totalCount;
}

/// The sales of one batch, loaded page by page, with search and single removal.
class BatchSalesController extends AsyncNotifier<BatchSalesState> {
  BatchSalesController(this.importId);

  final String importId;

  static const pageSize = 50;

  /// Ignores answers to searches the user already replaced by typing more.
  int _request = 0;

  @override
  Future<BatchSalesState> build() => _load(search: '');

  Future<void> search(String text) async {
    final request = ++_request;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _load(search: text.trim()));
    if (request == _request) state = result;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    state = AsyncData(
      await _load(
        search: current.search,
        page: current.page + 1,
        previous: current.items,
      ),
    );
  }

  Future<void> remove(String saleId) async {
    await ref.read(salesRepositoryProvider).deleteSale(importId, saleId);
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        BatchSalesState(
          items: [...current.items.where((s) => s.id != saleId)],
          totalCount: current.totalCount - 1,
          search: current.search,
          page: current.page,
        ),
      );
    }
    ref.invalidate(salesImportDetailProvider(importId));
    await ref.read(salesImportsControllerProvider.notifier).reload();
  }

  Future<BatchSalesState> _load({
    required String search,
    int page = 1,
    List<Sale> previous = const [],
  }) async {
    final result = await ref
        .read(salesRepositoryProvider)
        .listSales(importId, search: search, page: page, pageSize: pageSize);
    return BatchSalesState(
      items: [...previous, ...result.items],
      totalCount: result.totalCount,
      search: search,
      page: page,
    );
  }
}

final batchSalesProvider = AsyncNotifierProvider.autoDispose
    .family<BatchSalesController, BatchSalesState, String>(
      BatchSalesController.new,
    );
