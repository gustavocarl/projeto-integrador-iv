import '../../domain/entities/sale.dart';
import '../../domain/entities/sales_import.dart';

/// JSON mapping of the backend's sales DTOs.
abstract final class SalesImportModel {
  static SalesImport fromJson(Map<String, dynamic> json) => SalesImport(
    id: json['id'] as String,
    fileName: json['fileName'] as String,
    source: ImportSource.parse(json['source'] as String?),
    importedAt: DateTime.parse(json['importedAt'] as String),
    importedBy: json['importedBy'] as String,
    salesCount: json['salesCount'] as int,
    totalQuantity: json['totalQuantity'] as int,
    totalRevenue: (json['totalRevenue'] as num).toDouble(),
    periodStart: _date(json['periodStart']),
    periodEnd: _date(json['periodEnd']),
    createdProducts: json['createdProducts'] as int?,
  );

  static BatchDeletionImpact deletionImpactFromJson(
    Map<String, dynamic> json,
  ) => BatchDeletionImpact(
    salesCount: json['salesCount'] as int,
    totalRevenue: (json['totalRevenue'] as num).toDouble(),
    linkedProducts: json['linkedProducts'] as int,
    stockReturned: json['stockReturned'] as int,
  );

  static SalesImportDetail detailFromJson(Map<String, dynamic> json) =>
      SalesImportDetail(
        salesImport: fromJson(json['import'] as Map<String, dynamic>),
        byChannel: _breakdown(json['byChannel']),
        byMarketplace: _breakdown(json['byMarketplace']),
        byDay: _list(json['byDay'], _day),
        products: _list(json['products'], _product),
        profit: switch (json['profit']) {
          final Map<String, dynamic> p => ProfitSummary(
            salesWithCost: p['salesWithCost'] as int,
            revenue: (p['revenue'] as num).toDouble(),
            cost: (p['cost'] as num).toDouble(),
            profit: (p['profit'] as num).toDouble(),
            margin: (p['margin'] as num?)?.toDouble(),
          ),
          _ => ProfitSummary.none,
        },
      );

  static List<BreakdownItem> _breakdown(Object? json) => _list(
    json,
    (e) => BreakdownItem(
      key: e['key'] as String,
      name: e['name'] as String,
      sales: e['sales'] as int,
      quantity: e['quantity'] as int,
      revenue: (e['revenue'] as num).toDouble(),
    ),
  );

  static DailyItem _day(Map<String, dynamic> e) => DailyItem(
    date: DateTime.parse(e['date'] as String),
    sales: e['sales'] as int,
    quantity: e['quantity'] as int,
    revenue: (e['revenue'] as num).toDouble(),
  );

  static ProductItem _product(Map<String, dynamic> e) => ProductItem(
    key: e['key'] as String,
    name: e['name'] as String,
    sku: e['sku'] as String?,
    sales: e['sales'] as int,
    quantity: e['quantity'] as int,
    revenue: (e['revenue'] as num).toDouble(),
    revenueShare: (e['revenueShare'] as num).toDouble(),
    abcClass: AbcClass.parse(e['abcClass'] as String),
    recommendation: StockAction.parse(e['recommendation'] as String),
    lastSaleDate: DateTime.parse(e['lastSaleDate'] as String),
  );

  static Sale saleFromJson(Map<String, dynamic> json) => Sale(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    productName: json['productName'] as String,
    sku: json['sku'] as String?,
    quantity: json['quantity'] as int,
    unitPrice: (json['unitPrice'] as num).toDouble(),
    totalPrice: (json['totalPrice'] as num).toDouble(),
    channel: SalesChannel.parse(json['channel'] as String),
    marketplace: json['marketplace'] as String?,
    rowNumber: json['rowNumber'] as int?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    createdBy: json['createdBy'] as String,
    productId: json['productId'] as String?,
    isCheckout: json['isCheckout'] as bool? ?? false,
  );

  static Map<String, dynamic> checkoutToJson(CheckoutInput input) => {
    'date': _isoDate(input.date),
    'channel': input.channel?.apiValue,
    'marketplace': input.marketplace,
    'items': [
      for (final line in input.lines)
        {
          'productId': line.productId,
          'quantity': line.quantity,
          'unitPrice': line.unitPrice,
        },
    ],
  };

  static CheckoutResult checkoutFromJson(Map<String, dynamic> json) =>
      CheckoutResult(
        salesImport: fromJson(json['import'] as Map<String, dynamic>),
        sales: _list(json['sales'], saleFromJson),
        total: (json['total'] as num).toDouble(),
        cost: (json['cost'] as num?)?.toDouble(),
        profit: (json['profit'] as num?)?.toDouble(),
      );

  static SalesPage pageFromJson(Map<String, dynamic> json) => SalesPage(
    items: _list(json['items'], saleFromJson),
    page: json['page'] as int,
    pageSize: json['pageSize'] as int,
    totalCount: json['totalCount'] as int,
  );

  static ManualSaleResult manualSaleFromJson(Map<String, dynamic> json) =>
      ManualSaleResult(
        salesImport: fromJson(json['import'] as Map<String, dynamic>),
        sale: saleFromJson(json['sale'] as Map<String, dynamic>),
      );

  /// Keys are the backend's field names, which are also its error keys.
  static Map<String, dynamic> manualSaleToJson(ManualSaleInput input) => {
    'importId': input.importId,
    'importName': input.importName,
    'date': _isoDate(input.date),
    'productName': input.productName,
    'sku': input.sku,
    'quantity': input.quantity,
    'unitPrice': input.unitPrice,
    'channel': input.channel?.apiValue,
    'marketplace': input.marketplace,
  };

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Missing lists (older backend) become empty.
  static List<T> _list<T>(
    Object? json,
    T Function(Map<String, dynamic>) parse,
  ) => ((json as List<dynamic>?) ?? const [])
      .cast<Map<String, dynamic>>()
      .map(parse)
      .toList();

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
