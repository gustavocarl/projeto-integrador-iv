import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_service.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/request_guard.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<String> uploadImage(PickedFile file) => guardRequest(() async {
    // No content type: the backend recognizes the format by the file's bytes.
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(file.bytes, filename: file.name),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/products/images',
      data: form,
    );
    return response.data!['url'] as String;
  });

  @override
  Future<List<Product>> list({ProductFilter filter = const ProductFilter()}) =>
      guardRequest(() async {
        final response = await _dio.get<List<dynamic>>(
          '/api/products',
          queryParameters: {
            if (filter.search.isNotEmpty) 'search': filter.search,
            'category': ?filter.category,
            if (filter.includeInactive) 'includeInactive': true,
          },
        );
        return response.data!
            .cast<Map<String, dynamic>>()
            .map(ProductModel.fromJson)
            .toList();
      });

  @override
  Future<Product> create(ProductInput input) => guardRequest(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/products',
      data: ProductModel.toJson(input),
    );
    return ProductModel.fromJson(response.data!);
  });

  @override
  Future<Product> update(String id, ProductInput input) =>
      guardRequest(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '/api/products/$id',
          data: ProductModel.toJson(input),
        );
        return ProductModel.fromJson(response.data!);
      });

  @override
  Future<void> delete(String id) => guardRequest(() async {
    await _dio.delete<void>('/api/products/$id');
  });

  @override
  Future<List<String>> listCategories() => guardRequest(() async {
    final response = await _dio.get<List<dynamic>>('/api/products/categories');
    return response.data!.cast<String>();
  });
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepositoryImpl(ref.watch(dioProvider)),
);
