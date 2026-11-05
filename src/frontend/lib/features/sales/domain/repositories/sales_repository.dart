import 'dart:typed_data';

import '../../../../core/files/file_service.dart';
import '../entities/month_comparison.dart';
import '../entities/sale.dart';
import '../entities/sales_import.dart';

/// Sales spreadsheet contract. Methods throw [Failure] on error.
abstract interface class SalesRepository {
  /// Uploads a spreadsheet. The backend saves it only if every row is valid, and registers
  /// its unknown SKUs as products when the user's setting "Cadastrar produtos ao importar" is on.
  Future<SalesImport> importSpreadsheet(PickedFile file);

  /// Most recent first.
  Future<List<SalesImport>> listImports();

  Future<SalesImportDetail> getImport(String id);

  /// What [deleteImport] would take away (nothing is changed), for the confirmation.
  Future<BatchDeletionImpact> getDeletionImpact(String id);

  Future<void> deleteImport(String id);

  /// Adds a typed-in sale to an existing batch or to a new manual batch.
  Future<ManualSaleResult> createManualSale(ManualSaleInput input);

  /// Sells catalog products: all lines or none. Takes them out of stock.
  Future<CheckoutResult> checkout(CheckoutInput input);

  /// Most recent date first. [search] matches product name or SKU.
  Future<SalesPage> listSales(
    String importId, {
    String? search,
    int page = 1,
    int pageSize = 50,
  });

  /// Removes one sale; the backend recalculates the batch totals.
  Future<void> deleteSale(String importId, String saleId);

  /// Known marketplace names, to suggest while typing.
  Future<List<String>> listMarketplaces();

  /// Months with sales (every batch), most recent first.
  Future<List<SalesMonth>> listMonths();

  /// Compares two months ("2026-01") over every batch.
  Future<MonthComparison> compareMonths(String base, String target);

  /// The empty template (.xlsx) users fill in.
  Future<Uint8List> downloadTemplate();
}
