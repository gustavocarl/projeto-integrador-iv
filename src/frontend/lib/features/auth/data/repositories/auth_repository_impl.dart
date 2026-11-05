import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/request_guard.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  @override
  Future<User> login({required String email, required String password}) =>
      guardRequest(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/auth/login',
          data: {'email': email, 'password': password},
        );
        final body = response.data!;

        await _tokenStorage.save(body['accessToken'] as String);
        return UserModel.fromJson(body['user'] as Map<String, dynamic>);
      });

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    String? storeName,
  }) => guardRequest(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'storeName': ?storeName,
      },
    );
    final body = response.data!;

    await _tokenStorage.save(body['accessToken'] as String);
    return UserModel.fromJson(body['user'] as Map<String, dynamic>);
  });

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) => guardRequest(() async {
    await _dio.post<void>(
      '/api/auth/reset-password',
      data: {'email': email, 'newPassword': newPassword},
    );
  });

  @override
  Future<User?> restoreSession() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) return null;

    try {
      return await guardRequest(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/auth/me');
        return UserModel.fromJson(response.data!);
      });
    } on Failure catch (failure) {
      // Expired or invalid token: forget it. Other failures (e.g. offline) keep it for the next launch.
      if (failure.isUnauthorized) {
        await _tokenStorage.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<User> currentUser() => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/auth/me');
    return UserModel.fromJson(response.data!);
  });

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => guardRequest(() async {
    await _dio.post<void>(
      '/api/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  });

  @override
  Future<void> logout() => _tokenStorage.clear();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  ),
);
