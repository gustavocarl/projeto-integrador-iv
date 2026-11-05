import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/request_guard.dart';
import '../../domain/entities/sales_export.dart';
import '../../domain/entities/sales_period.dart';
import '../../domain/repositories/sales_export_repository.dart';
import '../models/sales_export_model.dart';

class SalesExportRepositoryImpl implements SalesExportRepository {
  /// [platform]: the operating system sent so the spreadsheet uses its default spreadsheet
  /// font (Calibri on Windows, Helvetica Neue on Apple, Liberation Sans on Linux, Roboto on
  /// Android). On the web, it is the browser's system.
  SalesExportRepositoryImpl(this._dio, {TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  final Dio _dio;
  final TargetPlatform _platform;

  @override
  Future<List<SalesExport>> list() => guardRequest(() async {
    final response = await _dio.get<List<dynamic>>('/api/sales/exports');
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(SalesExportModel.fromJson)
        .toList();
  });

  @override
  Future<SalesExport> create(SalesPeriod period) => guardRequest(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/sales/exports',
      data: {
        'start': SalesPeriod.apiDate(period.start),
        'end': SalesPeriod.apiDate(period.end),
        'platform': _platform.name,
      },
    );
    return SalesExportModel.fromJson(response.data!);
  });

  @override
  Future<Uint8List> download(String id) =>
      downloadBytes(_dio, '/api/sales/exports/$id/file');

  @override
  Future<void> delete(String id) =>
      guardRequest(() => _dio.delete<void>('/api/sales/exports/$id'));
}

final salesExportRepositoryProvider = Provider<SalesExportRepository>(
  (ref) => SalesExportRepositoryImpl(ref.watch(dioProvider)),
);
