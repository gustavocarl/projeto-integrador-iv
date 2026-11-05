import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/base_state.dart';
import '../../../../core/errors/failure.dart';
import '../../../../shared/widgets/brand.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/store.dart';
import '../controllers/store_providers.dart';
import '../widgets/store_area_view.dart';
import 'store_member_page.dart';

/// Admin: the store (name) and its users — pending requests first.
class StoreUsersPage extends ConsumerStatefulWidget {
  const StoreUsersPage({super.key});

  @override
  ConsumerState<StoreUsersPage> createState() => _StoreUsersPageState();
}

class _StoreUsersPageState extends BaseState<StoreUsersPage> {
  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _open(StoreMember member) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => StoreMemberPage(member: member)),
    );
    if (message != null && mounted) _message(message);
  }

  Future<void> _rename(String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: current),
    );
    if (name == null || name.trim() == current) return;
    final user = await runSafely(
      () => ref.read(authControllerProvider.notifier).renameStore(name.trim()),
    );
    if (user != null && mounted) _message('Loja renomeada.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).value;
    final store = user?.store;
    final members = ref.watch(storeMembersProvider);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Loja e usuários')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(storeMembersProvider.future),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (store != null)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  store.name,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Renomear a loja',
                                onPressed: isLoading
                                    ? null
                                    : () => _rename(store.name),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              'Quem vai trabalhar na loja cria a conta informando o '
                              'nome dela. Você recebe uma notificação e o pedido '
                              'aparece aqui para aprovar e escolher o que a pessoa '
                              'pode usar.',
                              style: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ...switch (members) {
                  AsyncValue(:final value?) => _members(value, user?.id),
                  AsyncError(:final error) => [
                    EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Não foi possível carregar os usuários',
                      message: error is Failure
                          ? error.generalMessages.join('\n')
                          : null,
                      action: FilledButton.tonal(
                        onPressed: () => ref.invalidate(storeMembersProvider),
                        child: const Text('Tentar de novo'),
                      ),
                    ),
                  ],
                  _ => const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _members(List<StoreMember> members, String? myId) {
    final pending = members.where((m) => m.isPending).toList();
    final active = members.where((m) => !m.isPending).toList();
    return [
      if (pending.isNotEmpty) ...[
        _Header('Pedidos de acesso (${pending.length})'),
        for (final m in pending)
          _MemberTile(member: m, isMe: false, onTap: () => _open(m)),
        const SizedBox(height: 16),
      ],
      _Header('Usuários (${active.length})'),
      for (final m in active)
        _MemberTile(member: m, isMe: m.id == myId, onTap: () => _open(m)),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.onTap,
  });

  final StoreMember member;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = member.name.trim().isEmpty
        ? '?'
        : member.name.trim()[0].toUpperCase();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: member.isAdmin
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: member.isAdmin
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          child: Text(initial),
        ),
        title: Text(isMe ? '${member.name} (você)' : member.name),
        subtitle: Text(
          member.isPending
              ? '${member.email}\nToque para aprovar ou recusar'
              : '${member.email}\n${member.role.label} · ${areasSummary(member.areas)}',
        ),
        isThreeLine: true,
        trailing: Icon(
          member.isPending ? Icons.how_to_reg_outlined : Icons.chevron_right,
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nome da loja'),
    content: TextField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      onSubmitted: (value) => Navigator.pop(context, value),
      decoration: const InputDecoration(labelText: 'Nome da loja'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _name.text),
        child: const Text('Salvar'),
      ),
    ],
  );
}
