import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:univesp_project/features/notifications/domain/entities/app_notification.dart';

import '../../helpers/fakes.dart';

NotificationRepositoryImpl _repository(FakeHttpAdapter adapter) =>
    NotificationRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter,
    );

const _request = {
  'id': 'n1',
  'kind': 'AccessRequested',
  'message': 'João pediu acesso à loja Loja da Maria.',
  'relatedUserId': 'u2',
  'read': false,
  'createdAt': '2026-11-02T20:00:00Z',
};

void main() {
  test('lists the inbox; unknown kinds are kept as plain messages', () async {
    final adapter = FakeHttpAdapter(
      (_) => (
        200,
        {
          'unread': 1,
          'items': [
            _request,
            {..._request, 'id': 'n2', 'kind': 'Futuro', 'read': true},
          ],
        },
      ),
    );

    final inbox = await _repository(adapter).list();

    expect(adapter.requests.single.path, '/api/notifications');
    expect(inbox.unread, 1);
    expect(inbox.items.first.kind, NotificationKind.accessRequested);
    expect(inbox.items.first.relatedUserId, 'u2');
    expect(inbox.items.first.read, isFalse);
    expect(inbox.items.last.kind, NotificationKind.other);
  });

  test('marks one or all as read', () async {
    final adapter = FakeHttpAdapter(
      (options) => options.path.endsWith('read-all')
          ? (200, {'marked': 3})
          : (200, {..._request, 'read': true}),
    );
    final repository = _repository(adapter);

    expect((await repository.markRead('n1')).read, isTrue);
    expect(adapter.requests.last.path, '/api/notifications/n1/read');
    expect(await repository.markAllRead(), 3);
    expect(adapter.requests.last.path, '/api/notifications/read-all');
  });
}
