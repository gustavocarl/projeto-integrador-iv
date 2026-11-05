import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/presentation/controllers/store_providers.dart';
import '../../domain/entities/app_notification.dart';
import '../controllers/notifications_controller.dart';
import '../pages/notifications_page.dart';

/// The bell in the app bar: unread counter, opens the notification center and warns (SnackBar)
/// when a new notification arrives. While it is on screen it asks the backend again every
/// [NotificationsController.pollInterval].
class NotificationsButton extends ConsumerStatefulWidget {
  const NotificationsButton({super.key});

  static void open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const NotificationsPage()));

  @override
  ConsumerState<NotificationsButton> createState() =>
      _NotificationsButtonState();
}

class _NotificationsButtonState extends ConsumerState<NotificationsButton> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      NotificationsController.pollInterval,
      (_) => ref.read(notificationsProvider.notifier).poll(),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _onChange(NotificationInbox? before, NotificationInbox? after) {
    // The first load is not news.
    if (before == null || after == null) return;
    final known = {for (final n in before.items) n.id};
    final fresh = [
      for (final n in after.items)
        if (!n.read && !known.contains(n.id)) n,
    ];
    if (fresh.isEmpty) return;

    // A new access request: the admin's list (and its counter) must show it.
    if (fresh.any((n) => n.kind == NotificationKind.accessRequested)) {
      ref.invalidate(storeMembersProvider);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            fresh.length == 1
                ? fresh.single.message
                : '${fresh.length} novas notificações.',
          ),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => NotificationsButton.open(context),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      notificationsProvider,
      (previous, next) => _onChange(previous?.value, next.value),
    );
    final unread = ref.watch(
      notificationsProvider.select((inbox) => inbox.value?.unread ?? 0),
    );
    return IconButton(
      key: const Key('notificationsButton'),
      tooltip: switch (unread) {
        0 => 'Notificações',
        1 => 'Notificações (1 não lida)',
        _ => 'Notificações ($unread não lidas)',
      },
      onPressed: () => NotificationsButton.open(context),
      icon: Badge.count(
        key: const Key('notificationsBadge'),
        count: unread,
        isLabelVisible: unread > 0,
        child: Icon(
          unread > 0 ? Icons.notifications : Icons.notifications_outlined,
        ),
      ),
    );
  }
}
