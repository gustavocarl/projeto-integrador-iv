import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/request_guard.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../models/user_settings_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<UserSettings> get() => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/settings');
    return UserSettingsModel.fromJson(response.data!);
  });

  @override
  Future<UserSettings> update({
    bool? requireProductImage,
    bool? createProductsOnImport,
    ThemePreference? theme,
    bool? notifyRestock,
  }) => guardRequest(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/settings',
      data: {
        'requireProductImage': ?requireProductImage,
        'createProductsOnImport': ?createProductsOnImport,
        'theme': ?theme?.apiValue,
        'notifyRestock': ?notifyRestock,
      },
    );
    return UserSettingsModel.fromJson(response.data!);
  });
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(dioProvider)),
);
