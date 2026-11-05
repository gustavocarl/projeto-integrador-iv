import '../../domain/entities/app_notification.dart';

/// JSON of the backend's `NotificationResponse` and `NotificationListResponse`.
abstract final class NotificationModel {
  static AppNotification fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    kind: NotificationKind.parse(json['kind'] as String?),
    message: json['message'] as String? ?? '',
    relatedUserId: json['relatedUserId'] as String?,
    read: json['read'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  static NotificationInbox inboxFromJson(Map<String, dynamic> json) =>
      NotificationInbox(
        unread: (json['unread'] as num?)?.toInt() ?? 0,
        items: [
          for (final item in json['items'] as List<dynamic>? ?? const [])
            fromJson(item as Map<String, dynamic>),
        ],
      );
}
