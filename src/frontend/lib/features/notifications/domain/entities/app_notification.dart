/// What a notification is about (the backend's `Kind`).
enum NotificationKind {
  /// To the store's admins: someone asked to join (see [AppNotification.relatedUserId]).
  accessRequested('AccessRequested'),

  /// To the person who asked: the access was approved.
  accessApproved('AccessApproved'),

  /// A kind this version of the app doesn't know yet (shown as a plain message).
  other('');

  const NotificationKind(this.apiValue);

  final String apiValue;

  static NotificationKind parse(String? value) => values.firstWhere(
    (kind) => kind != other && kind.apiValue == value,
    orElse: () => other,
  );
}

/// A message of the notification center (the bell in the app bar).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.message,
    required this.read,
    required this.createdAt,
    this.relatedUserId,
  });

  final String id;
  final NotificationKind kind;
  final String message;

  /// The user the notification talks about (e.g. who asked for access).
  final String? relatedUserId;
  final bool read;
  final DateTime createdAt;

  AppNotification markedRead() => AppNotification(
    id: id,
    kind: kind,
    message: message,
    read: true,
    createdAt: createdAt,
    relatedUserId: relatedUserId,
  );
}

/// The newest notifications and how many are unread (the bell's counter).
class NotificationInbox {
  const NotificationInbox({required this.unread, required this.items});

  static const empty = NotificationInbox(unread: 0, items: []);

  final int unread;
  final List<AppNotification> items;
}
