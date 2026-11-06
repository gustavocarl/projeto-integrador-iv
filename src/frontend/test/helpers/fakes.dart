import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:univesp_project/features/auth/presentation/controllers/auth_controller.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/core/storage/token_storage.dart';
import 'package:univesp_project/features/analytics/domain/entities/product_groups.dart';
import 'package:univesp_project/features/analytics/domain/entities/sales_forecast.dart';
import 'package:univesp_project/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:univesp_project/features/auth/domain/entities/user.dart';
import 'package:univesp_project/features/auth/domain/repositories/auth_repository.dart';
import 'package:univesp_project/features/notifications/domain/entities/app_notification.dart';
import 'package:univesp_project/features/notifications/domain/repositories/notification_repository.dart';
import 'package:univesp_project/features/products/domain/entities/product.dart';
import 'package:univesp_project/features/products/domain/repositories/product_repository.dart';
import 'package:univesp_project/features/sales/domain/entities/sale.dart';
import 'package:univesp_project/features/sales/domain/entities/month_comparison.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_import.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_export.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_period.dart';
import 'package:univesp_project/features/sales/domain/repositories/sales_export_repository.dart';
import 'package:univesp_project/features/sales/domain/repositories/sales_repository.dart';
import 'package:univesp_project/features/settings/domain/entities/user_settings.dart';
import 'package:univesp_project/features/settings/domain/repositories/settings_repository.dart';
import 'package:univesp_project/features/store/domain/entities/store.dart';
import 'package:univesp_project/features/store/domain/repositories/store_repository.dart';

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String token) async => this.token = token;

  @override
  Future<void> clear() async => token = null;
}

/// Answers Dio requests without a network. [handler] returns (status, body) or throws a [DioException].
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final (int, Object?) Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = handler(options);
    if (body is Uint8List) {
      return ResponseBody.fromBytes(body, status);
    }
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/problem+json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.sessionUser});

  User? sessionUser;
  Failure? loginFailure;
  int loginCalls = 0;

  static const validEmail = 'maria@exemplo.com';
  static const validPassword = 'Senha123';
  static const maria = User(
    id: '1',
    name: 'Maria Silva',
    email: validEmail,
    store: fakeAdminStore,
  );

  @override
  Future<User> login({required String email, required String password}) async {
    loginCalls++;
    if (loginFailure case final failure?) throw failure;
    if (accounts[email.toLowerCase()] != password) {
      throw const Failure(
        'Não autorizado.',
        statusCode: 401,
        errors: [FieldError('', 'E-mail ou senha inválidos.')],
      );
    }
    return sessionUser = email == validEmail
        ? maria
        : User(id: 'other', name: 'Outro', email: email, store: fakeAdminStore);
  }

  @override
  Future<User?> restoreSession() async => sessionUser;

  /// What [currentUser] answers (an admin may have changed the access); defaults to [sessionUser].
  User? serverUser;
  int currentUserCalls = 0;

  @override
  Future<User> currentUser() async {
    currentUserCalls++;
    return sessionUser = serverUser ?? sessionUser!;
  }

  /// Current password accepted by [changePassword]; updated when it succeeds.
  String password = validPassword;
  Failure? changePasswordFailure;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (changePasswordFailure case final failure?) throw failure;
    if (currentPassword != password) {
      throw const Failure(
        'Dados inválidos.',
        statusCode: 400,
        errors: [
          FieldError('currentPassword', 'A senha atual está incorreta.'),
        ],
      );
    }
    password = newPassword;
  }

  /// Accounts created by [register] or known in advance: e-mail → password.
  final accounts = <String, String>{validEmail: validPassword};
  final registered = <(String, String, String)>[];

  /// Store typed on each sign-up: `name:<store>`. "Marcelo Eletrônicos" (any casing or
  /// accents) is an existing store: the user waits for its admin.
  final registeredStores = <String>[];
  final resets = <(String, String)>[];
  Failure? registerFailure;

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    String? storeName,
  }) async {
    if (registerFailure case final failure?) throw failure;
    if (accounts.containsKey(email.toLowerCase())) {
      throw const Failure(
        'Conflito.',
        statusCode: 409,
        errors: [
          FieldError(
            'email',
            'Já existe um usuário cadastrado com este e-mail.',
          ),
        ],
      );
    }
    registered.add((name, email, password));
    registeredStores.add('name:$storeName');
    final existing =
        _storeKey(storeName ?? '') == _storeKey(fakeAdminStore.name);
    accounts[email.toLowerCase()] = password;
    return sessionUser = User(
      id: 'new',
      name: name,
      email: email,
      store: !existing
          ? StoreMembership(
              id: 'new-store',
              name: storeName ?? '',
              role: StoreRole.admin,
              areas: {...StoreArea.values},
            )
          : const StoreMembership(
              id: 's1',
              name: 'Marcelo Eletrônicos',
              role: StoreRole.pending,
              areas: {},
            ),
    );
  }

  static String _storeKey(String name) => name
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('Ô', 'O')
      .replaceAll('Ó', 'O');

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    if (!accounts.containsKey(email.toLowerCase())) {
      throw const Failure(
        'Não encontrado.',
        statusCode: 404,
        errors: [
          FieldError('email', 'Nenhum usuário cadastrado com este e-mail.'),
        ],
      );
    }
    resets.add((email, newPassword));
    accounts[email.toLowerCase()] = newPassword;
  }

  @override
  Future<void> logout() async => sessionUser = null;
}

class FakeFileService implements FileService {
  PickedFile? fileToPick;
  final saved = <String>[];

  @override
  Future<PickedFile?> pickSpreadsheet() async => fileToPick;

  @override
  Future<PickedFile?> pickImage() async => fileToPick;

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    saved.add(fileName);
    return true;
  }
}

SalesImport fakeImport({
  String id = 'imp-1',
  String fileName = 'vendas-outubro.xlsx',
  int salesCount = 112,
  ImportSource source = ImportSource.spreadsheet,
  int? createdProducts,
}) => SalesImport(
  id: id,
  fileName: fileName,
  source: source,
  importedAt: DateTime.utc(2026, 10, 30, 12),
  importedBy: 'maria@exemplo.com',
  salesCount: salesCount,
  totalQuantity: 284,
  totalRevenue: 38015.6,
  periodStart: DateTime(2026, 10, 1),
  periodEnd: DateTime(2026, 10, 28),
  createdProducts: createdProducts,
);

ProductItem fakeProduct(
  String name,
  int quantity,
  double revenue,
  AbcClass abcClass,
  StockAction recommendation,
) => ProductItem(
  key: name.toUpperCase(),
  name: name,
  sales: quantity,
  quantity: quantity,
  revenue: revenue,
  revenueShare: revenue / 11530,
  abcClass: abcClass,
  recommendation: recommendation,
  lastSaleDate: DateTime(2026, 10, 4),
);

Sale fakeSale({
  required String id,
  String product = 'Camiseta',
  int quantity = 1,
  double unitPrice = 50,
  int? rowNumber,
  SalesChannel channel = SalesChannel.online,
  String? marketplace,
  String? productId,
  bool isCheckout = false,
  DateTime? date,
}) => Sale(
  id: id,
  date: date ?? DateTime(2026, 10, 15),
  productName: product,
  quantity: quantity,
  unitPrice: unitPrice,
  totalPrice: quantity * unitPrice,
  channel: channel,
  marketplace: marketplace,
  rowNumber: rowNumber,
  createdAt: DateTime.utc(2026, 10, 29),
  createdBy: 'maria@exemplo.com',
  productId: productId,
  isCheckout: isCheckout,
);

class FakeSalesRepository implements SalesRepository {
  FakeSalesRepository([List<SalesImport>? imports]) : imports = imports ?? [];

  final List<SalesImport> imports;
  Failure? importFailure;

  /// Months offered by [listMonths], most recent first.
  List<SalesMonth> months = const [];

  /// The pairs asked to [compareMonths], in order.
  final compared = <(String, String)>[];

  /// Products the backend says the next import registered (the user's setting decides there).
  int productsToCreate = 0;

  @override
  Future<SalesImport> importSpreadsheet(PickedFile file) async {
    if (importFailure case final failure?) throw failure;
    final created = fakeImport(
      id: 'new',
      fileName: file.name,
      salesCount: 3,
      createdProducts: productsToCreate,
    );
    imports.insert(0, created);
    return created;
  }

  @override
  Future<List<SalesImport>> listImports() async {
    listCalls++;
    return [...imports];
  }

  /// How many times the batch list was asked (users without Importar must never ask).
  int listCalls = 0;

  @override
  Future<SalesImportDetail> getImport(String id) async => SalesImportDetail(
    salesImport: imports.firstWhere((i) => i.id == id),
    byChannel: const [
      BreakdownItem(
        key: 'InPerson',
        name: 'Presencial',
        sales: 39,
        quantity: 101,
        revenue: 11950.4,
      ),
      BreakdownItem(
        key: 'Online',
        name: 'Online',
        sales: 73,
        quantity: 183,
        revenue: 26065.2,
      ),
    ],
    byMarketplace: const [
      BreakdownItem(
        key: 'a',
        name: 'Mercado Livre',
        sales: 50,
        quantity: 120,
        revenue: 20000,
      ),
      BreakdownItem(
        key: 'none',
        name: 'Fora de marketplace',
        sales: 23,
        quantity: 63,
        revenue: 6065.2,
      ),
    ],
    byDay: [
      for (final (i, revenue) in const [100.0, 100.0, 200.0, 300.0].indexed)
        DailyItem(
          date: DateTime(2026, 10, i + 1),
          sales: i + 1,
          quantity: 2 * (i + 1),
          revenue: revenue,
        ),
    ],
    products: [
      fakeProduct(
        'Tênis Corrida',
        30,
        9000,
        AbcClass.a,
        StockAction.prioritize,
      ),
      fakeProduct('Jaqueta', 10, 2500, AbcClass.b, StockAction.keep),
      fakeProduct('Meia (par)', 2, 30, AbcClass.c, StockAction.reviewRemoval),
    ],
  );

  @override
  Future<void> deleteImport(String id) async =>
      imports.removeWhere((i) => i.id == id);

  /// What [getDeletionImpact] answers (by default: no linked products, no checkout units).
  BatchDeletionImpact? deletionImpact;
  Failure? deletionImpactFailure;

  @override
  Future<BatchDeletionImpact> getDeletionImpact(String id) async {
    if (deletionImpactFailure case final failure?) throw failure;
    final batch = imports.firstWhere((i) => i.id == id);
    return deletionImpact ??
        BatchDeletionImpact(
          salesCount: batch.salesCount,
          totalRevenue: batch.totalRevenue,
          linkedProducts: 0,
          stockReturned: 0,
        );
  }

  @override
  Future<List<SalesMonth>> listMonths() async => [...months];

  @override
  Future<MonthComparison> compareMonths(String base, String target) async {
    compared.add((base, target));
    return fakeComparison(base: base, target: target);
  }

  @override
  Future<Uint8List> downloadTemplate() async => Uint8List.fromList([1, 2, 3]);

  /// Sales per batch id, for the "Vendas" tab.
  final Map<String, List<Sale>> sales = {};
  final List<ManualSaleInput> manualInputs = [];
  final List<String> deletedSales = [];
  Failure? manualFailure;
  List<String> marketplaces = const ['Amazon', 'Mercado Livre'];

  @override
  Future<ManualSaleResult> createManualSale(ManualSaleInput input) async {
    manualInputs.add(input);
    if (manualFailure case final failure?) throw failure;

    final sale = fakeSale(
      id: 'sale-${manualInputs.length}',
      product: input.productName ?? '',
      quantity: input.quantity ?? 1,
      unitPrice: input.unitPrice ?? 0,
      // The backend echoes the typed date.
      date: input.date,
    );
    final SalesImport batch;
    if (input.importId case final id?) {
      final old = imports.firstWhere((i) => i.id == id);
      batch = fakeImport(
        id: old.id,
        fileName: old.fileName,
        salesCount: old.salesCount + 1,
        source: old.source,
      );
      imports[imports.indexOf(old)] = batch;
    } else {
      batch = fakeImport(
        id: 'manual-${manualInputs.length}',
        fileName: input.importName!,
        salesCount: 1,
        source: ImportSource.manual,
      );
      imports.insert(0, batch);
    }
    (sales[batch.id] ??= []).insert(0, sale);
    return ManualSaleResult(salesImport: batch, sale: sale);
  }

  @override
  Future<SalesPage> listSales(
    String importId, {
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    final matches = [
      ...?sales[importId]?.where(
        (s) =>
            search == null ||
            s.productName.toLowerCase().contains(search.toLowerCase()),
      ),
    ];
    return SalesPage(
      items: matches.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      pageSize: pageSize,
      totalCount: matches.length,
    );
  }

  @override
  Future<void> deleteSale(String importId, String saleId) async {
    deletedSales.add(saleId);
    sales[importId]?.removeWhere((s) => s.id == saleId);
  }

  @override
  Future<List<String>> listMarketplaces() async => marketplaces;

  final List<CheckoutInput> checkouts = [];
  Failure? checkoutFailure;

  /// Called after a successful checkout (e.g. to take stock out of a [FakeProductRepository]).
  void Function(CheckoutInput input)? onCheckout;

  @override
  Future<CheckoutResult> checkout(CheckoutInput input) async {
    checkouts.add(input);
    if (checkoutFailure case final failure?) throw failure;
    onCheckout?.call(input);

    final sales = [
      for (final (i, line) in input.lines.indexed)
        fakeSale(
          id: 'checkout-${checkouts.length}-$i',
          quantity: line.quantity ?? 1,
          unitPrice: line.unitPrice ?? 0,
          productId: line.productId,
          isCheckout: true,
        ),
    ];
    final batch = fakeImport(
      id: 'store-1',
      fileName: 'Vendas - outubro/2026',
      salesCount: sales.length,
      source: ImportSource.store,
    );
    imports
      ..removeWhere((i) => i.id == batch.id)
      ..insert(0, batch);
    return CheckoutResult(
      salesImport: batch,
      sales: sales,
      total: sales.fold(0, (sum, s) => sum + s.totalPrice),
      profit: 10,
    );
  }
}

Product fakeCatalogProduct({
  String id = 'p-1',
  String name = 'Mouse sem fio',
  String sku = 'MOU-280',
  String? category = 'Periféricos',
  double salePrice = 80,
  double? costPrice = 40,
  int stock = 10,
  int minimumStock = 2,
  bool isActive = true,
}) => Product(
  id: id,
  name: name,
  sku: sku,
  category: category,
  salePrice: salePrice,
  costPrice: costPrice,
  margin: costPrice == null ? null : (salePrice - costPrice) / salePrice,
  stockQuantity: stock,
  minimumStock: minimumStock,
  isLowStock: stock <= minimumStock,
  isActive: isActive,
);

class FakeProductRepository implements ProductRepository {
  FakeProductRepository([List<Product>? products]) : products = products ?? [];

  final List<Product> products;
  final List<ProductInput> saved = [];
  final List<ProductFilter> filters = [];
  Failure? saveFailure;
  Failure? deleteFailure;
  Failure? uploadFailure;

  /// Names of the files sent to [uploadImage].
  final uploaded = <String>[];

  @override
  Future<String> uploadImage(PickedFile file) async {
    if (uploadFailure case final failure?) throw failure;
    uploaded.add(file.name);
    return '/uploads/products/${uploaded.length}.png';
  }

  @override
  Future<List<Product>> list({
    ProductFilter filter = const ProductFilter(),
  }) async {
    filters.add(filter);
    final search = filter.search.toLowerCase();
    return products
        .where((p) => filter.includeInactive || p.isActive)
        .where((p) => filter.category == null || p.category == filter.category)
        .where(
          (p) =>
              search.isEmpty ||
              p.name.toLowerCase().contains(search) ||
              p.sku.toLowerCase().contains(search),
        )
        .toList();
  }

  @override
  Future<Product> create(ProductInput input) async {
    saved.add(input);
    if (saveFailure case final failure?) throw failure;
    final product = _fromInput('p-${products.length + 1}', input);
    products.add(product);
    return product;
  }

  @override
  Future<Product> update(String id, ProductInput input) async {
    saved.add(input);
    if (saveFailure case final failure?) throw failure;
    final product = _fromInput(id, input);
    products[products.indexWhere((p) => p.id == id)] = product;
    return product;
  }

  @override
  Future<void> delete(String id) async {
    if (deleteFailure case final failure?) throw failure;
    products.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<String>> listCategories() async =>
      products.map((p) => p.category).nonNulls.toSet().toList()..sort();

  /// Takes stock out, the way the backend does after a sale.
  void sell(String id, int quantity) {
    final i = products.indexWhere((p) => p.id == id);
    final p = products[i];
    products[i] = fakeCatalogProduct(
      id: p.id,
      name: p.name,
      sku: p.sku,
      category: p.category,
      salePrice: p.salePrice,
      costPrice: p.costPrice,
      stock: p.stockQuantity - quantity,
      minimumStock: p.minimumStock,
      isActive: p.isActive,
    );
  }

  static Product _fromInput(String id, ProductInput input) =>
      fakeCatalogProduct(
        id: id,
        name: input.name ?? '',
        sku: (input.sku ?? '').toUpperCase(),
        category: input.category,
        salePrice: input.salePrice ?? 0,
        costPrice: input.costPrice,
        stock: input.stockQuantity ?? 0,
        minimumStock: input.minimumStock ?? 0,
        isActive: input.isActive,
      );
}

/// Currency as the app shows it: "R\$ 80,00" (with the non-breaking space intl puts after R\$).
String brl(String amount) => 'R\$\u00A0$amount';

SalesMonth fakeMonth(String month, String label, double revenue) => SalesMonth(
  month: month,
  label: label,
  sales: 10,
  quantity: 20,
  revenue: revenue,
);

PeriodTotals _totals(int sales, int quantity, double revenue) =>
    PeriodTotals(sales: sales, quantity: quantity, revenue: revenue);

/// Base: R$ 1.000,00 in 10 sales; target: R$ 1.500,00 in 12 sales (+50%).
MonthComparison fakeComparison({
  String base = '2025-10',
  String target = '2026-10',
  int targetElapsedDays = 31,
}) => MonthComparison(
  base: MonthSummary(
    month: base,
    label: 'base $base',
    days: 31,
    elapsedDays: 31,
    sales: 10,
    quantity: 20,
    revenue: 1000,
  ),
  target: MonthSummary(
    month: target,
    label: 'alvo $target',
    days: 31,
    elapsedDays: targetElapsedDays,
    sales: 12,
    quantity: 30,
    revenue: 1500,
  ),
  byChannel: [
    ComparisonItem(
      key: 'InPerson',
      name: 'Presencial',
      base: _totals(4, 8, 400),
      target: _totals(4, 10, 300),
    ),
    ComparisonItem(
      key: 'Online',
      name: 'Online',
      base: _totals(6, 12, 600),
      target: _totals(8, 20, 1200),
    ),
  ],
  byMarketplace: [
    ComparisonItem(
      key: 'a',
      name: 'Mercado Livre',
      base: _totals(6, 12, 600),
      target: _totals(5, 10, 700),
    ),
    ComparisonItem(
      key: 'none',
      name: 'Fora de marketplace',
      base: PeriodTotals.zero,
      target: _totals(3, 10, 500),
    ),
  ],
  products: [
    ComparisonItem(
      key: 'TEN-010',
      name: 'Tênis Corrida',
      sku: 'TEN-010',
      base: _totals(5, 10, 600),
      target: _totals(8, 20, 1200),
    ),
    ComparisonItem(
      key: 'JAQUETA',
      name: 'Jaqueta',
      base: _totals(5, 10, 400),
      target: _totals(4, 10, 300),
    ),
  ],
  byDay: [
    for (var day = 1; day <= 31; day++)
      DayComparison(
        day: day,
        base: day == 1 ? _totals(10, 20, 1000) : PeriodTotals.zero,
        target: day == 2 ? _totals(12, 30, 1500) : PeriodTotals.zero,
      ),
  ],
);

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([this.settings = UserSettings.defaults]);

  UserSettings settings;
  Failure? loadFailure;
  Failure? saveFailure;

  /// Each call to [update], as `(requireProductImage, createProductsOnImport, theme)`.
  final updates = <(bool?, bool?, ThemePreference?)>[];

  /// Each value sent for `notifyRestock` (null = not sent).
  final restockUpdates = <bool?>[];

  @override
  Future<UserSettings> get() async {
    if (loadFailure case final failure?) throw failure;
    return settings;
  }

  @override
  Future<UserSettings> update({
    bool? requireProductImage,
    bool? createProductsOnImport,
    ThemePreference? theme,
    bool? notifyRestock,
  }) async {
    if (saveFailure case final failure?) throw failure;
    updates.add((requireProductImage, createProductsOnImport, theme));
    restockUpdates.add(notifyRestock);
    return settings = UserSettings(
      requireProductImage: requireProductImage ?? settings.requireProductImage,
      createProductsOnImport:
          createProductsOnImport ?? settings.createProductsOnImport,
      theme: theme ?? settings.theme,
      notifyRestock: notifyRestock ?? settings.notifyRestock,
    );
  }
}

/// Generated spreadsheets in memory. [create] builds the record from the period as the
/// backend would (label and file name from [SalesPeriod]).
class FakeSalesExportRepository implements SalesExportRepository {
  FakeSalesExportRepository([List<SalesExport>? exports])
    : exports = exports ?? [];

  final List<SalesExport> exports;
  final List<SalesPeriod> createdPeriods = [];
  final List<String> downloads = [];
  final List<String> deleted = [];
  Failure? createFailure;

  @override
  Future<List<SalesExport>> list() async => [...exports];

  @override
  Future<SalesExport> create(SalesPeriod period) async {
    createdPeriods.add(period);
    if (createFailure case final failure?) throw failure;
    final created = fakeExport(
      id: 'exp-${createdPeriods.length}',
      fileName: period.fileName,
      periodLabel: period.label,
      start: period.start,
      end: period.end,
    );
    exports.insert(0, created);
    return created;
  }

  @override
  Future<Uint8List> download(String id) async {
    downloads.add(id);
    return Uint8List.fromList([7, 8, 9]);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    exports.removeWhere((e) => e.id == id);
  }
}

SalesExport fakeExport({
  String id = 'exp-1',
  String fileName = 'vendas-2026-11.xlsx',
  String periodLabel = 'novembro/2026',
  DateTime? start,
  DateTime? end,
  int salesCount = 42,
  double totalRevenue = 1234.5,
}) => SalesExport(
  id: id,
  fileName: fileName,
  periodStart: start ?? DateTime(2026, 11),
  periodEnd: end ?? DateTime(2026, 11, 30),
  periodLabel: periodLabel,
  salesCount: salesCount,
  totalRevenue: totalRevenue,
  createdAt: DateTime(2026, 11, 1, 14, 30),
  createdBy: 'maria@exemplo.com',
);

MonthTotal fakeMonthTotal(
  String month,
  String label,
  int quantity,
  double revenue,
) => MonthTotal(
  month: month,
  label: label,
  quantity: quantity,
  revenue: revenue,
);

/// Three sold months and a forecast for [months] months (December/2026 onwards): a mouse that
/// needs buying, a cable that is covered and a spreadsheet-only product.
SalesForecast fakeForecast({int months = 3}) {
  const labels = [
    'dezembro/2026',
    'janeiro/2027',
    'fevereiro/2027',
    'março/2027',
    'abril/2027',
    'maio/2027',
  ];
  List<int> each(int base) => [for (var i = 0; i < months; i++) base + i];
  int sum(List<int> q) => q.fold(0, (a, b) => a + b);
  final mouse = each(10), cable = each(4), case_ = each(1);
  return SalesForecast(
    history: [
      fakeMonthTotal('2026-07', 'julho/2026', 20, 900),
      fakeMonthTotal('2026-08', 'agosto/2026', 22, 1000),
      fakeMonthTotal('2026-09', 'setembro/2026', 25, 1150),
    ],
    months: [
      for (var i = 0; i < months; i++)
        fakeMonthTotal(
          i == 0 ? '2026-12' : '2027-${(i).toString().padLeft(2, '0')}',
          labels[i],
          mouse[i] + cable[i] + case_[i],
          mouse[i] * 75.0 + cable[i] * 30.0 + case_[i] * 50.0,
        ),
    ],
    products: [
      ProductForecast(
        key: 'MOU-280',
        name: 'Mouse sem fio',
        sku: 'MOU-280',
        productId: 'p1',
        price: 75,
        quantities: mouse,
        quantity: sum(mouse),
        revenue: sum(mouse) * 75.0,
        stock: 5,
        minimumStock: 2,
        suggestedPurchase: sum(mouse) + 2 - 5,
      ),
      ProductForecast(
        key: 'CAPA',
        name: 'Capa de celular',
        sku: null,
        productId: null,
        price: 50,
        quantities: case_,
        quantity: sum(case_),
        revenue: sum(case_) * 50.0,
        stock: null,
        minimumStock: null,
        suggestedPurchase: null,
      ),
      ProductForecast(
        key: 'CAB-USC',
        name: 'Cabo USB-C',
        sku: 'CAB-USC',
        productId: 'p2',
        price: 30,
        quantities: cable,
        quantity: sum(cable),
        revenue: sum(cable) * 30.0,
        stock: 500,
        minimumStock: 10,
        suggestedPurchase: 0,
      ),
    ],
    validation: const ForecastValidation(
      month: '2026-09',
      label: 'setembro/2026',
      actualQuantity: 25,
      predictedQuantity: 23,
      baselineQuantity: 21,
      modelError: 0.12,
      baselineError: 0.2,
    ),
    ignoredMonths: const [
      IgnoredMonth(
        month: '2026-11',
        label: 'novembro/2026',
        reason: 'Mês em andamento: ainda não terminou.',
      ),
    ],
  );
}

GroupedProduct fakeGroupedProduct(String name, double monthly, double price) =>
    GroupedProduct(
      key: name.toUpperCase(),
      name: name,
      sku: null,
      monthlyQuantity: monthly,
      averagePrice: price,
      regularity: 1,
      quantity: (monthly * 3).round(),
      revenue: monthly * 3 * price,
    );

/// Two groups (or [groups], up to 3): expensive products that sell little, cheap ones that sell a lot.
ProductGroups fakeGroups({int groups = 2, bool automatic = true}) {
  final clusters = [
    ProductGroup(
      number: 1,
      name: 'Alto valor, baixo giro',
      description: 'Vendem pouco, mas cada venda vale muito.',
      monthlyQuantity: 5,
      averagePrice: 3000,
      regularity: 1,
      quantity: 30,
      revenue: 90000,
      revenueShare: 0.9,
      products: [
        fakeGroupedProduct('Notebook', 6, 3000),
        fakeGroupedProduct('iPhone', 4, 5000),
      ],
    ),
    ProductGroup(
      number: 2,
      name: 'Alto giro',
      description: 'Vendem muito e custam pouco.',
      monthlyQuantity: 40,
      averagePrice: 40,
      regularity: 1,
      quantity: 240,
      revenue: 9600,
      revenueShare: 0.096,
      products: [
        fakeGroupedProduct('Cabo USB-C', 40, 30),
        fakeGroupedProduct('Pen drive', 40, 50),
      ],
    ),
    ProductGroup(
      number: 3,
      name: 'Baixo giro',
      description: 'Vendem pouco e custam pouco.',
      monthlyQuantity: 1,
      averagePrice: 20,
      regularity: 0.33,
      quantity: 3,
      revenue: 60,
      revenueShare: 0.004,
      products: [fakeGroupedProduct('Adesivo', 1, 20)],
    ),
  ];
  return ProductGroups(
    groups: groups,
    automatic: automatic,
    silhouette: groups == 2 ? 0.58 : 0.41,
    candidates: const [
      GroupingQuality(groups: 2, silhouette: 0.58),
      GroupingQuality(groups: 3, silhouette: 0.41),
    ],
    clusters: clusters.take(groups).toList(),
    months: [fakeMonthTotal('2026-09', 'setembro/2026', 100, 99000)],
    ignoredMonths: const [],
  );
}

class FakeAnalyticsRepository implements AnalyticsRepository {
  final List<int> forecastCalls = [];
  final List<int?> groupsCalls = [];

  /// Thrown by both methods when set (e.g. 404: not enough history).
  Failure? failure;

  @override
  Future<SalesForecast> forecast(int months) async {
    forecastCalls.add(months);
    if (failure case final f?) throw f;
    return fakeForecast(months: months);
  }

  @override
  Future<ProductGroups> productGroups(int? groups) async {
    groupsCalls.add(groups);
    if (failure case final f?) throw f;
    return fakeGroups(groups: groups ?? 2, automatic: groups == null);
  }
}

const fakeAdminStore = StoreMembership(
  id: 's1',
  name: 'Marcelo Eletrônicos',
  role: StoreRole.admin,
  areas: {
    StoreArea.products,
    StoreArea.checkout,
    StoreArea.imports,
    StoreArea.exports,
    StoreArea.comparison,
    StoreArea.analytics,
  },
);

/// A member of the logged-in admin's store.
StoreMember fakeMember({
  String id = 'm1',
  String name = 'João Souza',
  StoreRole role = StoreRole.member,
  Set<StoreArea> areas = const {StoreArea.checkout},
}) => StoreMember(
  id: id,
  name: name,
  email: '${name.split(' ').first.toLowerCase()}@exemplo.com',
  role: role,
  areas: areas,
  createdAt: DateTime(2026, 11, 2),
);

/// Store and members in memory; records what the admin did.
class FakeStoreRepository implements StoreRepository {
  FakeStoreRepository({List<StoreMember>? members})
    : members =
          members ??
          [
            fakeMember(
              id: '1',
              name: 'Maria Silva',
              role: StoreRole.admin,
              areas: {...StoreArea.values},
            ),
          ];

  List<StoreMember> members;
  Failure? failure;
  final calls = <String>[];

  /// What enterStore/renameStore answer.
  User Function(String action, String value)? onUserChange;

  User _userChange(String action, String value) {
    calls.add('$action:$value');
    if (failure case final f?) throw f;
    return onUserChange!(action, value);
  }

  @override
  Future<User> enterStore(String name) async => _userChange('enter', name);

  @override
  Future<User> renameStore(String name) async => _userChange('rename', name);

  @override
  Future<List<StoreMember>> listMembers() async {
    if (failure case final f?) throw f;
    return [...members];
  }

  StoreMember _update(String id, StoreMember Function(StoreMember m) change) {
    if (failure case final f?) throw f;
    final updated = change(members.firstWhere((m) => m.id == id));
    members = [for (final m in members) m.id == id ? updated : m];
    return updated;
  }

  static StoreMember _copy(
    StoreMember m, {
    StoreRole? role,
    Set<StoreArea>? areas,
  }) => StoreMember(
    id: m.id,
    name: m.name,
    email: m.email,
    role: role ?? m.role,
    areas: areas ?? m.areas,
    createdAt: m.createdAt,
  );

  @override
  Future<StoreMember> approve(String memberId, Set<StoreArea> areas) async {
    calls.add('approve:$memberId:${areas.map((a) => a.apiValue).join(',')}');
    return _update(
      memberId,
      (m) => _copy(m, role: StoreRole.member, areas: {...areas}),
    );
  }

  @override
  Future<StoreMember> changeRole(String memberId, StoreRole role) async {
    calls.add('role:$memberId:${role.apiValue}');
    return _update(
      memberId,
      (m) => _copy(
        m,
        role: role,
        areas: role == StoreRole.admin ? {...StoreArea.values} : null,
      ),
    );
  }

  @override
  Future<StoreMember> updateAreas(String memberId, Set<StoreArea> areas) async {
    calls.add('areas:$memberId:${areas.map((a) => a.apiValue).join(',')}');
    return _update(memberId, (m) => _copy(m, areas: {...areas}));
  }

  @override
  Future<void> remove(String memberId) async {
    calls.add('remove:$memberId');
    if (failure case final f?) throw f;
    members = [
      for (final m in members)
        if (m.id != memberId) m,
    ];
  }
}

/// A notification of the center (unread by default).
AppNotification fakeNotification({
  String id = 'n1',
  NotificationKind kind = NotificationKind.accessRequested,
  String message =
      'João Souza (joao@exemplo.com) pediu acesso à loja Marcelo Eletrônicos.',
  String? relatedUserId = 'm1',
  bool read = false,
}) => AppNotification(
  id: id,
  kind: kind,
  message: message,
  relatedUserId: relatedUserId,
  read: read,
  createdAt: DateTime(2026, 11, 2, 14, 30),
);

/// Notification center in memory; records what was marked.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AppNotification>? items})
    : items = items ?? [];

  List<AppNotification> items;
  Failure? failure;
  int listCalls = 0;
  final calls = <String>[];

  @override
  Future<NotificationInbox> list() async {
    listCalls++;
    if (failure case final f?) throw f;
    return NotificationInbox(
      unread: items.where((n) => !n.read).length,
      items: [...items],
    );
  }

  @override
  Future<AppNotification> markRead(String id) async {
    calls.add('read:$id');
    if (failure case final f?) throw f;
    final read = items.firstWhere((n) => n.id == id).markedRead();
    items = [for (final n in items) n.id == id ? read : n];
    return read;
  }

  @override
  Future<int> markAllRead() async {
    calls.add('readAll');
    if (failure case final f?) throw f;
    final count = items.where((n) => !n.read).length;
    items = [for (final n in items) n.markedRead()];
    return count;
  }
}

/// For screens tested without the auth flow: someone is logged in a store, so the store
/// lists load (they stay empty without a session; see [sessionScopeProvider]).
final Override loggedInStore = sessionScopeProvider.overrideWithValue((
  '1',
  fakeAdminStore.id,
));
