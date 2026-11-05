/// A sales spreadsheet the user generated (every sale of a period). Only a record of the
/// file: its sales are already in the system.
class SalesExport {
  const SalesExport({
    required this.id,
    required this.fileName,
    required this.periodStart,
    required this.periodEnd,
    required this.periodLabel,
    required this.salesCount,
    required this.totalRevenue,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String fileName;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// "05/11/2026", "novembro/2026" or "02/11/2026 a 08/11/2026" (from the backend).
  final String periodLabel;
  final int salesCount;
  final double totalRevenue;
  final DateTime createdAt;

  /// E-mail of who generated it.
  final String createdBy;
}
