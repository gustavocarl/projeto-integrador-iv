import 'sales_import.dart';

enum SalesChannel {
  inPerson('InPerson', 'Presencial'),
  online('Online', 'Online');

  const SalesChannel(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SalesChannel parse(String value) =>
      values.firstWhere((c) => c.apiValue == value, orElse: () => online);
}

/// One sale of a batch.
class Sale {
  const Sale({
    required this.id,
    required this.date,
    required this.productName,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.channel,
    this.marketplace,
    this.rowNumber,
    required this.createdAt,
    required this.createdBy,
    this.productId,
    this.isCheckout = false,
  });

  final String id;
  final DateTime date;
  final String productName;
  final String? sku;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final SalesChannel channel;

  /// Online only; null = outside a marketplace (or in-person).
  final String? marketplace;

  /// Spreadsheet row; null when typed in or sold at the checkout.
  final int? rowNumber;
  final DateTime createdAt;
  final String createdBy;

  /// Registered product: sold at the checkout, or with the same SKU (typed in or imported).
  final String? productId;

  /// Sold at the checkout (took units from stock). A sale can have [productId] without it.
  final bool isCheckout;

  bool get isManual => rowNumber == null;
}

/// One page of a batch's sales.
class SalesPage {
  const SalesPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<Sale> items;
  final int page;
  final int pageSize;
  final int totalCount;
}

/// A sale typed in by the user. Exactly one of [importId] (existing batch) or
/// [importName] (new manual batch) is set. Values the user left empty or typed
/// wrong are null: the backend reports them.
class ManualSaleInput {
  const ManualSaleInput({
    this.importId,
    this.importName,
    required this.date,
    this.productName,
    this.sku,
    this.quantity,
    this.unitPrice,
    this.channel,
    this.marketplace,
  });

  final String? importId;
  final String? importName;
  final DateTime date;
  final String? productName;
  final String? sku;
  final int? quantity;
  final double? unitPrice;
  final SalesChannel? channel;
  final String? marketplace;
}

/// The sale created and its batch with the updated totals.
class ManualSaleResult {
  const ManualSaleResult({required this.salesImport, required this.sale});

  final SalesImport salesImport;
  final Sale sale;
}

/// One line of the cart: a catalog product, how many and for how much each.
class CheckoutLine {
  const CheckoutLine({required this.productId, this.quantity, this.unitPrice});

  final String productId;

  /// Null when typed wrong: the backend reports it.
  final int? quantity;

  /// Null = the product's sale price.
  final double? unitPrice;
}

/// A sale at the store. It goes into the month's batch ("Vendas - outubro/2026").
class CheckoutInput {
  const CheckoutInput({
    required this.date,
    this.channel,
    this.marketplace,
    required this.lines,
  });

  final DateTime date;
  final SalesChannel? channel;
  final String? marketplace;
  final List<CheckoutLine> lines;
}

class CheckoutResult {
  const CheckoutResult({
    required this.salesImport,
    required this.sales,
    required this.total,
    this.cost,
    this.profit,
  });

  /// The month's batch, with the updated totals.
  final SalesImport salesImport;
  final List<Sale> sales;
  final double total;

  /// Null when no product sold has a cost price.
  final double? cost;
  final double? profit;
}
