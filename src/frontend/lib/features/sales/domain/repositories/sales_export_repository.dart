import 'dart:typed_data';

import '../entities/sales_export.dart';
import '../entities/sales_period.dart';

/// Generated sales spreadsheets (Exportações screen). Methods throw Failure.
abstract interface class SalesExportRepository {
  /// Most recent first.
  Future<List<SalesExport>> list();

  /// Generates the spreadsheet of [period] (every batch), in the default spreadsheet font
  /// of the user's operating system, and keeps it in the backend.
  /// No sales in the period: Failure 404 with the backend's message.
  Future<SalesExport> create(SalesPeriod period);

  /// The .xlsx file as it was generated.
  Future<Uint8List> download(String id);

  /// Removes only the generated file; no sale changes.
  Future<void> delete(String id);
}
