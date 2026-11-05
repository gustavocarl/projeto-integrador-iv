import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/network/auth_interceptor.dart';

import '../../helpers/fakes.dart';

void main() {
  late int accessChanged;
  late int unauthorized;

  Dio dioAnswering(int status, Object? body) {
    accessChanged = 0;
    unauthorized = 0;
    return Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = FakeHttpAdapter((_) => (status, body))
      ..interceptors.add(
        AuthInterceptor(
          InMemoryTokenStorage('jwt'),
          onUnauthorized: () => unauthorized++,
          onAccessChanged: () => accessChanged++,
        ),
      );
  }

  Map<String, Object> problem(String key) => {
    'status': 403,
    'title': 'Acesso negado.',
    'errors': [
      {'key': key, 'message': 'x'},
    ],
  };

  for (final key in ['store', 'area']) {
    test('403 on "$key": the store access changed', () async {
      final dio = dioAnswering(403, problem(key));

      await expectLater(
        dio.get<void>('/api/products'),
        throwsA(isA<DioException>()),
      );

      expect(accessChanged, 1);
      expect(unauthorized, 0);
    });
  }

  test('403 for admin-only actions does not reload the profile', () async {
    final dio = dioAnswering(403, problem('admin'));

    await expectLater(
      dio.get<void>('/api/store/members'),
      throwsA(isA<DioException>()),
    );

    expect(accessChanged, 0);
  });
}
