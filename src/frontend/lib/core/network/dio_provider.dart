import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../session/access_changed_signal.dart';
import '../session/session_expired_signal.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'dev_certificate.dart';

/// HTTP client used by every repository.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  allowDevCertificate(dio);

  dio.interceptors.add(
    AuthInterceptor(
      ref.watch(tokenStorageProvider),
      onUnauthorized: () =>
          ref.read(sessionExpiredSignalProvider.notifier).emit(),
      onAccessChanged: () =>
          ref.read(accessChangedSignalProvider.notifier).emit(),
    ),
  );

  return dio;
});
