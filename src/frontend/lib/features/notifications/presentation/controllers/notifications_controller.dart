import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';

/// The notification center of the logged-in user (alive while the bell is on screen; the
/// bell calls [poll] every [pollInterval]). Starts over when the user changes.
class NotificationsController extends AsyncNotifier<NotificationInbox> {
  static const pollInterval = Duration(seconds: 30);

  bool _polling = false;

  @override
  Future<NotificationInbox> build() async {
    final userId = ref.watch(authControllerProvider.select((s) => s.value?.id));
    if (userId == null) return NotificationInbox.empty;
    return ref.read(notificationRepositoryProvider).list();
  }

  /// Reloads without a loading state. Failures keep what is shown (401 logs out elsewhere).
  Future<void> poll() async {
    if (_polling || ref.read(authControllerProvider).value == null) return;
    _polling = true;
    try {
      final inbox = await ref.read(notificationRepositoryProvider).list();
      // The bell may have left the screen meanwhile (the provider is gone).
      if (ref.mounted) state = AsyncData(inbox);
    } on Failure {
      // Keep the current list; the next poll tries again.
    } finally {
      _polling = false;
    }
  }

  /// Throws [Failure] on error.
  Future<void> markRead(AppNotification notification) async {
    if (notification.read) return;
    await ref.read(notificationRepositoryProvider).markRead(notification.id);
    if (!ref.mounted) return;
    final inbox = state.value;
    if (inbox == null) return;
    state = AsyncData(
      NotificationInbox(
        unread: inbox.unread > 0 ? inbox.unread - 1 : 0,
        items: [
          for (final n in inbox.items)
            n.id == notification.id ? n.markedRead() : n,
        ],
      ),
    );
  }

  /// Throws [Failure] on error.
  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    if (!ref.mounted) return;
    final inbox = state.value;
    if (inbox == null) return;
    state = AsyncData(
      NotificationInbox(
        unread: 0,
        items: [for (final n in inbox.items) n.read ? n : n.markedRead()],
      ),
    );
  }
}

final notificationsProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsController,
      NotificationInbox
    >(NotificationsController.new);
