import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/errors/failure.dart';
import 'package:univesp_project/features/store/data/repositories/store_repository_impl.dart';
import 'package:univesp_project/features/store/domain/entities/store.dart';

import '../../helpers/fakes.dart';

StoreRepositoryImpl _repository(FakeHttpAdapter adapter) => StoreRepositoryImpl(
  Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter,
);

const _member = {
  'id': 'm1',
  'name': 'João',
  'email': 'joao@exemplo.com',
  'role': 'Member',
  'areas': ['Checkout', 'Imports'],
  'createdAt': '2026-11-02T20:00:00Z',
};

void main() {
  test('the profile carries the store, role and areas', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        201,
        {
          'id': 'u1',
          'name': 'Maria',
          'email': 'maria@exemplo.com',
          'store': {
            'id': 's1',
            'name': 'Loja da Maria',
            'role': 'Admin',
            'areas': [
              'Products',
              'Checkout',
              'Imports',
              'Exports',
              'Comparison',
              'Analytics',
              'Futuro',
            ],
          },
        },
      ),
    );

    final user = await _repository(adapter).enterStore('Loja da Maria');

    expect(adapter.requests.single.path, '/api/store');
    expect(adapter.requests.single.data, {'name': 'Loja da Maria'});
    expect(user.store!.isAdmin, isTrue);
    // Unknown names from a newer backend are ignored.
    expect(user.store!.areas, StoreArea.values.toSet());
    expect(user.hasStoreAccess, isTrue);
  });

  test('a pending request has no access; no store at all neither', () async {
    final pending = await _repository(
      FakeHttpAdapter(
        (_) => (
          200,
          {
            'id': 'u2',
            'name': 'João',
            'email': 'joao@exemplo.com',
            'store': {
              'id': 's1',
              'name': 'Loja',
              'role': 'Pending',
              'areas': [],
            },
          },
        ),
      ),
    ).enterStore('loja');
    expect(pending.store!.isPending, isTrue);
    expect(pending.hasStoreAccess, isFalse);
    expect(pending.can(StoreArea.checkout), isFalse);

    final removed = await _repository(
      FakeHttpAdapter(
        (_) => (
          200,
          {
            'id': 'u2',
            'name': 'João',
            'email': 'joao@exemplo.com',
            'store': null,
          },
        ),
      ),
    ).renameStore('x');
    expect(removed.store, isNull);
    expect(removed.hasStoreAccess, isFalse);
  });

  test('members, approve with the chosen areas in menu order', () async {
    final adapter = FakeHttpAdapter(
      (options) => switch (options.method) {
        'GET' => (200, [_member]),
        _ => (200, _member),
      },
    );
    final repository = _repository(adapter);

    final members = await repository.listMembers();
    expect(members.single.areas, {StoreArea.checkout, StoreArea.imports});
    expect(members.single.role, StoreRole.member);

    await repository.approve('m1', {StoreArea.imports, StoreArea.checkout});
    expect(adapter.requests.last.path, '/api/store/members/m1/approve');
    expect(adapter.requests.last.data, {
      'areas': ['Checkout', 'Imports'],
    });

    await repository.changeRole('m1', StoreRole.admin);
    expect(adapter.requests.last.data, {'role': 'Admin'});

    await repository.updateAreas('m1', {});
    expect(adapter.requests.last.path, '/api/store/members/m1/areas');
    expect(adapter.requests.last.data, {'areas': <String>[]});
  });

  test('errors become Failure with the field keys', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        409,
        {
          'status': 409,
          'title': 'Conflito.',
          'errors': [
            {'key': '', 'message': 'A loja precisa de pelo menos um admin.'},
          ],
        },
      ),
    );

    await expectLater(
      _repository(adapter).remove('m1'),
      throwsA(
        isA<Failure>().having((f) => f.statusCode, 'status', 409).having(
          (f) => f.generalMessages,
          'messages',
          ['A loja precisa de pelo menos um admin.'],
        ),
      ),
    );
  });
}
