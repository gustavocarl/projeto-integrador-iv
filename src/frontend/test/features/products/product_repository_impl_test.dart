import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/files/file_service.dart';
import 'package:univesp_project/features/products/data/repositories/product_repository_impl.dart';
import 'package:univesp_project/features/products/domain/entities/product.dart';

import '../../helpers/fakes.dart';

const _productJson = {
  'id': 'p-1',
  'name': 'Notebook Pro 14',
  'sku': 'NB-14',
  'category': 'Notebooks',
  'salePrice': 6499.9,
  'costPrice': 4800,
  'margin': 0.2615,
  'stockQuantity': 2,
  'minimumStock': 2,
  'isLowStock': true,
  'isActive': true,
  'imageUrl': 'https://cdn.test/nb.png',
  'createdAt': '2026-10-30T12:00:00Z',
  'updatedAt': null,
};

ProductRepositoryImpl _repository(FakeHttpAdapter adapter) =>
    ProductRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

void main() {
  test('list sends only the filters in use and parses products', () async {
    final adapter = FakeHttpAdapter((_) => (200, [_productJson]));

    final products = await _repository(adapter)
        .list(filter: const ProductFilter(search: 'nb', includeInactive: true));

    expect(adapter.requests.single.queryParameters, {
      'search': 'nb',
      'includeInactive': true,
    });
    final p = products.single;
    expect(
      (p.sku, p.salePrice, p.costPrice, p.margin, p.isLowStock, p.isOutOfStock),
      ('NB-14', 6499.9, 4800.0, 0.2615, true, false),
    );
    expect(p.imageUrl, 'https://cdn.test/nb.png');
  });

  test('create sends every field, empty ones as null', () async {
    final adapter = FakeHttpAdapter((_) => (201, _productJson));

    await _repository(adapter).create(
      const ProductInput(
        name: 'Notebook',
        salePrice: 10,
        isActive: false,
        imageUrl: 'https://cdn.test/nb.png',
      ),
    );

    final request = adapter.requests.single;
    expect((request.method, request.path), ('POST', '/api/products'));
    expect(request.data, {
      'name': 'Notebook',
      'sku': null,
      'category': null,
      'salePrice': 10.0,
      'costPrice': null,
      'stockQuantity': null,
      'minimumStock': null,
      'isActive': false,
      'imageUrl': 'https://cdn.test/nb.png',
    });
  });

  test('delete of a sold product becomes a conflict Failure', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        409,
        {
          'status': 409,
          'errors': [
            {'key': '', 'message': 'Este produto já tem vendas.'},
          ],
        },
      ),
    );

    await expectLater(
      _repository(adapter).delete('p-1'),
      throwsA(
        isA<Failure>().having((f) => f.generalMessages, 'messages', [
          'Este produto já tem vendas.',
        ]),
      ),
    );
  });

  test(
    'uploadImage sends the file as multipart and returns its path',
    () async {
      final adapter = FakeHttpAdapter(
        (_) => (201, {'url': '/uploads/products/a1.png'}),
      );

      final path = await _repository(adapter).uploadImage(
        PickedFile(name: 'foto.png', bytes: Uint8List.fromList([1, 2, 3])),
      );

      final request = adapter.requests.single;
      expect((request.method, request.path), ('POST', '/api/products/images'));
      final form = request.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'foto.png');
      expect(path, '/uploads/products/a1.png');
    },
  );
}
