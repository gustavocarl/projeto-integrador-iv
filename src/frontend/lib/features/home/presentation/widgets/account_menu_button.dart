import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/pages/change_password_page.dart';
import '../../../settings/presentation/pages/user_settings_page.dart';
import '../../../store/presentation/controllers/store_providers.dart';
import '../../../store/presentation/pages/store_users_page.dart';
import '../../../store/presentation/widgets/store_area_view.dart';

/// The user's initial in the app bar; opens who is logged in (and their store), "Loja e
/// usuários" for admins (with the pending requests count on the item), the "Configurações do usuário"
/// menu (preferences, change password) and "Sair".
///
/// The user settings expand inside the same menu instead of a side submenu: next to the
/// screen edge a cascading submenu has no room and covers its own label on phones.
class AccountMenuButton extends ConsumerStatefulWidget {
  const AccountMenuButton({super.key, required this.user});

  final User user;

  @override
  ConsumerState<AccountMenuButton> createState() => _AccountMenuButtonState();
}

class _AccountMenuButtonState extends ConsumerState<AccountMenuButton> {
  bool _settingsOpen = false;

  Future<void> _changePassword() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Senha alterada.')));
    }
  }

  void _openPreferences() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const UserSettingsPage()));

  void _openStore() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const StoreUsersPage()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    final store = user.store;
    final isAdmin = store?.isAdmin ?? false;
    // Admins see how many people are waiting for approval.
    final pending = isAdmin
        ? ref.watch(
            storeMembersProvider.select(
              (members) => members.value?.where((m) => m.isPending).length ?? 0,
            ),
          )
        : 0;
    final initial = user.name.trim().isEmpty
        ? '?'
        : user.name.trim()[0].toUpperCase();

    return MenuAnchor(
      alignmentOffset: const Offset(-200, 0),
      // Opens collapsed every time.
      onClose: () {
        if (mounted) setState(() => _settingsOpen = false);
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: theme.textTheme.titleSmall),
              Text(
                user.email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (store != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${store.name} · ${store.role.label}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        if (isAdmin)
          MenuItemButton(
            leadingIcon: const Icon(Icons.storefront_outlined),
            trailingIcon: pending > 0
                ? Badge.count(key: const Key('pendingBadge'), count: pending)
                : null,
            onPressed: _openStore,
            child: const Text('Loja e usuários'),
          ),
        Semantics(
          expanded: _settingsOpen,
          child: MenuItemButton(
            closeOnActivate: false,
            leadingIcon: const Icon(Icons.manage_accounts_outlined),
            trailingIcon: Icon(
              _settingsOpen ? Icons.expand_less : Icons.expand_more,
            ),
            onPressed: () => setState(() => _settingsOpen = !_settingsOpen),
            child: const Text('Configurações do usuário'),
          ),
        ),
        if (_settingsOpen)
          MenuItemButton(
            // Indented under "Configurações do usuário".
            style: MenuItemButton.styleFrom(
              padding: const EdgeInsets.only(left: 40, right: 12),
            ),
            leadingIcon: const Icon(Icons.tune),
            onPressed: _openPreferences,
            child: const Text('Preferências'),
          ),
        if (_settingsOpen)
          MenuItemButton(
            // Indented under "Configurações do usuário".
            style: MenuItemButton.styleFrom(
              padding: const EdgeInsets.only(left: 40, right: 12),
            ),
            leadingIcon: const Icon(Icons.lock_reset),
            onPressed: _changePassword,
            child: const Text('Alterar senha'),
          ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('Sair'),
        ),
      ],
      // New requests are announced by the notification bell next to it.
      builder: (context, controller, _) => IconButton(
        tooltip: 'Conta',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text(initial, style: theme.textTheme.labelLarge),
        ),
      ),
    );
  }
}
