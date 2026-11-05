import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/request_guard.dart';
import '../../domain/entities/product_groups.dart';
import '../../domain/entities/sales_forecast.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../models/analytics_model.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<SalesForecast> forecast(int months) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/analytics/forecast',
      queryParameters: {'months': months},
    );
    return AnalyticsModel.forecastFromJson(response.data!);
  });

  @override
  Future<ProductGroups> productGroups(int? groups) => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/analytics/product-groups',
      queryParameters: {'groups': ?groups},
    );
    return AnalyticsModel.groupsFromJson(response.data!);
  });
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepositoryImpl(ref.watch(dioProvider)),
);
