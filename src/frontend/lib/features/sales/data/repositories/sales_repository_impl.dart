import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_service.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/request_guard.dart';
import '../../domain/entities/month_comparison.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sales_import.dart';
import '../../domain/repositories/sales_repository.dart';
import '../models/month_comparison_model.dart';
import '../models/sales_import_model.dart';

class SalesRepositoryImpl implements SalesRepository {
  /// [platform]: the operating system sent so generated spreadsheets use its default
  /// spreadsheet font (on the web, the browser's system).
  SalesRepositoryImpl(this._dio, {TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  static const xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final Dio _dio;
  final TargetPlatform _platform;

  @override
  Future<SalesImport> importSpreadsheet(PickedFile file) =>
      guardRequest(() async {
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            file.bytes,
            filename: file.name,
            contentType: DioMediaType.parse(xlsxMimeType),
          ),
        });
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/sales/imports',
          data: form,
        );
        return SalesImportModel.fromJson(response.data!);
      });

  @override
  Future<List<SalesImport>> listImports() => guardRequest(() async {
    final response = await _dio.get<List<dynamic>>('/api/sales/imports');
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(SalesImportModel.fromJson)
        .toList();
  });

  @override
  Future<SalesImportDetail> getImport(String id) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/sales/imports/$id',
    );
    return SalesImportModel.detailFromJson(response.data!);
  });

  @override
  Future<BatchDeletionImpact> getDeletionImpact(String id) =>
      guardRequest(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/sales/imports/$id/deletion-impact',
        );
        return SalesImportModel.deletionImpactFromJson(response.data!);
      });

  @override
  Future<void> deleteImport(String id) => guardRequest(() async {
    await _dio.delete<void>('/api/sales/imports/$id');
  });

  @override
  Future<ManualSaleResult> createManualSale(ManualSaleInput input) =>
      guardRequest(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/sales/manual',
          data: SalesImportModel.manualSaleToJson(input),
        );
        return SalesImportModel.manualSaleFromJson(response.data!);
      });

  @override
  Future<CheckoutResult> checkout(CheckoutInput input) =>
      guardRequest(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/sales/checkout',
          data: SalesImportModel.checkoutToJson(input),
        );
        return SalesImportModel.checkoutFromJson(response.data!);
      });

  @override
  Future<SalesPage> listSales(
    String importId, {
    String? search,
    int page = 1,
    int pageSize = 50,
  }) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/sales/imports/$importId/sales',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return SalesImportModel.pageFromJson(response.data!);
  });

  @override
  Future<void> deleteSale(String importId, String saleId) =>
      guardRequest(() async {
        await _dio.delete<void>('/api/sales/imports/$importId/sales/$saleId');
      });

  @override
  Future<List<String>> listMarketplaces() => guardRequest(() async {
    final response = await _dio.get<List<dynamic>>('/api/sales/marketplaces');
    return response.data!.cast<String>();
  });

  @override
  Future<List<SalesMonth>> listMonths() => guardRequest(() async {
    final response = await _dio.get<List<dynamic>>('/api/sales/months');
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(MonthComparisonModel.monthFromJson)
        .toList();
  });

  @override
  Future<MonthComparison> compareMonths(String base, String target) =>
      guardRequest(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/sales/comparison',
          queryParameters: {'base': base, 'target': target},
        );
        return MonthComparisonModel.fromJson(response.data!);
      });

  @override
  Future<Uint8List> downloadTemplate() => downloadBytes(
    _dio,
    '/api/sales/template',
    queryParameters: {'platform': _platform.name},
  );
}

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepositoryImpl(ref.watch(dioProvider)),
);
