import '../entities/app_notification.dart';

/// The logged-in user's notification center. Methods throw [Failure] on error.
abstract interface class NotificationRepository {
  /// The newest notifications (read or not) and the unread count.
  Future<NotificationInbox> list();

  Future<AppNotification> markRead(String id);

  /// Returns how many were marked.
  Future<int> markAllRead();
}
