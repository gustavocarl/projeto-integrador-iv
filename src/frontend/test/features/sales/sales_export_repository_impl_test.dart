import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/features/sales/data/repositories/sales_export_repository_impl.dart';
import 'package:univesp_project/features/sales/domain/entities/sales_period.dart';

import '../../helpers/fakes.dart';

const _exportJson = {
  'id': 'exp-1',
  'fileName': 'vendas-2026-11-02-a-2026-11-08.xlsx',
  'periodStart': '2026-11-02',
  'periodEnd': '2026-11-08',
  'periodLabel': '02/11/2026 a 08/11/2026',
  'salesCount': 12,
  'totalRevenue': 980.5,
  'createdAt': '2026-11-01T17:00:00Z',
  'createdBy': 'maria@exemplo.com',
};

SalesExportRepositoryImpl _repository(FakeHttpAdapter adapter) =>
    SalesExportRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter,
      platform: TargetPlatform.macOS,
    );

void main() {
  test(
    'create posts the period and parses the generated spreadsheet',
    () async {
      final adapter = FakeHttpAdapter((_) => (201, _exportJson));

      final export = await _repository(adapter)
          .create(SalesPeriod(DateTime(2026, 11, 2), DateTime(2026, 11, 8)));

      final request = adapter.requests.single;
      expect((request.method, request.path), ('POST', '/api/sales/exports'));
      // The system goes along, for the spreadsheet's font.
      expect(request.data, {
        'start': '2026-11-02',
        'end': '2026-11-08',
        'platform': 'macOS',
      });
      expect(
        (export.id, export.periodLabel, export.salesCount, export.totalRevenue),
        ('exp-1', '02/11/2026 a 08/11/2026', 12, 980.5),
      );
      expect(export.periodEnd, DateTime(2026, 11, 8));
    },
  );

  test('list, download and delete use the export routes', () async {
    final adapter = FakeHttpAdapter(
      (o) => switch (o.method) {
        'GET' when o.path.endsWith('/file') => (
          200,
          Uint8List.fromList([1, 2]),
        ),
        'GET' => (200, [_exportJson]),
        _ => (204, null),
      },
    );
    final repository = _repository(adapter);

    expect((await repository.list()).single.fileName, _exportJson['fileName']);
    expect(await repository.download('exp-1'), [1, 2]);
    await repository.delete('exp-1');

    expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
      'GET /api/sales/exports',
      'GET /api/sales/exports/exp-1/file',
      'DELETE /api/sales/exports/exp-1',
    ]);
  });

  test('a period without sales comes back with the backend message', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        404,
        {
          'status': 404,
          'errors': [
            {'key': '', 'message': 'Não há vendas em 10/11/2026.'},
          ],
        },
      ),
    );

    await expectLater(
      _repository(adapter)
          .create(SalesPeriod(DateTime(2026, 11, 10), DateTime(2026, 11, 10))),
      throwsA(
        isA<Failure>().having((f) => f.generalMessages, 'messages', [
          'Não há vendas em 10/11/2026.',
        ]),
      ),
    );
  });

  test('a download error (bytes) is decoded to the backend message', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        404,
        utf8.encode(
          '{"status":404,"errors":[{"key":"","message":"Planilha gerada não encontrada."}]}',
        ),
      ),
    );

    await expectLater(
      _repository(adapter).download('x'),
      throwsA(
        isA<Failure>().having((f) => f.generalMessages, 'messages', [
          'Planilha gerada não encontrada.',
        ]),
      ),
    );
  });
}
