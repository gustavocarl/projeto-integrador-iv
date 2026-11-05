import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Adds `Authorization: Bearer <token>` to every request and reports
/// when the backend rejects the token (401) or the store access (403).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(
    this._tokenStorage, {
    required this.onUnauthorized,
    this.onAccessChanged,
  });

  final TokenStorage _tokenStorage;
  final void Function() onUnauthorized;

  /// 403 on the `store` or `area` key: what the app knows about the user's access is stale.
  final void Function()? onAccessChanged;

  /// Error keys of a store access 403 (the backend's `StoreAccessService`).
  static const accessKeys = {'store', 'area'};

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only a request that carried a token means "session expired"; a 401 on login is just wrong credentials.
    final hadToken = err.requestOptions.headers.containsKey('Authorization');
    if (err.response?.statusCode == 401 && hadToken) {
      await _tokenStorage.clear();
      onUnauthorized();
    } else if (err.response?.statusCode == 403 &&
        _isAccessError(err.response?.data)) {
      onAccessChanged?.call();
    }
    handler.next(err);
  }

  static bool _isAccessError(Object? body) =>
      body is Map<String, dynamic> &&
      (body['errors'] as List<dynamic>? ?? const []).any(
        (e) => e is Map<String, dynamic> && accessKeys.contains(e['key']),
      );
}
