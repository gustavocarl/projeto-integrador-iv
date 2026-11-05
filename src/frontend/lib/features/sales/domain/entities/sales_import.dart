/// How a batch was created. A spreadsheet batch can still receive manual sales.
enum ImportSource {
  spreadsheet('Spreadsheet'),
  manual('Manual'),

  /// The month's checkout batch ("Vendas - outubro/2026"), created automatically.
  store('Store');

  const ImportSource(this.apiValue);

  final String apiValue;

  static ImportSource parse(String? value) =>
      values.firstWhere((s) => s.apiValue == value, orElse: () => spreadsheet);
}

/// A batch of sales: an uploaded spreadsheet or a batch of sales typed in by the user.
class SalesImport {
  const SalesImport({
    required this.id,
    required this.fileName,
    this.source = ImportSource.spreadsheet,
    required this.importedAt,
    required this.importedBy,
    required this.salesCount,
    required this.totalQuantity,
    required this.totalRevenue,
    this.periodStart,
    this.periodEnd,
    this.createdProducts,
  });

  final String id;

  /// The spreadsheet's file name, or the name of a manual batch.
  final String fileName;
  final ImportSource source;
  final DateTime importedAt;
  final String importedBy;
  final int salesCount;
  final int totalQuantity;
  final double totalRevenue;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// Only right after a spreadsheet import: products registered from the spreadsheet's
  /// new SKUs. Null in the batch list.
  final int? createdProducts;
}

/// What removing a batch takes away, shown in the confirmation before it is removed.
class BatchDeletionImpact {
  const BatchDeletionImpact({
    required this.salesCount,
    required this.totalRevenue,
    required this.linkedProducts,
    required this.stockReturned,
  });

  final int salesCount;
  final double totalRevenue;

  /// Registered products the batch's sales are linked to (they stay in the catalog).
  final int linkedProducts;

  /// Units sold at the checkout that go back to stock.
  final int stockReturned;
}

/// Anything with sales totals, so every chart measures groups, days and products the same way.
abstract interface class SalesTotals {
  int get sales;
  int get quantity;
  double get revenue;
}

/// Totals of one group (a channel or a marketplace).
class BreakdownItem implements SalesTotals {
  const BreakdownItem({
    required this.key,
    required this.name,
    required this.sales,
    required this.quantity,
    required this.revenue,
  });

  final String key;
  final String name;
  @override
  final int sales;
  @override
  final int quantity;
  @override
  final double revenue;

  BreakdownItem renamed(String name) => BreakdownItem(
    key: key,
    name: name,
    sales: sales,
    quantity: quantity,
    revenue: revenue,
  );
}

/// Totals of one day (days without sales come with zeros).
class DailyItem implements SalesTotals {
  const DailyItem({
    required this.date,
    required this.sales,
    required this.quantity,
    required this.revenue,
  });

  final DateTime date;
  @override
  final int sales;
  @override
  final int quantity;
  @override
  final double revenue;
}

/// ABC curve by revenue: A = first 80%, B = next 15%, C = last 5%.
enum AbcClass {
  a,
  b,
  c;

  String get label => name.toUpperCase();

  static AbcClass parse(String value) =>
      values.firstWhere((c) => c.label == value, orElse: () => c);
}

/// Stock suggestion calculated by the backend.
enum StockAction {
  prioritize('Prioritize'),
  keep('Keep'),
  reviewRemoval('ReviewRemoval');

  const StockAction(this.apiValue);

  final String apiValue;

  static StockAction parse(String value) =>
      values.firstWhere((a) => a.apiValue == value, orElse: () => keep);
}

class ProductItem implements SalesTotals {
  const ProductItem({
    required this.key,
    required this.name,
    this.sku,
    required this.sales,
    required this.quantity,
    required this.revenue,
    required this.revenueShare,
    required this.abcClass,
    required this.recommendation,
    required this.lastSaleDate,
  });

  final String key;
  final String name;
  final String? sku;
  @override
  final int sales;
  @override
  final int quantity;
  @override
  final double revenue;

  /// Fraction of the import's revenue (0.235 = 23,5%).
  final double revenueShare;
  final AbcClass abcClass;
  final StockAction recommendation;
  final DateTime lastSaleDate;
}

class SalesImportDetail {
  const SalesImportDetail({
    required this.salesImport,
    required this.byChannel,
    required this.byMarketplace,
    required this.byDay,
    required this.products,
    this.profit = ProfitSummary.none,
  });

  final SalesImport salesImport;

  /// Presencial and Online.
  final List<BreakdownItem> byChannel;

  /// Online sales only, per marketplace (including "Fora de marketplace", key "none").
  final List<BreakdownItem> byMarketplace;

  /// Every day of the period, in order.
  final List<DailyItem> byDay;

  /// Sorted by revenue, highest first.
  final List<ProductItem> products;

  /// Only the sales whose cost is known (checkout sales of products with cost price).
  final ProfitSummary profit;
}

/// Profit of the sales whose cost is known; spreadsheets have no cost column.
class ProfitSummary {
  const ProfitSummary({
    required this.salesWithCost,
    required this.revenue,
    required this.cost,
    required this.profit,
    this.margin,
  });

  static const none = ProfitSummary(
    salesWithCost: 0,
    revenue: 0,
    cost: 0,
    profit: 0,
  );

  /// How many sales the numbers cover; 0 = nothing to show.
  final int salesWithCost;

  /// Revenue of those sales only.
  final double revenue;
  final double cost;
  final double profit;

  /// Profit / revenue (0.35 = 35%).
  final double? margin;

  bool get isAvailable => salesWithCost > 0;
}
