import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/brand.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../store/presentation/controllers/store_providers.dart';
import '../../../store/presentation/pages/store_member_page.dart';
import '../../domain/entities/app_notification.dart';
import '../controllers/notifications_controller.dart';
import '../widgets/notification_view.dart';

/// The notification center: newest first. Tapping an access request opens it to approve.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends BaseState<NotificationsPage> {
  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _open(AppNotification notification) async {
    final notifications = ref.read(notificationsProvider.notifier);
    await runSafely(() => notifications.markRead(notification));
    if (!mounted) return;

    final isAdmin =
        ref.read(authControllerProvider).value?.store?.isAdmin ?? false;
    if (notification.kind != NotificationKind.accessRequested ||
        notification.relatedUserId == null ||
        !isAdmin) {
      return;
    }

    final members = await runSafely(
      () => ref.refresh(storeMembersProvider.future),
    );
    if (members == null || !mounted) return;
    final member = members
        .where((m) => m.id == notification.relatedUserId && m.isPending)
        .firstOrNull;
    if (member == null) {
      _message('Este pedido já foi respondido.');
      return;
    }

    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => StoreMemberPage(member: member)),
    );
    if (message != null && mounted) _message(message);
  }

  Future<void> _markAll() async {
    await runSafely(
      () => ref.read(notificationsProvider.notifier).markAllRead(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(notificationsProvider);
    final isAdmin = ref.watch(
      authControllerProvider.select((s) => s.value?.store?.isAdmin ?? false),
    );
    // Keeps the admin's list alive while this page is open (opening a request uses it).
    if (isAdmin) ref.watch(storeMembersProvider);
    final unread = inbox.value?.unread ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (unread > 0)
            // An icon: the label would squeeze the title on phones.
            IconButton(
              key: const Key('markAllRead'),
              tooltip: 'Marcar todas como lidas',
              onPressed: isLoading ? null : _markAll,
              icon: const Icon(Icons.done_all),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).poll(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: switch (inbox) {
              AsyncValue(:final value?) when value.items.isEmpty => ListView(
                children: const [
                  SizedBox(height: 48),
                  EmptyState(
                    key: Key('noNotifications'),
                    icon: Icons.notifications_none,
                    title: 'Nenhuma notificação',
                    message: 'Pedidos de acesso à loja e outros avisos aparecem aqui.',
                  ),
                ],
              ),
              AsyncValue(:final value?) => ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: value.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _NotificationTile(
                  notification: value.items[i],
                  onTap: isLoading ? null : () => _open(value.items[i]),
                ),
              ),
              AsyncError(:final error) => ListView(
                children: [
                  const SizedBox(height: 48),
                  EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Não foi possível carregar as notificações',
                    message: error is Failure
                        ? error.generalMessages.join('\n')
                        : 'Tente novamente.',
                  ),
                ],
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.read;
    final opensRequest =
        notification.kind == NotificationKind.accessRequested && unread;
    return ListTile(
      key: Key('notification_${notification.id}'),
      onTap: onTap,
      tileColor: unread
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
          : null,
      leading: Badge(
        isLabelVisible: unread,
        smallSize: 10,
        child: CircleAvatar(
          backgroundColor: unread
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: unread
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          child: Icon(notification.kind.icon),
        ),
      ),
      title: Text(
        notification.message,
        style: unread
            ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
            : theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        [
          Formatters.dateTime(notification.createdAt),
          if (opensRequest) 'Toque para aprovar ou recusar',
        ].join('\n'),
      ),
      isThreeLine: opensRequest,
    );
  }
}
