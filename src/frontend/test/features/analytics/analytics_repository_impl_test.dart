import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/features/analytics/data/repositories/analytics_repository_impl.dart';

import '../../helpers/fakes.dart';

AnalyticsRepositoryImpl _repository(FakeHttpAdapter adapter) =>
    AnalyticsRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter,
    );

const _forecastJson = {
  'history': [
    {
      'month': '2026-09',
      'label': 'setembro/2026',
      'quantity': 25,
      'revenue': 1150.5,
    },
  ],
  'months': [
    {
      'month': '2026-12',
      'label': 'dezembro/2026',
      'quantity': 14,
      'revenue': 870,
    },
  ],
  'products': [
    {
      'key': 'MOU-280',
      'name': 'Mouse sem fio',
      'sku': 'MOU-280',
      'productId': 'p1',
      'price': 75,
      'quantities': [10],
      'quantity': 10,
      'revenue': 750,
      'stock': 5,
      'minimumStock': 2,
      'suggestedPurchase': 7,
    },
    {
      'key': 'CAPA',
      'name': 'Capa',
      'sku': null,
      'productId': null,
      'price': 30,
      'quantities': [4],
      'quantity': 4,
      'revenue': 120,
      'stock': null,
      'minimumStock': null,
      'suggestedPurchase': null,
    },
  ],
  'validation': {
    'month': '2026-09',
    'label': 'setembro/2026',
    'actualQuantity': 25,
    'predictedQuantity': 23,
    'baselineQuantity': 21,
    'modelError': 0.12,
    'baselineError': 0.2,
  },
  'ignoredMonths': [
    {
      'month': '2026-11',
      'label': 'novembro/2026',
      'reason': 'Mês em andamento: ainda não terminou.',
    },
  ],
};

void main() {
  test('forecast asks for the months and parses the prediction', () async {
    final adapter = FakeHttpAdapter((_) => (200, _forecastJson));

    final forecast = await _repository(adapter).forecast(1);

    final request = adapter.requests.single;
    expect(request.path, '/api/analytics/forecast');
    expect(request.queryParameters, {'months': 1});
    expect((forecast.quantity, forecast.revenue), (14, 870.0));
    expect(forecast.months.single.date, DateTime(2026, 12));
    final mouse = forecast.products.first;
    expect((mouse.name, mouse.suggestedPurchase), ('Mouse sem fio', 7));
    expect(mouse.quantities, [10]);
    expect(forecast.products.last.stock, isNull);
    expect(forecast.toBuy.map((p) => p.key), ['MOU-280']);
    expect(forecast.validation!.beatsBaseline, isTrue);
    expect(forecast.ignoredMonths.single.label, 'novembro/2026');
  });

  test(
    'product groups: automatic sends no groups, a choice sends it',
    () async {
      final adapter = FakeHttpAdapter(
        (_) => (
          200,
          {
            'groups': 2,
            'automatic': true,
            'silhouette': 0.58,
            'candidates': [
              {'groups': 2, 'silhouette': 0.58},
            ],
            'clusters': [
              {
                'number': 1,
                'name': 'Alto giro',
                'description': 'Vendem muito.',
                'monthlyQuantity': 40.5,
                'averagePrice': 30,
                'regularity': 1,
                'quantity': 120,
                'revenue': 3600,
                'revenueShare': 1,
                'products': [
                  {
                    'key': 'CAB',
                    'name': 'Cabo',
                    'sku': 'CAB',
                    'productId': null,
                    'monthlyQuantity': 40.5,
                    'averagePrice': 30,
                    'regularity': 1,
                    'quantity': 120,
                    'revenue': 3600,
                  },
                ],
              },
            ],
            'months': [
              {
                'month': '2026-09',
                'label': 'setembro/2026',
                'quantity': 120,
                'revenue': 3600,
              },
            ],
            'ignoredMonths': <Object>[],
          },
        ),
      );
      final repository = _repository(adapter);

      final groups = await repository.productGroups(null);
      await repository.productGroups(3);

      expect(adapter.requests.first.path, '/api/analytics/product-groups');
      expect(adapter.requests.first.queryParameters, isEmpty);
      expect(adapter.requests.last.queryParameters, {'groups': 3});
      expect(
        (groups.groups, groups.automatic, groups.productCount),
        (2, true, 1),
      );
      expect(groups.clusters.single.products.single.monthlyQuantity, 40.5);
    },
  );

  test(
    'not enough history arrives as a Failure 404 with the message',
    () async {
      final adapter = FakeHttpAdapter(
        (_) => (
          404,
          {
            'status': 404,
            'errors': [
              {
                'key': '',
                'message': 'A previsão precisa de pelo menos 3 meses completos de vendas e há só 1.',
              },
            ],
          },
        ),
      );

      await expectLater(
        _repository(adapter).forecast(3),
        throwsA(
          isA<Failure>()
              .having((f) => f.statusCode, 'statusCode', 404)
              .having(
                (f) => f.generalMessages.single,
                'general message',
                contains('pelo menos 3 meses'),
              ),
        ),
      );
    },
  );
}
