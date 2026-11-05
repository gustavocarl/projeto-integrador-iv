import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/core/network/auth_interceptor.dart';
import 'package:univesp_project/features/auth/data/repositories/auth_repository_impl.dart';

import '../../helpers/fakes.dart';

const _userJson = {
  'id': 'a1',
  'name': 'Maria Silva',
  'email': 'maria@exemplo.com',
};

void main() {
  late InMemoryTokenStorage storage;
  late int unauthorizedCalls;

  AuthRepositoryImpl repositoryWith(FakeHttpAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(storage, onUnauthorized: () => unauthorizedCalls++),
      );
    return AuthRepositoryImpl(dio, storage);
  }

  setUp(() {
    storage = InMemoryTokenStorage();
    unauthorizedCalls = 0;
  });

  test('login stores the token and returns the user', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        200,
        {
          'accessToken': 'jwt-123',
          'expiresAt': '2026-01-01T00:00:00Z',
          'user': _userJson,
        },
      ),
    );

    final user = await repositoryWith(adapter)
        .login(email: 'maria@exemplo.com', password: 'Senha123');

    expect(user.name, 'Maria Silva');
    expect(storage.token, 'jwt-123');
    expect(adapter.requests.single.path, '/api/auth/login');
  });

  test('login with wrong credentials throws the backend message and does not expire the session', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        401,
        {
          'title': 'Não autorizado.',
          'status': 401,
          'errors': [
            {'key': '', 'message': 'E-mail ou senha inválidos.'},
          ],
        },
      ),
    );

    final call = repositoryWith(adapter)
        .login(email: 'maria@exemplo.com', password: 'errada');

    await expectLater(
      call,
      throwsA(
        isA<Failure>()
            .having((f) => f.isUnauthorized, 'isUnauthorized', isTrue)
            .having((f) => f.generalMessages, 'generalMessages', [
              'E-mail ou senha inválidos.',
            ]),
      ),
    );
    expect(unauthorizedCalls, 0);
  });

  test('connection problems become a connection failure', () async {
    final adapter = FakeHttpAdapter(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      ),
    );

    await expectLater(
      repositoryWith(adapter).login(email: 'a@b.com', password: 'x'),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          contains('conectar'),
        ),
      ),
    );
  });

  test('restoreSession without a token does not call the backend', () async {
    final adapter = FakeHttpAdapter((_) => (200, _userJson));

    expect(await repositoryWith(adapter).restoreSession(), isNull);
    expect(adapter.requests, isEmpty);
  });

  test('restoreSession sends the token and returns the user', () async {
    storage.token = 'jwt-123';
    final adapter = FakeHttpAdapter((_) => (200, _userJson));

    final user = await repositoryWith(adapter).restoreSession();

    expect(user?.email, 'maria@exemplo.com');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer jwt-123');
  });

  test(
    'restoreSession with an expired token clears it and signals session expiry',
    () async {
      storage.token = 'expirado';
      final adapter = FakeHttpAdapter((_) => (401, null));

      expect(await repositoryWith(adapter).restoreSession(), isNull);
      expect(storage.token, isNull);
      expect(unauthorizedCalls, 1);
    },
  );

  test('changePassword posts both passwords with the session token', () async {
    storage.token = 'jwt-123';
    final adapter = FakeHttpAdapter((_) => (204, null));

    await repositoryWith(
      adapter,
    ).changePassword(currentPassword: 'Senha123', newPassword: 'NovaSenha456');

    final request = adapter.requests.single;
    expect(
      (request.method, request.path),
      ('POST', '/api/auth/change-password'),
    );
    expect(request.data, {
      'currentPassword': 'Senha123',
      'newPassword': 'NovaSenha456',
    });
    expect(request.headers['Authorization'], 'Bearer jwt-123');
  });

  test('changePassword with a wrong current password is a field error, not an expired session', () async {
    storage.token = 'jwt-123';
    final adapter = FakeHttpAdapter(
      (_) => (
        400,
        {
          'title': 'Dados inválidos.',
          'status': 400,
          'errors': [
            {
              'key': 'currentPassword',
              'message': 'A senha atual está incorreta.',
            },
          ],
        },
      ),
    );

    await expectLater(
      repositoryWith(adapter).changePassword(
        currentPassword: 'Errada123',
        newPassword: 'NovaSenha456',
      ),
      throwsA(
        isA<Failure>().having(
          (f) => f.messageFor('currentPassword'),
          'currentPassword',
          'A senha atual está incorreta.',
        ),
      ),
    );
    expect(unauthorizedCalls, 0);
    expect(storage.token, 'jwt-123');
  });

  test(
    'register posts the data, stores the token and returns the user',
    () async {
      final adapter = FakeHttpAdapter(
        (_) => (
          201,
          {
            'accessToken': 'jwt-new',
            'expiresAt': '2026-01-01T00:00:00Z',
            'user': _userJson,
          },
        ),
      );

      final user = await repositoryWith(adapter).register(
        name: 'Maria Silva',
        email: 'maria@exemplo.com',
        password: 'Senha123',
      );

      final request = adapter.requests.single;
      expect((request.method, request.path), ('POST', '/api/auth/register'));
      expect(request.data, {
        'name': 'Maria Silva',
        'email': 'maria@exemplo.com',
        'password': 'Senha123',
      });
      expect(user.email, 'maria@exemplo.com');
      expect(storage.token, 'jwt-new');
    },
  );

  test(
    'resetPassword posts the e-mail and the new password without a session',
    () async {
      final adapter = FakeHttpAdapter((_) => (204, null));

      await repositoryWith(
        adapter,
      ).resetPassword(email: 'maria@exemplo.com', newPassword: 'NovaSenha456');

      final request = adapter.requests.single;
      expect(
        (request.method, request.path),
        ('POST', '/api/auth/reset-password'),
      );
      expect(request.data, {
        'email': 'maria@exemplo.com',
        'newPassword': 'NovaSenha456',
      });
      expect(storage.token, isNull);
    },
  );

  test(
    'resetPassword with an unknown e-mail is an error on the e-mail field',
    () async {
      final adapter = FakeHttpAdapter(
        (_) => (
          404,
          {
            'title': 'Não encontrado.',
            'status': 404,
            'errors': [
              {
                'key': 'email',
                'message': 'Nenhum usuário cadastrado com este e-mail.',
              },
            ],
          },
        ),
      );

      await expectLater(
        repositoryWith(
          adapter,
        ).resetPassword(email: 'joao@exemplo.com', newPassword: 'NovaSenha456'),
        throwsA(
          isA<Failure>().having(
            (f) => f.messageFor('email'),
            'email',
            'Nenhum usuário cadastrado com este e-mail.',
          ),
        ),
      );
    },
  );
}
