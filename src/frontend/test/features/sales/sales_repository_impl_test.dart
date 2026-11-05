import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:univesp_project/features/sales/domain/entities/sale.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_import.dart';

import '../../helpers/fakes.dart';

const _importJson = {
  'id': 'imp-1',
  'fileName': 'vendas.xlsx',
  'importedAt': '2026-10-30T00:15:45Z',
  'importedBy': 'maria@exemplo.com',
  'salesCount': 112,
  'totalQuantity': 284,
  'totalRevenue': 38015.6,
  'periodStart': '2026-10-01',
  'periodEnd': '2026-10-28',
  'createdProducts': 4,
};

SalesRepositoryImpl _repository(FakeHttpAdapter adapter) => SalesRepositoryImpl(
  Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter,
  platform: TargetPlatform.windows,
);

const _saleJson = {
  'id': 'sale-1',
  'date': '2026-10-15',
  'productName': 'Mouse',
  'sku': null,
  'quantity': 2,
  'unitPrice': 79.9,
  'totalPrice': 159.8,
  'channel': 'Online',
  'channelName': 'Online',
  'marketplace': 'Amazon',
  'rowNumber': null,
  'createdAt': '2026-10-30T00:15:45Z',
  'createdBy': 'maria@exemplo.com',
};

void main() {
  test('import sends the file as multipart and parses the summary', () async {
    final adapter = FakeHttpAdapter((_) => (201, _importJson));

    final result = await _repository(adapter).importSpreadsheet(
      PickedFile(name: 'vendas.xlsx', bytes: Uint8List.fromList([1, 2, 3])),
    );

    final request = adapter.requests.single;
    expect(request.path, '/api/sales/imports');
    final form = request.data as FormData;
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'vendas.xlsx');
    expect(
      form.files.single.value.contentType.toString(),
      SalesRepositoryImpl.xlsxMimeType,
    );
    expect(form.fields, isEmpty);
    expect(result.createdProducts, 4);

    expect(result.salesCount, 112);
    expect(result.totalRevenue, 38015.6);
    expect(result.periodStart, DateTime(2026, 10, 1));
  });

  test('getDeletionImpact reads what removing the batch takes away', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        200,
        {
          'importId': 'imp-1',
          'fileName': 'vendas.xlsx',
          'salesCount': 112,
          'totalRevenue': 38015.6,
          'linkedProducts': 8,
          'stockReturned': 0,
        },
      ),
    );

    final impact = await _repository(adapter).getDeletionImpact('imp-1');

    final request = adapter.requests.single;
    expect(
      (request.method, request.path),
      ('GET', '/api/sales/imports/imp-1/deletion-impact'),
    );
    expect(
      (impact.salesCount, impact.linkedProducts, impact.stockReturned),
      (112, 8, 0),
    );
  });

  test(
    'row errors from the backend become a Failure with every message',
    () async {
      final adapter = FakeHttpAdapter(
        (_) => (
          400,
          {
            'title': 'Dados inválidos.',
            'status': 400,
            'errors': [
              {
                'key': '',
                'message':
                    'Linha 3: Venda presencial não pode ter marketplace.',
              },
              {'key': '', 'message': 'Linha 4: O produto é obrigatório.'},
            ],
          },
        ),
      );

      await expectLater(
        _repository(adapter)
            .importSpreadsheet(PickedFile(name: 'v.xlsx', bytes: Uint8List(1))),
        throwsA(
          isA<Failure>().having((f) => f.generalMessages.length, 'messages', 2),
        ),
      );
    },
  );

  test('detail parses the breakdowns', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        200,
        {
          'import': _importJson,
          'byChannel': [
            {
              'key': 'InPerson',
              'name': 'Presencial',
              'sales': 39,
              'quantity': 101,
              'revenue': 11950.4,
            },
          ],
          'byMarketplace': [
            {
              'key': 'none',
              'name': 'Fora de marketplace',
              'sales': 16,
              'quantity': 43,
              'revenue': 5207,
            },
          ],
          'byDay': [
            {
              'date': '2026-10-01',
              'sales': 4,
              'quantity': 7,
              'revenue': 1252.5,
            },
          ],
          'products': [
            {
              'key': 'TEN-010',
              'name': 'Tênis Corrida',
              'sku': 'TEN-010',
              'sales': 15,
              'quantity': 40,
              'revenue': 11960,
              'revenueShare': 0.3146,
              'abcClass': 'A',
              'recommendation': 'Prioritize',
              'lastSaleDate': '2026-10-26',
            },
            {
              'key': 'MEIA',
              'name': 'Meia',
              'sku': null,
              'sales': 1,
              'quantity': 1,
              'revenue': 10,
              'revenueShare': 0.0003,
              'abcClass': 'C',
              'recommendation': 'ReviewRemoval',
              'lastSaleDate': '2026-10-02',
            },
          ],
          'profit': {
            'salesWithCost': 3,
            'revenue': 300,
            'cost': 180,
            'profit': 120,
            'margin': 0.4,
          },
        },
      ),
    );

    final detail = await _repository(adapter).getImport('imp-1');

    expect(adapter.requests.single.path, '/api/sales/imports/imp-1');
    expect(detail.byChannel.single.name, 'Presencial');
    expect(detail.byMarketplace.single.revenue, 5207.0);
    expect(detail.byDay.single.date, DateTime(2026, 10, 1));
    expect(detail.byDay.single.revenue, 1252.5);
    expect(detail.products.first.abcClass, AbcClass.a);
    expect(detail.products.first.recommendation, StockAction.prioritize);
    expect(detail.products.first.lastSaleDate, DateTime(2026, 10, 26));
    expect(detail.products.last.sku, isNull);
    expect(detail.products.last.recommendation, StockAction.reviewRemoval);
    expect(
      (detail.profit.isAvailable, detail.profit.profit, detail.profit.margin),
      (true, 120.0, 0.4),
    );
  });

  test('template is downloaded as bytes', () async {
    final adapter = FakeHttpAdapter(
      (_) => (200, Uint8List.fromList([80, 75, 3, 4])),
    );

    final bytes = await _repository(adapter).downloadTemplate();

    expect(bytes, [80, 75, 3, 4]);
    expect(adapter.requests.single.responseType, ResponseType.bytes);
    // The system goes along, for the template's font.
    expect(adapter.requests.single.queryParameters, {'platform': 'windows'});
  });

  test('delete calls the import url', () async {
    final adapter = FakeHttpAdapter((_) => (204, null));

    await _repository(adapter).deleteImport('imp-1');

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/api/sales/imports/imp-1');
  });

  test('manual sale posts the backend field names', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        201,
        {
          'import': {..._importJson, 'source': 'Manual'},
          'sale': _saleJson,
        },
      ),
    );

    final result = await _repository(adapter).createManualSale(
      ManualSaleInput(
        importName: 'Balcão',
        date: DateTime(2026, 10, 5),
        productName: 'Mouse',
        quantity: 2,
        unitPrice: 79.9,
        channel: SalesChannel.inPerson,
      ),
    );

    final request = adapter.requests.single;
    expect((request.method, request.path), ('POST', '/api/sales/manual'));
    expect(request.data, {
      'importId': null,
      'importName': 'Balcão',
      'date': '2026-10-05',
      'productName': 'Mouse',
      'sku': null,
      'quantity': 2,
      'unitPrice': 79.9,
      'channel': 'InPerson',
      'marketplace': null,
    });
    expect(result.salesImport.source, ImportSource.manual);
    expect(result.sale.isManual, isTrue);
    expect(result.sale.channel, SalesChannel.online);
    expect(result.sale.marketplace, 'Amazon');
  });

  test('sales of a batch are paged and searched', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        200,
        {
          'items': [
            {..._saleJson, 'rowNumber': 7, 'sku': 'MOU-1'},
          ],
          'page': 2,
          'pageSize': 20,
          'totalCount': 21,
        },
      ),
    );

    final page = await _repository(adapter)
        .listSales('imp-1', search: 'mou', page: 2, pageSize: 20);

    final request = adapter.requests.single;
    expect(request.path, '/api/sales/imports/imp-1/sales');
    expect(request.queryParameters, {
      'search': 'mou',
      'page': 2,
      'pageSize': 20,
    });
    expect(page.totalCount, 21);
    expect(page.items.single.rowNumber, 7);
    expect(page.items.single.isManual, isFalse);
  });

  test('deletes one sale of the batch', () async {
    final adapter = FakeHttpAdapter((_) => (204, null));

    await _repository(adapter).deleteSale('imp-1', 'sale-1');

    final request = adapter.requests.single;
    expect(
      (request.method, request.path),
      ('DELETE', '/api/sales/imports/imp-1/sales/sale-1'),
    );
  });

  test('lists marketplace names', () async {
    final adapter = FakeHttpAdapter((_) => (200, ['Amazon', 'Shopee']));

    expect(await _repository(adapter).listMarketplaces(), ['Amazon', 'Shopee']);
  });

  test('checkout sends the cart lines and parses the result', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        201,
        {
          'import': {..._importJson, 'source': 'Store'},
          'sales': [
            {..._saleJson, 'productId': 'p-1', 'isCheckout': true},
          ],
          'total': 159.8,
          'cost': 80,
          'profit': 79.8,
        },
      ),
    );

    final result = await _repository(adapter).checkout(
      CheckoutInput(
        date: DateTime(2026, 10, 30),
        channel: SalesChannel.online,
        marketplace: 'Amazon',
        lines: const [CheckoutLine(productId: 'p-1', quantity: 2)],
      ),
    );

    final request = adapter.requests.single;
    expect(request.path, '/api/sales/checkout');
    expect(request.data, {
      'date': '2026-10-30',
      'channel': 'Online',
      'marketplace': 'Amazon',
      'items': [
        {'productId': 'p-1', 'quantity': 2, 'unitPrice': null},
      ],
    });
    expect(result.salesImport.source, ImportSource.store);
    expect((result.total, result.cost, result.profit), (159.8, 80.0, 79.8));
    expect(
      (result.sales.single.productId, result.sales.single.isCheckout),
      ('p-1', true),
    );
  });

  test('lists the months with sales', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        200,
        [
          {
            'month': '2026-10',
            'label': 'outubro/2026',
            'sales': 115,
            'quantity': 299,
            'revenue': 63315.6,
          },
        ],
      ),
    );

    final months = await _repository(adapter).listMonths();

    expect(adapter.requests.single.path, '/api/sales/months');
    expect(
      (months.single.label, months.single.year, months.single.monthNumber),
      ('outubro/2026', 2026, 10),
    );
  });

  test('compares two months and parses both sides', () async {
    Map<String, dynamic> totals(int sales, double revenue) => {
      'sales': sales,
      'quantity': sales * 2,
      'revenue': revenue,
    };
    Map<String, dynamic> summary(String month, String label, int days) => {
      'month': month,
      'label': label,
      'days': days,
      'elapsedDays': days,
      'sales': 10,
      'quantity': 20,
      'revenue': 1000,
      'profit': {
        'salesWithCost': 0,
        'revenue': 0,
        'cost': 0,
        'profit': 0,
        'margin': null,
      },
    };
    final adapter = FakeHttpAdapter(
      (_) => (
        200,
        {
          'base': summary('2026-02', 'fevereiro/2026', 28),
          'target': summary('2026-03', 'março/2026', 31),
          'byChannel': [
            {
              'key': 'InPerson',
              'name': 'Presencial',
              'sku': null,
              'base': totals(1, 10),
              'target': totals(2, 20),
            },
          ],
          'byMarketplace': <Object>[],
          'products': [
            {
              'key': 'CAM-01',
              'name': 'Camiseta',
              'sku': 'CAM-01',
              'base': totals(0, 0),
              'target': totals(3, 150),
            },
          ],
          'byDay': [
            {'day': 28, 'base': totals(1, 10), 'target': totals(0, 0)},
            {'day': 29, 'base': null, 'target': totals(1, 50)},
          ],
        },
      ),
    );

    final result = await _repository(adapter)
        .compareMonths('2026-02', '2026-03');

    final request = adapter.requests.single;
    expect(request.path, '/api/sales/comparison');
    expect(request.queryParameters, {'base': '2026-02', 'target': '2026-03'});
    expect((result.base.label, result.base.days), ('fevereiro/2026', 28));
    expect(result.target.isInProgress, isFalse);
    expect(result.byChannel.single.target.revenue, 20);
    expect(result.products.single.sku, 'CAM-01');
    expect(result.byDay.last.base, isNull);
    expect(result.byDay.last.target!.revenue, 50);
  });
}
