import '../../domain/entities/sales_export.dart';

abstract final class SalesExportModel {
  static SalesExport fromJson(Map<String, dynamic> json) => SalesExport(
    id: json['id'] as String,
    fileName: json['fileName'] as String,
    periodStart: DateTime.parse(json['periodStart'] as String),
    periodEnd: DateTime.parse(json['periodEnd'] as String),
    periodLabel: json['periodLabel'] as String,
    salesCount: (json['salesCount'] as num).toInt(),
    totalRevenue: (json['totalRevenue'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    createdBy: json['createdBy'] as String? ?? '',
  );
}
