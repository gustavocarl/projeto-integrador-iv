import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/request_guard.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notification_model.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<NotificationInbox> list() => guardRequest(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/notifications');
    return NotificationModel.inboxFromJson(response.data!);
  });

  @override
  Future<AppNotification> markRead(String id) => guardRequest(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/notifications/$id/read',
    );
    return NotificationModel.fromJson(response.data!);
  });

  @override
  Future<int> markAllRead() => guardRequest(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/notifications/read-all',
    );
    return (response.data?['marked'] as num?)?.toInt() ?? 0;
  });
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(ref.watch(dioProvider)),
);
